# Development workstation

Flat, explicit NixOS modules with locked inputs. Required setup belongs here—not in manual package installs, copied dotfiles or an extra framework.

**Select the host, not the login name:** `nixosConfigurations.nixos` is this physical UEFI/NVMe laptop; `nixosConfigurations.dev` is EC2 only. Both use the `dev` account. Never activate the EC2 closure on the laptop or the laptop closure on EC2.

## Layout

| File | Owns |
| --- | --- |
| `hosts.nix`, `flake.nix`, `flake.lock` | Machine entry table, host construction and exact Nixpkgs/Home Manager/tool/dotfile pins |
| `common.nix` | Shared environment, locale/timezone, Nix features, update policy and compatibility version |
| `physical.nix`, `hardware-configuration.nix` | Laptop boot/storage, panel scale and CPU sensor; deployment identity comes from `hosts.nix` |
| `configuration.nix` | AWS boot/storage/network/recovery integration; deployment identity comes from `hosts.nix` |
| `users.nix` | `dev`, SSH authorization, sudo, Home Manager and workspace ownership |
| `tools.nix`, `network.nix` | Development toolkit, terminal/shell, rootless Podman, VPN/proxy clients, local Tor service and network diagnostics |
| `colors.nix`, `wallpaper.nix`, `wallpaper.svg` | Shared One Ring palette, hash-pinned wallpaper and original fallback artwork |
| `desktop.nix`, `hyprland.lua`, `anyrun.css`, `swaync.css`, `desktop-help.py`, `desktop-actions.py` | Session/bar, launchers, described help, capture, clipboard, notifications, lock/idle and styling |
| `apps.nix`, `element-nightly.nix` | Firefox ESR, Tor Browser, KeePassXC, Thunderbird, Steam, pinned Element Nightly, Slack, Tauon, GNOME Network Displays, file/media viewers and MIME defaults |
| `neovim.nix`, `neovim-test.lua` | Unmodified upstream editor deployment and opt-in native runtime audit |
| `updates.nix`, `update-system.sh`, `update-test.py` | Shared dev-owned checkouts, daily boot-staged updates and failure/concurrency regression tests |
| `switch-system.sh`, `switch-test.py` | Same installed manual apply/preview command on both hosts, with host identity supplied by Nix |
| `physical-test.nix`, `tools-test.nix`, `git-credentials-test.nix` | Physical/AWS safety, shared-policy assertions, offline tool/help smoke tests and disposable Git credential-cache checks |
| `desktop-test.nix`, `desktop-test.py`, `audit-desktop.sh` | Disposable graphical/PAM/audio/scaling audit |
| `workstation.nix`, `greeter-theme.nix`, `appearance-test.nix` | Local hardware/SDDM integration, Wi-Fi Display networking, One Ring login theme and isolated rendering/font check |
| `nvidia.nix`, `cuda.nix`, `cuda-check.cu`, [NVIDIA.md](NVIDIA.md) | Opt-in proprietary NVIDIA driver, installed CUDA SDK/cuDNN, Podman CDI and GPU setup guide |
| [DESKTOP.md](DESKTOP.md) | Live audit, wallpaper provenance, JaKooLit comparison and explicit feature-completion plan |
| [`templates/agent/`](templates/agent/README.md), `agent-template-test.nix` | Copyable DSH devShell example, built-in Bubblewrap sandbox guide and offline example check |

## Account and session

