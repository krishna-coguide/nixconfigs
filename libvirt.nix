# Laptop-only libvirt/QEMU/KVM host with virt-manager. Guests are created and
# managed interactively; none are declared here. Imported from physical.nix
# only (not EC2 or test VMs).
{ ... }:
let
  images = "/var/lib/libvirt/images";
in
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = false; # QEMU runs as qemu-libvirtd, not root.
      swtpm.enable = true; # Emulated TPM 2.0 for guests that need one.
      # Keep NixOS's default namespaces setting. libvirt's default swtpm user,
      # tss, does not exist here; use the same unprivileged QEMU account.
      verbatimConfig = ''
        namespaces = []
        swtpm_user = "qemu-libvirtd"
        swtpm_group = "qemu-libvirtd"
      '';
    };
    onBoot = "ignore"; # Never autostart guests.
    onShutdown = "shutdown"; # Ask guests to shut down cleanly with the host.
  };
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  users.users.dev.extraGroups = [ "libvirtd" ];
  environment.sessionVariables.LIBVIRT_DEFAULT_URI = "qemu:///system";
  home-manager.users.dev.dconf.settings."org/virt-manager/virt-manager/connections" = {
    autoconnect = [ "qemu:///system" ];
    uris = [ "qemu:///system" ];
  };

  systemd.tmpfiles.rules = [
    "d ${images} 0711 root root -"
    # Btrfs copy-on-write fragments VM images badly; new files inherit +C.
    "h ${images} - - - - +C"
    # swtpm_setup signs each vTPM's EK cert with a local CA kept here. It runs
    # as swtpm_user (qemu-libvirtd), which cannot create dirs in /var/lib, and
    # the NixOS libvirtd module does not create it.
    "d /var/lib/swtpm-localca 0750 qemu-libvirtd qemu-libvirtd -"
  ];
}
