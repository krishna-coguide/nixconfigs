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

  # Local, opt-in SOCKS client only. Keep the daemon on the system package pin.
  # No relay/exit, control listener, transparent proxy or host DNS changes.
  services.tor = {
    enable = true;
    openFirewall = false;
    relay.enable = false;
    client = {
      enable = true;
      socksListenAddress = {
        addr = "127.0.0.1";
        port = 9050;
        IsolateDestAddr = true;
        IsolateSOCKSAuth = true;
      };
    };
    settings.ClientOnly = true;
  };
  # The NixOS module enables tor.service at boot and supplies its sandbox/user.
  # Retry even after a clean daemon exit; never exhaust systemd's start limit.
  systemd.services.tor = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = "5s";
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
    fping
    ldns # drill and DNS/DNSSEC inspection utilities.
    torsocks
    proxychains-ng # Opt-in wrappers; no global proxy environment is set.
    doggo
    iftop
    bandwhich
    wireshark-cli # tshark; no capture group/capabilities or daemon.
  ];
  # No VPN services, peers, keys, routes or opened firewall ports.
}
