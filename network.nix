{ lib, pkgs, ... }:

{
  # Keep each host's existing interface/DHCP owner. On EC2 this is dhcpcd;
  # NixOS wires its resolvconf hook to resolved's compatibility interface.
  services.resolved = {
    # Physical hosts can retain their existing DNS setup during migration.
    enable = lib.mkDefault true;
    settings.Resolve = {
      LLMNR = false;
      MulticastDNS = false;
      # Do not force public DNS, DNSSEC or DNS-over-TLS over DHCP/VPN policy.
    };
  };

  programs.mtr.enable = true;
  environment.systemPackages = with pkgs; [
    wireguard-tools # wg and wg-quick; no interfaces or credentials are configured.
    openvpn
    iperf3
    nmap
    traceroute
    whois
    dnsutils
    tcpdump
    ethtool
    netcat-openbsd
    socat
  ];
  # Client tools only: no VPN services, peers, keys, routes or firewall ports.
}
