# EC2 only. Physical machines must use the separate nixos host target.
{ modulesPath, ... }:
{
  imports = [
    # Keep the image's EC2 boot, storage, metadata, SSH and SSM integration.
    "${modulesPath}/virtualisation/amazon-image.nix"
    ./common.nix
  ];

  # Deployment path/target are selected centrally in hosts.nix.
}
