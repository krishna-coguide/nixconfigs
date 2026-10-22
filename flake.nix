{
  description = "Development host";

  inputs = {
    # Rolling, latest-tested NixOS; flake.lock records the resolved snapshot.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fast-moving standalone apps/tools can advance ahead of the tested channel.
    # nixpkgs-unstable only moves to commits Hydra has built, unlike master, so
    # these stay current without compiling uncached or broken packages.
    # flake.lock still records the exact resolved snapshot.
    nixpkgs-latest.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Local dictation. main only receives release merges (dev is development),
    # so this follows the newest release; flake.lock records the exact one.
    voxtype = {
      url = "github:peteonrails/voxtype/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, home-manager, ... }:
    let
      mkHost =
        name:
        {
          modules,
          system ? "x86_64-linux",
          repo ? "/etc/nixos",
        }:
        assert builtins.match "[a-zA-Z_][a-zA-Z0-9_-]*" name != null;
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = modules ++ [
            home-manager.nixosModules.home-manager
            {
              nixpkgs.hostPlatform = system;
              systemd.services.nixos-update.environment = {
                NIXOS_CONFIG_REPO = repo;
                NIXOS_UPDATE_HOST = name;
              };
            }
          ];
        };
      cuda = import ./cuda.nix {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfreePredicate =
            nixpkgs.legacyPackages.x86_64-linux._cuda.lib.allowUnfreeCudaPredicate;
        };
      };
    in
    {
      lib.mkHost = mkHost;
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost (import ./hosts.nix);
      devShells.x86_64-linux.cuda = cuda.shell;
      packages.x86_64-linux.cuda-check = cuda.smoke;

      templates.agent = {
        path = ./templates/agent;
        description = "Copyable project devShell example for DeepSeek Harness with Bubblewrap";
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      packages.x86_64-linux.element-nightly = import ./element-nightly.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };
      packages.x86_64-linux.tastytrade = import ./tastytrade.nix {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "tastytrade";
        };
      };

      nixosModules = {
        desktop = ./desktop.nix;
        apps = ./apps.nix;
        tools = ./tools.nix;
        network = ./network.nix;
        workstation = ./workstation.nix;
        nvidia = ./nvidia.nix;
        voxtype = ./voxtype.nix;
      };
      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          agent-template = import ./agent-template-test.nix { inherit pkgs; };
          desktop = import ./desktop-test.nix { inherit inputs pkgs; };
          appearance = import ./appearance-test.nix {
            inherit pkgs;
            config = inputs.self.nixosConfigurations.nixos.config;
          };
          nvidia-config = import ./nvidia-test.nix {
            inherit inputs pkgs;
            laptop = inputs.self.nixosConfigurations.nixos.config;
            ec2 = inputs.self.nixosConfigurations.dev.config;
          };
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
