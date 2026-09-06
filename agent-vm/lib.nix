{ nixpkgs, microvm }:
{
  system,
  project,
  modules ? [ ],
}:
let
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (pkgs) lib;
  nixos = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      microvm.nixosModules.microvm
      ./module.nix
      {
        agentVM.packages = project.packages or [ ];
        environment.variables = project.env or { };
      }
    ]
    ++ modules;
  };
  net = nixos.config.agentVM.network;
  package = pkgs.writeShellApplication {
    name = "agent-vm";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      openssh
      bubblewrap
      gnugrep
      gnused
    ];
    runtimeEnv = {
      AGENT_RUNNER = "${nixos.config.microvm.declaredRunner}/bin";
      AGENT_NETWORK = net.mode;
      AGENT_WEB_BIND = net.hostAddress;
      AGENT_WEB_PORT = toString net.webPort;
      AGENT_SSH_HOST = if net.mode == "user" then "127.0.0.1" else net.guestAddress;
      AGENT_SSH_PORT = toString (if net.mode == "user" then net.sshPort else 22);
    };
    text = builtins.readFile ./launch.sh;
  };
in
assert lib.assertMsg (
  system == "x86_64-linux"
) "agent-vm currently supports x86_64-linux hosts/guests";
{
  inherit nixos package;
  app = {
    type = "app";
    program = lib.getExe package;
    meta.description = "Run DSH with this project's toolchain and live workspace";
  };
}
