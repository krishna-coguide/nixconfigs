{
  description = "Development host";

  inputs = {
    # Reviewed stable 26.05 snapshot; update deliberately, not at boot/login.
    nixpkgs.url = "github:NixOS/nixpkgs/a5cc6f2c37bf518436dc8d1c288ccd0c43c2f4c4";

    home-manager = {
      url = "github:nix-community/home-manager/65258d5c65a250189fde2e35f490d15e064c4c62";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}
