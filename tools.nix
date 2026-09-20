{ inputs, pkgs, ... }:

let
  c = import ./colors.nix;
  font = "JetBrainsMono Nerd Font";
  # Standalone tools from the fast-moving pin, NOT an overlay of the system's
  # Python/GCC/libraries. Desktop, drivers and NixOS services remain coherent.
  latest = import inputs.nixpkgs-latest {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config;
  };
in
{
  programs.git = {
    enable = true;
    package = latest.git;
    lfs.enable = true;
    lfs.package = latest.git-lfs;
  };
  programs.zsh.enable = true;
  # Native module supplies rootless mappings/networking. No Docker daemon,
  # docker-group access, public API socket, containers or images on activation.
  virtualisation.podman.enable = true;
  # Mason's upstream Linux executables expect a conventional dynamic loader.
  programs.nix-ld.enable = true;

  environment.systemPackages = [
    pkgs.nixfmt
    # DSH's built-in sandbox-local prefers bwrap; no setuid wrapper or service.
    pkgs.bubblewrap
  ]
  ++ (with latest; [
    pi-coding-agent

    # Native builds and the unchanged Lazy/Mason runtime prerequisites.
    gcc
    gnumake
    pkg-config
    cmake
    ninja
    meson
    ccache
    python3
    nodejs
    lua5_1
    luajitPackages.luarocks
    clang-tools
    gdb
    lldb
    valgrind
    heaptrack
    rr
    elfutils
    bpftrace

    # Language toolchains, testing and dependency/security audits.
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    cargo-nextest
    cargo-audit
    cargo-deny
    cargo-expand
    cargo-edit
    go
    gopls
    delve
    golangci-lint
    uv
    ruff
    pyright
    pnpm
    typescript
    biome
    bun
    deno
    # JVM, .NET, Ruby/PHP, Zig and BEAM: project versions still belong in devShells.
    jdk25
    maven
    gradle_9
    kotlin
    dotnet-sdk_10
    ruby
    bundler
    php
    phpPackages.composer
    zig
    zls
    beamPackages.elixir
    beamPackages.erlang
    protobuf
    buf
    shellcheck
    shfmt
    just
    hyperfine
    watchexec
    tokei
    yamllint
    actionlint
    pre-commit
    dprint
    stylua
    taplo
    marksman
    markdownlint-cli2
    sqlfluff
    hadolint
    ast-grep
    ripgrep-all

    # Version control: no invented identity, login or credentials.
    gh
    glab
    git-absorb
    git-filter-repo
    difftastic
    jujutsu

    # Nix introspection and development; never replace the system Nix daemon.
    nix-output-monitor
    nvd
    nix-tree
    nix-diff
    statix
    deadnix
    nixd
    nixpkgs-review

    # Shell, structured data, file navigation and documentation.
    ripgrep
    fd
    eza
    jq
    yq-go
    jless
    sd
    tree
    file
    hexyl
    parallel
    moreutils
    tealdeer
    zellij
    miller
    csvlens
    sqlite
    duckdb
    pgcli
    litecli
    redis

    # HTTP/API clients. Packet-level tools belong in network.nix.
    curl
    wget
    xh
    grpcurl
    websocat
    hurl
    oha
    step-cli
    mkcert # Installed only: no CA is created or trusted automatically.

    # Cloud, containers and orchestration: clients only, no live infrastructure.
    awscli2
    skopeo
    buildah
    podman-compose
    dive
    kubectl
    kubernetes-helm
    k9s
    kubectx
    stern
    kustomize
    opentofu
    ansible

    # Encryption, secret scanning, backup and transfer. No automatic jobs or keys.
    age
    sops
    gnupg
    gitleaks
    trivy
    cosign
    syft
    grype
    restic
    rclone
    rsync
    mosh
    sshfs
    openssl
    unzip
    zip
    p7zip
    zstd
    lz4

    # Logs, storage, process and hardware diagnosis. No extra privileges granted.
    dust
    duf
    ncdu
    procs
    sysstat
    iotop
    lnav
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

    # Media/document tooling and rich Yazi previews.
    ffmpeg
    imagemagick
    mediainfo
    exiftool
    poppler-utils
    pandoc
    yt-dlp
    chafa
    asciinema
    vhs
  ]);

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  # Desktop/greeter consumers derive their font from this shared default.
  fonts.fontconfig.defaultFonts.monospace = [ font ];

  home-manager.users.dev = { config, ... }: {
    programs.git = {
      enable = true;
      package = null; # The system module supplies Git.
      settings = {
        user.useConfigOnly = true;
        core.askPass = ""; # Use /dev/tty, never fall back to SSH's GUI askpass.
        credential = {
          # Reset inherited helpers; keep secrets in memory, never plaintext files.
          helper = [
            ""
            "cache --timeout=31536000"
          ]; # 365 days; cleared on reboot.
          useHttpPath = true; # Don't reuse a repository token for unrelated paths.
        };
      };
    };
    home.sessionVariables = {
      GIT_ASKPASS = "";
      GIT_TERMINAL_PROMPT = "1";
    };

    programs.delta = {
      enable = true;
      package = latest.delta;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
      };
    };
    programs.lazygit = {
      enable = true;
      package = latest.lazygit;
      settings.gui = {
        nerdFontsVersion = "3";
        showRandomTip = false;
      };
    };
    programs.direnv = {
      enable = true;
      package = latest.direnv;
      enableZshIntegration = true;
      nix-direnv = {
        enable = true;
        package = latest.nix-direnv;
      };
      # Deliberately no whitelist: each project's .envrc needs `direnv allow`.
    };
    programs.tmux = {
      enable = true;
      package = latest.tmux;
      terminal = "tmux-256color";
      mouse = true;
      keyMode = "vi";
      historyLimit = 50000;
      escapeTime = 10;
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
        # `su dev` can inherit root's runtime directory and user bus. Preserve a
        # valid owned runtime; otherwise let terminal tools use their own fallback.
        if [[ -n ''${XDG_RUNTIME_DIR:-} && ! -O "$XDG_RUNTIME_DIR" ]]; then
          if [[ ''${DBUS_SESSION_BUS_ADDRESS:-} == "unix:path=$XDG_RUNTIME_DIR/bus"* ]]; then
            unset DBUS_SESSION_BUS_ADDRESS
          fi
          unset XDG_RUNTIME_DIR
        fi

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
      package = latest.fzf;
      defaultCommand = "fd --type f --hidden --exclude .git";
      fileWidget.command = "fd --type f --hidden --exclude .git";
      changeDirWidget.command = "fd --type d --hidden --exclude .git";
      defaultOptions = [
        "--height=45%"
        "--layout=reverse"
        "--border=rounded"
      ];
      fileWidget.options = [ "--preview 'bat --color=always --line-range=:200 -- {}'" ];
      colors = {
        bg = c.background;
        fg = c.text;
        "bg+" = c.surface;
        "fg+" = c.text;
        hl = c.cyan;
        "hl+" = c.cyan;
        border = c.border;
        prompt = c.accent;
        pointer = c.purple;
        marker = c.green;
        info = c.muted;
      };
    };

    programs.starship = {
      enable = true;
      package = latest.starship;
      settings = {
        add_newline = true;
        format = "$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration\n$character";
        directory = {
          style = "bold ${c.accent}";
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
      package = latest.zoxide;
      enableZshIntegration = true;
    };
    programs.bat = {
      enable = true;
      package = latest.bat;
      config.theme = "base16";
    };
    programs.btop = {
      enable = true;
      package = latest.btop;
      settings = {
        theme_background = false;
        rounded_corners = true;
        update_ms = 1500;
      };
    };
    programs.yazi = {
      enable = true;
      package = latest.yazi;
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
        name = font;
        size = 12;
      };
      settings = {
        window_padding_width = 10;
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
        selection_background = c.selection;
        url_color = c.blue;
        active_border_color = c.accent;
        inactive_border_color = c.border;
        color0 = c.surface;
        color1 = c.red;
        color2 = c.green;
        color3 = c.yellow;
        color4 = c.blue;
        color5 = c.purple;
        color6 = c.cyan;
        color7 = c.text;
        color8 = c.muted;
        color9 = "#eda692";
        color10 = "#b8c992";
        color11 = "#e6ca91";
        color12 = "#a7c2c8";
        color13 = "#c9b9d1";
        color14 = "#adcbb7";
        color15 = c.text;
      };
    };
  };
}