- Daily account: **dev**, UID 1001, `/home/dev`, workspace `~/projects`, Zsh.
- `dev` has **full passwordless sudo**, not a rebuild-only privilege. Nix daemon trusted-user access is not separately granted.
- The physical host uses the locally established `dev` password; mutable users preserve it. No plaintext password, private key or password hash is embedded in this repo/store.
- At the user's request, **Plasma and the previously managed `kbot` account are removed**. This configuration does not delete `/home/kbot`; retained files and old generations are not erased. Home Manager only manages `dev`.
- SDDM exposes **Hyprland (uwsm-managed)** only. Plain Hyprland is deliberately hidden because it does not start the session-bound bar, wallpaper, idle and polkit services. UWSM is the single session owner.
- The login greeter uses **SDDM Astronaut**, customized to the One Ring wallpaper, charcoal/parchment/gold palette, JetBrains Mono, a minimal left-hand form and matching cursor. This is a Qt6 login theme, not Plasma. PAM, passwords, session selection and the bootloader are unchanged; host autologin remains disabled.
- Both checkouts are **dev-owned**, including Git metadata: `/etc/nix` on the laptop and `/etc/nixos` on EC2. Existing paths are retained to avoid moving deployed repositories. NixOS maintains ownership without following symlinks into the Nix store; the laptop's original `/etc/nixos` files stay untouched.
- On EC2, AWS boot/storage/networking and SSM/SSH recovery remain intact; no physical greeter, Wi-Fi/Bluetooth or battery services are added. User settings, locale/timezone, packages and update policy come from the same modules. The graphical VM now uses the same SDDM/UWSM integration as the laptop.
- The SSH key in `dev-authorized-keys` is public. Account/cloud/browser/VPN credentials and vaults remain user-controlled.

When entering `dev` from root, use **`su - dev`**, not `su dev`: a non-login
switch can inherit root's `/run/user/0` runtime and D-Bus address. Zsh drops an
inherited runtime directory owned by another user and its matching bus address.
For an already-open affected shell, run
`unset XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS ZELLIJ_SOCKET_DIR` before Zellij.
Never change permissions on `/run/user/0` to work around this.

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

**JetBrains Mono Nerd Font** is the shared system default for monospace, sans-serif and serif requests, GTK/Qt application UI, bar, launchers, notifications, dialogs and lock/login screens. The family is declared once in `tools.nix`; UI sizes remain 11pt where appropriate and Kitty stays 12pt. Noto fonts preserve emoji and international-character coverage. App/site-specific embedded fonts and Tor Browser's privacy defaults are not forcibly overridden; the Linux text console still uses its bitmap font.

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
- **Networking (`network.nix`):** WireGuard/OpenVPN, NetworkManager VPN integration on the laptop, mtr, iperf3, nmap (including ncat/nping), tcpdump/tshark, doggo/dig, ldns/drill, fping, iftop/bandwhich, traceroute, whois, ethtool, netcat, socat, torsocks and proxychains-ng. Tor runs as a local client service (below). No tunnels, peers, credentials, extra capture privileges or opened firewall ports.

These are system-owned executables from Nix, not unmanaged `npm -g`, `pip install --user` or `cargo install` bootstraps. Project dependencies may still be downloaded by their ordinary package managers. `nix develop` / `.envrc` remain appropriate for project-specific versions; this is not a promise that every language project uses the same global toolchain.

### Git credentials: terminal, not a GUI

Git HTTPS authentication uses terminal username/token prompts and Git's native
**in-memory cache with a 365-day timeout** (`31536000` seconds). Inherited helpers
are reset, and Git/SSH graphical askpass fallback is disabled for normal terminal
Git invocations. No credential-manager GUI or plaintext `credential-store` is used.
Credentials are scoped to the repository path as well as the host.

This is cache retention, **not a new token expiry**: rebooting, stopping the cache
daemon or rejecting a credential clears it, and the provider can expire/revoke a
token sooner. A successful re-approval refreshes its cache timeout. Choose a
one-year token expiry at your Git provider if it supports it; no real credentials
or provider settings are changed by this configuration. SSH keys/agents and
KeePassXC's storage for other applications remain unchanged. IDEs or repositories
that explicitly override Git helpers/askpass can override these user defaults.

To forget all cached Git HTTPS credentials immediately:

```sh
git credential-cache exit
```

### NVIDIA / CUDA and additional machines

Add `./nvidia.nix` to a GPU machine's `modules` in **`hosts.nix`**. This installs
NVIDIA's stable proprietary driver, **`nvidia-smi`, `nvcc`, cuda-gdb,
compute-sanitizer, CUDA libraries/headers, cuDNN and nvtop**, plus CDI support for
rootless Podman. The driver follows the system kernel/pin; CUDA does not cause
global CUDA-enabled rebuilds of unrelated applications. Non-GPU hosts remain
unchanged. Blackwell+ requires `hardware.nvidia.open = true`; older cards and
hybrid laptops need the native overrides described in [NVIDIA.md](NVIDIA.md).

