# Physical safety, shared host policy and built files; no activation/connections.
{
  config,
  ec2Config,
  pkgs,
}:
let
  inherit (pkgs) lib;
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
        && !(config.users.users ? kbot)
        && dev.password == null
        && dev.hashedPassword == null
        && dev.hashedPasswordFile == null;
      message = "Retire kbot without overwriting dev's locally established password.";
    }
    {
      assertion =
        dev.isNormalUser
        && dev.uid == 1001
        && dev.home == "/home/dev"
        && builtins.elem "wheel" dev.extraGroups
        && builtins.elem "networkmanager" dev.extraGroups
        && builtins.attrNames config.home-manager.users == [ "dev" ];
      message = "dev is the sole managed daily account, with local administration/network access.";
    }
    {
      assertion =
        config.services.displayManager.sddm.enable
        && !config.services.desktopManager.plasma6.enable
        && config.programs.hyprland.enable
        && config.programs.hyprland.withUWSM
        && !config.services.greetd.enable
        && !config.services.displayManager.autoLogin.enable
        && config.services.displayManager.defaultSession == "hyprland-uwsm"
        && !(builtins.elem "hyprland" config.services.displayManager.sessionData.sessionNames);
      message = "Offer only the managed Hyprland desktop in SDDM, without Plasma or autologin.";
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
        config.systemd.services.nixos-update.environment.NIXOS_UPDATE_HOST == "nixos"
        && config.systemd.services.nixos-update.environment.NIXOS_CONFIG_REPO == "/etc/nix"
        && config.systemd.services.nixos-update.serviceConfig.User == "dev"
        && builtins.elem "Z /etc/nix - dev users -" config.systemd.tmpfiles.rules
        && config.systemd.timers.nixos-update.timerConfig.Persistent
        && !(config.systemd.services ? amazon-ssm-agent)
        && !(builtins.elem "Z /etc/nixos - dev users -" config.systemd.tmpfiles.rules);
      message = "The laptop must keep its own checkout/target, not EC2's deployment settings.";
    }
    {
      assertion =
        lib.all
          (
            c:
            let
              update = c.systemd.services.nixos-update;
            in
            update.serviceConfig.User == "dev"
            && update.serviceConfig.Group == "users"
            && update.serviceConfig.ExecStart == config.systemd.services.nixos-update.serviceConfig.ExecStart
            && c.systemd.timers.nixos-update.timerConfig == config.systemd.timers.nixos-update.timerConfig
            && !(update.environment ? NIXOS_UPDATE_MODE)
            && builtins.elem "Z ${update.environment.NIXOS_CONFIG_REPO} - dev users -" c.systemd.tmpfiles.rules
            && builtins.elem "Z /var/cache/nixos-update - dev users -" c.systemd.tmpfiles.rules
            && c.users.mutableUsers
            && c.time.timeZone == "America/Chicago"
            && c.i18n.defaultLocale == "en_US.UTF-8"
          )
          [
            config
            ec2Config
          ];
      message = "Both hosts must share the dev-owned checkout/updater and user preferences; no per-host activation policy.";
    }
    {
      assertion =
        ec2Config.systemd.services.nixos-update.environment.NIXOS_UPDATE_HOST == "dev"
        && ec2Config.systemd.services.nixos-update.environment.NIXOS_CONFIG_REPO == "/etc/nixos"
        && ec2Config.boot.loader.grub.enable
        && ec2Config.boot.loader.grub.device == "/dev/xvda"
        && !ec2Config.boot.loader.systemd-boot.enable
        && ec2Config.fileSystems."/".device == "/dev/disk/by-label/nixos"
        && ec2Config.fileSystems."/".fsType == "ext4"
        && ec2Config.services.openssh.enable
        && ec2Config.services.amazon-ssm-agent.enable
        && ec2Config.networking.dhcpcd.enable
        && ec2Config.services.resolved.enable
        && !ec2Config.networking.networkmanager.enable
        && !ec2Config.services.displayManager.sddm.enable;
      message = "EC2 must retain its AWS boot, disks, networking and remote recovery, not laptop hardware services.";
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
  test ! -e "$sessions/wayland-sessions/plasma.desktop"
  test -f "$sessions/wayland-sessions/hyprland-uwsm.desktop"
  test ! -e "$sessions/wayland-sessions/hyprland.desktop"
  for tool in wg wg-quick openvpn iperf3 nmap traceroute whois mtr dig tcpdump ethtool nc socat nm-connection-editor; do
    test -x "${config.system.path}/bin/$tool"
  done
  touch "$out"
''
