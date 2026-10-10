# Official Nightly binary, pinned like the other external application sources.
# Keep its matching Electron/native modules together; do not disable the sandbox.
{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "element-nightly";
  version = "2026101001";
  src = pkgs.fetchurl {
    url = "https://packages.element.io/debian/pool/main/e/element-nightly/element-nightly_2026101001_amd64.deb";
    hash = "sha256-93DrV3PIMrJwECxvNBKPqbKlSMdZ6zsvjxbuRUOFGDo=";
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
    systemd
  ];
  dontUnpack = true;
  dontBuild = true;
  dontWrapGApps = true;
  installPhase = ''
    runHook preInstall
    dpkg --fsys-tarfile "$src" | tar --extract --no-same-owner
    mkdir -p "$out/lib" "$out/bin"
    mv opt/Element-Nightly "$out/lib/element-nightly"
    mv usr/share "$out/share"
    substituteInPlace "$out/share/applications/element-desktop-nightly.desktop" \
      --replace-fail /opt/Element-Nightly/element-desktop-nightly "$out/bin/element-desktop-nightly"
    runHook postInstall
  '';
  preFixup = ''
    makeWrapper "$out/lib/element-nightly/element-desktop-nightly" "$out/bin/element-desktop-nightly" \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]} \
      --add-flags "--password-store=gnome-libsecret --disable-setuid-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland}}"
    # Compatibility command only, not a duplicate launcher or a second install.
    ln -s element-desktop-nightly "$out/bin/element-desktop"
  '';
  meta = {
    description = "Element Nightly, the upstream development build of the Matrix client";
    homepage = "https://element.io/download";
    license = pkgs.lib.licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "element-desktop-nightly";
  };
}
