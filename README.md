# Development host

Flat, explicit NixOS modules, with locked inputs. Required machine setup belongs in these configs—not a list of manual installs or dotfile copies.

| File | Owns |
| --- | --- |
| `flake.nix`, `flake.lock` | Host entry point and exact Nixpkgs/Home Manager/dotfile revisions and content hashes |
| `configuration.nix` | EC2 base, platform, Nix features, compatibility version, imports |
| `users.nix` | `dev`, SSH/sudo, Home Manager integration, workspace/repo ownership |
| `dev-authorized-keys` | Public SSH keys for `dev`—never private keys |
| `tools.nix`, `colors.nix` | Zsh, Kitty, Pi, Starship, fzf, Yazi, btop, Git policy and common CLI tools; shared readable palette |
| `desktop.nix`, `hyprland.lua`, `anyrun.css`, `wallpaper.svg` | Hyprland/UWSM, bar, launcher, original wallpaper, notifications, lock/idle, PipeWire and desktop styling |
| `apps.nix` | Firefox ESR, KeePassXC, Thunderbird, Steam, Element, Slack and Zathura |
| `workstation.nix`, `nvidia.nix` | Separately selected physical-workstation/greeter and NVIDIA integration; not enabled on EC2 |
| `updates.nix`, `update-system.sh` | Daily stable-input updates in an isolated Git worktree; validated commits, no forced reboot or GC |
| `desktop-test.nix`, `desktop-test.py`, `audit-desktop.sh`, `update-test.py` | Disposable graphical audit and updater failure/concurrency tests |
| `network.nix` | systemd-resolved and network/WireGuard diagnostics; leaves interface management with the host |
| `neovim.nix`, `neovim-test.lua` | Editor, unchanged upstream dotfile deployment and opt-in native runtime audit |
| [DESKTOP.md](DESKTOP.md) | Historical component research; executable configuration is in the files above |

## Account

- Daily user: `dev`, UID 1001, home `/home/dev`, workspace `~/projects`.
- Passwordless sudo is scoped to `dev`; existing SSM-user administration and root SSH recovery remain intact.
- `dev` is authorized by the public key in this repo. No private key or password is embedded.
- `/etc/nixos` is writable by `dev` through a native tmpfiles ownership rule, which does not follow store symlinks.
- Nix daemon access stays untrusted for ordinary use. Sudo is a separate, explicit administrative capability.
- The declared daily shell is Zsh, with completion, suggestions, highlighting, Starship, fzf (`Ctrl-R`, `Ctrl-T`, `Alt-C`), and zoxide (`z`, `zi`). Root/SSM shells are not changed.
- Kitty uses an opaque dark background, 13pt JetBrains Mono and generous padding. `Ctrl-Shift-+` / `Ctrl-Shift--` zoom its font; `Ctrl-Shift-Backspace` resets it. `y` opens Yazi with shell-directory integration.
- Desktop keys: `Super-Enter` Kitty, `Super-Space` launcher, `Super-E` Yazi, `Super-B` Firefox, `Super-P` KeePassXC, `Super-Escape` lock, `Super-Q` close, `Super-1…0` workspaces, `Print` screenshot/annotation. Launch the **Hyprland (uwsm-managed)** session.
- KeePassXC preferences are seeded once and remain writable. Open/create your own vault and pair its browser extension; no vault, account or VPN credentials are embedded. The physical-workstation module requires a securely provisioned `hashedPasswordFile`; EC2 gets no greeter or autologin.
- Element uses libsecret for encrypted local storage through KeePassXC. Before using it, create/open your own vault and select a dedicated application-token group in **Database Settings → Secret Service Integration**. Keep that vault unlocked when requested. Do not select Element's weaker/no-encryption fallback. Vault setup and application authentication are intentionally user-controlled.
- `wg` and `wg-quick` are installed without any tunnels, peers, keys or added firewall ports. `resolvectl` is backed by resolved; DHCP remains under the existing host network manager.

Enter from an administrator session with `sudo -iu dev`.

Git author identity and remote destination are deliberately unset. `user.useConfigOnly` is now a Home Manager setting in `tools.nix`, not a required manual `git config` step.

## Build and apply

As `dev`, from `/etc/nixos`:

```sh
nixfmt --check ./*.nix
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.updates .#checks.x86_64-linux.desktop-config --no-link
nix build .#nixosConfigurations.dev.config.system.build.toplevel --no-update-lock-file
```

New source files must be added to Git for flakes to see them. Keep `flake.lock` in version control. A build does **not** activate changes.

Review and activate exactly the built closure:

```sh
built=$(readlink -f result)
sudo "$built/sw/bin/nixos-rebuild" dry-activate --no-reexec --store-path "$built"
sudo "$built/sw/bin/nixos-rebuild" switch --no-reexec --store-path "$built"
```

Use the rebuild tool from that closure with `--no-reexec`: otherwise the bootstrap tool can try to rebuild itself through the old channel even when `--store-path` is supplied. Capturing `built` also keeps review and activation on the same immutable result.

