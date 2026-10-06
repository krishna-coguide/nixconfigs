# Laptop-only Windows 11 guest: libvirt/QEMU/KVM with TPM 2.0 + Secure Boot,
# the integrated USB webcam passed through and the internal microphone shared
# through SPICE audio. Imported from physical.nix only (not EC2 or test VMs).
#
# The domain definition below is authoritative: it is (re)defined on every
# boot/activation, so change it here rather than in virt-manager. Disk, NVRAM
# and TPM state live under /var/lib/libvirt and are never recreated.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "windows";
  images = "/var/lib/libvirt/images";
  disk = "${images}/${name}.qcow2";
  diskSize = "128G"; # Sparse; only the initial size of a missing image.
  installIso = "${images}/Win11.iso"; # Optional; fetched by hand from Microsoft.
  driversIso = "${images}/virtio-win.iso"; # GC-rooted link to the pinned ISO.

  # Integrated Camera (lsusb 5986:11ac). Video-only; the microphone is the
  # internal Intel SOF DMIC, which reaches the guest through SPICE instead.
  webcam = {
    vendor = "0x5986";
    product = "0x11ac";
  };

  domain = pkgs.writeText "${name}.xml" ''
    <domain type="kvm">
      <name>${name}</name>
      <uuid>1e1a686d-7d4d-4699-a1b0-c68f0e07d1bf</uuid>
      <title>Windows 11</title>
      <metadata>
        <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
          <libosinfo:os id="http://microsoft.com/win/11"/>
        </libosinfo:libosinfo>
      </metadata>
      <memory unit="GiB">12</memory>
      <currentMemory unit="GiB">12</currentMemory>
      <vcpu placement="static">4</vcpu>
      <os firmware="efi">
        <type arch="x86_64" machine="q35">hvm</type>
        <firmware>
          <feature enabled="yes" name="enrolled-keys"/>
          <feature enabled="yes" name="secure-boot"/>
        </firmware>
        <boot dev="hd"/>
        <boot dev="cdrom"/>
      </os>
      <features>
        <acpi/>
        <apic/>
        <hyperv mode="custom">
          <relaxed state="on"/>
          <vapic state="on"/>
          <spinlocks state="on" retries="8191"/>
          <vpindex state="on"/>
          <runtime state="on"/>
          <synic state="on"/>
          <stimer state="on"/>
          <reset state="on"/>
          <frequencies state="on"/>
          <tlbflush state="on"/>
          <ipi state="on"/>
        </hyperv>
        <vmport state="off"/>
        <smm state="on"/>
      </features>
      <cpu mode="host-passthrough" check="none" migratable="on">
        <topology sockets="1" dies="1" cores="4" threads="1"/>
      </cpu>
      <clock offset="localtime">
        <timer name="rtc" tickpolicy="catchup"/>
        <timer name="pit" tickpolicy="delay"/>
        <timer name="hpet" present="no"/>
        <timer name="hypervclock" present="yes"/>
      </clock>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>destroy</on_crash>
      <pm>
        <suspend-to-mem enabled="no"/>
        <suspend-to-disk enabled="no"/>
      </pm>
      <devices>
        <emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator>
        <disk type="file" device="disk">
          <driver name="qemu" type="qcow2" cache="none" io="native" discard="unmap"/>
          <source file="${disk}"/>
          <target dev="vda" bus="virtio"/>
        </disk>
        <disk type="file" device="cdrom">
          <driver name="qemu" type="raw"/>
          <source file="${installIso}" startupPolicy="optional"/>
          <target dev="sda" bus="sata"/>
          <readonly/>
        </disk>
        <disk type="file" device="cdrom">
          <driver name="qemu" type="raw"/>
          <source file="${driversIso}">
            <seclabel model="dac" relabel="no"/>
          </source>
          <target dev="sdb" bus="sata"/>
          <readonly/>
        </disk>
        <controller type="usb" model="qemu-xhci" ports="15"/>
        <interface type="network">
          <mac address="52:54:00:da:59:58"/>
          <source network="default"/>
          <model type="virtio"/>
        </interface>
        <input type="tablet" bus="usb"/>
        <tpm model="tpm-crb">
          <backend type="emulator" version="2.0"/>
        </tpm>
        <graphics type="spice">
          <listen type="none"/>
          <image compression="off"/>
        </graphics>
        <video>
          <model type="virtio" heads="1" primary="yes"/>
        </video>
        <!-- Guest speakers and microphone, carried by the SPICE viewer's
             PipeWire session; the mic is live only while a viewer is open. -->
        <sound model="ich9">
          <audio id="1"/>
        </sound>
        <audio id="1" type="spice"/>
        <channel type="spicevmc">
          <target type="virtio" name="com.redhat.spice.0"/>
        </channel>
        <channel type="unix">
          <target type="virtio" name="org.qemu.guest_agent.0"/>
        </channel>
        <!-- Integrated webcam, owned by the guest while it runs. Optional so
             the VM still starts if the camera is missing or disabled. -->
        <hostdev mode="subsystem" type="usb" managed="yes">
          <source startupPolicy="optional">
            <vendor id="${webcam.vendor}"/>
            <product id="${webcam.product}"/>
          </source>
        </hostdev>
        <!-- Ad-hoc SPICE USB redirection (e.g. a headset) from the viewer. -->
        <redirdev bus="usb" type="spicevmc"/>
        <redirdev bus="usb" type="spicevmc"/>
        <memballoon model="virtio"/>
        <rng model="virtio">
          <backend model="random">/dev/urandom</backend>
        </rng>
      </devices>
    </domain>
  '';
in
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = false; # QEMU runs as qemu-libvirtd, not root.
      swtpm.enable = true; # Windows 11 requires TPM 2.0.
      # Keep NixOS's default namespaces setting. libvirt's default swtpm user,
      # tss, does not exist here; use the same unprivileged QEMU account.
      verbatimConfig = ''
        namespaces = []
        swtpm_user = "qemu-libvirtd"
        swtpm_group = "qemu-libvirtd"
      '';
    };
    onBoot = "ignore"; # Never autostart the guest.
    onShutdown = "shutdown"; # Ask Windows to shut down cleanly with the host.
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
    "L+ ${driversIso} - - - - ${pkgs.virtio-win.src}"
  ];

  systemd.services."libvirt-define-${name}" = {
    description = "Define the ${name} libvirt guest";
    wantedBy = [ "multi-user.target" ];
    requires = [ "libvirtd.service" ];
    after = [
      "libvirtd.service"
      "systemd-tmpfiles-setup.service"
    ];
    path = [
      config.virtualisation.libvirtd.package
      config.virtualisation.libvirtd.qemu.package
    ];
    restartTriggers = [ domain ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -e ${disk} ]; then
        qemu-img create -f qcow2 -o nocow=on ${disk} ${diskSize}
      fi
      virsh net-autostart default
      if ! virsh net-info default | grep -q '^Active:.*yes'; then
        virsh net-start default
      fi
      virsh define ${domain}
    '';
  };
}
