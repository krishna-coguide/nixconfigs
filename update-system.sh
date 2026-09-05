# Run as dev; privileged activation uses the already declared scoped sudo rule.
repo=${NIXOS_CONFIG_REPO:-/etc/nixos}
state=${CACHE_DIRECTORY:-/var/cache/nixos-update}
mkdir -p "$state"
exec 9>"$state/lock"
flock -n 9 || exit 0

cd "$repo"
if [ -n "$(git status --porcelain)" ]; then
  echo 'Skipping automatic update: the configuration has local changes.'
  exit 0
fi
baseline=$(git rev-parse HEAD)
branch=$(git symbolic-ref HEAD)
work=$(mktemp -d "$state/work.XXXXXXXX")
cleanup() {
  git -C "$repo" worktree remove --force "$work" >/dev/null 2>&1 || true
  rm -rf -- "$work"
}
trap cleanup EXIT

git worktree add --detach "$work" "$baseline"
cd "$work"
# Only these stable release inputs advance. Neovim's source stays pinned.
nix flake update nixpkgs home-manager
if git diff --quiet -- flake.lock; then
  echo 'Stable inputs are already current.'
  exit 0
fi
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.updates .#checks.x86_64-linux.desktop-config \
  --no-update-lock-file --no-link
git add flake.lock
git -c user.name='NixOS Updater' -c user.email='nixos-updater@localhost' \
  commit -m 'chore: update stable NixOS and Home Manager inputs'
built=$(nix build .#nixosConfigurations.dev.config.system.build.toplevel \
  --no-update-lock-file --no-link --print-out-paths)
candidate=$(git rev-parse HEAD)

# Never overwrite work started while the candidate was building.
cd "$repo"
if [ "$(git rev-parse HEAD)" != "$baseline" ] || \
   [ "$(git symbolic-ref HEAD)" != "$branch" ] || \
   [ -n "$(git status --porcelain)" ]; then
  echo 'Configuration changed during the build; leaving it untouched.'
  exit 0
fi
previous=$(readlink -f /run/current-system)
sudo "$built/sw/bin/nixos-rebuild" dry-activate --no-reexec --store-path "$built"
git merge --ff-only "$candidate"
if ! sudo "$built/sw/bin/nixos-rebuild" switch --no-reexec --store-path "$built"; then
  echo 'Activation failed; restoring the previous system. See the journal.' >&2
  sudo "$previous/sw/bin/nixos-rebuild" switch --no-reexec --store-path "$previous"
  if [ "$(git rev-parse HEAD)" = "$candidate" ] && [ -z "$(git status --porcelain)" ]; then
    git -c user.name='NixOS Updater' -c user.email='nixos-updater@localhost' \
      revert --no-edit "$candidate"
  fi
  exit 1
fi
# No forced reboot or garbage collection: recovery generations are retained.
