# Packaged Qt6 theme, styled with the same wallpaper/palette as the desktop.
# No runtime downloader, custom QML, Plasma desktop, or authentication changes.
{ pkgs, font }:
let
  c = import ./colors.nix;
  wallpaper = import ./wallpaper.nix { inherit pkgs; };
in
(pkgs.sddm-astronaut.override {
  embeddedTheme = "black_hole";
  themeConfig = {
    Font = font;
    FontSize = "11";
    HeaderText = "Welcome back";
    HourFormat = "HH:mm";
    DateFormat = "dddd d MMMM";
    Background = "Backgrounds/one-ring.jpg";
    DimBackground = "0.15";
    CropBackground = "true";
    FormPosition = "left";
    HaveFormBackground = "true";
    PartialBlur = "false";
    FullBlur = "false";
    RoundCorners = "10";
    UseRealName = "false";
    HideCompletePassword = "true";
    AllowEmptyPassword = "false";
    HeaderTextColor = c.accent;
    DateTextColor = c.muted;
    TimeTextColor = c.text;
    FormBackgroundColor = c.background;
    BackgroundColor = c.background;
    DimBackgroundColor = c.background;
    LoginFieldBackgroundColor = c.surface;
    PasswordFieldBackgroundColor = c.surface;
    LoginFieldTextColor = c.text;
    PasswordFieldTextColor = c.text;
    PlaceholderTextColor = c.muted;
    WarningColor = c.red;
    LoginButtonTextColor = c.background;
    LoginButtonBackgroundColor = c.accent;
    UserIconColor = c.text;
    PasswordIconColor = c.text;
    SystemButtonsIconsColor = c.text;
    SessionButtonTextColor = c.text;
    VirtualKeyboardButtonTextColor = c.text;
    DropdownTextColor = c.text;
    DropdownSelectedBackgroundColor = c.selection;
    DropdownBackgroundColor = c.surface;
    HighlightTextColor = c.background;
    HighlightBackgroundColor = c.accent;
    HighlightBorderColor = c.accent;
    HoverUserIconColor = c.accent;
    HoverPasswordIconColor = c.accent;
    HoverSystemButtonsIconsColor = c.accent;
    HoverSessionButtonTextColor = c.accent;
    HoverVirtualKeyboardButtonTextColor = c.accent;
  };
}).overrideAttrs
  (old: {
    postInstall = (old.postInstall or "") + ''
      # The theme resolves background paths relative to its own directory.
      chmod u+w "$out/share/sddm/themes/sddm-astronaut-theme/Backgrounds"
      ln -s ${wallpaper} "$out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/one-ring.jpg"
    '';
  })
