# Disposable graphical audit. Test credentials/autologin NEVER reach the host.
{
  pkgs,
  inputs,
  hostRenderNode ? null,
}:
pkgs.testers.runNixOSTest {
  name = "development-desktop";
  node.pkgsReadOnly = false;
  node.specialArgs = { inherit inputs; };
  requiredFeatures.kvm = false;
  qemu.package = pkgs.qemu;
  qemu.forceAccel = false;

  nodes.machine = { pkgs, ... }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      ./common.nix
      ./workstation.nix
    ];
    # Exercise the shared host policy, but never run automatic updates in a VM.
    systemd.services.nixos-update.environment = {
      NIXOS_CONFIG_REPO = "/etc/nix";
      NIXOS_UPDATE_HOST = "nixos";
    };
    systemd.timers.nixos-update.enable = false;
    boot.blacklistedKernelModules = [ "floppy" ];
    virtualisation = {
      memorySize = 6144;
      diskSize = 4096;
      cores = 8;
      resolution = {
        x = 1920;
        y = 1080;
      };
      qemu.options = [
        "-vga none"
        "-audiodev none,id=test-audio"
        "-device ich9-intel-hda"
        "-device hda-duplex,audiodev=test-audio"
        "-device virtio-gpu${if hostRenderNode == null then "" else "-gl"}-pci,xres=1920,yres=1080"
      ]
      ++ pkgs.lib.optionals (hostRenderNode != null) [
        "-display egl-headless,rendernode=${hostRenderNode}"
      ];
    };
    # VirGL exposes OpenGL, not Vulkan. Keep GTK/WGPU off guest-side lavapipe.
    environment.sessionVariables = {
      GSK_RENDERER = "gl";
      WGPU_BACKEND = "gl";
    }
    // pkgs.lib.optionalAttrs (hostRenderNode == null) {
      LIBGL_ALWAYS_SOFTWARE = "1";
      LP_NUM_THREADS = "1";
    };
    users.users.dev.hashedPasswordFile = toString (
      pkgs.runCommand "test-only-password-hash" { nativeBuildInputs = [ pkgs.mkpasswd ]; } ''
        mkpasswd --method=sha-512 --salt=nixostest desktop-test > "$out"
      ''
    );
    # The same SDDM/UWSM session as the laptop; autologin is test-only.
    services.displayManager.autoLogin = {
      enable = true;
      user = "dev";
    };
  };
  testScript = builtins.readFile ./desktop-test.py;
}
