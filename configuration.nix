{
  config,
  inputs,
  modulesPath,
  ...
}:

{
  imports = [
    # Keep the image's EC2 boot, storage, metadata, SSH and SSM integration.
    "${modulesPath}/virtualisation/amazon-image.nix"
    ./users.nix
    ./tools.nix
    ./network.nix
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
