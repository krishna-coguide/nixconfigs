#!/usr/bin/env bash
# Optional render node moves GPU work out of QEMU TCG; no physical display is changed.
set -euo pipefail
umask 077
if [[ "${1:-}" == --help ]]; then
  echo 'Usage: ./audit-desktop.sh [accessible /dev/dri/renderD* or card* node]'
  exit 0
fi
export NIXOS_AUDIT_REPO
NIXOS_AUDIT_REPO=$(dirname "$(readlink -f "$0")")
export NIXOS_AUDIT_RENDER_NODE=${1:-}
if [[ -n "$NIXOS_AUDIT_RENDER_NODE" ]] &&
   [[ ! -r "$NIXOS_AUDIT_RENDER_NODE" || ! -w "$NIXOS_AUDIT_RENDER_NODE" ]]; then
  echo "Render node is not accessible: $NIXOS_AUDIT_RENDER_NODE" >&2
  exit 1
fi
base="${XDG_CACHE_HOME:-$HOME/.cache}/desktop-audit"
mkdir -p "$base"
output=$(mktemp -d "$base/run.XXXXXXXX")
export TMPDIR="$output/tmp"
mkdir -p "$TMPDIR"
driver=$(nix build --impure --no-update-lock-file --out-link "$output/driver" --print-out-paths --expr '
  let
    repo = builtins.getEnv "NIXOS_AUDIT_REPO";
    f = builtins.getFlake repo;
    node = builtins.getEnv "NIXOS_AUDIT_RENDER_NODE";
  in (import (repo + "/desktop-test.nix") {
    inputs = f.inputs;
    pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
    hostRenderNode = if node == "" then null else node;
  }).driver
')
if [[ -n "$NIXOS_AUDIT_RENDER_NODE" ]]; then
  mesa=$(nix eval --impure --raw --expr '
    (builtins.getFlake (builtins.getEnv "NIXOS_AUDIT_REPO")).inputs.nixpkgs.legacyPackages.x86_64-linux.mesa.outPath
  ')
  # Isolated host-side Mesa software rendering, never global driver overrides.
  # Prevent the test driver appending -nographic over the EGL-headless backend.
  export DISPLAY=""
  export LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=4
  export GBM_BACKENDS_PATH="$mesa/lib/gbm" LIBGL_DRIVERS_PATH="$mesa/lib/dri"
  export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa/share/glvnd/egl_vendor.d/50_mesa.json"
fi
printf 'Audit output: %s\n' "$output"
exec "$driver/bin/nixos-test-driver" -o "$output"
