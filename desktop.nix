{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = import ./colors.nix;
  font = builtins.head config.fonts.fontconfig.defaultFonts.monospace;
  styleTokens = c // {
    inherit font;
  };
  renderColors =
    text:
    builtins.replaceStrings (map (name: "@${name}@") (
      builtins.attrNames styleTokens
    )) (builtins.attrValues styleTokens) text;
  rgb = color: "rgb(${lib.removePrefix "#" color})";
  wallpaper = import ./wallpaper.nix { inherit pkgs; };
  help = pkgs.writeShellApplication {
    name = "desktop-help";
    runtimeInputs = [
      pkgs.python3
      pkgs.hyprland
      pkgs.fuzzel
    ];
    text = ''exec python ${./desktop-help.py} "$@"'';
  };
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
  actions = pkgs.writeShellApplication {
    name = "desktop";
    runtimeInputs = with pkgs; [
      python3
      hyprland
      uwsm
      systemd
      fuzzel
      libnotify
      cliphist
      wl-clipboard
      grim
      slurp
      satty
      wf-recorder
      wireplumber
      pulseaudio
      brightnessctl
      power-profiles-daemon
      xdg-user-dirs
      xdg-utils
      swaynotificationcenter
      hyprlock
      networkmanager
      util-linux
    ];
    text = ''
      export DESKTOP_EMOJI_FILE=${pkgs.unicode-emoji.emoji-test}/share/unicode/emoji/emoji-test.txt
      exec python ${./desktop-actions.py} "$@"
    '';
  };
  screenshot = pkgs.writeShellApplication {
    name = "desktop-screenshot";
    runtimeInputs = [ actions ];
    text = ''exec desktop screenshot area --annotate "$@"'';
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
    actions
    help
    hyprpicker
    wf-recorder
    pavucontrol
    playerctl
    brightnessctl
    xdg-utils
    libnotify
  ];
  services.udev.packages = [ pkgs.brightnessctl ];
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.defaultFonts = {
    # Use the code font for generic UI/document families too, retaining
    # international glyph fallbacks rather than replacing missing characters.
    sansSerif = [
      font
      "Noto Sans"
    ];
    serif = [
      font
      "Noto Serif"
    ];
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
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
    gtk = {
      enable = true;
      font = {
        name = font;
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
      # GTK integration also supplies the same font to Qt 5/6 applications.
      # Let Home Manager provide BOTH Qt 5 and Qt 6 style plugins.
      style.name = "adwaita-dark";
    };
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        font-name = "${font} 11";
        document-font-name = "${font} 11";
        monospace-font-name = "${font} 12";
        accent-color = "yellow";
      };
      "org/gnome/desktop/wm/preferences".titlebar-font = "${font} Bold 11";
    };

    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      systemd.enable = false; # UWSM owns the session and environment.
      configType = "lua";
      extraConfig = renderColors (builtins.readFile ./hyprland.lua);
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
        layer = "Top";
        modules = {
          left = [
            [
              "appLauncher"
              "Workspaces"
              "desktopHelp"
            ]
            "WindowTitle"
          ];
          center = [ "Tempo" ];
          right = [
            "recording"
            "MediaPlayer"
            "SystemInfo"
            "notifications"
            "Tray"
            "Privacy"
            "Settings"
          ];
        };
        CustomModule = [
          {
            name = "appLauncher";
            icon = "󰍜";
            command = "uwsm app -- anyrun";
          }
          {
            name = "desktopHelp";
            icon = "󰋖";
            command = "uwsm app -- desktop-help";
          }
          {
            name = "notifications";
            icon = "󰂚";
            command = "uwsm app -- desktop notifications";
            listen_cmd = "swaync-client -swb";
            icons."dnd.*" = "󰂛";
            alert = "notification";
          }
          {
            name = "recording";
            command = "uwsm app -- desktop record";
            listen_cmd = "desktop status";
            alert = "recording";
          }
        ];
        enable_esc_key = true;
        media_player.max_title_length = 18;
        window_title = {
          mode = "Title";
          truncate_title_after_length = 26;
        };
        system_info = {
          indicators = [
            "Cpu"
            "Memory"
            "Temperature"
          ];
          interval = 5;
        };
        tempo.clock_format = "%a  %d %b  %H:%M";
        workspaces = {
          visibility_mode = "MonitorSpecific";
          enable_workspace_filling = false;
          workspace_names = [
            "01"
            "02"
            "03"
            "04"
            "05"
            "06"
            "07"
            "08"
            "09"
            "10"
          ];
        };
        settings = {
          lock_cmd = "loginctl lock-session";
          logout_cmd = "uwsm app -- desktop power";
          shutdown_cmd = "uwsm app -- desktop power";
          reboot_cmd = "uwsm app -- desktop power";
          CustomButton = [
            {
              name = "Actions";
              icon = "󰒓";
              command = "uwsm app -- desktop menu";
            }
            {
              name = "Health";
              icon = "󰄦";
              command = "uwsm app -- kitty --hold -e desktop health";
            }
          ];
          audio_sinks_more_cmd = "uwsm app -- pavucontrol -t 3";
          audio_sources_more_cmd = "uwsm app -- pavucontrol -t 4";
          wifi_more_cmd = "uwsm app -- nm-connection-editor";
          vpn_more_cmd = "uwsm app -- nm-connection-editor";
          bluetooth_more_cmd = "uwsm app -- blueman-manager";
          indicators = [
            "IdleInhibitor"
            "Audio"
          ]
          ++ lib.optionals networkManager [
            "Network"
            "Vpn"
          ]
          ++ lib.optionals bluetooth [ "Bluetooth" ]
          ++ lib.optionals power [ "Battery" ];
          audio_indicator_format = "IconAndPercentage";
        };
        appearance = {
          font_name = font;
          scale_factor = 1.15;
          style = "Solid";
          opacity = 1.0;
          primary_color = {
            base = c.accent;
            text = c.background;
          };
          text_color = c.text;
          success_color = c.green;
          danger_color = c.red;
          background_color = {
            base = c.background;
            weak = c.surface;
            strong = c.raised;
          };
          secondary_color.base = c.surface;
          workspace_colors = [ c.accent ];
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
        width.fraction = 0.5;
        y.fraction = 0.12;
        hidePluginInfo = true;
        closeOnClick = true;
        showResultsImmediately = true;
        maxEntries = 6;
      };
      extraCss = renderColors (builtins.readFile ./anyrun.css);
      extraConfigFiles."applications.ron".text = ''
        (
          desktop_actions: false,
          hide_description: true,
          max_entries: 6,
          terminal: Some((command: "uwsm", args: "app -- kitty -e {}")),
          preprocess_exec_script: Some("${launcherExec}"),
        )
      '';
    };

    # Calculator copy-to-clipboard needs the daemon; Home Manager owns its unit.
    programs.anyrun.daemon.enable = true;
    systemd.user.services.anyrun.Unit.ConditionEnvironment = "WAYLAND_DISPLAY";

    # Fuzzel is the shared dmenu-style picker for actions/help; Anyrun remains
    # the app launcher/calculator, not a second competing autostarted shell.
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "${font}:size=11";
          terminal = "kitty";
          "launch-prefix" = "uwsm app --";
          "line-height" = 22;
          width = 46;
          lines = 10;
          "horizontal-pad" = 18;
          "vertical-pad" = 14;
        };
        colors = {
          background = "${lib.removePrefix "#" c.background}ff";
          text = "${lib.removePrefix "#" c.text}ff";
          match = "${lib.removePrefix "#" c.accent}ff";
          selection = "${lib.removePrefix "#" c.selection}ff";
          "selection-text" = "${lib.removePrefix "#" c.text}ff";
          "selection-match" = "${lib.removePrefix "#" c.accent}ff";
          border = "${lib.removePrefix "#" c.border}ff";
          prompt = "${lib.removePrefix "#" c.muted}ff";
        };
        border = {
          width = 2;
          radius = 6;
        };
      };
    };

    services.swaync = {
      enable = true;
      style = renderColors (builtins.readFile ./swaync.css);
      settings = {
        positionX = "right";
        positionY = "top";
        control-center-width = 340;
        control-center-height = 500;
        control-center-margin-top = 8;
        control-center-margin-right = 8;
        notification-window-width = 360;
        fit-to-screen = false;
        timeout = 6;
        timeout-critical = 0;
        keyboard-shortcuts = true;
        hide-on-action = true;
        widgets = [
          "title"
          "dnd"
          "mpris"
          "notifications"
        ];
        widget-config = {
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = "Clear";
          };
          dnd.text = "Do not disturb";
          mpris = {
            image-size = 64;
            image-radius = 4;
          };
        };
      };
    };
    services.hyprsunset = {
      enable = true;
      settings.profile = [
        {
          time = "07:00";
          identity = true;
        }
        {
          time = "21:00";
          temperature = 4200;
        }
      ];
    };
    systemd.user.services.desktop-clipboard = {
      Unit = {
        Description = "Session-local clipboard history";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${actions}/bin/desktop clipboard-store";
        ExecStopPost = "${actions}/bin/desktop clipboard-clear";
        Restart = "on-failure";
        UMask = "0077";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    systemd.user.services.desktop-battery = lib.mkIf power {
      Unit = {
        Description = "Low/critical battery notifications";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionPathExistsGlob = "/sys/class/power_supply/BAT*";
      };
      Service = {
        ExecStart = "${actions}/bin/desktop battery";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
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
            font_size = 64;
            font_family = font;
            color = rgb c.text;
            position = "0,100";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = "$USER";
            font_size = 18;
            font_family = font;
            color = rgb c.muted;
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
            font_family = font;
            rounding = 6;
            inner_color = rgb c.surface;
            outer_color = rgb c.accent;
            font_color = rgb c.text;
            check_color = rgb c.green;
            fail_color = rgb c.red;
            capslock_color = rgb c.yellow;
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
          lock_cmd = "${actions}/bin/desktop lock-start";
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
