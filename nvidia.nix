# Opt-in driver/runtime profile for a host with an assigned NVIDIA GPU.
# Import from hosts.nix; override native hardware.nvidia options per machine.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  desktop = config.services.xserver.enable;
  sdk = import ./cuda.nix { inherit pkgs; };
in
{
  # Selecting the driver does NOT start X/SDDM on a headless machine.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true; # Includes the active driver's libcuda.so.
  hardware.graphics.enable32Bit = lib.mkDefault (desktop && pkgs.stdenv.hostPlatform.isx86_64);
  hardware.nvidia = {
    branch = lib.mkDefault "stable"; # Always built for config.boot.kernelPackages.
    open = lib.mkDefault false; # Proprietary kernel; Blackwell+ requires true.
    modesetting.enable = lib.mkDefault true;
    powerManagement.enable = lib.mkDefault desktop;
    powerManagement.finegrained = lib.mkDefault false; # Enable only on a supported PRIME laptop.
    nvidiaSettings = lib.mkDefault desktop;
    nvidiaPersistenced = lib.mkDefault (!desktop); # Avoid holding a laptop dGPU awake.
    # Suspend preservation needs disk-backed space, not a small RAM-backed /tmp.
    moduleParams.nvidia = lib.mkIf config.hardware.nvidia.powerManagement.enable {
      NVreg_TemporaryFilePath = lib.mkDefault "/var/tmp";
    };
  };

  # NixOS owns UVM/device nodes and CDI regeneration on boot/driver events.
  # No Docker daemon, privileged containers or legacy enableNvidia hook.
  hardware.nvidia-container-toolkit.enable = lib.mkDefault config.virtualisation.podman.enable;
  environment.systemPackages =
    sdk.packages
    ++ [ pkgs.nvtopPackages.nvidia ]
    ++ lib.optional config.hardware.nvidia-container-toolkit.enable config.hardware.nvidia-container-toolkit.package;
  environment.variables.CUDA_PATH = "${sdk.toolkit}";

  # Permit driver/CUDA licenses if this profile is imported without apps.nix.
  # The workstation's explicit predicate permits the same set when enabled.
  nixpkgs.config = lib.mkDefault {
    allowUnfreePredicate =
      package:
      builtins.elem (lib.getName package) [
        "nvidia-x11"
        "nvidia-kernel-modules"
        "nvidia-settings"
        "nvidia-persistenced"
      ]
      || pkgs._cuda.lib.allowUnfreeCudaPredicate package;
  };
  # No global cudaSupport, LD_LIBRARY_PATH or forced GL/GBM renderer.
  # `nix develop .#cuda` additionally supplies CMake and the matching host compiler.
}
