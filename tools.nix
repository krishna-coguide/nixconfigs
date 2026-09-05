{ pkgs, ... }:

let
  c = import ./colors.nix;
in
{
  programs.git.enable = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    nixfmt
    pi-coding-agent
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

    programs.kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 13;
      };
      settings = {
        window_padding_width = 14;
        background_opacity = "1.0";
        hide_window_decorations = true;
        scrollback_lines = 20000;
        enable_audio_bell = false;
        cursor_shape = "beam";
        cursor_blink_interval = 0;
        adjust_line_height = "110%";
        foreground = c.text;
        background = c.background;
        cursor = c.cyan;
        selection_foreground = c.text;
        selection_background = "#354562";
        url_color = c.blue;
        active_border_color = c.blue;
        inactive_border_color = c.border;
        color0 = c.surface;
        color1 = c.red;
        color2 = c.green;
        color3 = c.yellow;
        color4 = c.blue;
        color5 = c.purple;
        color6 = c.cyan;
        color7 = "#dde1e6";
        color8 = c.muted;
        color9 = "#ff99a0";
        color10 = "#6fdc8c";
        color11 = "#f7d75c";
        color12 = "#a6c8ff";
        color13 = "#d4bbff";
        color14 = "#82e9de";
        color15 = c.text;
      };
    };
  };
}
