# Evaluate NVIDIA auto-detection on synthetic hosts; no driver build or GPU.
{
  inputs,
  pkgs,
  laptop,
  ec2,
}:
let
  inherit (pkgs) lib;
  # A minimal nixos-facter report: one CPU, one monitor and the given card.
  report = card: {
    version = 1;
    system = "x86_64-linux";
    virtualisation = "none";
    hardware = {
      cpu = [ { vendor_name = "AuthenticAMD"; } ];
      monitor = [ { model = "Test monitor"; } ];
      graphics_card = [ card ];
    };
  };
  nvidiaCard = device: {
    vendor.value = 4318; # 0x10de
    device.value = device;
    driver_modules = [ "nouveau" ];
  };
  host =
    name: extra:
    (inputs.self.lib.mkHost name {
      modules = [
        ./common.nix
        ./workstation.nix
        {
          boot.loader.systemd-boot.enable = true;
          fileSystems."/" = {
            device = "/dev/disk/by-label/nixos";
            fsType = "ext4";
          };
          networking.hostName = name;
        }
        extra
      ];
    }).config;
  rig = host "rig" { hardware.facter.report = report (nvidiaCard 9860); }; # 0x2684, RTX 4090
  pascal = host "pascal" { hardware.facter.report = report (nvidiaCard 7040); }; # 0x1b80, GTX 1080
  explicit = host "explicit" { services.xserver.videoDrivers = [ "nvidia" ]; };
  nv = rig.hardware.nvidia;
  cuda = rig.environment.variables.CUDA_PATH;
  cudaVersion = builtins.head (builtins.match ".*-cuda-merged-([0-9.]+)" cuda);
  tests = [
    {
      assertion = nv.enabled && builtins.elem "nvidia" rig.services.xserver.videoDrivers;
      message = "An Ada or newer NVIDIA card in the facter report must select the NVIDIA driver.";
    }
    {
      assertion =
        nv.open
        && lib.versionAtLeast nv.package.version "595"
        && nv.powerManagement.enable
        && nv.powerManagement.kernelSuspendNotifier
        && !nv.powerManagement.finegrained
        && !nv.nvidiaPersistenced
        && nv.modesetting.enable;
      message = "The desktop uses the stable open kernel modules with suspend support and no PRIME power tweaks.";
    }
    {
      assertion =
        !nv.prime.offload.enable
        && !nv.prime.sync.enable
        && !(rig.environment.sessionVariables ? LIBVA_DRIVER_NAME)
        && !(rig.environment.sessionVariables ? __GLX_VENDOR_LIBRARY_NAME)
        && !(rig.environment.sessionVariables ? GBM_BACKEND)
        && builtins.elem pkgs.nvidia-vaapi-driver rig.hardware.graphics.extraPackages;
      message = "No PRIME or forced renderer variables on a single-GPU desktop; VA-API comes from the module.";
    }
    {
      assertion =
        lib.versionAtLeast cudaVersion "13"
        && rig.hardware.nvidia-container-toolkit.enable
        && rig.hardware.graphics.enable32Bit;
      message = "GPU hosts get the newest (13+) CUDA SDK, CDI for rootless Podman and 32-bit graphics for Steam.";
    }
    {
      assertion = explicit.hardware.nvidia.enabled && explicit.hardware.nvidia.open;
      message = "Selecting the nvidia driver without a facter report applies the same profile.";
    }
    {
      assertion =
        !pascal.hardware.nvidia.enabled && !laptop.hardware.nvidia.enabled && !ec2.hardware.nvidia.enabled;
      message = "Pre-Ada cards and hosts without NVIDIA hardware stay on their existing drivers.";
    }
  ];
in
assert lib.all (test: lib.assertMsg test.assertion test.message) tests;
# Forces every NixOS assertion of the synthetic desktop without building it.
builtins.seq rig.system.build.toplevel.drvPath (
  pkgs.runCommand "nvidia-config-check" { } ''
    echo ${lib.escapeShellArg (builtins.unsafeDiscardStringContext cuda)} > "$out"
  ''
)
