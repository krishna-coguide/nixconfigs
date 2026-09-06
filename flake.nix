{
  description = "Development host";

  inputs = {
    # Rolling, latest-tested NixOS; flake.lock records the resolved snapshot.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fast-moving developer tools can advance ahead of the tested channel.
    # flake.lock still records the exact resolved snapshot.
    nixpkgs-latest.url = "github:NixOS/nixpkgs/master";

    neovim-dots = {
      url = "git+https://git.cyber.ayyalasomayajula.net/marsultor/neovim-dots?ref=main&rev=380eb86778a7c53a0f1c18e84f14037456155347";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, home-manager, ... }:
    let
      mkHost =
        module:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            module
            home-manager.nixosModules.home-manager
          ];
        };
    in
    {
      nixosConfigurations = {
        dev = mkHost ./configuration.nix; # EC2 integration
        nixos = mkHost ./physical.nix; # This laptop's boot/storage/hardware
      };

      templates.agent = {
        path = ./templates/agent;
        description = "Project toolchain + live-workspace DeepSeek Harness microVM";
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      packages.x86_64-linux.element-nightly = import ./element-nightly.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };

      nixosModules = {
        desktop = ./desktop.nix;
        apps = ./apps.nix;
        tools = ./tools.nix;
        network = ./network.nix;
        workstation = ./workstation.nix;
        nvidia = ./nvidia.nix;
      };
      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          desktop = import ./desktop-test.nix { inherit inputs pkgs; };
          git-credentials = import ./git-credentials-test.nix {
            inherit pkgs;
            config = inputs.self.nixosConfigurations.nixos.config;
          };
          tools = import ./tools-test.nix {
            inherit pkgs;
            config = inputs.self.nixosConfigurations.nixos.config;
          };
          physical-config = import ./physical-test.nix {
            inherit pkgs;
            config = inputs.self.nixosConfigurations.nixos.config;
            ec2Config = inputs.self.nixosConfigurations.dev.config;
          };
          switch-system =
            pkgs.runCommand "switch-system-check"
              {
                nativeBuildInputs = with pkgs; [
                  python3
                  bash
                  coreutils
                  util-linux
                  shellcheck
                ];
              }
              ''
                shellcheck ${./switch-system.sh}
                python ${./switch-test.py} ${./switch-system.sh}
                touch "$out"
              '';
          desktop-actions =
            pkgs.runCommand "desktop-actions-check" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                python ${./desktop-actions-test.py} ${./desktop-actions.py}
                touch "$out"
              '';
          desktop-config =
            pkgs.runCommand "hyprland-config-check" { nativeBuildInputs = [ pkgs.hyprland ]; }
              ''
                export HOME="$TMPDIR/home" XDG_RUNTIME_DIR="$TMPDIR/runtime"
                mkdir -m 700 -p "$HOME" "$XDG_RUNTIME_DIR"
                Hyprland --verify-config -c ${
                  inputs.self.nixosConfigurations.nixos.config.home-manager.users.dev.xdg.configFile."hypr/hyprland.lua".source
                }
                touch "$out"
              '';
          updates =
            pkgs.runCommand "update-workflow-check"
              {
                nativeBuildInputs = with pkgs; [
                  python3
                  git
                  bash
                  coreutils
                  util-linux
                ];
              }
              ''
                python ${./update-test.py} ${./update-system.sh}
                touch "$out"
              '';
        };
    };
}
