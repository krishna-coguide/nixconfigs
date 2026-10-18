# The wallpaper is a local, git-tracked image; nothing is downloaded at login.
{ pkgs }:
builtins.path {
  name = "wallpaper.png";
  path = ./wallpaper.png;
}
