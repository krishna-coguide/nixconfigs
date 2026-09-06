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
  nixpkgs.overlays = [
    (_final: prev: {
      # Pi is a fast-moving agent harness; stable branches can be generations old.
      # Use the latest resolving Nixpkgs input while keeping the rest of the
      # system on the stable release branch.
      pi-coding-agent =
        (import inputs.nixpkgs-latest {
          inherit (prev.stdenv.hostPlatform) system;
          config = prev.config or { };
        }).pi-coding-agent;
    })
  ];

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
