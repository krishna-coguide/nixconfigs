{ pkgs, ... }:

{
  # Preserve locally provisioned passwords on every host; never invent one.
  users.mutableUsers = true;
  users.users.dev = {
    isNormalUser = true;
    uid = 1001;
    description = "Development user";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ ./dev-authorized-keys ];
  };

  security.sudo.extraRules = [
    {
      users = [ "dev" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "before-nix";
    users.dev.home.stateVersion = "26.05";
  };

  systemd.tmpfiles.rules = [
    "d /home/dev/.config 0755 dev users -"
    "d /home/dev/projects 0755 dev users -"
  ];
}
