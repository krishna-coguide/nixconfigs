# Development workstation

Flat, explicit NixOS modules with locked inputs. Required setup belongs here—not in manual package installs, copied dotfiles or an extra framework.

**Select the host, not the login name:** `nixosConfigurations.nixos` is this physical UEFI/NVMe laptop; `nixosConfigurations.dev` is EC2 only. Both use the `dev` account. Never activate the EC2 closure on the laptop.

## Layout

| File | Owns |
| --- | --- |
| `flake.nix`, `flake.lock` | Host entry points, exact Nixpkgs/Home Manager/tool/dotfile revisions and hashes |
| `common.nix` | Shared environment, platform, Nix features and compatibility version |
| `physical.nix`, `hardware-configuration.nix` | Laptop boot/storage, SDDM with only managed Hyprland, networking, Bluetooth, power, firmware and host-specific updates |
| `configuration.nix` | EC2-only boot/storage/SSM integration, updater and repo ownership |
| `users.nix` | `dev`, SSH authorization, sudo, Home Manager and workspace ownership |
| `tools.nix`, `network.nix` | Development toolkit, terminal/shell, rootless Podman, VPN clients and network diagnostics |
| `colors.nix`, `wallpaper.nix`, `wallpaper.svg` | Shared One Ring palette, hash-pinned wallpaper and original fallback artwork |
| `desktop.nix`, `hyprland.lua`, `anyrun.css`, `swaync.css`, `desktop-help.py`, `desktop-actions.py` | Session/bar, launchers, described help, capture, clipboard, notifications, lock/idle and styling |
| `apps.nix`, `element-nightly.nix` | Firefox ESR, KeePassXC, Thunderbird, Steam, pinned Element Nightly, Slack, file/media viewers and MIME defaults |
| `neovim.nix`, `neovim-test.lua` | Unmodified upstream editor deployment and opt-in native runtime audit |
| `updates.nix`, `update-system.sh`, `update-test.py` | Daily isolated-worktree updates and failure/concurrency regression tests |
| `physical-test.nix`, `tools-test.nix` | Built host/session assertions and bounded offline tool/help smoke tests |
| `desktop-test.nix`, `desktop-test.py`, `audit-desktop.sh` | Disposable graphical/PAM/audio/scaling audit |
| `workstation.nix`, `nvidia.nix` | Optional ReGreet workstation and NVIDIA modules; not this Intel laptop's configuration |
| [DESKTOP.md](DESKTOP.md) | Live audit, wallpaper provenance, JaKooLit comparison and explicit feature-completion plan |

## Account and session

- Daily account: **dev**, UID 1001, `/home/dev`, workspace `~/projects`, Zsh.
- `dev` has **full passwordless sudo**, not a rebuild-only privilege. Nix daemon trusted-user access is not separately granted.
- The physical host uses the locally established `dev` password; mutable users preserve it. No plaintext password, private key or password hash is embedded in this repo/store.
- At the user's request, **Plasma and the previously managed `kbot` account are removed**. This configuration does not delete `/home/kbot`; retained files and old generations are not erased. Home Manager only manages `dev`.
- SDDM exposes **Hyprland (uwsm-managed)** only. Plain Hyprland is deliberately hidden because it does not start the session-bound bar, wallpaper, idle and polkit services. UWSM is the single session owner.
- On EC2, SSM/root recovery and the host's integration remain intact; there is no graphical greeter or autologin. `/etc/nixos` is dev-owned there. On the laptop `/etc/nix` remains administrator-owned and the original `/etc/nixos` files are untouched.
- The SSH key in `dev-authorized-keys` is public. Account/cloud/browser/VPN credentials and vaults remain user-controlled.

### Everyday controls

