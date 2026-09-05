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
        "-device virtio-gpu${if hostRenderNode == null then "" else "-gl"}-pci,xres=1920,yres=1080"
      ]
      ++ pkgs.lib.optionals (hostRenderNode != null) [
        "-display egl-headless,rendernode=${hostRenderNode}"
      ];
    };
    environment.sessionVariables = pkgs.lib.optionalAttrs (hostRenderNode == null) {
      LIBGL_ALWAYS_SOFTWARE = "1";
      # Prevent llvmpipe from monopolizing every emulated CPU under QEMU TCG.
      LP_NUM_THREADS = "1";
    };
    environment.systemPackages = [ pkgs.python3 ];
    users.users.dev.hashedPasswordFile = toString (
      pkgs.runCommand "test-only-password-hash" { nativeBuildInputs = [ pkgs.mkpasswd ]; } ''
        mkpasswd --method=sha-512 --salt=nixostest desktop-test > "$out"
      ''
    );
    services.greetd.settings.initial_session = {
      user = "dev";
      command = "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland hyprland.desktop";
    };
    services.pipewire.extraConfig.pipewire."99-test-audio"."context.objects" = [
      {
        factory = "adapter";
        args = {
          "factory.name" = "support.null-audio-sink";
          "node.name" = "test-speakers";
          "node.description" = "Test speakers";
          "media.class" = "Audio/Sink";
          "audio.position" = [
            "FL"
            "FR"
          ];
        };
      }
    ];
  };
  testScript = builtins.readFile ./desktop-test.py;
}
