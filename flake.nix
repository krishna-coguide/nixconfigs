{
  description = "Development host";

  inputs = {
    # Release branches may advance; flake.lock records every exact snapshot.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fast-moving developer tools can lag behind stable release branches.
    # flake.lock still records the exact resolved snapshot.
    nixpkgs-latest.url = "github:NixOS/nixpkgs/master";

    neovim-dots = {
      url = "git+https://git.cyber.ayyalasomayajula.net/marsultor/neovim-dots?ref=main&rev=380eb86778a7c53a0f1c18e84f14037456155347";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, home-manager, ... }:
    {
      nixosConfigurations.dev = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };

      # Physical host: adds dev/Hyprland without removing kbot/Plasma.
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./physical.nix
          home-manager.nixosModules.home-manager
        ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

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
          physical-config = import ./physical-test.nix {
            inherit pkgs;
            config = inputs.self.nixosConfigurations.nixos.config;
          };
          desktop-config =
            pkgs.runCommand "hyprland-config-check" { nativeBuildInputs = [ pkgs.hyprland ]; }
              ''
                export HOME="$TMPDIR/home" XDG_RUNTIME_DIR="$TMPDIR/runtime"
                mkdir -m 700 -p "$HOME" "$XDG_RUNTIME_DIR"
                Hyprland --verify-config -c ${./hyprland.lua}
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