| Key / command | Action |
| --- | --- |
| `Super-H`, bar `?` | Search described shortcuts from the live compositor; selecting a row does not execute it |
| `Super-Enter` | Kitty |
| `Super-D` | Anyrun applications/calculator |
| `Super-E`, `Super-Ctrl-E`, `y` | Thunar / Yazi; `y` includes shell-directory integration |
| `Super-B`, `Super-Alt-P` | Firefox / KeePassXC |
| `Ctrl-Alt-L`, `Super-Escape` | Lock |
| `Super-Q`, `Super-Shift-F`, `Super-Space` | Close / fullscreen / floating |
| `Super-1…0`, `Super-Shift-1…0` | Focus workspace / move and follow; Ctrl moves silently |
| `Super-U`, `Super-Shift-U` | Scratch workspace / move window to it |
| `Super-Shift-Enter` | Drop-down terminal |
| `Super-Shift-E`, `Ctrl-Alt-P` | Actions / confirmed session-power menu |
| `Super-Shift-N`, `Super-Ctrl-N` | Notification history / DND |
| `Super-Alt-V` | Clipboard history |
| `Print`, `Super-Shift-S` | Screenshot menu / region annotation |
| `Super-Alt-R` | Start/stop recording; red REC indicator when active |
| `Super-N`, `Super-Alt-E` | Night light / emoji |
| `Super-A`, `Alt-Tab` | Window search / cycle windows |
| `Ctrl-R`, `Ctrl-T`, `Alt-C` in Zsh | fzf history / files / directories |
| `z`, `zi` | zoxide directory navigation |
| `direnv allow` | Explicitly approve a project's `.envrc`; no automatic trust whitelist |
| `tmux`, `zellij`, `lazygit` | Persistent terminal workspaces and Git UI; not auto-started or forced |

Kitty uses an opaque charcoal background, 12pt JetBrains Mono and compact padding. Font zoom remains `Ctrl-Shift-+` / `Ctrl-Shift--`; reset with `Ctrl-Shift-Backspace`. Semantic ANSI colors remain distinguishable from the gold UI accent. Neovim's own theme is unchanged.

The **informative top bar** includes workspaces/window context, clock, CPU/RAM/host temperature, media, notification count, privacy and laptop status. Click its right-hand status area for audio, microphone, brightness, network/Bluetooth, idle inhibition and power-profile controls. **Actions** and **Health** open the searchable action palette and real system/update diagnostics. Notification history is a separate compact drawer, not another settings dashboard.

See [DESKTOP.md](DESKTOP.md) for the screenshot-led audit, functional coverage, wallpaper provenance and remaining hardware/account checks. JaKooLit informed the general shortcuts and workflow coverage—not the visual design.

## Tool coverage

`tools.nix` is organized by purpose, not a single unexplained package dump:

- **Native/debug:** GCC, Make, pkg-config, CMake, Ninja, Meson, ccache, clang tools, GDB, LLDB, Valgrind, Heaptrack, rr, ELF utilities and bpftrace.
- **Rust:** rustc/Cargo/rustfmt/Clippy/rust-analyzer, nextest, cargo-audit/deny/expand/edit.
- **Go:** Go, gopls, Delve, golangci-lint.
- **Python:** Python, uv, Ruff, Pyright; existing Lua/LuaRocks prerequisites stay for Neovim.
- **JS/TS:** Node, pnpm, TypeScript, Biome, Bun, Deno.
- **Additional ecosystems:** OpenJDK 25, Maven, Gradle 9, Kotlin, .NET SDK 10, Ruby/Bundler, PHP/Composer, Zig/ZLS and Elixir/Erlang.
- **Project/CI:** just, watchexec, hyperfine, tokei, ShellCheck, shfmt, yamllint, actionlint, pre-commit, dprint, StyLua, Taplo, Marksman, markdownlint, SQLFluff, Hadolint, ast-grep and ripgrep-all.
- **Source control:** Git/LFS, gh, glab, LazyGit, delta, difftastic, Jujutsu, git-absorb/filter-repo. No guessed Git identity or account authentication.
- **Nix:** direnv/nix-direnv, nix-output-monitor, nvd, nix-tree/diff, nixd, statix, deadnix, nixpkgs-review and the repo formatter.
- **Containers/cloud:** rootless Podman, Compose, Buildah, Skopeo, Dive, AWS CLI, kubectl, Helm, k9s, kubectx, Stern, Kustomize, OpenTofu, Ansible. No Docker daemon, docker-group privilege, deployed infrastructure or automatic image downloads.
- **Data/API:** SQLite, DuckDB, pgcli/litecli, Redis tools, Miller, csvlens, jq/yq/jless, xh, grpcurl, websocat, Protobuf/Buf, Hurl and oha. Installing these does not start database servers or load-test an endpoint.
- **Security/backup:** age, sops, GnuPG, Gitleaks, Trivy, Cosign, Syft, Grype, step, mkcert, restic, rclone, rsync, Mosh and SSHFS. No keys, trusted CA, backup destination, schedules or scan targets are created.
- **Diagnostics:** btop, procs, lnav, sysstat, iotop, dust/duf/ncdu, strace/lsof, NVMe/SMART/USB/PCI/sensor tools.
- **Media/documents:** FFmpeg, ImageMagick, ExifTool, MediaInfo, Poppler utilities, Pandoc, yt-dlp, Chafa, Asciinema, VHS and archive/compression tools.
- **Networking (`network.nix`):** WireGuard/OpenVPN, NetworkManager VPN integration on the laptop, mtr, iperf3, nmap, tcpdump/tshark, doggo/dig, iftop/bandwhich, traceroute, whois, ethtool, netcat and socat. No tunnels, peers, credentials, extra capture privileges or opened firewall ports.

