#!/usr/bin/env bash
# The installed command gets its host/path from updates.nix on both machines.
# Direct execution requires an explicit host: both machines use the dev account.
set -euo pipefail
repo=${NIXOS_CONFIG_REPO:-/etc/nix}
host=${NIXOS_UPDATE_HOST:-}

usage() {
  printf 'Usage: %s [switch|dry-activate|boot|test]\n' "$0"
  printf 'Build %s#%s using flake.lock.\n' "$repo" "${host:-<host>}"
  printf '%s\n' \
    'NIXOS_UPDATE_HOST is required: select a target from hosts.nix.' \
    'NIXOS_CONFIG_REPO selects the checkout (default: /etc/nix).' \
    'Default: switch now and save for boot (an explicit manual action).' \
    'dry-activate previews changes; boot stages them; test applies temporarily.' \
    'Creates the dev account (UID 1001) if missing, e.g. on a fresh NixOS machine.' \
    'Does not pull Git, update package pins, delete generations, or reboot.'
}

if [[ $# -eq 1 && ($1 == --help || $1 == -h) ]]; then
  usage
  exit 0
fi
if (($# > 1)); then
  usage >&2
  exit 2
fi
action=${1:-switch}
case "$action" in
  switch | dry-activate | boot | test) ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# Permit new hosts without editing this script; reject selector/path injection.
# Nix rejects a well-formed but nonexistent flake target before any activation.
if [[ ! $host =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
  printf '%s\n' 'Set NIXOS_UPDATE_HOST to an explicit target from hosts.nix (letters, digits, _ or -; not a leading digit).' \
    'Refusing an empty/invalid target; never guessing from the login name.' >&2
  exit 2
fi

# A fresh NixOS machine has no dev account until this configuration is active.
# Create it as users.nix declares it (UID 1001, users, wheel) so the checkout
# owner exists; activation then applies its shell, SSH keys and sudo rule.
# No password is set: mutable users keep a locally provisioned one.
if ! id -u dev >/dev/null 2>&1; then
  if ((EUID != 0)); then
    printf '%s\n' 'The dev account does not exist yet; re-running with sudo to create it.' >&2
    exec sudo env NIXOS_CONFIG_REPO="$repo" NIXOS_UPDATE_HOST="$host" \
      "$(readlink -f -- "${BASH_SOURCE[0]}")" "$@"
  fi
  printf '%s\n' 'Creating the dev account (UID 1001) declared in users.nix.'
  useradd --uid 1001 --gid users --groups wheel --comment 'Development user' \
    --home-dir /home/dev --no-create-home dev
  install -d -m 0700 -o dev -g users /home/dev
fi

# Keep builds/Git access under the checkout owner, including when invoked via sudo.
# Only activating the built system needs root. Root activates directly: before
# the first activation a new dev account has no sudo rule or password.
as_dev=()
as_root=(sudo)
state=${CACHE_DIRECTORY:-/var/cache/nixos-update}
if ((EUID == 0)); then
  as_dev=(runuser -u dev --)
  as_root=()
  # updates.nix manages these after activation; seed them dev-owned beforehand.
  [[ -d $state ]] || install -d -m 0700 -o dev -g users "$state"
  [[ -e $state/lock ]] || install -m 0600 -o dev -g users /dev/null "$state/lock"
  if [[ $(stat -c %U -- "$repo") != dev ]]; then
    printf 'Giving dev ownership of %s, as updates.nix does on activation.\n' "$repo"
    chown -hR dev:users -- "$repo"
  fi
fi

# Share the automatic updater's lock. Directory ownership is managed by NixOS.
mkdir -p "$state"
exec 9>"$state/lock"
flock 9

cd "$repo"
printf 'Building %s#%s (%s).\n' "$repo" "$host" "$action"
# Flakes are not yet enabled on a fresh machine; common.nix enables them later.
built=$("${as_dev[@]}" nix --extra-experimental-features 'nix-command flakes' build \
  ".#nixosConfigurations.$host.config.system.build.toplevel" \
  --no-update-lock-file --no-link --print-out-paths)
# Keep this shell alive holding the lock: sudo closes inherited descriptors.
"${as_root[@]}" "$built/sw/bin/nixos-rebuild" "$action" --no-reexec --store-path "$built"
