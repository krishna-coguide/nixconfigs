# NVIDIA driver/CUDA profile, imported by common.nix on every host. It turns
# itself on when the host's nixos-facter report (hardware.facter.reportPath)
# lists an Ada or newer NVIDIA GPU, or when a host module selects
# services.xserver.videoDrivers = [ "nvidia" ] itself. Otherwise it is inert.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.nvidia;
  desktop = config.services.xserver.enable;
  sdk = import ./cuda.nix { inherit pkgs; };
  # Facter reports PCI IDs as decimal numbers: vendor 0x10de is NVIDIA, and
  # device IDs from 0x2600 are Ada (RTX 40) and newer. Older cards keep nouveau.
  isSupported = card: (card.vendor.value or null) == 4318 && (card.device.value or 0) >= 9728;
  detected = lib.any isSupported (config.hardware.facter.report.hardware.graphics_card or [ ]);
in
{
  config = lib.mkMerge [
    # Selecting the driver does NOT start X/SDDM on a headless machine.
    (lib.mkIf detected { services.xserver.videoDrivers = [ "nvidia" ]; })

    (lib.mkIf cfg.enabled {
      hardware.graphics.enable = true; # Includes the active driver's libcuda.so.
      hardware.graphics.enable32Bit = lib.mkDefault (desktop && pkgs.stdenv.hostPlatform.isx86_64);
      hardware.nvidia = {
        branch = lib.mkDefault "stable"; # Always built for config.boot.kernelPackages.
        # NVIDIA's open kernel modules: recommended for Ada, required for Blackwell.
        # On driver 595+ they also bring kernel suspend notifiers.
        open = lib.mkDefault true;
        modesetting.enable = lib.mkDefault true;
        powerManagement.enable = lib.mkDefault desktop;
        powerManagement.finegrained = lib.mkDefault false; # Enable only on a supported PRIME laptop.
        nvidiaSettings = lib.mkDefault desktop;
        nvidiaPersistenced = lib.mkDefault (!desktop); # Avoid holding a laptop dGPU awake.
        # Suspend preservation needs disk-backed space, not a small RAM-backed /tmp.
        moduleParams.nvidia = lib.mkIf cfg.powerManagement.enable {
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

      # Permit driver/CUDA licenses if this profile is used without apps.nix.
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
      # No global cudaSupport, LD_LIBRARY_PATH or forced GL/GBM/VA-API driver:
      # libva already maps nvidia-drm to the installed nvidia-vaapi-driver, and
      # Hyprland picks its NVIDIA cursor and anti-flicker handling itself.
      # `nix develop .#cuda` additionally supplies CMake and the matching host compiler.
    })
  ];
}
