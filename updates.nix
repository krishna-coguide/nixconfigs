{
  config,
  lib,
  pkgs,
  ...
}:
let
  env = config.systemd.services.nixos-update.environment;
  repo = env.NIXOS_CONFIG_REPO;
  runtimeInputs = with pkgs; [
    nix
    git
    coreutils
    util-linux
  ];
  updater = pkgs.writeShellApplication {
    name = "update-system";
    inherit runtimeInputs;
    text = builtins.readFile ./update-system.sh;
  };
  switcher = pkgs.writeShellApplication {
    name = "switch-system";
    inherit runtimeInputs;
    text = ''
      export NIXOS_CONFIG_REPO=${lib.escapeShellArg repo}
      export NIXOS_UPDATE_HOST=${lib.escapeShellArg env.NIXOS_UPDATE_HOST}
      ${builtins.readFile ./switch-system.sh}
    '';
  };
in
{
  environment.systemPackages = [
    updater
    switcher
  ];
  # Z does not follow symlinks: in /etc/nix, Nix-owned configuration links and
  # result links never cause ownership changes in /etc/static or /nix/store.
  systemd.tmpfiles.rules = [
    "d ${repo} 0755 dev users -"
    "Z ${repo} - dev users -"
    "d /var/cache/nixos-update 0700 dev users -"
    "Z /var/cache/nixos-update - dev users -"
  ];
  systemd.services.nixos-update = {
    description = "Build and stage NixOS/tool updates for the next boot";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      Type = "oneshot";
      User = "dev";
      Group = "users";
      WorkingDirectory = repo;
      CacheDirectory = "nixos-update";
      CacheDirectoryMode = "0700";
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
