{
  config,
  lib,
  pkgs,
  ...
}:
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
  systemd.services.nixos-update = {
    description = "Build and record host-specific NixOS/tool updates without disturbing local work";
    environment = {
      NIXOS_CONFIG_REPO = lib.mkDefault "/etc/nixos";
      NIXOS_UPDATE_HOST = lib.mkDefault "dev";
      NIXOS_UPDATE_MODE = lib.mkDefault "switch";
    };
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      Type = "oneshot";
      User = lib.mkDefault "dev";
      Group = lib.mkDefault "users";
      WorkingDirectory = config.systemd.services.nixos-update.environment.NIXOS_CONFIG_REPO;
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
