{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  latest = import inputs.nixpkgs-latest {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config;
  };
in
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

  programs.mtr = {
    enable = true;
    package = latest.mtr;
  };
  environment.systemPackages = with latest; [
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
    doggo
    iftop
    bandwhich
    wireshark-cli # tshark; no capture group/capabilities or daemon.
  ];
  # Client tools only: no VPN services, peers, keys, routes or firewall ports.
}
