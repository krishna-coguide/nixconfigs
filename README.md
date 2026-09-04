# Development host

Flat, explicit NixOS modules, with locked inputs. Required machine setup belongs in these configs—not a list of manual installs or dotfile copies.

| File | Owns |
| --- | --- |
| `flake.nix`, `flake.lock` | Host entry point and exact Nixpkgs/Home Manager/dotfile revisions and content hashes |
| `configuration.nix` | EC2 base, platform, Nix features, compatibility version, imports |
| `users.nix` | `dev`, SSH/sudo, Home Manager integration, workspace/repo ownership |
| `dev-authorized-keys` | Public SSH keys for `dev`—never private keys |
| `tools.nix` | Git, declarative user Git policy, official Nix formatter |
| `neovim.nix` | Editor and deployment of the unchanged upstream dotfiles |

## Account

- Daily user: `dev`, UID 1001, home `/home/dev`, workspace `~/projects`.
- Passwordless sudo is scoped to `dev`; existing SSM-user administration and root SSH recovery remain intact.
- `dev` is authorized by the public key in this repo. No private key or password is embedded.
- `/etc/nixos` is writable by `dev` through a native tmpfiles ownership rule, which does not follow store symlinks.
- Nix daemon access stays untrusted for ordinary use. Sudo is a separate, explicit administrative capability.
- Bash is the temporary default; further shell/workflow preferences remain the user's choice.

Enter from an administrator session with `sudo -iu dev`.

Git author identity and remote destination are deliberately unset. `user.useConfigOnly` is now a Home Manager setting in `tools.nix`, not a required manual `git config` step.

## Build and apply

As `dev`, from `/etc/nixos`:

```sh
nixfmt --check ./*.nix
nix flake check --no-update-lock-file
nix build .#nixosConfigurations.dev.config.system.build.toplevel --no-update-lock-file
```

New source files must be added to Git for flakes to see them. Keep `flake.lock` in version control. A build does **not** activate changes.

Review and activate exactly the built closure:

```sh
sudo nixos-rebuild dry-activate --store-path "$(readlink -f result)"
sudo nixos-rebuild switch --store-path "$(readlink -f result)"
```

For initial deployment on a compatible NixOS EC2 base where flakes are not enabled yet, check out this repo and run the build as an existing administrator with the temporary CLI flag:

```sh
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.dev.config.system.build.toplevel --no-update-lock-file
```

Then review/apply the resulting closure as above. The configuration creates `dev`, sets permissions and deploys its files. **No separate Neovim clone, copy, useradd, chown or global Git-config recipe is required.**

This host build does not use a mutable channel. NixOS's native flake integration also pins the `nixpkgs` registry entry and `<nixpkgs>` lookup to the system input. Dev-environment templates/composition remain deferred; there is no flake framework here.

## Neovim: import, do not rewrite

The input is [the existing neovim-dots repository](https://git.cyber.ayyalasomayajula.net/marsultor/neovim-dots), initially pinned to `380eb86778a7c53a0f1c18e84f14037456155347`.

Home Manager deploys its files under `~/.config/nvim`, with the **Lua, AstroNvim, Lazy, Mason, plugins and keymaps unchanged**. `programs.neovim.configure` stays empty so Neovim discovers `init.lua` normally. No Nixvim or custom Lua loader.

- Configuration files are linked from the pinned source and managed by Nix. Change the upstream repo and its input revision rather than editing generated links.
- Lazy's `lazy-lock.json` must remain writable. The config seeds a copy at `~/.local/state/nvim/locks/<dotfile-revision>.json` and links to it. A new dotfile revision gets its own original lock; repeated activation preserves runtime changes to an existing lock.
- A declared migration preserves the earlier manual checkout intact at `~/projects/neovim-dots-before-nix`. It refuses to overwrite an existing backup. On a clean home this migration does nothing.

**Reproducibility boundary:** Nix locks the host inputs and dotfile source, and reproduces their deployment. The existing Lua still bootstraps Lazy and manages plugin/Mason downloads at runtime. The supplied Lazy lock records plugin revisions, but it is writable and Mason's tool versions are not pinned by this Nix config. This is not a claim that every runtime download/cache is a Nix-reproducible build. Changing that policy requires a separate agreement; do not silently replace the user's plugin managers.

## Updates and safety

- To change a pinned source, update its revision in `flake.nix`, regenerate `flake.lock` with `nix flake lock`, review the diff, then check/build before switching. No unattended updates.
- Keep the EC2 module, sandboxing, signature verification and recovery access intact.
- `system.stateVersion` and `home.stateVersion` are both `26.05`; these preserve compatibility, not package versions.
- `test` activates changes too; it is not a dry run. Keep the original system generation.
- Rollbacks do not restore mutable user/application data, lockfile updates, backups, or this Git working tree.
- No private keys, plaintext secrets, build outputs or agent notes in this repo.
