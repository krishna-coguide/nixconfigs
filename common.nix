# Shared dev environment; boot, storage, recovery users and updates are host-specific.
{ config, inputs, ... }:
{
  imports = [
    ./users.nix
    ./tools.nix
    ./network.nix
    ./desktop.nix
    ./apps.nix
    ./neovim.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

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

  # Initial data/default compatibility, not the desired package release.
  system.stateVersion = "26.05";
}