These are system-owned executables from Nix, not unmanaged `npm -g`, `pip install --user` or `cargo install` bootstraps. Project dependencies may still be downloaded by their ordinary package managers. `nix develop` / `.envrc` remain appropriate for project-specific versions; this is not a promise that every language project uses the same global toolchain.

## Build and apply

### One-command sync on this laptop

Save your work, then run from any directory (it requests sudo when needed):

```sh
/etc/nix/switch-system.sh               # apply now and make it the boot default
/etc/nix/switch-system.sh dry-activate  # build and preview changes without applying
/etc/nix/switch-system.sh boot          # stage for the next boot instead
```

This builds the current **`/etc/nix#nixos`** checkout and activates that exact output, including `dev`'s Home Manager configuration. It shares the automatic updater's lock, stops on build failure, keeps recovery generations and never reboots. It does **not** pull remote Git changes or update `flake.lock`: “latest” here means the files currently checked out in `/etc/nix`. New source files must be added to Git to be included. Open a new terminal afterward for shell environment changes; some desktop changes require a fresh login. `--help` lists the modes, including temporary `test` activation.

### Detailed validation and activation

On the **physical laptop**, from an administrator shell:

```sh
cd /etc/nix
nixfmt --check ./*.nix
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.updates \
  .#checks.x86_64-linux.desktop-config \
  .#checks.x86_64-linux.physical-config \
  .#checks.x86_64-linux.tools .#checks.x86_64-linux.desktop-actions \
  --no-update-lock-file --no-link
nix build .#nixosConfigurations.nixos.config.system.build.toplevel \
  --no-update-lock-file --out-link result-nixos
built=$(readlink -f result-nixos)
sudo "$built/sw/bin/nixos-rebuild" dry-activate --no-reexec --store-path "$built"
```

New source files must be added to Git for flakes to include them. A build or dry activation does not activate the result. Review the dry activation; removing Plasma and `kbot` is intentional, removing `dev`, NetworkManager or the installed mounts is not.

**Save work before activating.** A desktop/display-manager change can end a graphical session. Use `Ctrl-Alt-F3`, log in as `dev`, and retain that console:

```sh
built=$(readlink -f /etc/nix/result-nixos)
sudo "$built/sw/bin/nixos-rebuild" test --no-reexec --store-path "$built"
# After testing login/session, persist exactly that closure:
sudo "$built/sw/bin/nixos-rebuild" switch --no-reexec --store-path "$built"
```

`test` is a real activation, not a dry run. For a non-disruptive deployment that takes effect on next boot, use `boot` instead of `test`/`switch`. The daily physical updater uses that policy.

On **EC2 only**, use `/etc/nixos` and `.#nixosConfigurations.dev.config.system.build.toplevel`. Run the same evaluation/checks and activate the exact output with its own `nixos-rebuild --no-reexec --store-path`. Never select a target merely because it matches your username.

### Recovery

Keep existing generations. Inspect what is actually selected and booted:

```sh
readlink -f /run/current-system /run/booted-system /nix/var/nix/profiles/system
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
```

To restore the booted closure temporarily from the retained console:

```sh
previous=$(readlink -f /run/booted-system)
sudo "$previous/sw/bin/nixos-rebuild" test --no-reexec --store-path "$previous"
```

If boot fails, choose a known-good systemd-boot generation (hold Space at startup). Do not blindly select “generation 1”: generation numbers are machine/history-specific. System rollback does not restore mutable user data, Git changes, application databases or backups.

## Automatic freshness, precisely

