{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    # Leave configure empty: load the user's init.lua normally.
  };

  home-manager.users.dev =
    { config, lib, ... }:
    let
      url = "https://github.com/krishna-coguide/nvim-dots";
      configDir = "${config.xdg.configHome}/nvim";
      git = lib.getExe pkgs.git;
    in
    {
      # ~/.config/nvim is a real, dev-owned Git checkout of the dotfiles: edit,
      # commit and push there. Lazy updates its tracked lazy-lock.json in place.
      # Clone only when absent (after old store links are removed); never fetch,
      # reset or overwrite an existing checkout or unrelated files.
      home.activation.neovimCheckout = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [[ ! -e "${configDir}" && ! -L "${configDir}" ]] ||
          [[ -d "${configDir}" && ! -L "${configDir}" && -z "$(ls -A "${configDir}")" ]]; then
          # Activation also runs at boot, possibly offline: warn, do not fail.
          if ! run env GIT_TERMINAL_PROMPT=0 ${git} clone --quiet ${url} "${configDir}"; then
            echo "Could not clone ${url}; retry with: git clone ${url} ${configDir}" >&2
          fi
        elif [[ ! -e "${configDir}/.git" ]]; then
          echo "Leaving ${configDir} untouched: it is not a Git checkout of ${url}." >&2
        fi
      '';
    };
}
