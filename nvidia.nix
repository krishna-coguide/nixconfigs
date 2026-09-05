# Opt in only on a supported physical NVIDIA machine, not EC2/Mesa targets.
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # Turing or newer; select deliberately for the real hardware.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    nvidiaSettings = true;
  };
  # No global renderer overrides or Firefox sandbox-disabling variables.
}
