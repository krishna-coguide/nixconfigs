# Host configuration and built-file checks: no activation, VM or VPN connections.
{ config, pkgs }:
let
  inherit (pkgs) lib;
  kbot = config.users.users.kbot;
  dev = config.users.users.dev;
  btrfsDevice = "/dev/disk/by-uuid/8a16015f-d6f8-4f74-8558-6261b9112216";
  mounts = {
    "/" = {
      device = btrfsDevice;
      fsType = "btrfs";
    };
    "/home" = {
      device = btrfsDevice;
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = btrfsDevice;
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/DEC5-51CB";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };
  tests = [
    {
      assertion = config.boot.loader.systemd-boot.enable && !config.boot.loader.grub.enable;
      message = "The physical host must use systemd-boot, never EC2's GRUB disk.";
    }
    {
      assertion = lib.all (
        mount:
        let
          actual = config.fileSystems.${mount};
          expected = mounts.${mount};
        in
        actual.device == expected.device
        && actual.fsType == expected.fsType
        && lib.all (option: builtins.elem option actual.options) (expected.options or [ ])
      ) (builtins.attrNames mounts);
      message = "Preserve the installed root/home/nix/EFI filesystems and Btrfs subvolumes.";
    }
    {
      assertion =
        config.users.mutableUsers
        && kbot.isNormalUser
        && kbot.uid == 1000
        && kbot.home == "/home/kbot"
        && builtins.elem "wheel" kbot.extraGroups
        && builtins.elem "networkmanager" kbot.extraGroups
        && kbot.password == null
        && kbot.hashedPassword == null
        && kbot.hashedPasswordFile == null;
      message = "Keep kbot's identity, local password and administrative/network access.";
    }
    {
      assertion =
        dev.isNormalUser
        && dev.uid == 1001
        && dev.home == "/home/dev"
        && builtins.elem "wheel" dev.extraGroups
        && builtins.elem "networkmanager" dev.extraGroups
        && builtins.attrNames config.home-manager.users == [ "dev" ];
      message = "Add dev independently; Home Manager must not manage kbot's home.";
    }
    {
      assertion =
        config.services.displayManager.sddm.enable
        && config.services.desktopManager.plasma6.enable
        && config.programs.hyprland.enable
        && config.programs.hyprland.withUWSM
        && !config.services.greetd.enable
        && !config.services.displayManager.autoLogin.enable;
      message = "Keep the Plasma/SDDM recovery login alongside Hyprland, without autologin.";
    }
    {
      assertion =
        config.networking.networkmanager.enable
        && !config.services.resolved.enable
        && builtins.elem (lib.getName pkgs.networkmanager-openvpn) (
          map lib.getName config.networking.networkmanager.plugins
        );
      message = "Keep NetworkManager/DNS and provide its OpenVPN integration.";
    }
    {
      assertion =
        !(config.systemd.services ? nixos-update)
        && !(config.systemd.timers ? nixos-update)
        && !(config.systemd.services ? amazon-ssm-agent)
        && !(builtins.elem "Z /etc/nixos - dev users -" config.systemd.tmpfiles.rules);
      message = "The physical host must not inherit EC2 services, updater or repo ownership.";
    }
    {
      assertion =
        lib.all
          (package: builtins.elem (lib.getName package) (map lib.getName config.environment.systemPackages))
          (
            with pkgs;
            [
              wireguard-tools
              openvpn
              iperf3
              nmap
              traceroute
              whois
              dnsutils
              tcpdump
              ethtool
              netcat-openbsd
              socat
            ]
          )
        && config.programs.mtr.enable;
      message = "The VPN clients and network diagnostics must remain installed.";
    }
    {
      assertion =
        config.networking.wireguard.interfaces == { }
        && config.networking.wg-quick.interfaces == { }
        && config.services.openvpn.servers == { };
      message = "Installing VPN tools must not invent tunnels, peers or credentials.";
    }
  ];
in
assert lib.all (test: lib.assertMsg test.assertion test.message) tests;
pkgs.runCommand "physical-config-check" { } ''
  sessions=${config.services.displayManager.sessionData.desktops}/share
  test -f "$sessions/wayland-sessions/plasma.desktop"
  test -f "$sessions/wayland-sessions/hyprland-uwsm.desktop"
  for tool in wg wg-quick openvpn iperf3 nmap traceroute whois mtr dig tcpdump ethtool nc socat nm-connection-editor; do
    test -x "${config.system.path}/bin/$tool"
  done
  touch "$out"
''
