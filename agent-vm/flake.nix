{
  description = "Project-composable, rootless microVMs for a DeepSeek coding agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      microvm,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      example = self.lib.mkAgentVM {
        inherit system;
        project = {
          packages = [ pkgs.hello ];
          env.AGENT_PROJECT_TEST = "shared";
        };
      };
    in
    {
      lib.mkAgentVM = import ./lib.nix { inherit nixpkgs microvm; };
      nixosModules.agent = ./module.nix;
      nixosConfigurations.agent = example.nixos;
      packages.${system}.default = example.package;
      apps.${system}.default = example.app;
      formatter.${system} = pkgs.nixfmt;
      checks.${system} = import ./tests.nix { inherit inputs pkgs example; };
    };
}
