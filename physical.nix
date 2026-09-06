# This machine: dev + managed Hyprland only; preserve boot/storage and old home data.
# Hardware settings were copied from /etc/nixos; those original files stay untouched.
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
  imports = [
    ./hardware-configuration.nix
    ./common.nix
    ./updates.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openvpn ];
  };
  # Keep NetworkManager's installed DNS policy.
  services.resolved.enable = false;

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Keep the working SDDM greeter; only the managed Hyprland session is offered.
  # No autologin, second desktop environment, or competing session owner.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };
  services.displayManager = {
    sddm.enable = true;
    defaultSession = "hyprland-uwsm";
    # The upstream package also advertises a plain session that never starts
    # our bar/idle/polkit services. Hide that trap, not the managed startup.
    sessionPackages = lib.mkForce [ managedHyprlandSession ];
  };
  services.printing.enable = true;
  services.pulseaudio.enable = false;

  # Preserve dev's locally established password. Removing the previously
  # managed kbot account does NOT request deletion of /home/kbot.
  users.mutableUsers = true;
  users.users.dev.extraGroups = [ "networkmanager" ];
  environment.systemPackages = [ pkgs.networkmanagerapplet ];
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.fwupd.enable = true;
  home-manager.users.dev.services.udiskie.enable = true;
  # One clean step below the panel's automatic 150%: 1440x900 logical pixels.
  # Leave external displays on the shared configuration's automatic scale.
  home-manager.users.dev.wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 4 / 3 })
  '';
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };
  services.blueman.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  # sysinfo's component label for this Intel CPU, not another laptop's ACPI zone.
  home-manager.users.dev.programs.ashell.settings.system_info.temperature.sensor =
    "coretemp Package id 0";
  home-manager.users.dev.xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman
    Hidden=true
  '';

  # Retain the installed host's package policy.
  nixpkgs.config.allowUnfree = true;

  # /etc/nix is administrator-owned. Stage tested updates for the next boot,
  # rather than restarting a compositor/display manager under an active user.
  systemd.services.nixos-update = {
    environment = {
      NIXOS_CONFIG_REPO = "/etc/nix";
      NIXOS_UPDATE_HOST = "nixos";
      NIXOS_UPDATE_MODE = "boot";
    };
    serviceConfig = {
      User = "root";
      Group = "root";
    };
  };
  # Neither /etc/nixos nor /home/kbot is handed over to dev/Home Manager.
}
