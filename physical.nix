# This machine: retain the installed kbot/Plasma recovery environment and add dev.
# Hardware settings were copied from /etc/nixos; those original files stay untouched.
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./common.nix
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
  # Keep the installed DNS setup while testing the additional desktop.
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

  # SDDM offers both Plasma and Hyprland (uwsm-managed). Do not replace it with
  # workstation.nix's greetd/ReGreet or enable autologin during this migration.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.printing.enable = true;
  services.pulseaudio.enable = false;

  # Preserve kbot's existing password and allow `sudo passwd dev` after activation.
  # No password hashes or credentials are copied into this repository/the store.
  users.mutableUsers = true;
  users.users.kbot = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/kbot";
    description = "kbot";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = [ pkgs.kdePackages.kate ];
  };
  users.users.dev.extraGroups = [ "networkmanager" ];
  environment.systemPackages = [ pkgs.networkmanagerapplet ];
  home-manager.users.dev.services.udiskie.enable = true;

  # Retain the installed host's package policy.
  nixpkgs.config.allowUnfree = true;

  # Intentionally no updates.nix: that updater builds the EC2 dev target.
  # Neither /etc/nixos nor /home/kbot is handed over to dev/Home Manager.
}
