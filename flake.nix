{
  description = "Development host";

  inputs = {
    # Keep the machine's existing Nixpkgs revision; this is not an upgrade.
    nixpkgs.url = "github:NixOS/nixpkgs/d57af924f160a5084293c71c2043f058bd1cdb60";

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
