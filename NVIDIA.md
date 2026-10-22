# NVIDIA hosts and CUDA

## Detected from the host's hardware report

Every host imports [`nvidia.nix`](nvidia.nix) through `common.nix`. It does
nothing unless the host's **nixos-facter report** lists an **Ada (RTX 40) or
newer** NVIDIA GPU, i.e. PCI vendor `10de` with a device ID from `2600`. The
stock `hardware-configuration.nix` cannot be used for this: `nixos-generate-config`
never records the GPU. Older NVIDIA cards are not auto-enabled and keep nouveau.
A host module that sets `services.xserver.videoDrivers = [ "nvidia" ];` itself
gets the same profile without a report (for example, a GPU cloud instance).

[`hosts.nix`](hosts.nix) is the entry table. Each key is a NixOS flake target;
`modules` selects that machine's hardware and optional profiles, `system` selects
its CPU architecture, and `repo` sets its checkout path. The same target/path
are passed to the installed switch command and updater. Existing `dev` (EC2)
and `nixos` (the specific laptop) have no NVIDIA GPU and are unchanged.

For a new PC, generate its hardware module and report **on that machine**
(from the installer or its current system), review them, and add them to Git:

```sh
mkdir -p machines/gpu-box
sudo nixos-generate-config --show-hardware-config > machines/gpu-box/hardware-configuration.nix
sudo nix run nixpkgs#nixos-facter -- -o machines/gpu-box/facter.json
```

Then add an entry with its **own bootloader configuration**, `./common.nix`
and, for the local desktop, `./workstation.nix`. Do not copy `physical.nix`:
its disk UUIDs, Intel NPU, panel scale and sensor belong to the existing laptop.

```nix
gpu_box = {
  system = "x86_64-linux";
  repo = "/etc/nixos";
  modules = [
    ./machines/gpu-box/hardware-configuration.nix
    {
      hardware.facter.reportPath = ./machines/gpu-box/facter.json;
      boot.loader.systemd-boot.enable = true; # Match the machine's real boot setup.
      boot.loader.efi.canTouchEfiVariables = true;
      networking.hostName = "gpu-box";
    }
    ./common.nix
    ./workstation.nix # Omit for a headless worker.
  ];
};
```

The facter report also drives NixOS's own hardware modules: initrd storage and
input modules, microcode/firmware, Bluetooth and the platform. Those `machines/`
files are yours to create, not fake disks supplied by this repository. Select
the named target explicitly; the switch/update scripts accept additional simple
host names without being edited. Missing targets fail Nix builds before
activation; no target is inferred from the login name. The full desktop/app
bundle is validated on **x86_64 Linux** only.

## What a detected GPU gets

- **NVIDIA's vendor driver** from the system pin's **stable** branch, with
  NVIDIA's **open kernel modules** (recommended for Ada, required for
  Blackwell), compiled for the selected `boot.kernelPackages`.
- **`nvidia-smi`**, the driver CUDA runtime (`libcuda.so`), NixOS-managed device
  nodes/UVM, kernel mode setting and the NVIDIA VA-API driver.
- **`nvcc`, `cuda-gdb`, `compute-sanitizer`**, CUDA headers, runtime and math
  libraries through Nixpkgs' complete SDK layout, plus **cuDNN**.
- **`nvtop`**, and **`nvidia-settings`** when a local X/desktop setup is enabled.
- **NVIDIA Container Toolkit/CDI** when Podman is enabled (it already is in
  `common.nix`); devices are discovered at runtime by the native NixOS module.
- **Suspend support** on desktops: video memory is preserved in `/var/tmp`, and
  driver 595+ with the open modules uses kernel suspend notifiers.
- **`nvidia-persistenced`** on headless hosts only, not desktop/laptop hosts
  where holding a dGPU awake would defeat power saving.

The SDK is installed system-wide on GPU hosts, with `CUDA_PATH` pointing to its
Nix store layout. No NVIDIA `.run` installer, manual `/usr/local/cuda` files,
Docker daemon, privileged container, global `LD_LIBRARY_PATH` or blanket
`allowUnfree = true` is needed. CUDA/driver licenses are permitted only for the
relevant package set/profile. Installing the SDK does **not** set global
`nixpkgs.config.cudaSupport`: that would rebuild unrelated applications against
CUDA and greatly expand the closure.

Nothing is version-pinned here: the driver is Nixpkgs' `stable` branch and
[`cuda.nix`](cuda.nix) selects the **newest CUDA major** Nixpkgs packages, at its
newest minor release, so both move with `flake.lock`. The locked snapshot
currently provides **driver 595.104.02** and **CUDA 13.4**. The same package set
serves the installed SDK, the development shell and the check binary. The
complete SDK join suits software expecting a single `CUDA_PATH`; new Nix
package builds should use the split redistributables and hooks, as the small
check derivation does.

No renderer variables are forced on the session. libva maps `nvidia-drm` to the
installed VA-API driver by itself, and Hyprland detects NVIDIA and adjusts its
cursor and anti-flicker handling. Driver 555+ explicit sync covers Wayland
frame pacing.

**Open NVIDIA kernel modules are not Nouveau.** They still use the same NVIDIA
userspace driver, firmware, `nvidia-smi` and proprietary CUDA libraries. NixOS
blacklists conflicting Nouveau and Nova drivers when this profile is enabled.
The "CUDA Version" printed by `nvidia-smi` is a driver capability, **not the
installed SDK version**; use `nvcc --version` for that.

## Hybrid laptops (Intel/AMD + NVIDIA)

Use PRIME offload rather than forcing every application onto NVIDIA:

```nix
{
  hardware.nvidia.prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;
    nvidiaBusId = "PCI:1:0:0"; # Replace from this machine's lspci output.
    intelBusId = "PCI:0:2:0";  # Or amdgpuBusId, never both.
  };
}
```

NixOS expects **decimal** bus IDs; `lspci` prints hexadecimal. Do not copy these
example IDs blindly. Use `nvidia-offload PROGRAM` for a specific GUI app; CUDA
programs discover NVIDIA independently. Fine-grained runtime power management
stays off until you explicitly enable it on supported hardware. Suspend
preservation defaults on for desktop hosts and uses `/var/tmp`; ensure enough
disk space for VRAM and validate suspend/resume on the real laptop. No forced
GBM/GL renderer or browser sandbox-disabling variables are set globally.

A **desktop** whose monitors are plugged into the NVIDIA card needs none of
this, even with the CPU's integrated GPU enabled: the session renders on the
GPU the firmware booted with, so leave PRIME unset.

Ordinary headless GPU workers do **not** need `hardware.nvidia.datacenter.enable`:
that NixOS option adds NVLink/NVSwitch Fabric Manager and is not a synonym for
"no monitor". Specialized multi-GPU fabric and vGPU/GRID deployments require
matching vendor-specific configuration. WSL uses a Windows-owned driver; never
select the Linux `nvidia` driver there. GPU passthrough must first
be configured by the hypervisor/provider.

## Build, activate, then verify

From the intended checkout, after reviewing its host entry:

```sh
NIXOS_CONFIG_REPO="$PWD" NIXOS_UPDATE_HOST=gpu_box ./switch-system.sh dry-activate
NIXOS_CONFIG_REPO="$PWD" NIXOS_UPDATE_HOST=gpu_box ./switch-system.sh boot
# Reboot when convenient; retain the previous generation for recovery.
```

Replace `gpu_box` with the real target. Driver changes should be staged and
booted: a live switch can leave new userspace talking to the old loaded kernel
module. Do not unload GPU modules beneath an active compositor or job. Secure
Boot must accept the module signature; handle signing/enrolment with the
machine's existing boot policy rather than disabling Secure Boot blindly.

After boot:

```sh
nvidia-smi
nvcc --version
cuda-gdb --version
compute-sanitizer --version
modinfo -F license nvidia
ls -l /dev/nvidia* /run/opengl-driver/lib/libcuda.so*
nix run .#cuda-check
```

`cuda-check` enumerates visible CUDA devices, launches a tiny kernel on each and
verifies its result. It returns failure if no usable GPU/driver exists. Building
it needs no GPU; running it does. No test framework, synthetic GPU or automatic
GPU workload is installed. `nvtop` provides interactive utilization monitoring.

For CUDA development, including CMake/Ninja and the compiler version supported
by NVCC:

```sh
nix develop .#cuda
```

This shell can also be entered on a non-GPU host to compile for another machine;
it does not install a kernel driver or make a GPU appear. For direct `nvcc`
invocations, pass `-I"$CUDA_PATH/include" -L"$CUDA_PATH/lib"` when the build system
does not discover the SDK itself; CMake can use `CUDA_PATH`/`CUDACXX`.
Use the host driver's
`/run/opengl-driver/lib` at runtime, never CUDA's link-time stub directory. For
non-Nix Python wheels, prefer the framework's documented CUDA build; a toolkit
install alone does not turn a CPU-only wheel into a CUDA wheel. Keep any needed
library-path workaround scoped to that environment instead of exporting it to
the entire desktop.

### Rootless Podman GPU access

After the driver is loaded, inspect the generated CDI device list:

```sh
systemctl status nvidia-container-toolkit-cdi-generator.service
nvidia-ctk cdi list
podman run --rm --device=nvidia.com/gpu=all ubuntu:24.04 nvidia-smi -L
```

The last command explicitly downloads/runs a container. No image is pulled on
activation. Choose a suitable NVIDIA CUDA image for actual CUDA workloads, with
a toolkit version compatible with the host driver. Do not use `--privileged` or
the obsolete `virtualisation.podman.enableNvidia` setting. If the driver/GPU
assignment changes, restart the CDI generator after devices become available.

**DSH note:** its default bwrap profile creates a fresh `/dev` and does not expose
NVIDIA device nodes. Host CUDA support does not automatically grant GPU access
to sandboxed DSH Bash calls. Run GPU work explicitly outside that sandbox (or use
a deliberately designed GPU-capable container); do not silently disable the
sandbox or promise passthrough from installing these packages.

## References checked

- [NVIDIA 595 kernel flavors and GPU support](https://download.nvidia.com/XFree86/Linux-x86_64/595.104.02/README/kernel_open.html)
- [CUDA release notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html)
- [CUDA/driver compatibility](https://docs.nvidia.com/deploy/cuda-compatibility/minor-version-compatibility.html)
- [Nixpkgs CUDA manual](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/doc/languages-frameworks/cuda.section.md)
- [NixOS NVIDIA module](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/hardware/video/nvidia.nix)
- [NixOS Facter](https://nix-community.github.io/nixos-facter/) and the [NixOS wiki NVIDIA page](https://wiki.nixos.org/wiki/NVIDIA)

`nix build .#checks.x86_64-linux.nvidia-config` evaluates a synthetic RTX 4090
desktop from a facter report, a pre-Ada card, the laptop and EC2, without
building a driver. Neither existing host has an NVIDIA GPU. Configuration
checks cannot certify GPU execution, suspend or display behavior on a machine
that has not been tested.
