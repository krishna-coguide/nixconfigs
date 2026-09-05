{ pkgs, ... }:

{
  # Keep each host's existing interface/DHCP owner. On EC2 this is dhcpcd;
  # NixOS wires its resolvconf hook to resolved's compatibility interface.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      LLMNR = false;
      MulticastDNS = false;
      # Do not force public DNS, DNSSEC or DNS-over-TLS over DHCP/VPN policy.
    };
  };

  programs.mtr.enable = true;
  environment.systemPackages = with pkgs; [
    wireguard-tools
    dnsutils
    tcpdump
    ethtool
    netcat-openbsd
    socat
  ];
  # wg/wg-quick are available, but no invented peers, keys, routes or ports.
}
