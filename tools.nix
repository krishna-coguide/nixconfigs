{ pkgs, ... }:

{
  programs.git.enable = true;
  home-manager.users.dev.programs.git = {
    enable = true;
    package = null; # The system module supplies Git.
    settings.user.useConfigOnly = true;
  };

  environment.systemPackages = [
    pkgs.nixfmt
  ];
}
