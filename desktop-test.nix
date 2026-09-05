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
      ./users.nix
      ./tools.nix
      ./network.nix
      ./neovim.nix
      ./desktop.nix
      ./apps.nix
      ./workstation.nix
    ];
    system.stateVersion = "26.05";
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
    services.greetd.settings.initial_session = {
      user = "dev";
      command = "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland hyprland.desktop";
    };
  };
  testScript = builtins.readFile ./desktop-test.py;
}
