{
  config,
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
  # NetworkManager owns local DNS on workstations. With dhcpcd (EC2),
  # NixOS wires resolvconf to resolved. Preserve both hosts' existing behavior.
  services.resolved = {
    enable = lib.mkDefault (!config.networking.networkmanager.enable);
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