`hosts.nix` is also the entry point for a new machine: give it its own hardware
module, platform and checkout path, not this laptop's disk UUIDs. Its attribute
name becomes the exact build/update target. See [NVIDIA.md](NVIDIA.md) for
examples, staging/reboot instructions and verification. `nix develop .#cuda`
provides the matching development environment; `nix run .#cuda-check` launches
a small real kernel and checks its result (requires an accessible GPU).

### Per-project DeepSeek Harness

Copy or borrow from [`templates/agent/flake.nix`](templates/agent/flake.nix) when
writing your project flake. It is just a `devShell` with Node, Bubblewrap and
example project tools—no VM, launcher, helper input or service. The
[setup and sandbox guide](templates/agent/README.md) gives the direct upstream
**DSH `@alpha`** command (fresh alpha-channel metadata on each launch) and
migration instructions. For an opt-in `0.0.0.0` listener, use the documented
`--patch ./web-network.patch.yml` CLI argument; upstream alpha rejects the literal
`--host 0.0.0.0` flag. Normal startup remains loopback-only. `tools.nix` also
installs Bubblewrap on both hosts.

DSH already bundles the official `@deepseek-ai/dsh-sandbox-local`, policy,
sandboxed Bash and filesystem plugins. Linux prefers **bwrap**, with Landlock as
an upstream fallback; the example selects `workspace-write`. **This is write
confinement, not VM isolation:** readable host files, credentials, network and
host sockets are not hidden. Keep Permissions at `workspace-write` + approval,
review escalations, and do not run as root or start from your whole home.

### System DNS

`network.nix` enables **`systemd-resolved.service` on both hosts at boot**, with automatic restart after five seconds and no retry limit. NetworkManager supplies per-link DNS on the laptop; EC2 retains dhcpcd. NixOS connects `/etc/resolv.conf` to resolved's stub and provides the D-Bus service used by `resolvectl`. Upstream DNS still comes from DHCP/VPN configuration, not hard-coded public or private servers. An explicit `systemctl stop systemd-resolved` still stops it normally.

Use `systemctl status systemd-resolved` and `resolvectl status` to inspect it. `sudo resolvectl dns krishna-laptop 192.168.1.19` sets DNS on that existing interface at runtime; it does not persist across interface recreation or reboot. Put persistent VPN DNS and any routing domains in the VPN/NetworkManager profile.

### Wireless displays (Miracast)

`apps.nix` installs **GNOME Network Displays** from the system package pin. After
applying the configuration, launch `gnome-network-displays` or select **GNOME
Network Displays** in the application launcher. It uses the existing Hyprland
screencast portal and PipeWire; GNOME Shell/GDM are not required or enabled, and
SDDM's managed Hyprland session remains unchanged.

`workstation.nix` keeps NetworkManager on **wpa_supplicant** for Wi-Fi Direct.
The requested broad compatibility firewall policy applies on **all workstation
interfaces**, including Ethernet, Wi-Fi, VPNs and dynamically created P2P links:

- **TCP 7236/7250:** Miracast RTSP and infrastructure-mode signaling.
- **TCP/UDP 53, UDP 67/68:** NetworkManager's P2P DNS and both DHCP roles.
- **UDP 5353:** Avahi mDNS discovery.
- **UDP 1024–65535:** permissive coverage for negotiated RTP/RTCP media ports;
  this is a compatibility policy, not a range required by the Miracast standard.
- **Loose reverse-path filtering:** tolerate asymmetric Wi-Fi/VPN routing while
  retaining the firewall. Unrelated TCP ports remain blocked.

**Security tradeoff:** any other application listening on these ports is also
reachable from connected networks; the rules are not limited to the display
application or a trusted LAN. No entire interface is trusted, and no global DNS
or DHCP server is started. Avahi supplies LAN display discovery without host/service
publishing or NSS integration; `systemd-resolved` still handles system DNS. EC2
gets the shared application, but no Avahi, NetworkManager or display openings.

Wi-Fi Direct requires compatible Wi-Fi hardware/drivers and a Miracast receiver;
configuration checks do not verify a real wireless connection. Enable the
receiver's screen-mirroring mode (LG: **Screen Share**) and Wi-Fi. GNOME Network
Displays can open Hyprland's **screen-sharing picker at startup**: select the
monitor/window to share rather than dismissing the prompt, then choose the TV
and approve its connection prompt. No capture permission is granted automatically.
If needed, select the **Network-Displays** audio output in `pavucontrol`.

