# Offline example regression check; no npm downloads, DSH profiles or servers.
{ pkgs }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  example = import ./templates/agent/flake.nix;
  outputs = example.outputs {
    nixpkgs.legacyPackages.${system} = pkgs;
  };
  shell = outputs.devShells.${system}.default;
in
assert builtins.attrNames example.inputs == [ "nixpkgs" ];
assert builtins.attrNames outputs == [ "devShells" ];
assert shell.shellHook == "";
assert shell.DSH_PERMISSION_MODE == "workspace-write";
assert shell.DSH_TELEMETRY_DISABLED == "1";
pkgs.runCommand "agent-template-check"
  {
    inherit (shell) nativeBuildInputs DSH_PERMISSION_MODE DSH_TELEMETRY_DISABLED;
  }
  ''
    for tool in node npm pnpm bash true bwrap git rg python3 uv ruff; do
      command -v "$tool" >/dev/null
    done
    test "$DSH_PERMISSION_MODE" = workspace-write
    test "$DSH_TELEMETRY_DISABLED" = 1
    node --version
    bwrap --version
    touch "$out"
  ''