For initial deployment on a compatible NixOS EC2 base where flakes are not enabled yet, check out this repo and run the build as an existing administrator with the temporary CLI flag:

```sh
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.dev.config.system.build.toplevel --no-update-lock-file
```

Then review/apply the resulting closure as above. The configuration creates `dev`, sets permissions and deploys its files. **No separate Neovim clone, copy, useradd, chown or global Git-config recipe is required.**

This host build does not use a mutable channel. NixOS's native flake integration pins the `nixpkgs` registry entry and login-shell `<nixpkgs>` lookup to the system input; the global `nix-path` setting keeps the same pin when `NIX_PATH` is unset. Old root channel profiles are retained for recovery, not used as build inputs. Dev-environment templates/composition remain deferred; there is no flake framework here.

## Neovim: import, do not rewrite

The input is [the existing neovim-dots repository](https://git.cyber.ayyalasomayajula.net/marsultor/neovim-dots), initially pinned to `380eb86778a7c53a0f1c18e84f14037456155347`.

Home Manager deploys its files under `~/.config/nvim`, with the **Lua, AstroNvim, Lazy, Mason, plugins and keymaps unchanged**. `programs.neovim.configure` stays empty so Neovim discovers `init.lua` normally. No Nixvim or custom Lua loader.

- `tools.nix` supplies GCC/Make, pkg-config, Python, Node, Lua 5.1/LuaRocks and `nix-ld` for the existing plugin builds and Mason's upstream Linux executables. These are runtime prerequisites, not a replacement plugin manager or project-template framework.
- Configuration files are linked from the pinned source and managed by Nix. Change the upstream repo and its input revision rather than editing generated links.
- Lazy's `lazy-lock.json` must remain writable. The config seeds a copy at `~/.local/state/nvim/locks/<dotfile-revision>.json` and links to it. A new dotfile revision gets its own original lock; repeated activation preserves runtime changes to an existing lock.
- A declared migration preserves the earlier manual checkout intact at `~/projects/neovim-dots-before-nix`. It refuses to overwrite an existing backup. On a clean home this migration does nothing.

**Reproducibility boundary:** Nix locks the host inputs and dotfile source, and reproduces their deployment. The existing Lua still bootstraps Lazy and manages plugin/Mason downloads at runtime. The supplied Lazy lock records plugin revisions, but it is writable and Mason's tool versions are not pinned by this Nix config. This is not a claim that every runtime download/cache is a Nix-reproducible build. Changing that policy requires a separate agreement; do not silently replace the user's plugin managers.

## Validation and commits

The initial deployment was tested with an empty disposable home: all upstream files were reproduced byte-for-byte, the Lazy lock remained writable across repeated activation, and the migration preserved local data and refused to overwrite an existing backup. The real plugin bootstrap is a separate runtime test, not covered by these file-deployment checks. As `dev`, run `nvim --headless ~/.config/nvim/init.lua -c 'luafile /etc/nixos/neovim-test.lua'` for a bounded runtime check of Lazy, the configured Mason tools (including executable startup), and nine parsers. This uses the existing writable plugin/Mason cache and may download dependencies; it does not edit the managed Lua or save buffers.

Run the graphical test separately with `./audit-desktop.sh`. An optional accessible render node, for example `./audit-desktop.sh /dev/dri/renderD128`, moves rendering out of QEMU's CPU emulation without touching the host display. Screenshots and logs go to `~/.cache/desktop-audit/run.*`. The test uses an isolated VM, test-only credentials and an emulated sound card with a silent backend. It checks session services, fonts, 100%/150% scaling, real PAM lock/unlock, speaker volume, microphone mute and audio controls. Hardware audio, NVIDIA, suspend and mixed-monitor behavior still need the target workstation. `nix flake check` without `--no-build` also runs the software-rendered VM and can be very slow without KVM.

Make focused changes, format/evaluate them, and commit regularly. Build and activate a reviewed commit rather than accumulating uncommitted setup. `system.configurationRevision` records the source revision in the system generation. Do not put human identity guesses in Git settings or push to an unapproved remote.

## Updates and safety

- `nixos-update.timer` checks daily with up to one hour of jitter. Only the stable Nixpkgs/Home Manager branches advance; Neovim's source stays fixed. The updater skips a dirty repository, builds in a detached worktree, records a tested commit and applies it without rebooting. It attempts rollback if activation fails and retains recovery generations. Inspect `journalctl -u nixos-update` or trigger it with `sudo systemctl start nixos-update`.
- For a manual input refresh: `nix flake update nixpkgs home-manager`, review `flake.lock`, then check/build. The exact resolved revisions and hashes remain committed.
- Keep the EC2 module, sandboxing, signature verification and recovery access intact.
- `system.stateVersion` and `home.stateVersion` are both `26.05`; these preserve compatibility, not package versions.
- `test` activates changes too; it is not a dry run. Keep the original system generation.
- Rollbacks do not restore mutable user/application data, lockfile updates, backups, or this Git working tree.
- No private keys, plaintext secrets, build outputs or agent notes in this repo.
