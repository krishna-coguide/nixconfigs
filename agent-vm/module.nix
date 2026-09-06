{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.agentVM;
  net = cfg.network;
  ipv4 = types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+";
  dshNode = pkgs.writeShellScript "dsh-node" ''
    # Cordis HMR requires this Node flag; npm's published dsh shebang omits it.
    exec node --expose-internals "$(command -v dsh)" "$@"
  '';
  dshLatest = pkgs.writeShellApplication {
    name = "dsh";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.pnpm
    ];
    text = ''
      export npm_config_cache=/var/cache/dsh/npm
      # Explicitly rolling upstream, not a pretend-reproducible Nix derivation.
      exec npm exec --yes --package=@deepseek-ai/dsh@latest -- ${dshNode} "$@"
    '';
  };
  guestLaunch = pkgs.writeShellScript "dsh-project" ''
    cd -- "$(cat /run/agent-vm/workdir)"
    exec "$@"
  '';
  share = source: mountPoint: tag: {
    inherit source mountPoint tag;
    proto = "9p";
    securityModel = "none"; # QEMU writes as its unprivileged host uid, not guest root.
    readOnly = false;
  };
in
{
  options.agentVM = {
    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "The same project package list used by the development shell.";
    };
    package = mkOption {
      type = types.package;
      default = dshLatest;
      description = "Official DSH launcher; resolves the npm latest tag inside the guest at launch.";
    };
    network = {
      mode = mkOption {
        type = types.enum [
          "user"
          "tap"
        ];
        default = "user";
        description = "Rootless QEMU NAT, or an administrator-prepared TAP interface.";
      };
      hostAddress = mkOption {
        type = ipv4;
        default = "127.0.0.1";
        description = "Host IPv4 bind address for the SSH-forwarded Web UI.";
      };
      sshPort = mkOption {
        type = types.port;
        default = 2222;
        description = "Host SSH port in user mode; SSH is always bound to host loopback.";
      };
      webPort = mkOption {
        type = types.port;
        default = 3080;
        description = "Host Web UI port; the guest DSH listener stays on 127.0.0.1:3080.";
      };
      trustedHosts = mkOption {
        type = types.listOf (types.strMatching "[a-zA-Z0-9.:-]+");
        default = [ ];
        description = "Additional exact browser authorities for DSH's Host/Origin protection. Required for wildcard publication.";
      };
      tapName = mkOption {
        type = types.strMatching "[a-zA-Z0-9_-]{1,15}";
        default = "agent0";
        description = "Pre-created host TAP interface, not a physical NIC.";
      };
      mac = mkOption {
        type = types.strMatching "[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}";
        default = "02:00:00:00:00:01";
        description = "Unique locally administered guest MAC; change for each TAP guest.";
      };
      guestAddress = mkOption {
        type = types.nullOr ipv4;
        default = null;
        description = "Static guest IPv4 address in TAP mode.";
      };
      prefixLength = mkOption {
        type = types.ints.between 1 32;
        default = 24;
        description = "Guest IPv4 prefix length in TAP mode.";
      };
      gateway = mkOption {
        type = types.nullOr ipv4;
        default = null;
        description = "Guest default router in TAP mode; routing/NAT is configured separately.";
      };
      dns = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "DNS servers in TAP mode. User mode uses QEMU DHCP/DNS.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion =
          net.mode != "tap" || (net.guestAddress != null && net.gateway != null && net.dns != [ ]);
        message = "agentVM TAP mode requires network.guestAddress, gateway and dns.";
      }
      {
        assertion = net.webPort >= 1024 && net.sshPort >= 1024 && net.webPort != net.sshPort;
        message = "Rootless Web/SSH listeners need distinct unprivileged ports (>=1024).";
      }
      {
        assertion = net.hostAddress != "0.0.0.0" || net.trustedHosts != [ ];
        message = "When publishing on 0.0.0.0, list the actual browser IP:port/hostname:port in network.trustedHosts.";
      }
    ];

    networking.hostName = lib.mkDefault "project-agent";
    system.stateVersion = "26.05";
    microvm = {
      hypervisor = "qemu";
      mem = lib.mkDefault 4096;
      vcpu = lib.mkDefault 4;
      socket = "control.sock";
      storeOnDisk = true;
      # Ephemeral guest-only Nix writes; never share the host store or daemon.
      writableStoreOverlay = "/nix/.rw-store";
      volumes = [
        {
          image = "cache.img";
          mountPoint = "/var/cache/dsh";
          size = 4096;
        }
      ];
      # Paths are in the launcher's restricted mount namespace, not Nix paths.
      # No credential/project contents enter the Nix store.
      shares = [
        (share "/workspace" "/workspace" "project")
        (share "/dsh-home" "/root/.dsh" "dsh-home")
        (share "/skills" "/root/.agents/skills" "agent-skills")
      ];
      interfaces = [
        {
          type = net.mode;
          id = if net.mode == "user" then "agentnet" else net.tapName;
          inherit (net) mac;
        }
      ];
      forwardPorts = lib.optionals (net.mode == "user") [
        {
          from = "host";
          host.address = "127.0.0.1";
          host.port = net.sshPort;
          guest.port = 22;
        }
      ];
      # Firmware credentials carry only dedicated VM SSH keys, not DSH secrets.
      # Relative runtime filenames avoid embedding user paths in derivations.
      qemu.extraArgs =
        lib.concatMap
          (name: [
            "-fw_cfg"
            "name=opt/io.systemd.credentials/${name},file=${name}"
          ])
          [
            "ssh-authorized-key"
            "ssh-host-key"
            "workdir"
          ];
    };
    fileSystems."/workspace".options = [
      "nodev"
      "nosuid"
      "cache=none"
    ];
    fileSystems."/root/.dsh".options = [
      "nodev"
      "nosuid"
      "cache=none"
    ];
    fileSystems."/root/.agents/skills".options = [
      "nodev"
      "nosuid"
      "cache=none"
    ];

    networking.useDHCP = false;
    systemd.network.enable = true;
    systemd.network.networks."20-agent" = {
      matchConfig.MACAddress = net.mac;
      networkConfig =
        if net.mode == "user" then
          { DHCP = "ipv4"; }
        else
          {
            Address = [ "${net.guestAddress}/${toString net.prefixLength}" ];
            Gateway = net.gateway;
            DNS = net.dns;
          };
    };
    networking.firewall.allowedTCPPorts = [ 22 ]; # Web stays on guest loopback.
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.auto-optimise-store = false;
    nix.channel.enable = false;

    users.users.root.hashedPassword = "!";
    services.openssh = {
      enable = true;
      hostKeys = [
        {
          path = "/run/agent-vm/ssh-host-key";
          type = "ed25519";
        }
      ];
      authorizedKeysFiles = lib.mkForce [ "/run/agent-vm/ssh-authorized-key" ];
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AllowAgentForwarding = false;
        X11Forwarding = false;
        AllowTcpForwarding = "local";
      };
    };
    systemd.services.agent-vm-credentials = {
      before = [
        "sshd.service"
        "sshd-keygen.service"
        "agent.service"
      ];
      requiredBy = [
        "sshd.service"
        "sshd-keygen.service"
        "agent.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "agent-vm";
        RuntimeDirectoryMode = "0700";
        ImportCredential = [
          "ssh-authorized-key"
          "ssh-host-key"
          "workdir"
        ];
      };
      script = ''
        for name in ssh-authorized-key ssh-host-key workdir; do
          install -m 600 "$CREDENTIALS_DIRECTORY/$name" "/run/agent-vm/$name"
        done
      '';
    };
    environment.variables = {
      DSH_HOME = "/root/.dsh";
      DSH_AGENTS_HOME = "/root/.agents";
      DSH_TELEMETRY_DISABLED = "1";
    };
    programs.git.config.safe.directory = "/workspace"; # 9p files retain host ownership.
    programs.nix-ld.enable = true; # Upstream npm native executables, guest only.
    environment.systemPackages = [
      cfg.package
    ]
    ++ cfg.packages
    ++ (with pkgs; [
      bashInteractive
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      diffutils
      git
      git-lfs
      openssh
      ripgrep
      fd
      jq
      yq-go
      tree
      file
      less
      python3
      nodejs
      pnpm
      curl
      wget
      cacert
      unzip
      zip
      gnutar
      gzip
      xz
      zstd
      procps
      util-linux
      which
      patch
      gnumake
      pkg-config
      shellcheck
      bubblewrap
    ]);
    systemd.services.agent = {
      description = "Official DeepSeek Harness (root inside the guest)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.RequiresMountsFor = [
        "/workspace"
        "/root/.dsh"
        "/root/.agents/skills"
        "/var/cache/dsh"
      ];
      path = [ "/run/current-system/sw" ];
      environment = config.environment.variables // {
        HOME = "/root";
      };
      # Preserve the real cwd path in DSH's workspace/session identity. Mapping
      # every project to /workspace alone would conflate their shared sessions.
      preStart = ''
        workdir=$(cat /run/agent-vm/workdir)
        mkdir -p -- "$workdir"
        mountpoint -q -- "$workdir" || mount --bind /workspace "$workdir"
        git config --global --replace-all safe.directory "$workdir"
      '';
      serviceConfig = {
        User = "root";
        WorkingDirectory = "/workspace";
        ExecStart = lib.escapeShellArgs (
          [
            "${guestLaunch}"
            "${cfg.package}/bin/dsh"
            "web"
            "--no-open"
            "--host"
            "127.0.0.1"
            "--port"
            "3080"
          ]
          ++
            lib.concatMap
              (host: [
                "--trusted-host"
                host
              ])
              (
                net.trustedHosts
                ++ lib.optional (
                  !builtins.elem net.hostAddress [
                    "127.0.0.1"
                    "0.0.0.0"
                  ]
                ) "${net.hostAddress}:${toString net.webPort}"
              )
        );
        Restart = "on-failure";
        RestartSec = 3;
        UMask = "0077";
      };
    };
  };
}
