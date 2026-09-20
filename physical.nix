# Laptop-only boot/storage, hardware measurements and checkout identity.
# The original /etc/nixos files and /home/kbot remain untouched.
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./common.nix
    ./workstation.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  networking.hostName = "nixos";

  # 1440x900 logical pixels; leave other displays on automatic scaling.
  home-manager.users.dev.wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 4 / 3 })
  '';
  home-manager.users.dev.programs.ashell.settings.system_info.temperature.sensor =
    "coretemp Package id 0";

  # Deployment path/target are selected centrally in hosts.nix.
}
