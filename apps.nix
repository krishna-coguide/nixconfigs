{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = import ./colors.nix;
  browserAddon = pkgs.fetchurl {
    name = "keepassxc-browser-1.10.3.xpi";
    url = "https://addons.mozilla.org/firefox/downloads/file/4831838/keepassxc_browser-1.10.3.xpi";
    sha256 = "4df9c54e0a293aa2e37e9bcf97ec307a35a00e78cebaa9a68edba552c07c4568";
  };
  keepassDefaults = (pkgs.formats.ini { }).generate "keepassxc-defaults.ini" {
    General = {
      ConfigVersion = 2;
      UpdateCheckMessageShown = true;
    };
    GUI = {
      ApplicationTheme = "dark";
      ShowTrayIcon = true;
      MinimizeToTray = true;
      MinimizeOnStartup = true;
    };
    Browser = {
      Enabled = true;
      UpdateBinaryPath = false;
    };
    Security.LockDatabaseScreenLock = true;
    FdoSecrets.Enabled = true;
  };
in
{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) (
      [
        "steam"
        "steam-unwrapped"
        "steam-run"
        "steam-original"
        "slack"
      ]
      ++ lib.optionals (builtins.elem "nvidia" config.services.xserver.videoDrivers) [
        "nvidia-x11"
        "nvidia-settings"
        "nvidia-persistenced"
      ]
    );
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = false;
  };
  programs.firefox = {
    enable = true;
    # Stable's ESR is security-current (153.2); regular 155.0 is one patch behind.
    package = pkgs.firefox-esr;
    nativeMessagingHosts.packages = [ pkgs.keepassxc ];
    policies = {
      DisableTelemetry = true;
      OfferToSaveLogins = false;
      ExtensionSettings."keepassxc-browser@keepassxc.org" = {
        installation_mode = "normal_installed";
        install_url = "file://${browserAddon}";
      };
    };
  };
  services.dbus.packages = [ pkgs.keepassxc ];

  home-manager.users.dev = {
    home.packages = with pkgs; [
      thunderbird
      element-desktop
      slack
    ];
    programs.keepassxc = {
      enable = true;
      autostart = true;
    };
    # C copies only when absent. Preferences stay writable; vaults, browser
    # association and the Secret Service exposed group remain user-controlled.
    systemd.user.tmpfiles.rules = [
      "d %h/.config/keepassxc 0700 - - -"
      "C %h/.config/keepassxc/keepassxc.ini 0600 - - - ${keepassDefaults}"
    ];
    programs.zathura = {
      enable = true;
      options = {
        font = "Inter 12";
        adjust-open = "best-fit";
        zoom-step = 10;
        recolor = false; # Preserve actual document colors; Ctrl-R toggles recolor.
        default-bg = c.background;
        default-fg = c.text;
        statusbar-bg = c.surface;
        statusbar-fg = c.text;
        inputbar-bg = c.surface;
        inputbar-fg = c.text;
        completion-bg = c.background;
        completion-fg = c.text;
        completion-highlight-bg = "#354562";
        completion-highlight-fg = c.text;
        notification-bg = c.surface;
        notification-fg = c.text;
        notification-error-bg = c.red;
        notification-error-fg = c.background;
        recolor-darkcolor = c.text;
        recolor-lightcolor = c.background;
      };
    };
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "text/html" = [ "firefox-esr.desktop" ];
        "x-scheme-handler/http" = [ "firefox-esr.desktop" ];
        "x-scheme-handler/https" = [ "firefox-esr.desktop" ];
        "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
        "x-scheme-handler/matrix" = [ "element-desktop.desktop" ];
      };
    };
  };
}
