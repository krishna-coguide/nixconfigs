# Included by writeShellApplication: bash and PATH are supplied by Nix.
set -euo pipefail
if [[ ${1:-} == --help ]]; then
  echo 'Usage: nix run .#agent -- [run | ssh [command ...] | url | stop]'
  echo 'Workspace = cwd. RW config/credentials/skills = DSH_HOME (default ~/.dsh)'
  echo 'Also shares DSH_AGENTS_HOME/skills (default ~/.agents/skills). RAM/CPU/network: flake.'
  exit 0
fi
[[ $EUID != 0 ]] || { echo 'Run as your normal host user, not sudo/root.' >&2; exit 1; }
umask 077
project=$(pwd -P)
dsh=$(realpath -m "${DSH_HOME:-$HOME/.dsh}")
skills=$(realpath -m "${DSH_AGENTS_HOME:-$HOME/.agents}/skills")
state=$(realpath -m "${XDG_STATE_HOME:-$HOME/.local/state}/agent-vm/$(printf %s "$project" | sha256sum | cut -c1-16)")
for path in "$project" "$dsh" "$skills"; do
  case "$path" in /|/home|/etc|/nix|/nix/*|/proc|/proc/*|/sys|/sys/*|/dev|/dev/*|/run|/run/*|"$HOME"|*$'\n'*) echo "Refusing broad/system share: $path" >&2; exit 1;; esac
  [[ $state != "$path" && $state != "$path/"* ]] || { echo 'State must be outside shared directories.' >&2; exit 1; }
done
# Prevent a broad workspace/config mount from accidentally including other mounts.
disjoint() {
  [[ $1 != "$2" && $1 != "$2/"* && $2 != "$1/"* ]] || { echo 'Writable shares must not overlap.' >&2; exit 1; }
}
disjoint "$project" "$dsh"; disjoint "$project" "$skills"; disjoint "$dsh" "$skills"
ssh_cmd=(ssh -F /dev/null -i "$state/client-key" -p "$AGENT_SSH_PORT"
  -o IdentitiesOnly=yes -o IdentityAgent=none -o ForwardAgent=no -o BatchMode=yes
  -o StrictHostKeyChecking=yes -o HostKeyAlias=agent-vm -o ConnectTimeout=3
  -o "UserKnownHostsFile=$state/known_hosts" -o GlobalKnownHostsFile=/dev/null)
remote="root@$AGENT_SSH_HOST"
url() {
  local found address=$AGENT_WEB_BIND
  [[ $address != 0.0.0.0 ]] || address=127.0.0.1
  found=$("${ssh_cmd[@]}" "$remote" 'journalctl -u agent -b -o cat --no-pager' |
    grep -oE 'http://127\.0\.0\.1:3080/\?token=[a-zA-Z0-9_%.-]+' | tail -1) || return 1
  [[ -n $found ]] || return 1
  printf '%s\n' "${found/http:\/\/127.0.0.1:3080/http:\/\/$address:$AGENT_WEB_PORT}"
}
# Expand cwd inside the guest, not on the host.
# shellcheck disable=SC2016
case ${1:-run} in
  ssh) shift; if (( $# )); then exec "${ssh_cmd[@]}" "$remote" 'cd -- "$(cat /run/agent-vm/workdir)" || exit; '"$*"; else exec "${ssh_cmd[@]}" -t "$remote" 'cd -- "$(cat /run/agent-vm/workdir)" || exit; exec bash -l'; fi;;
  url) url || { echo "DSH not ready; inspect: nix run .#agent -- ssh 'journalctl -u agent -b'" >&2; exit 1; }; exit;;
  stop) cd "$state"; exec "$AGENT_RUNNER/microvm-shutdown";;
  run) [[ $# -le 1 ]] || { echo 'Unexpected run arguments; use --help.' >&2; exit 1; };;
  *) echo 'Unknown command; use --help.' >&2; exit 1;;
esac
[[ -r /dev/kvm && -w /dev/kvm ]] || { echo 'Need read/write access to /dev/kvm.' >&2; exit 1; }
mkdir -p "$state" "$dsh" "$skills"
for dir in "$state" "$dsh"; do
  [[ $(stat -c %u "$dir") == "$(id -u)" && $(stat -c %a "$dir") == 700 ]] || {
    echo "Make this directory private and user-owned first: $dir (chmod 700)" >&2; exit 1;
  }
done
exec 9>"$state/run.lock"
flock -n 9 || { echo 'This project VM is already running.' >&2; exit 1; }
for key in client-key ssh-host-key; do
  [[ -f $state/$key ]] || ssh-keygen -q -t ed25519 -N '' -C agent-vm -f "$state/$key"
done
printf '%s\n' "$project" > "$state/workdir"
cp "$state/client-key.pub" "$state/ssh-authorized-key"
printf 'agent-vm %s\n' "$(cut -d' ' -f1,2 "$state/ssh-host-key.pub")" > "$state/known_hosts"
printf 'RW workspace: %s -> /workspace\nRW DSH home: %s\nRW shared skills: %s\nConsole log: %s/console.log\n' "$project" "$dsh" "$skills" "$state"
if [[ $AGENT_WEB_BIND != 127.0.0.1 ]]; then
  echo 'WARNING: off-host Web access is plaintext HTTP. Use a VPN/TLS; never expose directly to the Internet.' >&2
fi
vm_pid=''
tunnel_pid=''
cleanup() {
  trap - EXIT INT TERM
  if [[ -n $vm_pid ]] && kill -0 "$vm_pid" 2>/dev/null; then
    (cd "$state"; timeout 30 "$AGENT_RUNNER/microvm-shutdown") >/dev/null 2>&1 || true
    kill "$vm_pid" 2>/dev/null || true
    wait "$vm_pid" 2>/dev/null || true
  fi
  if [[ -n $tunnel_pid ]]; then kill "$tunnel_pid" 2>/dev/null || true; wait "$tunnel_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Host-side defense in depth around QEMU. No host home/session sockets or other
# processes; only the three explicit shares and private VM control state are RW.
# Network is intentionally inherited for API access (not an egress firewall).
devices=()
[[ $AGENT_NETWORK != tap ]] || devices=(--dev-bind /dev/net/tun /dev/net/tun)
bwrap "${devices[@]}" --die-with-parent --new-session --unshare-user --unshare-pid --unshare-ipc \
  --unshare-uts --unshare-cgroup-try --cap-drop ALL --clearenv \
  --setenv HOME /tmp --setenv PATH /no-host-path --setenv LANG C.UTF-8 \
  --ro-bind /nix/store /nix/store --proc /proc --dev /dev --dev-bind /dev/kvm /dev/kvm \
  --tmpfs /tmp --bind "$state" /state --bind "$project" /workspace \
  --bind "$dsh" /dsh-home --bind "$skills" /skills \
  --ro-bind-try /etc/resolv.conf /etc/resolv.conf --ro-bind-try /etc/hosts /etc/hosts \
  --chdir /state "$AGENT_RUNNER/microvm-run" >"$state/console.log" 2>&1 &
vm_pid=$!
ready=false
for ((i=0; i<90; i++)); do
  kill -0 "$vm_pid" 2>/dev/null || { echo "VM exited; see $state/console.log" >&2; exit 1; }
  if "${ssh_cmd[@]}" "$remote" true 2>/dev/null; then ready=true; break; fi
  sleep 1
done
$ready || { echo "SSH boot timeout; see $state/console.log" >&2; exit 1; }
# DSH deliberately refuses --host 0.0.0.0. Keep its own authenticated browser
# endpoint on guest loopback and publish an SSH forward on the chosen host IP.
"${ssh_cmd[@]}" -N -g -o ExitOnForwardFailure=yes -o ServerAliveInterval=10 \
  -o ServerAliveCountMax=3 -L "$AGENT_WEB_BIND:$AGENT_WEB_PORT:127.0.0.1:3080" \
  "$remote" >>"$state/console.log" 2>&1 &
tunnel_pid=$!
echo "Booted. DSH resolves npm @latest on startup; first launch may take a few minutes."
echo 'Use another terminal: nix run .#agent -- url   (or: ssh / stop)'
printed=false
while kill -0 "$vm_pid" 2>/dev/null; do
  # Normal guest poweroff can close SSH slightly before QEMU exits.
  if ! kill -0 "$tunnel_pid" 2>/dev/null; then
    timeout 30 tail --pid="$vm_pid" -f /dev/null || true
    if kill -0 "$vm_pid" 2>/dev/null; then echo "Web tunnel exited; see $state/console.log" >&2; exit 1; fi
    break
  fi
  if ! $printed; then
    if login_url=$(url 2>/dev/null); then printf 'Private login URL: %s\n' "$login_url"; printed=true; fi
  fi
  sleep 2
done
wait "$vm_pid"
