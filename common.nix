# Shared user environment and update policy; only machine integration differs.
{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./users.nix
    ./tools.nix
    ./network.nix
    ./desktop.nix
    ./apps.nix
    ./neovim.nix
    ./updates.nix
  ];

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # tools.nix/network.nix select current standalone CLIs without overriding the
  # system package set (or mixing unstable libraries into the desktop stack).

  nix = {
    channel.enable = false;
    # Keep non-login environments on the same pin when NIX_PATH is unset.
    settings.nix-path = config.nix.nixPath;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  # Preserve a new machine's explicitly chosen/generated compatibility version.
  # Existing hosts retain 26.05; this is not the desired package release.
  system.stateVersion = lib.mkDefault "26.05";
}
