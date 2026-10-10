# Both hosts stage for the next boot. Only the checkout and flake target differ;
# target identity is explicit, never inferred from the login name.
repo=${NIXOS_CONFIG_REPO:?Set NIXOS_CONFIG_REPO}
host=${NIXOS_UPDATE_HOST:?Set NIXOS_UPDATE_HOST}
if [[ ! $host =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
  echo "Refusing invalid update target: $host" >&2
  exit 2
fi
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
if ! branch=$(git symbolic-ref -q HEAD); then
  echo 'Skipping automatic update: checkout is detached.'
  exit 0
fi
work=$(mktemp -d "$state/work.XXXXXXXX")
cleanup() {
  git -C "$repo" worktree remove --force "$work" >/dev/null 2>&1 || true
  rm -rf -- "$work"
}
trap cleanup EXIT

git worktree add --detach "$work" "$baseline"
cd "$work"
# Advance package inputs to newest resolving branch heads.
nix flake update nixpkgs home-manager nixpkgs-latest
if git diff --quiet -- flake.lock; then
  echo 'Package inputs are already current.'
  exit 0
fi
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.updates .#checks.x86_64-linux.desktop-config \
  .#checks.x86_64-linux.physical-config .#checks.x86_64-linux.tools \
  .#checks.x86_64-linux.desktop-actions .#checks.x86_64-linux.switch-system \
  --no-update-lock-file --no-link
git add flake.lock
git -c user.name='NixOS Updater' -c user.email='nixos-updater@localhost' \
  commit -m 'chore: update NixOS package inputs'
built=$(nix build ".#nixosConfigurations.$host.config.system.build.toplevel" \
  --no-update-lock-file --no-link --print-out-paths)
candidate=$(git rev-parse HEAD)

# Never overwrite work started while the candidate was building.
cd "$repo"
unchanged() {
  [ "$(git rev-parse HEAD)" = "$baseline" ] &&
  [ "$(git symbolic-ref -q HEAD)" = "$branch" ] &&
  [ -z "$(git status --porcelain)" ]
}
if ! unchanged; then
  echo 'Configuration changed during the build; leaving it untouched.'
  exit 0
fi
# Preserve an already staged generation on failure, not just the running one.
previous=$(readlink -f /nix/var/nix/profiles/system)
sudo "$built/sw/bin/nixos-rebuild" dry-activate --no-reexec --store-path "$built"
if ! unchanged; then
  echo 'Configuration changed during dry activation; leaving it untouched.'
  exit 0
fi
git merge --ff-only "$candidate"
if ! sudo "$built/sw/bin/nixos-rebuild" boot --no-reexec --store-path "$built"; then
  echo 'Staging failed; restoring the previous boot generation. See the journal.' >&2
  sudo "$previous/sw/bin/nixos-rebuild" boot --no-reexec --store-path "$previous"
  if [ "$(git rev-parse HEAD)" = "$candidate" ] && [ -z "$(git status --porcelain)" ]; then
    git -c user.name='NixOS Updater' -c user.email='nixos-updater@localhost' \
      revert --no-edit "$candidate"
  fi
  exit 1
fi
printf '%s %s %s\n' "$(date -Is)" "$candidate" "$built" > "$state/last-success"
echo "Updated $host (staged for next boot): $built"
# No forced reboot or garbage collection: recovery generations are retained.
