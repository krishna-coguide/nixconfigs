# Opt-in physical workstation integration. Never imported by the EC2 host.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.networkmanager.enable = true;
  networking.dhcpcd.enable = false;
  users.users.dev.extraGroups = [ "networkmanager" ];
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };
  services.blueman.enable = true;
  # Keep Blueman's manager/mechanism, not a second tray applet next to ashell.
  home-manager.users.dev.xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman
    Hidden=true
  '';
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.udisks2.enable = true;
  home-manager.users.dev.services.udiskie.enable = true;
  environment.systemPackages = [ pkgs.networkmanagerapplet ];

  programs.regreet = {
    enable = true;
    theme.name = "Adwaita-dark";
    font = {
      package = pkgs.inter;
      name = "Inter";
      size = 13;
    };
    settings.GTK.application_prefer_dark_theme = true;
  };
  # No autologin. The physical host must supply a secure credential file.
  assertions = [
    {
      assertion = config.users.users.dev.hashedPasswordFile != null;
      message = "workstation.nix requires users.users.dev.hashedPasswordFile (provision outside the Nix store); no production password is invented.";
    }
  ];
}
