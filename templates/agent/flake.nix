# Example only: copy this file or merge the devShell into your project's flake.
# DSH runs directly on the host; its built-in sandbox plugin confines tool writes.
# Inside nix develop, run the rolling alpha channel (see README.md for boundaries):
# npm exec --yes --prefer-online --package=@deepseek-ai/dsh@alpha --call \
#   'node --expose-internals "$(command -v dsh)" web --no-open --host 127.0.0.1 --port 3080'
{
  description = "Example project shell for DeepSeek Harness with Bubblewrap";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux"; # Use aarch64-linux on ARM Linux.
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          # DSH runtime and the preferred Linux sandbox backend.
          nodejs_24
          pnpm
          bashInteractive
          coreutils # Includes `true`, used by DSH's functional bwrap probe.
          bubblewrap

          # Example project tools; replace these with your own.
          git
          ripgrep
          python3
          uv
          ruff
        ];
        env = {
          DSH_PERMISSION_MODE = "workspace-write";
          DSH_TELEMETRY_DISABLED = "1";
          UV_PYTHON_DOWNLOADS = "never";
        };
      };
    };
}
