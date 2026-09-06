#!/usr/bin/env bash
# The installed command gets its host/path from updates.nix on both machines.
# Direct execution from this checkout defaults to the laptop, never the login name.
set -euo pipefail
repo=${NIXOS_CONFIG_REPO:-/etc/nix}
host=${NIXOS_UPDATE_HOST:-nixos}

usage() {
  printf 'Usage: %s [switch|dry-activate|boot|test]\n' "$0"
  printf 'Build %s#%s using flake.lock.\n' "$repo" "$host"
  printf '%s\n' \
    'Default: switch now and save for boot (an explicit manual action).' \
    'dry-activate previews changes; boot stages them; test applies temporarily.' \
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

case "$host" in
  nixos | dev) ;;
  *)
    printf 'Unsupported host: %s\n' "$host" >&2
    exit 2
    ;;
esac

# Keep builds/Git access under the checkout owner, including when invoked via sudo.
# Only activating the built system needs root.
if ((EUID == 0)); then
  exec runuser -u dev -- env NIXOS_CONFIG_REPO="$repo" NIXOS_UPDATE_HOST="$host" \
    "$(readlink -f -- "${BASH_SOURCE[0]}")" "$@"
fi
sudo -v

# Share the automatic updater's lock. Directory ownership is managed by NixOS.
state=${CACHE_DIRECTORY:-/var/cache/nixos-update}
mkdir -p "$state"
exec 9>"$state/lock"
flock 9

cd "$repo"
printf 'Building %s#%s (%s).\n' "$repo" "$host" "$action"
built=$(nix build ".#nixosConfigurations.$host.config.system.build.toplevel" \
  --no-update-lock-file --no-link --print-out-paths)
# Keep this shell alive holding the lock: sudo closes inherited descriptors.
sudo "$built/sw/bin/nixos-rebuild" "$action" --no-reexec --store-path "$built"
