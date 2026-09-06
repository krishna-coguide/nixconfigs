{
  inputs,
  pkgs,
  example,
}:
let
  c = example.nixos.config;
  testVM = inputs.self.lib.mkAgentVM {
    system = pkgs.stdenv.hostPlatform.system;
    project = {
      packages = [ pkgs.hello ];
      env.AGENT_PROJECT_TEST = "shared";
    };
    modules = [
      {
        # Offline infrastructure test. A real DSH startup is tested separately;
        # @latest needs the network and is intentionally outside Nix reproducibility.
        agentVM.package = pkgs.writeShellScriptBin "dsh" ''
          echo 'http://127.0.0.1:3080/?token=offline-test'
          exec ${pkgs.coreutils}/bin/sleep infinity
        '';
      }
    ];
  };
  tap = inputs.self.lib.mkAgentVM {
    system = pkgs.stdenv.hostPlatform.system;
    project.packages = [ ];
    modules = [
      {
        microvm.mem = 8192;
        microvm.vcpu = 6;
        agentVM.network = {
          mode = "tap";
          tapName = "agent-test";
          guestAddress = "192.168.77.2";
          gateway = "192.168.77.1";
          dns = [ "192.168.77.1" ];
        };
      }
    ];
  };
in
{
  config =
    assert c.microvm.mem == 4096;
    assert c.microvm.vcpu == 4;
    assert builtins.length c.microvm.shares == 3;
    assert builtins.all (s: !s.readOnly && s.securityModel == "none") c.microvm.shares;
    assert c.microvm.storeOnDisk;
    assert c.systemd.services.agent.serviceConfig.User == "root";
    assert c.systemd.services.agent.serviceConfig.WorkingDirectory == "/workspace";
    assert c.services.openssh.settings.PasswordAuthentication == false;
    assert c.services.openssh.settings.AllowAgentForwarding == false;
    assert !c.services.xserver.enable;
    assert !c.services.displayManager.enable;
    assert builtins.elem inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.playwright-cli
      c.environment.systemPackages;
    assert builtins.length c.microvm.forwardPorts == 1;
    assert (builtins.head c.microvm.forwardPorts).host.address == "127.0.0.1";
    assert builtins.elem pkgs.hello c.environment.systemPackages;
    assert c.environment.variables.AGENT_PROJECT_TEST == "shared";
    assert tap.nixos.config.microvm.mem == 8192;
    assert tap.nixos.config.microvm.vcpu == 6;
    assert tap.nixos.config.microvm.forwardPorts == [ ];
    assert (builtins.head tap.nixos.config.microvm.interfaces).id == "agent-test";
    pkgs.runCommand "agent-vm-config-check" { } ''touch "$out"'';

  shell =
    pkgs.runCommand "agent-vm-shell-check"
      {
        nativeBuildInputs = [
          pkgs.shellcheck
          pkgs.bash
        ];
      }
      ''
        shellcheck -s bash ${./launch.sh} ${./boot-test.sh} ${./playwright-test.sh}
        bash -n ${./launch.sh}
        touch "$out"
      '';

  playwright =
    pkgs.runCommand "agent-playwright-firefox-check"
      {
        nativeBuildInputs = [
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.playwright-cli
          pkgs.nodejs
          pkgs.jq
          pkgs.coreutils
          pkgs.gnugrep
        ];
      }
      ''
        export PLAYWRIGHT_TEST_OUTPUT="$out"
        bash ${./playwright-test.sh}
      '';

  boot =
    pkgs.runCommand "agent-vm-boot-check"
      {
        requiredSystemFeatures = [ "kvm" ];
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
        ];
      }
      ''
        bash ${./boot-test.sh} ${testVM.package}/bin/agent-vm ${./playwright-test.sh}
        touch "$out"
      '';
}
