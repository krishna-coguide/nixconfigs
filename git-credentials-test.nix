# Offline protocol checks using dummy credentials in a disposable HOME only.
{ config, pkgs }:
let
  hm = config.home-manager.users.dev;
in
assert
  hm.programs.git.settings.credential.helper == [
    ""
    "cache --timeout=31536000"
  ];
assert hm.programs.git.settings.credential.useHttpPath;
assert hm.programs.git.settings.core.askPass == "";
assert hm.home.sessionVariables.GIT_ASKPASS == "";
assert hm.home.sessionVariables.GIT_TERMINAL_PROMPT == "1";
pkgs.runCommand "git-terminal-credentials-check"
  {
    nativeBuildInputs = [
      config.programs.git.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.expect
    ];
  }
  ''
    export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/home/.config" XDG_CACHE_HOME="$TMPDIR/cache"
    export GIT_CONFIG_NOSYSTEM=1 GIT_ASKPASS="" GIT_TERMINAL_PROMPT=0
    mkdir -p "$XDG_CONFIG_HOME/git"
    cp ${hm.xdg.configFile."git/config".source} "$XDG_CONFIG_HOME/git/config"
    test "$(git config --get core.askPass)" = ""
    git config --get-all credential.helper | grep -qx 'cache --timeout=31536000'
    trap 'git credential-cache exit' EXIT

    printf 'protocol=https\nhost=git.example.invalid\npath=project.git\nusername=test\npassword=offline-test-token\n\n' |
      git credential approve
    printf 'protocol=https\nhost=git.example.invalid\npath=project.git\n\n' |
      git credential fill > "$TMPDIR/retrieved"
    grep -qx 'password=offline-test-token' "$TMPDIR/retrieved"
    test -S "$XDG_CACHE_HOME/git/credential/socket"
    test ! -e "$HOME/.git-credentials"

    # Even with a GUI fallback in the environment, a cache miss must not invoke it.
    printf '#!${pkgs.runtimeShell}\ntouch "$TMPDIR/gui-was-used"\necho unwanted\n' > "$TMPDIR/gui-askpass"
    chmod +x "$TMPDIR/gui-askpass"
    export SSH_ASKPASS="$TMPDIR/gui-askpass"
    if printf 'protocol=https\nhost=git.example.invalid\npath=other.git\n\n' | git credential fill; then
      echo 'Credentials leaked across repository paths' >&2; exit 1
    fi
    test ! -e "$TMPDIR/gui-was-used"
    printf 'protocol=https\nhost=git.example.invalid\npath=project.git\n\n' | git credential reject
    if printf 'protocol=https\nhost=git.example.invalid\npath=project.git\n\n' | git credential fill; then
      echo 'Rejected credentials remained cached' >&2; exit 1
    fi
    # Exercise genuine /dev/tty entry too, without contacting a Git server.
    export GIT_TERMINAL_PROMPT=1
    expect <<'EXPECT'
    set timeout 10
    spawn -noecho git credential fill
    send -- "protocol=https\rhost=terminal.example.invalid\rpath=project.git\r\r"
    expect {
      -exact "Username for 'https://terminal.example.invalid/project.git': " { send -- "terminal-user\r" }
      timeout { exit 1 }
      eof { exit 1 }
    }
    expect {
      -exact "Password for 'https://terminal-user@terminal.example.invalid/project.git': " { send -- "offline-tty-token\r" }
      timeout { exit 1 }
      eof { exit 1 }
    }
    expect {
      -exact "password=offline-tty-token" { }
      timeout { exit 1 }
      eof { exit 1 }
    }
    expect eof
    lassign [wait] pid spawnid os_error status
    exit $status
    EXPECT
    test ! -e "$TMPDIR/gui-was-used"
    touch "$out"
  ''
