#!/usr/bin/env bash
# Apply this laptop's checkout, never the separate EC2 "dev" configuration.
set -euo pipefail

usage() {
  printf 'Usage: %s [switch|dry-activate|boot|test]\n' "$0"
  printf '%s\n' \
    'Build /etc/nix#nixos using flake.lock; default: switch now and save for boot.' \
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

if ((EUID != 0)); then
  exec sudo -- "$(readlink -f -- "${BASH_SOURCE[0]}")" "$@"
fi

# Share the existing updater's lock so it cannot change the checkout/profile
# underneath this build and activation.
mkdir -p /var/cache/nixos-update
exec 9>/var/cache/nixos-update/lock
flock 9

cd /etc/nix
printf 'Building the current /etc/nix checkout for nixos (%s).\n' "$action"
built=$(nix build .#nixosConfigurations.nixos.config.system.build.toplevel \
  --no-update-lock-file --no-link --print-out-paths)
exec "$built/sw/bin/nixos-rebuild" "$action" --no-reexec --store-path "$built"
