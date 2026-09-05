{ pkgs, ... }:
let
  updater = pkgs.writeShellApplication {
    name = "update-system";
    runtimeInputs = with pkgs; [
      nix
      git
      coreutils
      util-linux
    ];
    text = builtins.readFile ./update-system.sh;
  };
in
{
  environment.systemPackages = [ updater ];
  systemd.tmpfiles.rules = [ "d /var/cache/nixos-update 0700 dev users -" ];
  systemd.services.nixos-update = {
    description = "Build, record and apply stable NixOS updates without disturbing local work";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      Type = "oneshot";
      User = "dev";
      Group = "users";
      WorkingDirectory = "/etc/nixos";
      CacheDirectory = "nixos-update";
      UMask = "0077";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "2h";
      ExecStart = "${updater}/bin/update-system";
    };
  };
  systemd.timers.nixos-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
