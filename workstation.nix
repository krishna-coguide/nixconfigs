# Local hardware/session integration. Shared by the laptop and graphical VM,
# not the headless EC2 host; all application/user settings live in common.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  font = builtins.head config.fonts.fontconfig.defaultFonts.monospace;
  greeterTheme = import ./greeter-theme.nix { inherit pkgs font; };
  # Work around missed wpa_supplicant peer signals by refreshing the P2P peer
  # property during discovery. Remove once NetworkManager handles this natively.
  networkManager = pkgs.networkmanager.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./networkmanager-p2p-peer-refresh.patch ];
    passthru = (old.passthru or { }) // {
      miracastPeerRefresh = true;
    };
  });
  managedHyprlandSession =
    pkgs.runCommand "hyprland-managed-session"
      {
        passthru.providedSessions = [ "hyprland-uwsm" ];
      }
      ''
        mkdir -p "$out/share/wayland-sessions"
        ln -s ${config.programs.hyprland.package}/share/wayland-sessions/hyprland-uwsm.desktop \
          "$out/share/wayland-sessions/hyprland-uwsm.desktop"
      '';
in
{
  networking.networkmanager = {
    enable = true;
    package = networkManager;
    plugins = [ pkgs.networkmanager-openvpn ];
    # Miracast requires NetworkManager's Wi-Fi Direct support, not iwd.
    wifi.backend = "wpa_supplicant";
  };
  networking.dhcpcd.enable = false;
  users.users.dev.extraGroups = [ "networkmanager" ];

  # Broad Miracast compatibility on every workstation interface (LAN and
  # dynamically named Wi-Fi Direct links), never on the headless EC2 host.
  # This intentionally exposes other listeners on these ports too.
  networking.firewall = {
    enable = true;
    checkReversePath = "loose"; # Permit asymmetric Wi-Fi/VPN return routes.
    allowedTCPPorts = [
      53 # NetworkManager's DNS server when providing the P2P network
      7236 # Miracast RTSP
      7250 # Miracast over infrastructure (MICE)
    ];
    allowedUDPPorts = [
      53 # P2P DNS
      67 # P2P DHCP server
      68 # P2P DHCP client, including broadcast replies
    ];
    # RTP/RTCP uses negotiated ports, not a fixed UDP 7236 listener. This is
    # an explicitly broad compatibility policy, not a protocol-required range.
    allowedUDPPortRanges = [
      {
        from = 1024;
        to = 65535;
      }
    ];
  };
  # LAN display discovery uses Avahi's D-Bus API. Keep resolved as the DNS
  # resolver; Avahi opens UDP 5353 without enabling host/service publishing.
  services.avahi = {
    enable = true;
    openFirewall = true;
  };

  services.xserver.enable = true;
  services.displayManager = {
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm; # Qt6 runtime, not the Plasma desktop.
      theme = "sddm-astronaut-theme";
      extraPackages = [ greeterTheme ]; # Carries the theme's Qt6 QML dependencies.
      settings.Theme = {
        Font = font;
        CursorTheme = "Bibata-Modern-Ice";
        CursorSize = 24;
      };
    };
    defaultSession = "hyprland-uwsm";
    # Plain Hyprland bypasses the UWSM-owned bar/idle/polkit services.
    sessionPackages = lib.mkForce [ managedHyprlandSession ];
  };
  services.printing.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.fwupd.enable = true;
  home-manager.users.dev.services.udiskie.enable = true;
  environment.systemPackages = [
    pkgs.networkmanagerapplet
    greeterTheme
    pkgs.bibata-cursors
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };
  services.blueman.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  # Retain Blueman's manager without a second tray applet next to ashell.
  home-manager.users.dev.xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman
    Hidden=true
  '';
}
