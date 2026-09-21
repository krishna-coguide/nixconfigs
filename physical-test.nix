# Boot/storage, shared service policy and built files; no activation/connections.
{
  config,
  ec2Config,
  pkgs,
}:
let
  inherit (pkgs) lib;
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
        config.services.displayManager.sddm.enable
        && !config.services.desktopManager.plasma6.enable
        && !config.services.desktopManager.gnome.enable
        && config.programs.hyprland.enable
        && config.programs.hyprland.withUWSM
        && !config.services.greetd.enable
        && !config.services.displayManager.autoLogin.enable
        && config.services.displayManager.defaultSession == "hyprland-uwsm"
        && !(builtins.elem "hyprland" config.services.displayManager.sessionData.sessionNames);
      message = "Offer only the managed Hyprland desktop in SDDM, without Plasma, GNOME or autologin.";
    }
    {
      assertion =
        config.networking.networkmanager.enable
        && config.networking.networkmanager.wifi.backend == "wpa_supplicant"
        && config.networking.networkmanager.dns == "systemd-resolved"
        && builtins.elem (lib.getName pkgs.networkmanager-openvpn) (
          map lib.getName config.networking.networkmanager.plugins
        );
      message = "Keep NetworkManager with Wi-Fi Direct support, resolved DNS and its OpenVPN integration.";
    }
    {
      assertion =
        lib.all (c: builtins.elem pkgs.gnome-network-displays c.environment.systemPackages) [
          config
          ec2Config
        ]
        && config.services.pipewire.enable
        && config.services.pipewire.pulse.enable
        && config.xdg.portal.enable
        && builtins.elem pkgs.xdg-desktop-portal-hyprland config.xdg.portal.extraPortals;
      message = "Install GNOME Network Displays as a shared app and retain the workstation's PipeWire/Hyprland screencast portal.";
    }
    {
      assertion =
        config.networking.firewall.enable
        && lib.all (port: builtins.elem port config.networking.firewall.allowedTCPPorts) [
          7236
          7250
        ]
        && lib.all (port: builtins.elem port config.networking.firewall.allowedUDPPorts) [
          7236
          5353
        ]
        && config.services.avahi.enable
        && config.services.avahi.openFirewall
        && !config.services.avahi.publish.enable
        && !config.services.avahi.nssmdns4
        && !config.services.avahi.nssmdns6;
      message = "Workstations need the Wi-Fi Display ports and Avahi discovery, without changing host DNS or publishing services.";
    }
    {
      assertion =
        ec2Config.networking.firewall.enable
        && ec2Config.networking.firewall.allowedTCPPorts == [ 22 ]
        && ec2Config.networking.firewall.allowedUDPPorts == [ ]
        && !ec2Config.services.avahi.enable
        && !ec2Config.services.desktopManager.gnome.enable;
      message = "Keep display discovery and its firewall openings off EC2; preserve SSH-only inbound ports.";
    }
    {
      assertion =
        lib.all
          (
            c:
            let
              unit = c.systemd.services.systemd-resolved;
            in
            c.services.resolved.enable
            && builtins.elem "sysinit.target" unit.wantedBy
            && builtins.elem "dbus-org.freedesktop.resolve1.service" unit.aliases
            && unit.serviceConfig.Restart == "always"
            && unit.serviceConfig.RestartSec == "5s"
            && unit.unitConfig.StartLimitIntervalSec == 0
            && !c.networking.resolvconf.enable
            && c.networking.resolvconf.package == c.systemd.package
            && c.environment.etc."resolv.conf".source == "/run/systemd/resolve/stub-resolv.conf"
            && c.services.resolved.settings.Resolve.DNS == [ ]
            && !c.services.resolved.settings.Resolve.LLMNR
            && !c.services.resolved.settings.Resolve.MulticastDNS
          )
          [
            config
            ec2Config
          ];
      message = "Both hosts need boot-enabled, restarting resolved with D-Bus/stub DNS integration, without hard-coded DNS servers.";
    }
    {
      assertion =
        config.systemd.services.nixos-update.environment.NIXOS_UPDATE_HOST == "nixos"
        && config.systemd.services.nixos-update.environment.NIXOS_CONFIG_REPO == "/etc/nix"
        && config.systemd.timers.nixos-update.timerConfig.Persistent
        && !(config.systemd.services ? amazon-ssm-agent);
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
            update.serviceConfig.ExecStart == config.systemd.services.nixos-update.serviceConfig.ExecStart
            && c.systemd.timers.nixos-update.timerConfig == config.systemd.timers.nixos-update.timerConfig
            && !(update.environment ? NIXOS_UPDATE_MODE)
          )
          [
            config
            ec2Config
          ];
      message = "Both hosts must share the updater and timer; no per-host activation policy.";
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
              fping
              ldns
              torsocks
              proxychains-ng
              tor
            ]
          )
        && config.programs.mtr.enable;
      message = "The VPN/proxy clients and network diagnostics must remain installed.";
    }
    {
      assertion =
        lib.all
          (
            c:
            let
              tor = c.services.tor;
              unit = c.systemd.services.tor;
            in
            tor.enable
            && tor.client.enable
            && !tor.relay.enable
            && !tor.openFirewall
            && tor.settings.ClientOnly
            && tor.settings.ORPort == [ ]
            && tor.settings.DirPort == [ ]
            && tor.settings.ExitPolicy == [ "reject *:*" ]
            && tor.relay.onionServices == { }
            && !tor.controlSocket.enable
            && tor.settings.ControlPort == [ ]
            && !tor.client.dns.enable
            && !tor.client.transparentProxy.enable
            && tor.settings.DNSPort == [ ]
            && tor.settings.TransPort == [ ]
            && builtins.length tor.settings.SOCKSPort == 1
            && lib.all (
              listener:
              listener.addr == "127.0.0.1"
              && listener.port == 9050
              && listener.IsolateDestAddr
              && listener.IsolateSOCKSAuth
            ) tor.settings.SOCKSPort
            && builtins.elem "multi-user.target" unit.wantedBy
            && unit.serviceConfig.Restart == "always"
            && unit.serviceConfig.RestartSec == "5s"
            && unit.unitConfig.StartLimitIntervalSec == 0
            && unit.serviceConfig.User == "tor"
            && unit.serviceConfig.NoNewPrivileges
          )
          [
            config
            ec2Config
          ];
      message = "Both hosts need a boot-enabled, restarting, loopback-only Tor client, without relay, control, DNS or transparent-proxy listeners.";
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
  for tool in wg wg-quick openvpn iperf3 nmap traceroute whois mtr dig tcpdump ethtool nc socat \
    fping drill torsocks proxychains4 tor nm-connection-editor resolvectl gnome-network-displays; do
    test -x "${config.system.path}/bin/$tool"
  done
  # Validate the exact generated torrc offline without touching live Tor state.
  mkdir -m 700 "$TMPDIR/tor"
  ${config.services.tor.package}/bin/tor --verify-config \
    -f ${builtins.head config.systemd.services.tor.restartTriggers} \
    --DataDirectory "$TMPDIR/tor"
  touch "$out"
''
