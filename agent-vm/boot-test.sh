#!/usr/bin/env bash
# Offline test of the real microvm.nix runner, mounts, SSH and host-side sandbox.
set -euo pipefail
launcher=$1
browser_test=${2:-}
tmp=$(mktemp -d)
export HOME=$tmp/home DSH_HOME=$tmp/dsh DSH_AGENTS_HOME=$tmp/agents XDG_STATE_HOME=$tmp/state
mkdir -p "$HOME" "$tmp/project" "$DSH_HOME/skills" "$DSH_AGENTS_HOME/skills"
chmod 700 "$DSH_HOME"
printf 'not shared\n' > "$HOME/host-only-secret"
ln -s "$HOME/host-only-secret" "$tmp/project/escape"
cd "$tmp/project"
"$launcher" run > "$tmp/launcher.log" 2>&1 &
pid=$!
cleanup() {
  status=$?
  if (( status )); then
    grep -h . "$tmp/launcher.log" "$XDG_STATE_HOME"/agent-vm/*/console.log | tail -80 || true
  fi
  "$launcher" stop >/dev/null 2>&1 || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  # Never delete real project/config data; everything here is a test fixture.
  rm -rf "$tmp"
  return "$status"
}
trap cleanup EXIT
ready=false
for ((i=0; i<120; i++)); do
  if "$launcher" ssh true 2>/dev/null; then ready=true; break; fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 2
done
if ! $ready; then
  grep -h . "$tmp/launcher.log" "$XDG_STATE_HOME"/agent-vm/*/console.log || true
  exit 1
fi
[[ $("$launcher" ssh 'id -u') == 0 ]]
[[ $("$launcher" ssh pwd) == "$tmp/project" ]]
[[ $("$launcher" ssh nproc) == 4 ]]
[[ $("$launcher" ssh 'printenv AGENT_PROJECT_TEST') == shared ]]
[[ $("$launcher" ssh hello) == 'Hello, world!' ]]
"$launcher" ssh 'test ! -e /workspace/escape; test ! -e /run/host; test -d /nix/.rw-store'
"$launcher" ssh 'printf edited > /workspace/changed; printf config > /root/.dsh/config-test; printf creds > /root/.dsh/credentials-test; printf skill > /root/.dsh/skills/test.md; printf shared > /root/.agents/skills/test.md'
[[ $(< changed) == edited && $(< "$DSH_HOME/config-test") == config ]]
[[ $(< "$DSH_HOME/credentials-test") == creds && $(< "$DSH_HOME/skills/test.md") == skill ]]
[[ $(< "$DSH_AGENTS_HOME/skills/test.md") == shared ]]
[[ $(stat -c %u changed) == "$(id -u)" ]]
"$launcher" ssh 'command -v rg python3 git playwright-cli; findmnt /workspace; findmnt /root/.dsh'
# pnpm's atomic saves preserve ownership; these chowns must work over 9p.
"$launcher" ssh 'chown 0:0 /root/.dsh/config-test; chown --reference=/root/.dsh/config-test /root/.dsh/credentials-test'
"$launcher" ssh 'systemctl start agent.service; test ! -e /tmp/.X11-unix/X0'
skill="$DSH_AGENTS_HOME/skills/playwright-firefox/SKILL.md"
grep -q '^name: playwright-firefox$' "$skill"
[[ ! -L $skill && -w $skill && $(stat -c %a "$skill") == 600 ]]
[[ $(stat -c %u "$skill") == "$(id -u)" ]]
printf '\nuser customization\n' >> "$skill"
manifest="$DSH_HOME/profiles/web/package.json"
[[ $(< "$DSH_HOME/plugin-calls") == 'plugin --profile web add dsh-context@latest' ]]
[[ -f $DSH_HOME/profiles/web/node_modules/dsh-context/package.json ]]
[[ ! -L $manifest && -w $manifest && $(stat -c %a "$manifest") == 600 ]]
[[ $(stat -c %u "$manifest") == "$(id -u)" ]]
cp "$manifest" "$tmp/installed.json"
"$launcher" ssh 'systemctl restart agent.service'
grep -q '^user customization$' "$skill"
[[ $(wc -l < "$DSH_HOME/plugin-calls") == 1 ]]
cmp "$manifest" "$tmp/installed.json"
if [[ -n $browser_test ]]; then
  cp "$browser_test" ./playwright-test.sh
  "$launcher" ssh 'bash ./playwright-test.sh'
fi
# A second start must fail without disrupting the existing VM.
if "$launcher" run >/dev/null 2>&1; then echo 'Duplicate launch succeeded' >&2; exit 1; fi
"$launcher" stop
wait "$pid"
trap - EXIT
rm -rf "$tmp"
echo 'PASS: microVM boot, root SSH, shared toolchain, RW cwd/config/creds/skills, writable non-clobbering skill seed, context-only plugin setup preserved on restart, headless browser CLI, host ownership, symlink isolation, duplicate lock, shutdown'
