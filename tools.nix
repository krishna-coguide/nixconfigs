{ pkgs, ... }:

let
  c = import ./colors.nix;
in
{
  programs.git.enable = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    nixfmt
    ripgrep
    fd
    eza
    jq
    yq-go
    curl
    wget
    file
    tree
    unzip
    zip
    p7zip
    rsync
    openssl
    lsof
    strace
    psmisc
    pciutils
    usbutils
    smartmontools
    nvme-cli
    lm_sensors
    man-pages
    man-pages-posix
  ];

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];

  home-manager.users.dev = { config, ... }: {
    programs.git = {
      enable = true;
      package = null; # The system module supplies Git.
      settings.user.useConfigOnly = true;
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      defaultKeymap = "emacs";
      history = {
        path = "${config.xdg.stateHome}/zsh/history";
        size = 50000;
        save = 50000;
        ignoreSpace = true;
        expireDuplicatesFirst = true;
      };
      shellAliases = {
        ll = "eza --long --group-directories-first --icons=auto";
        la = "eza --long --all --group-directories-first --icons=auto";
      };
      initContent = ''
        bindkey '^[[H' beginning-of-line
        bindkey '^[[F' end-of-line
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
      '';
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
      defaultOptions = [
        "--height=45%"
        "--layout=reverse"
        "--border=rounded"
      ];
      fileWidgetOptions = [ "--preview 'bat --color=always --line-range=:200 -- {}'" ];
      colors = {
        bg = c.background;
        fg = c.text;
        "bg+" = c.surface;
        "fg+" = c.text;
        hl = c.cyan;
        "hl+" = c.cyan;
        border = c.border;
        prompt = c.blue;
        pointer = c.purple;
        marker = c.green;
        info = c.muted;
      };
    };

    programs.starship = {
      enable = true;
      settings = {
        add_newline = true;
        format = "$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration\n$character";
        directory = {
          style = "bold ${c.blue}";
          truncation_length = 4;
          truncation_symbol = "…/";
          read_only = " [read-only]";
        };
        git_branch = {
          symbol = "git:";
          style = c.purple;
        };
        git_status.style = c.purple;
        nix_shell = {
          format = "[nix:$name]($style) ";
          style = c.cyan;
        };
        cmd_duration = {
          format = "[$duration]($style) ";
          style = c.muted;
        };
        character = {
          success_symbol = "[❯](bold ${c.cyan})";
          error_symbol = "[❯](bold ${c.red})";
        };
      };
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    programs.bat = {
      enable = true;
      config.theme = "base16";
    };
    programs.btop = {
      enable = true;
      settings = {
        theme_background = false;
        rounded_corners = true;
        update_ms = 1500;
      };
    };
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      settings.mgr = {
        show_hidden = true;
        sort_by = "natural";
        sort_dir_first = true;
      };
    };

    programs.alacritty = {
      enable = true;
      settings = {
        window = {
          padding = {
            x = 16;
            y = 12;
          };
          dynamic_padding = true;
          decorations = "None";
          opacity = 1.0;
        };
        font = {
          normal = {
            family = "JetBrainsMono Nerd Font";
            style = "Regular";
          };
          bold = {
            family = "JetBrainsMono Nerd Font";
            style = "Bold";
          };
          italic = {
            family = "JetBrainsMono Nerd Font";
            style = "Italic";
          };
          size = 13.0;
          offset.y = 2;
        };
        cursor = {
          style = {
            shape = "Beam";
            blinking = "Off";
          };
          unfocused_hollow = true;
        };
        scrolling.history = 20000;
        selection.save_to_clipboard = false;
        colors = {
          primary = {
            background = c.background;
            foreground = c.text;
          };
          cursor = {
            text = c.background;
            cursor = c.cyan;
          };
          selection = {
            text = c.text;
            background = "#354562";
          };
          normal = {
            black = c.surface;
            red = c.red;
            green = c.green;
            yellow = c.yellow;
            blue = c.blue;
            magenta = c.purple;
            cyan = c.cyan;
            white = "#dde1e6";
          };
          bright = {
            black = c.muted;
            red = "#ff99a0";
            green = "#6fdc8c";
            yellow = "#f7d75c";
            blue = "#a6c8ff";
            magenta = "#d4bbff";
            cyan = "#82e9de";
            white = c.text;
          };
        };
        keyboard.bindings = [
          {
            key = "Equals";
            mods = "Control|Shift";
            action = "IncreaseFontSize";
          }
          {
            key = "Minus";
            mods = "Control|Shift";
            action = "DecreaseFontSize";
          }
          {
            key = "Key0";
            mods = "Control|Shift";
            action = "ResetFontSize";
          }
        ];
      };
    };
  };
}
