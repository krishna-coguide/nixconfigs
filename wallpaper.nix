# The image is fetched reproducibly, not downloaded by a login/startup script.
# Source/attribution details and the original fallback are documented in DESKTOP.md.
{ pkgs }:
pkgs.fetchurl {
  name = "one-ring-dark-1920x1200.jpg";
  url = "https://w.wallhaven.cc/full/01/wallhaven-01e5v4.jpg";
  hash = "sha256-3jkKzJ0q4MTlHygwUs3SuSiUIjUjkiTqSaM+q8EL/oc=";
}
