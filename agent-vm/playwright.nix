# The official CLI is also shipped as `playwright-core cli`. Keep it and the
# patched Firefox on the SAME rolling Nixpkgs revision, without npm/browser skew.
{ pkgs }:
let
  browsers = pkgs.playwright-driver.browsers.override {
    withChromium = false;
    withChromiumHeadlessShell = false;
    withWebkit = false;
    withFirefox = true;
    withFfmpeg = true;
  };
  fontConfig = pkgs.makeFontsConf {
    fontDirectories = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
    impureFontDirectories = [ ];
  };
in
pkgs.writeShellApplication {
  name = "playwright-cli";
  runtimeInputs = [ pkgs.nodejs ];
  text = ''
    export PLAYWRIGHT_BROWSERS_PATH=${browsers}
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    export PLAYWRIGHT_MCP_BROWSER="''${PLAYWRIGHT_MCP_BROWSER:-firefox}"
    export PLAYWRIGHT_MCP_HEADLESS="''${PLAYWRIGHT_MCP_HEADLESS:-true}"
    export FONTCONFIG_FILE="''${FONTCONFIG_FILE:-${fontConfig}}"
    exec node ${pkgs.playwright-driver}/cli.js cli "$@"
  '';
  meta.description = "Official Playwright CLI with matching Firefox, headless by default";
}
