{ inputs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    # Leave configure empty: load the user's init.lua normally.
  };

  home-manager.users.dev =
    { config, lib, ... }:
    let
      dots = inputs.neovim-dots;
      configDir = "${config.xdg.configHome}/nvim";
      lockFile = "${config.xdg.stateHome}/nvim/locks/${dots.rev}.json";
      backup = "${config.home.homeDirectory}/projects/neovim-dots-before-nix";
    in
    {
      # Import the original repo, without translating or patching its Lua.
      xdg.configFile."nvim" = {
        source = lib.cleanSourceWith {
          src = dots;
          filter = path: _: baseNameOf path != "lazy-lock.json";
        };
        recursive = true;
      };

      # Lazy writes this file. Seed a writable copy per pinned config revision.
      xdg.configFile."nvim/lazy-lock.json".source = config.lib.file.mkOutOfStoreSymlink lockFile;
      home.activation.neovimLock = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
        if [[ ! -e "${lockFile}" ]]; then
          run install -D -m 0600 "${dots}/lazy-lock.json" "${lockFile}"
        fi
      '';

      # Preserve the earlier manual checkout intact; never overwrite a backup.
      # On a clean machine this is a no-op, not a deployment prerequisite.
      home.activation.neovimCheckoutBackup =
        lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            if [[ -d "${configDir}/.git" ]]; then
              if [[ -e "${backup}" || -L "${backup}" ]]; then
                echo "Refusing to overwrite Neovim checkout backup: ${backup}" >&2
                exit 1
              fi
              run mkdir -p "$(dirname "${backup}")"
              run mv -T "${configDir}" "${backup}"
            fi
          '';
    };
}
