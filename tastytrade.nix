# Official tastytrade desktop (2.0) binary from the upstream electron-updater
# feed (desktop-2.0/latest-linux.yml). Pinned to the versioned artifact rather
# than the mutable "latest" URL; do not disable the Chromium sandbox.
{ pkgs }:
pkgs.stdenv.mkDerivation rec {
  pname = "tastytrade";
  version = "0.61.0";
  src = pkgs.fetchurl {
    url = "https://download.tastytrade.com/desktop-2.0/tastytrade-linux-amd64-${version}.deb";
    hash = "sha256-oQTjnqpaiIOg55MDlvXnWzmL9/CATMJfHHbvmCooozQ=";
  };
  nativeBuildInputs = with pkgs; [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];
  buildInputs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libgbm
    libdrm
    libxkbcommon
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxrender
    libxtst
    libxscrnsaver
    libxshmfence
    libuuid
    nss
    nspr
    pango
    libsecret
    stdenv.cc.cc
  ];
  runtimeDependencies = with pkgs; [
    libnotify
    libGL
    libsecret
    libpulseaudio
    libappindicator-gtk3
    systemd
  ];
  # Bundled prebuilt native modules for other platforms/libcs are never loaded.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];
  dontUnpack = true;
  dontBuild = true;
  dontWrapGApps = true;
  installPhase = ''
    runHook preInstall
    dpkg --fsys-tarfile "$src" | tar --extract --no-same-owner
    mkdir -p "$out/lib" "$out/bin"
    mv "opt/tastytrade 2.0" "$out/lib/tastytrade"
    mv usr/share "$out/share"
    rm -r "$out/share/doc"
    substituteInPlace "$out/share/applications/tastytrade.desktop" \
      --replace-fail '"/opt/tastytrade 2.0/tastytrade"' "$out/bin/tastytrade"
    runHook postInstall
  '';
  preFixup = ''
    makeWrapper "$out/lib/tastytrade/tastytrade" "$out/bin/tastytrade" \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]} \
      --add-flags "--password-store=gnome-libsecret --disable-setuid-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland}}"
  '';
  meta = {
    description = "tastytrade desktop trading platform";
    homepage = "https://tastytrade.com/trading-platforms/";
    license = pkgs.lib.licenses.unfree;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "tastytrade";
  };
}
