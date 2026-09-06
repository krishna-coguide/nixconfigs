# EC2 only. Physical machines must use the separate nixos host target.
{ modulesPath, ... }:
{
  imports = [
    # Keep the image's EC2 boot, storage, metadata, SSH and SSM integration.
    "${modulesPath}/virtualisation/amazon-image.nix"
    ./common.nix
  ];

  # Keep the existing deployment path; ownership/update policy is shared.
  systemd.services.nixos-update.environment = {
    NIXOS_CONFIG_REPO = "/etc/nixos";
    NIXOS_UPDATE_HOST = "dev";
  };
}
