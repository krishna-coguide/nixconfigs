{
  description = "Project toolchain + DeepSeek Harness microVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Local bootstrap. For teammates/CI use your Git remote's moving branch:
    # git+https://YOUR-REMOTE/nixconfig.git?dir=agent-vm&ref=main
    agent-vm.url = "path:/etc/nix/agent-vm";
    agent-vm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, agent-vm, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      project = import ./project.nix { inherit pkgs; };
      agent = agent-vm.lib.mkAgentVM {
        inherit system project;
        modules = [
          {
            microvm.mem = 4096; # MiB
            microvm.vcpu = 4;
            agentVM.network = {
              hostAddress = "127.0.0.1"; # Or a host LAN/VPN IPv4 address, or 0.0.0.0.
              sshPort = 2222; # Always host localhost in user-network mode.
              webPort = 3080; # First available host Web port in this inclusive range.
              webPortEnd = 3100; # Set equal to webPort to disable port hopping.
              # For 0.0.0.0, list actual browser hosts, not a wildcard.
              # A port-less host allows any selected port; host:port stays exact.
              # trustedHosts = [ "192.168.1.20" ];
            };
          }
        ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        inherit (project) packages env;
      };
      packages.${system}.agent = agent.package;
      apps.${system}.agent = agent.app;
      nixosConfigurations.agent = agent.nixos;
      formatter.${system} = pkgs.nixfmt;
    };
}