- **Every day**, `nixos-update.timer` runs with up to one hour of jitter and catches missed runs. It advances `nixpkgs`, `home-manager`, and `nixpkgs-latest`; the Neovim source remains fixed.
- The system/desktop use the stable `nixos-26.05` and matching Home Manager release branch. Most standalone CLI tools use the locked **Nixpkgs master** input to avoid stable-release feature lag. They are imported separately, **not** overlaid onto the desktop's GCC/Python/libraries. The Nix daemon and service-integrated packages remain from the system pin.
- **Laptop:** administrator-owned `/etc/nix`, explicit `nixos` target, build/check/record and **stage for next boot**. No surprise logout, live compositor replacement or automatic reboot. Installed versions change when that generation is booted, or when explicitly switched by the user.
- **EC2:** dev-owned `/etc/nixos`, explicit `dev` target and live `switch`, retaining the prior activation/rollback behavior.
- Both policies skip dirty/detached repositories, serialize runs, use an isolated worktree, check for edits again after dry activation, commit only the tested lock, attempt rollback on failure and retain recovery generations. A failed rollback is reported as failure, not silently marked successful.
- **“Current” means newest successfully checked/built versions packaged in those branch heads**, not a guarantee of every upstream release immediately. Master can contain breakage and uncached builds; failure retains the previous working generation. Upstream Pi, Mason/plugin downloads, browser add-ons, firmware and project dependencies are separate update boundaries. No runtime self-updater is bolted on to override Nix-owned executables.
- The updater does not fetch/merge repository code from origin. Configuration code is reviewed separately. A dirty working tree intentionally prevents automatic input changes until work is committed/stashed.

Inspect or trigger:

```sh
systemctl list-timers nixos-update.timer
journalctl -u nixos-update
sudo systemctl start nixos-update.service
sudo less /var/cache/nixos-update/last-success
```

Manual refresh: `nix flake update nixpkgs home-manager nixpkgs-latest`, review `flake.lock`, then check/build. `system.stateVersion` / `home.stateVersion` remain `26.05`: they govern compatibility, not package freshness. Channels are disabled; the Nixpkgs registry and `<nixpkgs>` lookup follow the locked system input.

## Editor and application data

Neovim imports [the existing neovim-dots source](https://git.cyber.ayyalasomayajula.net/marsultor/neovim-dots), pinned to `380eb86778a7c53a0f1c18e84f14037456155347`. Lua, AstroNvim, Lazy, Mason, plugins and keymaps are unchanged. No Nixvim, replacement loader or plugin-manager migration.

Home Manager links configuration files under `~/.config/nvim`. Lazy's writable lock lives under `~/.local/state/nvim/locks/<revision>.json`, seeded once per dotfile revision. An earlier manual checkout is preserved at `~/projects/neovim-dots-before-nix`; activation refuses to overwrite an existing backup. The host input is reproducible; Lazy/Mason's mutable runtime downloads are not claimed to be fully Nix-reproducible.

As `dev`, the separate runtime audit may download dependencies but does not modify managed Lua or save buffers:

```sh
nvim --headless ~/.config/nvim/init.lua -c 'luafile /etc/nix/neovim-test.lua'
```

KeePassXC preferences are seeded once and stay writable. Create/open your own vault, pair the browser extension and choose a dedicated **Secret Service Integration** group for application tokens. Element Nightly is forced to libsecret storage; **do not select its unencrypted fallback**. The native audit confirmed that Nightly starts, but login needs an unlocked/configured vault. No vault, account or VPN credentials are embedded.

`element-nightly.nix` packages the official Element Nightly **2026090401** Debian artifact by URL and SHA-256, preserving its matched Electron/native modules. It uses Chromium's user-namespace sandbox rather than the unusable setuid helper; `--no-sandbox` is not used. Its Nightly profile is separate from stable Element; existing account data is not copied or deleted. The launcher is **Element-Nightly**, command `element-desktop-nightly`; `element-desktop` is a compatibility alias.

**Nightly update boundary:** this upstream binary is not packaged by the pinned Nixpkgs inputs. Its URL/version/hash must be refreshed in `element-nightly.nix` from the official `packages.element.io` package index, then rebuilt. The daily flake-input updater does not silently mutate this source file. This intentionally keeps the setup simple and reproducible rather than adding another downloader/self-updater.

## Validation and contributions

`./audit-desktop.sh` runs the disposable graphical VM; `./audit-desktop.sh /dev/dri/renderD128` optionally uses an accessible render node. Logs/screenshots go to `~/.cache/desktop-audit/run.*`. The VM tests session services, fonts, audio, scaling and real PAM with **test-only** credentials. The native live screenshot audit covers this laptop; neither substitutes for real hardware suspend, hotplug or browser portal tests.

Plain `nix flake check` also builds/runs the VM and may be slow without KVM. Use `--no-build` for evaluation, then select bounded checks explicitly. Keep changes focused, format/evaluate/test them, and commit reviewed configuration. Do not push to an unapproved remote, invent a human Git identity, commit secrets, screenshots of personal windows, build outputs or agent scratch notes.
