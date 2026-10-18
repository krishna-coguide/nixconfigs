# Render the actual packaged greeter in an isolated X server, never live SDDM.
{ config, pkgs }:
let
  inherit (pkgs) lib;
  font = "JetBrainsMono Nerd Font";
  hm = config.home-manager.users.dev;
  theme = import ./greeter-theme.nix { inherit pkgs font; };
  sddm = config.services.displayManager.sddm.package.override {
    extraPackages = config.services.displayManager.sddm.extraPackages;
  };
  fontConfig = pkgs.makeFontsConf {
    fontDirectories = config.fonts.packages;
    impureFontDirectories = [ ];
    includes = [ "${config.environment.etc.fonts.source}/conf.d" ];
  };
in
assert lib.all (family: builtins.head config.fonts.fontconfig.defaultFonts.${family} == font) [
  "sansSerif"
  "serif"
  "monospace"
];
assert hm.gtk.font.name == font;
assert hm.qt.platformTheme.name == "gtk3";
assert hm.programs.kitty.font.name == font;
assert hm.programs.ashell.settings.appearance.font_name == font;
assert hm.dconf.settings."org/gnome/desktop/interface".font-name == "${font} 11";
assert lib.all (label: label.font_family == font) hm.programs.hyprlock.settings.label;
assert lib.hasInfix font hm.programs.anyrun.extraCss;
assert lib.hasInfix font hm.services.swaync.style;
assert config.services.displayManager.sddm.theme == "sddm-astronaut-theme";
assert config.services.displayManager.sddm.settings.Theme.Font == font;
assert !config.services.displayManager.autoLogin.enable;
assert !config.services.desktopManager.plasma6.enable;
pkgs.runCommand "desktop-appearance-check"
  {
    nativeBuildInputs = with pkgs; [
      fontconfig
      xvfb-run
      xdotool
      imagemagick
      gnugrep
    ];
  }
  ''
    export HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache" XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -m 700 -p "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR" "$out"
    export FONTCONFIG_FILE=${fontConfig}
    for family in sans-serif serif monospace; do
      fc-match --format='%{family}' "$family" | grep -Fq '${font}'
    done
    fc-match --format='%{family}' emoji | grep -Fq 'Noto Color Emoji'
    fc-match --format='%{family}' ':charset=4e00' | grep -Fq 'Noto Sans CJK'
    test -r ${theme}/share/sddm/themes/sddm-astronaut-theme/Backgrounds/wallpaper.png
    export QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 QT_QPA_PLATFORM=xcb
    xvfb-run -a -s '-screen 0 1920x1080x24' ${pkgs.runtimeShell} -euc '
      ${sddm}/bin/sddm-greeter-qt6 --test-mode \
        --theme ${theme}/share/sddm/themes/sddm-astronaut-theme > "$out/greeter.log" 2>&1 &
      pid=$!
      trap "kill $pid 2>/dev/null || true" EXIT
      for attempt in $(seq 1 40); do
        kill -0 "$pid"
        if xdotool search --onlyvisible --pid "$pid" > /dev/null 2>&1; then break; fi
        sleep 0.5
      done
      sleep 3
      kill -0 "$pid"
      xdotool search --onlyvisible --pid "$pid" > /dev/null
      magick import -window root "$out/greeter.png"
      # Check the focused password field and enabled-button appearance, without login.
      window=$(xdotool search --onlyvisible --pid "$pid" | head -n 1)
      xdotool windowfocus --sync "$window"
      xdotool type --clearmodifiers "preview-only"
      sleep 1
      magick import -window root "$out/greeter-password.png"
      if grep -Ei "(module .* is not installed|failed to load|is not a type|ReferenceError|TypeError|cannot assign)" "$out/greeter.log"; then
        exit 1
      fi
    '
  ''
