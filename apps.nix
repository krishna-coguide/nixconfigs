{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  c = import ./colors.nix;
  # Tauon follows the fast-moving pin without overlaying the system libraries.
  latest = import inputs.nixpkgs-latest {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config;
  };
  elementNightly = import ./element-nightly.nix { inherit pkgs; };
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
        "nvidia-kernel-modules"
        "nvidia-settings"
        "nvidia-persistenced"
      ]
    )
    || (
      builtins.elem "nvidia" config.services.xserver.videoDrivers
      && pkgs._cuda.lib.allowUnfreeCudaPredicate pkg
    );
  programs.thunar = {
    enable = true;
    plugins = [
      pkgs.thunar-archive-plugin
      pkgs.thunar-volman
    ];
  };
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = false;
  };
  programs.firefox = {
    enable = true;
    # Use the security-supported ESR line from the system pin.
    package = pkgs.firefox-esr;
    nativeMessagingHosts.packages = [ pkgs.keepassxc ];
    policies = {
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      Preferences = {
        "browser.compactmode.show" = {
          Value = true;
          Status = "default";
        };
        "browser.uidensity" = {
          Value = 1;
          Status = "default";
        };
        "browser.newtabpage.activity-stream.showSponsored" = {
          Value = false;
          Status = "locked";
        };
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = {
          Value = false;
          Status = "locked";
        };
      };
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
      # Keep Tor Browser's separate profile and upstream privacy defaults.
      # This is not Firefox pointed at the system Tor SOCKS port.
      tor-browser
      thunderbird
      file-roller
      imv
      latest.tauon
      # Electron does not reliably detect a keyring under Hyprland. Use the
      # KeePassXC Secret Service explicitly; never fall back to basic_text.
      elementNightly
      slack
    ];
    # Fix the pinned package's stale launcher command, preserving its metadata.
    xdg.dataFile."applications/tauonmb.desktop".source = pkgs.runCommand "tauonmb.desktop" { } ''
      substitute ${latest.tauon}/share/applications/tauonmb.desktop "$out" \
        --replace-quiet 'Exec=tauonmb ' 'Exec=${lib.getExe latest.tauon} '
    '';
    programs.mpv = {
      enable = true;
      config = {
        hwdec = "auto-safe";
        keep-open = true;
      };
    };
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
        font = "${builtins.head config.fonts.fontconfig.defaultFonts.monospace} 12";
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
        completion-highlight-bg = c.selection;
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
        "inode/directory" = [ "thunar.desktop" ];
        "application/zip" = [ "org.gnome.FileRoller.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/webp" = [ "imv.desktop" ];
        "video/mp4" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "audio/mpeg" = [ "mpv.desktop" ];
        "text/html" = [ "firefox-esr.desktop" ];
        "x-scheme-handler/http" = [ "firefox-esr.desktop" ];
        "x-scheme-handler/https" = [ "firefox-esr.desktop" ];
        "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
        "x-scheme-handler/matrix" = [ "element-desktop-nightly.desktop" ];
        "x-scheme-handler/element" = [ "element-desktop-nightly.desktop" ];
        "x-scheme-handler/io.element.desktop" = [ "element-desktop-nightly.desktop" ];
      };
    };
  };
}