For troubleshooting, check `nmcli device` for a `p2p-dev-*` device. Close the app
before running `G_MESSAGES_DEBUG=all gnome-network-displays`, otherwise the command
may only activate the existing non-debug instance. A `P2P-DEVICE-FOUND` entry in
`journalctl -u wpa_supplicant` confirms radio discovery, not successful streaming;
`Screencast SelectSources() canceled` indicates a dismissed screen-sharing prompt,
not a firewall failure. Wi-Fi Direct discovery happens before IP firewall rules.
These rules cannot add missing receiver protocols, fix incompatible drivers/codecs,
or carry link-local mDNS discovery across arbitrary routers/VPNs.

Upstream references: [GNOME troubleshooting](https://gitlab.gnome.org/GNOME/gnome-network-displays/-/blob/master/README.md),
[its P2P firewall zone](https://gitlab.gnome.org/GNOME/gnome-network-displays/-/blob/master/src/nd-firewalld.c),
and [GStreamer's negotiated RTP/RTCP sockets](https://gstreamer.freedesktop.org/documentation/gst-rtsp-server/rtsp-stream.html).

### Local Tor client

On both hosts, `network.nix` installs Tor from the **system pin** and enables `tor.service` at boot. It runs as the dedicated `tor` user with the NixOS module's sandbox and private persistent state in `/var/lib/tor`. Systemd restarts an exited daemon after five seconds without a retry limit; an explicit `systemctl stop tor` still stops it normally. A running process does not guarantee network connectivity—check for `Bootstrapped 100%` in the journal.

The SOCKS listener is **`127.0.0.1:9050` only**, with destination and SOCKS-auth isolation. There is no relay/exit, onion service, control listener, transparent proxy, system DNS change or global proxy environment. Applications must opt in; installing Tor does **not** anonymize the whole machine. Prefer native SOCKS5 support with proxy-side hostname resolution (`socks5h`), for example:

```sh
systemctl status tor.service
journalctl -u tor.service -b --no-pager
curl --fail --show-error --max-time 60 --proxy socks5h://127.0.0.1:9050 \
  https://check.torproject.org/api/ip
# For compatible dynamically linked applications, explicitly wrap one command:
torsocks curl --fail --show-error --max-time 60 https://check.torproject.org/api/ip
```

`torsocks` and `proxychains4` are opt-in wrappers, not sandboxes: static binaries and applications that bypass their hooks are not reliably covered. Tor carries TCP, not arbitrary UDP/ICMP; do not assume tools such as fping, raw-packet nmap or traceroute run through it. Keep ordinary DNS lookups out of workflows that require Tor-side resolution. **Tor Browser is installed by `apps.nix`**: launch `tor-browser` or select **Tor Browser** in the application launcher after applying the configuration. It retains its separate profile and upstream privacy defaults; Firefox remains the default browser. Tor Browser is not simply a generic browser pointed at the system SOCKS port, and it is not auto-started.

## Build and apply

### One-command sync on either host

Save your work, then run the installed command from any directory:

```sh
switch-system               # explicitly apply now and make it the boot default
switch-system dry-activate  # build and preview changes without applying
switch-system boot          # stage for the next boot instead
```

`hosts.nix` supplies the correct checkout/target to the **same script** on each host. Builds run as `dev`; only activation uses sudo. It applies the exact built output, including `dev`'s Home Manager configuration, shares the automatic updater's lock, stops on build failure, keeps recovery generations and never reboots. It does **not** pull Git or update `flake.lock`: “latest” means the current checkout. Add new source files to Git for flakes to include them. Open a new terminal afterward for shell environment changes; some desktop changes require a fresh login. `--help` lists the modes, including temporary `test` activation.

Direct source-script execution **requires `NIXOS_UPDATE_HOST`**; an unset or empty value is rejected before building or using sudo. It never selects a host from your login name. Set `NIXOS_CONFIG_REPO` to the checkout you actually intend to build (the source-script default is `/etc/nix`). For an **EC2 checkout at `/etc/nix`**:

```sh
cd /etc/nix
NIXOS_CONFIG_REPO="$PWD" NIXOS_UPDATE_HOST=dev ./switch-system.sh dry-activate
# After reviewing the preview, stage without changing the running system:
NIXOS_CONFIG_REPO="$PWD" NIXOS_UPDATE_HOST=dev ./switch-system.sh boot
```

Use `switch` instead of `boot` only when you intend to apply immediately. On the **laptop**, use `NIXOS_UPDATE_HOST=nixos`. EC2's installed command and updater still use `/etc/nixos#dev`; running the source script from `/etc/nix` does not change that deployment path. Automatic updates, unlike an explicit manual switch, **always stage for the next boot on both hosts**.

If EC2 reports `efiSysMountPoint = '/boot' is not a mounted partition` after building `#nixos`, the wrong host was selected: `physical.nix` expects the laptop's EFI partition and Btrfs UUIDs, while `configuration.nix` retains EC2's GRUB and ext4 storage. Do not format or invent an EFI partition to work around it. Select `#dev` and inspect the system profile as described under Recovery; a failed bootloader installation can still leave the wrong generation selected.

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
  .#checks.x86_64-linux.switch-system --no-update-lock-file --no-link
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

`test` is a real activation, not a dry run. For a non-disruptive deployment that takes effect on next boot, use `boot` instead of `test`/`switch`. Both hosts' daily updaters use that policy.

On **EC2 only**, use `/etc/nixos` and `.#nixosConfigurations.dev.config.system.build.toplevel`. Run the same evaluation/checks and activate the exact output with its own `nixos-rebuild --no-reexec --store-path`. Never select a target merely because it matches your username.

### Recovery

Keep existing generations. Inspect what is actually selected and booted:

```sh
readlink -f /run/current-system /run/booted-system /nix/var/nix/profiles/system
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
```

If a wrong-host switch failed during bootloader installation, `/nix/var/nix/profiles/system` may point at that failed generation even though `/run/current-system` and the installed boot menu still reference the working system. To stage the **currently running** closure again without a live activation or reboot:

```sh
current=$(readlink -f /run/current-system)
sudo "$current/sw/bin/nixos-rebuild" boot --no-reexec --store-path "$current"
```

This does update the system profile and boot menu; inspect the links first and retain the known-good generations. Alternatively, build/preview and successfully stage the correct host target.

To restore the booted closure temporarily from the retained console:

```sh
previous=$(readlink -f /run/booted-system)
sudo "$previous/sw/bin/nixos-rebuild" test --no-reexec --store-path "$previous"
```

If boot fails, choose a known-good systemd-boot generation (hold Space at startup). Do not blindly select “generation 1”: generation numbers are machine/history-specific. System rollback does not restore mutable user data, Git changes, application databases or backups.

## Automatic freshness, precisely

- **Every day**, `nixos-update.timer` runs with up to one hour of jitter and catches missed runs. It advances `nixpkgs`, `home-manager`, and `nixpkgs-latest`; the Neovim source remains fixed.
- The system/desktop now follow rolling **`nixos-unstable`** (the latest tested channel) and Home Manager **`master`**, rather than a fixed release branch. Most standalone CLI tools use **Nixpkgs master** for faster updates. They are imported separately, **not** overlaid onto the desktop's GCC/Python/libraries. Flake locks record each resolved snapshot; input updates, not deleting locks, advance Nix-owned packages.
- **Same policy on both hosts:** run as `dev`, build/check/record and **stage for next boot**. There is no automatic live switch, logout or reboot. Only checkout path and explicit flake target differ: laptop `/etc/nix#nixos`, EC2 `/etc/nixos#dev`. Installed versions change when that generation is booted, or explicitly switched by the user.
- Both skip dirty/detached repositories, serialize runs with manual switching, use an isolated worktree, check for edits again after dry activation and commit only the tested lock. On staging failure, the updater restores the previously selected **boot generation**, including a generation that was already staged but not running. A failed rollback is reported as failure; recovery generations are retained.
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

**Tauon** is installed for `dev` from `nixpkgs-latest` (Nixpkgs master), with the
exact snapshot recorded in `flake.lock`. The current pin provides **12.0.0**,
matching the latest upstream stable release when added. It advances through the
existing daily input-update workflow. Launch `tauon` or choose **Tauon**
in the application launcher after applying; existing MIME defaults are unchanged.

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
