# Machine entry points. Keep disk/boot hardware in the selected machine module.
# NVIDIA GPUs are picked up from a host's nixos-facter report (see NVIDIA.md).
# The attribute name is the exact flake/update target, never the login name.
{
  dev = {
    system = "x86_64-linux";
    repo = "/etc/nixos";
    modules = [ ./configuration.nix ]; # EC2 image boot/storage/recovery only.
  };
  nixos = {
    system = "x86_64-linux";
    repo = "/etc/nix";
    modules = [ ./physical.nix ]; # This laptop's actual hardware, not a generic PC.
  };
}
