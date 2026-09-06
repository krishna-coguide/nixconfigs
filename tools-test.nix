# Bounded, offline smoke tests. No user caches, credentials, servers or downloads.
{ config, pkgs }:
assert builtins.elem pkgs.tor-browser config.home-manager.users.dev.home.packages;
pkgs.runCommand "workstation-tools-check"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export PATH=${config.system.path}/bin:$PATH
    for tool in pi git git-lfs gh glab cmake ninja gdb \
      cargo rustc rustfmt cargo-clippy cargo-nextest go gopls dlv uv ruff pyright \
      node pnpm tsc biome bun deno shellcheck shfmt just hyperfine watchexec \
      nom nvd nix-tree nix-diff statix deadnix nixd \
      jq yq jless mlr csvlens sqlite3 duckdb pgcli \
      xh grpcurl websocat aws skopeo buildah podman podman-compose dive \
      kubectl helm k9s kubectx stern kustomize tofu ansible \
      age sops gpg gitleaks trivy restic rclone dust duf ncdu procs lnav \
      ffmpeg magick mediainfo exiftool pdftotext pandoc yt-dlp chafa desktop-help \
      valgrind heaptrack rr eu-readelf bpftrace java javac mvn gradle kotlin \
      dotnet ruby bundle php composer zig zls elixir erl protoc buf \
      dprint stylua taplo marksman markdownlint-cli2 sqlfluff hadolint ast-grep rga \
      hurl oha step mkcert cosign syft grype mosh sshfs asciinema vhs switch-system; do
      command -v "$tool" >/dev/null
    done
    # Inspect only: don't start a graphical browser or make Tor connections.
    test -x ${pkgs.tor-browser}/bin/tor-browser
    test -x ${config.home-manager.users.dev.programs.lazygit.package}/bin/lazygit
    test -x ${config.home-manager.users.dev.programs.tmux.package}/bin/tmux
    switch-system --help > "$TMPDIR/switch-help"
    grep -Fq '/etc/nix#nixos' "$TMPDIR/switch-help"
    pi --version
    uv --version
    ruff --version
    cargo --version
    rustc --version
    go version
    node --version
    java -version
    dotnet --version
    zig version
    ruby --version
    php --version | head -1
    socat -V
    # fping opens ICMP sockets even for -v; physical-config checks its binary.
    drill -v
    tor --version
    torsocks --version
    printf 'socat-offline-check\n' | socat -u STDIN STDOUT | grep -qx socat-offline-check
    torsocks curl --version
    proxychains4 -q curl --version
    printf 'select 42;\n' | sqlite3 | grep -qx 42
    python - <<'PY'
    import importlib.util
    spec = importlib.util.spec_from_file_location("desktop_help", "${./desktop-help.py}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    rows = module.rows([
        {"modmask": 65, "key": "H", "description": "Help"},
        {"modmask": 0, "key": "Print", "description": "Capture"},
        {"modmask": 64, "key": "Q", "description": "Close; $(touch /not-executed)"},
        {"modmask": 0, "key": "", "keycode": 20, "description": "Code", "submap": "resize"},
        {"key": "undocumented"},
    ])
    assert "Help    Super + Shift + H" in rows
    assert "Code [resize]    code:20" in rows
    assert len(rows) == 4
    PY
    touch "$out"
  ''
