# EC2 only. Physical machines must use the separate nixos host target.
{ modulesPath, ... }:
{
  imports = [
    # Keep the image's EC2 boot, storage, metadata, SSH and SSM integration.
    "${modulesPath}/virtualisation/amazon-image.nix"
    ./common.nix
    ./updates.nix
  ];

  # Only the EC2 host keeps its dev-owned configuration checkout here.
  systemd.tmpfiles.rules = [ "Z /etc/nixos - dev users -" ];
}
