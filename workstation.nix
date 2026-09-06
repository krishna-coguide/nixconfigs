# Local hardware/session integration. Shared by the laptop and graphical VM,
# not the headless EC2 host; all application/user settings live in common.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
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
    plugins = [ pkgs.networkmanager-openvpn ];
  };
  networking.dhcpcd.enable = false;
  users.users.dev.extraGroups = [ "networkmanager" ];

  services.xserver.enable = true;
  services.displayManager = {
    sddm.enable = true;
    defaultSession = "hyprland-uwsm";
    # Plain Hyprland bypasses the UWSM-owned bar/idle/polkit services.
    sessionPackages = lib.mkForce [ managedHyprlandSession ];
  };
  services.printing.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.fwupd.enable = true;
  home-manager.users.dev.services.udiskie.enable = true;
  environment.systemPackages = [ pkgs.networkmanagerapplet ];

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
