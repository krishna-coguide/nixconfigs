{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = import ./colors.nix;
  wallpaper = pkgs.runCommand "quiet-orbit.png" { nativeBuildInputs = [ pkgs.resvg ]; } ''
    resvg ${./wallpaper.svg} "$out"
  '';
  wallpaperInit = pkgs.writeShellApplication {
    name = "initialize-wallpaper";
    runtimeInputs = [
      pkgs.awww
      pkgs.coreutils
    ];
    text = ''
      # Socket readiness precedes Wayland output discovery on a cold login.
      for ((attempt=0; attempt<30; attempt++)); do
        if awww img ${wallpaper} --transition-type fade --transition-duration 0.5; then
          exit 0
        fi
        sleep 0.5
      done
      echo 'No wallpaper output became ready.' >&2
      exit 1
    '';
  };
  screenshot = pkgs.writeShellApplication {
    name = "desktop-screenshot";
    runtimeInputs = with pkgs; [
      grim
      slurp
      satty
      wl-clipboard
      coreutils
    ];
    text = ''
      geometry=$(slurp) || exit 0
      [ -n "$geometry" ] || exit 0
      mkdir -p "$HOME/Pictures/Screenshots"
      grim -g "$geometry" - | satty --filename - --copy-command wl-copy \
        --output-filename "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
    '';
  };
  launcherExec = pkgs.writeShellScript "anyrun-uwsm" ''
    kind=$1
    shift
    if [ "$kind" = term ]; then
      printf '%s\n' "$*"
    else
      printf 'uwsm app -- %s\n' "$*"
    fi
  '';
  networkManager = config.networking.networkmanager.enable;
  bluetooth = config.hardware.bluetooth.enable;
  power = config.services.upower.enable;
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  hardware.graphics.enable = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;
  programs.dconf.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # NixOS's Hyprland module already installs the Hyprland and GTK portals.
  xdg.portal.config.hyprland = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    wl-clipboard
    grim
    slurp
    satty
    screenshot
    pavucontrol
    playerctl
    brightnessctl
    xdg-utils
    libnotify
  ];
  services.udev.packages = [ pkgs.brightnessctl ];
  fonts.packages = with pkgs; [
    inter
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.defaultFonts = {
    sansSerif = [
      "Inter"
      "Noto Sans"
    ];
    serif = [ "Noto Serif" ];
    emoji = [ "Noto Color Emoji" ];
  };

  home-manager.users.dev = {
    xdg.enable = true;
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };
    xdg.autostart.enable = true;
    home.pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
    gtk = {
      enable = true;
      font = {
        name = "Inter";
        size = 11;
      };
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    };
    qt = {
      enable = true;
      platformTheme.name = "gtk3";
      # Let Home Manager provide BOTH Qt 5 and Qt 6 style plugins.
      style.name = "adwaita-dark";
    };
    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      font-name = "Inter 11";
      monospace-font-name = "JetBrainsMono Nerd Font 13";
    };

    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      systemd.enable = false; # UWSM owns the session and environment.
      configType = "lua";
      extraConfig = builtins.readFile ./hyprland.lua;
    };
    services.hyprpolkitagent.enable = true;
    services.awww.enable = true;
    systemd.user.services.awww.Service = {
      Type = "notify";
      CacheDirectory = "awww";
      ExecStartPost = "${wallpaperInit}/bin/initialize-wallpaper";
    };

    programs.ashell = {
      enable = true;
      systemd.enable = true;
      settings = {
        log_level = "warn";
        position = "Top";
        modules = {
          left = [
            [
              "appLauncher"
              "Workspaces"
            ]
          ];
          center = [ "Tempo" ];
          right = [
            "SystemInfo"
            [
              "Tray"
              "Privacy"
              "Settings"
            ]
          ];
        };
        CustomModule = [
          {
            name = "appLauncher";
            icon = "󰍜";
            command = "uwsm app -- anyrun";
          }
        ];
        tempo.clock_format = "%a  %d %b  %H:%M";
        workspaces = {
          visibility_mode = "MonitorSpecific";
          enable_workspace_filling = true;
        };
        system_info = {
          indicators = [
            "Cpu"
            "Memory"
          ];
          interval = 5;
        };
        settings = {
          lock_cmd = "loginctl lock-session";
          logout_cmd = "uwsm stop";
          audio_sinks_more_cmd = "uwsm app -- pavucontrol -t 3";
          audio_sources_more_cmd = "uwsm app -- pavucontrol -t 4";
          wifi_more_cmd = "uwsm app -- nm-connection-editor";
          vpn_more_cmd = "uwsm app -- nm-connection-editor";
          bluetooth_more_cmd = "uwsm app -- blueman-manager";
          indicators = [
            "IdleInhibitor"
            "Audio"
            "Microphone"
          ]
          ++ lib.optionals networkManager [
            "Network"
            "Vpn"
          ]
          ++ lib.optionals bluetooth [ "Bluetooth" ]
          ++ lib.optionals power [
            "PowerProfile"
            "Battery"
            "Brightness"
          ];
          audio_indicator_format = "IconAndPercentage";
        };
        appearance = {
          font_name = "Inter";
          scale_factor = 1.15;
          style = "Islands";
          opacity = 1.0;
          primary_color = c.blue;
          text_color = c.text;
          success_color = c.green;
          danger_color = c.red;
          background_color = {
            base = c.background;
            weak = c.surface;
            strong = c.raised;
          };
          secondary_color.base = c.surface;
          workspace_colors = [
            c.blue
            c.purple
            c.cyan
          ];
        };
      };
    };
    systemd.user.services.ashell.Unit.PartOf = [ "graphical-session.target" ];

    programs.anyrun = {
      enable = true;
      config = {
        plugins = [
          "${pkgs.anyrun}/lib/libapplications.so"
          "${pkgs.anyrun}/lib/librink.so"
        ];
        width.fraction = 0.42;
        y.fraction = 0.2;
        hidePluginInfo = true;
        closeOnClick = true;
        maxEntries = 8;
      };
      extraCss = builtins.readFile ./anyrun.css;
      extraConfigFiles."applications.ron".text = ''
        (
          desktop_actions: false,
          max_entries: 8,
          terminal: Some((command: "uwsm", args: "app -- kitty -e {}")),
          preprocess_exec_script: Some("${launcherExec}"),
        )
      '';
    };

    services.mako = {
      enable = true;
      settings = {
        font = "Inter 11";
        width = 360;
        height = 160;
        margin = "12";
        padding = "14";
        border-size = 2;
        border-radius = 12;
        background-color = c.background;
        text-color = c.text;
        border-color = c.border;
        default-timeout = 6000;
        max-visible = 4;
        max-icon-size = 48;
        "urgency=critical" = {
          border-color = c.red;
          default-timeout = 0;
        };
      };
    };
    programs.hyprlock = {
      enable = true;
      package = null;
      settings = {
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
        };
        background = [
          {
            monitor = "";
            path = "${wallpaper}";
            blur_passes = 2;
          }
        ];
        label = [
          {
            monitor = "";
            text = "cmd[update:1000] date +'%H:%M'";
            font_size = 84;
            font_family = "Inter";
            color = "rgb(f2f4f8)";
            position = "0,100";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = "$USER";
            font_size = 18;
            font_family = "Inter";
            color = "rgb(a2a9b0)";
            position = "0,0";
            halign = "center";
            valign = "center";
          }
        ];
        input-field = [
          {
            monitor = "";
            size = "320,60";
            position = "0,-100";
            halign = "center";
            valign = "center";
            outline_thickness = 2;
            dots_center = true;
            fade_on_empty = false;
            font_family = "Inter";
            inner_color = "rgb(262626)";
            outer_color = "rgb(78a9ff)";
            font_color = "rgb(f2f4f8)";
            check_color = "rgb(3ddbd9)";
            fail_color = "rgb(ff6b7a)";
            capslock_color = "rgb(f1c21b)";
            placeholder_text = "<i>Password</i>";
            fail_text = "<i>Try again ($ATTEMPTS)</i>";
          }
        ];
      };
    };
    services.hypridle = {
      enable = true;
      package = null; # NixOS owns the service and PAM integration.
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
          inhibit_sleep = 3;
        };
        listener = [
          {
            timeout = 600;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 900;
            on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
            on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
          }
        ];
      };
    };
  };
}
