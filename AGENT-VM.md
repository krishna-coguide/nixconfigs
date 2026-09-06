# DeepSeek Harness project VMs

Official **`deepseek-ai/deepseek-harness` (`dsh`)**, not OpenCode. A reusable NixOS
module + flake function + shell launcher. No custom Python control plane, host
service, sudo launcher, or host rebuild is needed.

## Start a project

As your normal user, on **x86_64 Linux** with accessible `/dev/kvm` and enabled
unprivileged user namespaces (for Bubblewrap):

```sh
mkdir -p ~/projects/example && cd ~/projects/example
nix flake init -t path:/etc/nix#agent
# Edit project.nix (tools/env) and flake.nix (RAM/CPU/network).
git init
git add flake.nix project.nix README.md .gitignore
nix flake lock
git add flake.lock
nix develop                   # ordinary host project shell
nix run .#agent               # boots VM; waits and prints a private browser URL
```

Run commands **from the project directory**, including in the second terminal:

```sh
nix run .#agent -- url         # print the current token-bearing browser login URL
nix run .#agent -- ssh         # root shell, starting in the SAME project cwd
nix run .#agent -- ssh 'id; pwd; rg --version'
nix run .#agent -- ssh 'journalctl -u agent -b --no-pager'
nix run .#agent -- stop        # graceful poweroff; Ctrl-C in the launcher also stops it
```

Open the printed URL. In a fresh DSH profile, **Choose workspace → add/select the
project's original absolute path**, which exists in the guest. Then
**Settings → Models** to configure DeepSeek, if you haven't already. Existing
credentials/settings are reused. No API key is required merely to boot the UI.
No model inference runs locally: the VM's RAM/CPUs are for tools/builds, not model weights.
The VM is **headless by default**: use DSH's Web UI from your host browser; no
VM desktop or display forwarding is started. Browser automation uses headless
Firefox inside the VM, as described below.

The template input `path:/etc/nix/agent-vm` is a local bootstrap. For collaboration
or guest-side evaluation of the flake, replace it with your accessible Git remote,
e.g. `git+https://git.cyber.ayyalasomayajula.net/marsultor/nixconfig.git?dir=agent-vm&ref=main`
**after these files have actually been committed and published there**. No push is
performed by this setup. Input changes require `nix flake update agent-vm`.

## Exactly what is shared

All of these mounts are **read-write**, as requested:

| Host source, resolved when you launch | Guest path | Includes |
| --- | --- | --- |
| Current working directory, not the flake's store copy | Same absolute cwd; `/workspace` is also an alias | Live source, uncommitted work, `.git`, project `.dsh/skills` and `.agents/skills` |
| `$DSH_HOME`, otherwise `~/.dsh` | `/root/.dsh` | `.credentials.yaml`, `settings.yaml`, `.env`, profiles, plugins, skills, sessions and other DSH state |
| `${DSH_AGENTS_HOME:-~/.agents}/skills` | `/root/.agents/skills` | Shared cross-agent skills only, not the rest of `~/.agents` |

**Upstream's standard directory is `~/.dsh`, not `~/.config/dsh`.** If you have
chosen an XDG-style location, use the upstream override, consistently for all commands:

```sh
export DSH_HOME="$HOME/.config/dsh"
nix run .#agent
```

Missing directories are created. Existing DSH home must be user-owned and private:
`chmod 700 ~/.dsh` (or your actual `DSH_HOME`); existing credentials must be mode
600 as DSH requires. The launcher never reads the credentials into Nix, copies
them to the store, or replaces your settings/skills with generated content.
The one bundled `playwright-firefox` skill is seeded into the actual shared skills
directory only if its `SKILL.md` is absent. It is a normal writable file (0600),
not a store symlink; existing files and user edits are never overwritten.

Root inside the guest is **not host root**. QEMU/9p writes as the launching host
user, so newly created project files belong to you. The whole DSH directory is
mounted instead of individual credential files so atomic rename-based saves work.
DSH retains each project's real cwd identity rather than confusing every project's
sessions with a single `/workspace` identity. Do not run host DSH and several
VMs concurrently against the same mutable profile: package-fallback links and
profile changes can race. Separate `DSH_HOME` values provide independent profiles.

The runner retains a private per-cwd directory under
`${XDG_STATE_HOME:-~/.local/state}/agent-vm/`: dedicated SSH keys, console log,
control socket, and a 4 GiB sparse npm-cache disk. Guest root, guest Nix writes,
processes and other unshared state are otherwise ephemeral. This is **not** a
push/pull/snapshot workflow; edits immediately affect the mounted host files.

## Resources and Nix composition

The template uses one ordinary Nix attrset:

```nix
project = import ./project.nix { inherit pkgs; };
devShells.${system}.default = pkgs.mkShell {
  inherit (project) packages env;
};
agent = agent-vm.lib.mkAgentVM {
  inherit system project;
  modules = [ {
    microvm.mem = 8192; # MiB
    microvm.vcpu = 6;
    agentVM.packages = [ pkgs.strace ]; # additional guest-only tool
  } ];
};
```

The function imports the microvm.nix and agent NixOS modules and merges your
modules with them. Normal `imports`, `mkDefault`, `mkForce`, and list merging work.
`apps.${system}.agent = agent.app` exposes `nix run .#agent`; `agent.nixos` exposes
the NixOS configuration for inspection. RAM/CPU/network changes apply on **stop
and restart**, not live. vCPUs are not a host CPU-time quota, and QEMU has some
memory overhead beyond guest RAM.

The standard guest toolkit includes Git/LFS, ripgrep, fd, Python, Node/npm/pnpm,
jq/yq, curl/wget, common archive tools, Make, pkg-config, ShellCheck, and ordinary
Unix inspection tools, plus the official **Playwright CLI and patched Firefox**.
Project versions/tools belong in `project.nix`.

This deliberately shares **packages and non-secret environment variables**, not
an arbitrary shell's internals. Existing `shellHook`, `inputsFrom`, cross-compilation
setup hooks, library search paths and background dev services are not magically
converted into NixOS configuration. Factor tools/env into the shared attrset;
configure required guest services through `modules`. Do not put credentials in
`project.env`. Build outputs/package definitions can use the same `pkgs` input.

## Firefox automation and subagent sessions

DSH discovers the bundled [playwright-firefox skill](agent-vm/skills/playwright-firefox/SKILL.md)
from `/root/.agents/skills/playwright-firefox/SKILL.md`, which is the live host
`${DSH_AGENTS_HOME:-~/.agents}/skills/playwright-firefox/SKILL.md`. No changes to
`settings.yaml`, credentials, plugins or external MCP configuration are needed.
Ask DSH/subagents to use **playwright-firefox** for browser tasks.

The `playwright-cli` executable uses the official CLI shipped in Playwright core
(`playwright-core cli`), with its matching Nixpkgs Firefox and rendering fonts.
It defaults to **Firefox, headless, nonpersistent profiles**. This avoids an
independently updated npm CLI demanding a different browser revision, or trying
to automate ordinary Firefox without Playwright's Juggler support. CLI, patched
browser and dependencies advance together with the consuming flake's Nixpkgs
input; no handwritten Playwright version/hash or runtime browser download.

Each subagent must use its own unique name and artifact directory. For example,
inside the guest, from the same project cwd throughout:

```sh
# Parent-assigned examples: give each task a different suffix.
PLAYWRIGHT_MCP_OUTPUT_DIR="$PWD/.playwright-cli/login-a1b2c3d4" \
  playwright-cli -s=login-a1b2c3d4 open http://127.0.0.1:3000 --browser=firefox
PLAYWRIGHT_MCP_OUTPUT_DIR="$PWD/.playwright-cli/search-e5f6a7b8" \
  playwright-cli -s=search-e5f6a7b8 open http://127.0.0.1:3000 --browser=firefox
playwright-cli -s=login-a1b2c3d4 snapshot
playwright-cli -s=search-e5f6a7b8 eval 'document.title'
playwright-cli list
playwright-cli -s=login-a1b2c3d4 close   # leaves the other subagent alone
playwright-cli -s=search-e5f6a7b8 close
```

Cookies, DOM, tabs and storage are independent between named sessions. This is
**not a security boundary** between root-running subagents. The skill requires
explicit `-s=` on every browser command, unique per-task output paths, modest
parallelism (normally two browsers with 4 GiB RAM), and scoped cleanup. It forbids
`close-all`, `kill-all`, global process killing and accidental use of the default
session. Profiles are ephemeral unless persistence is explicitly requested;
screenshots/traces/auth-state exports can contain secrets. New templates ignore
`.playwright-cli/`; add that ignore rule to existing projects too.

The application server must run **inside the VM** for guest `127.0.0.1` URLs.
Headed operation is opt-in (`open --headed`) and needs a separately configured
guest display; the default VM provides none and never mounts your host desktop.
Do not import your normal browser profile or install another browser/CLI with npm.

After updating the helper input, stop/restart the project VM to get the new tools
and initial skill. Existing skill edits deliberately survive restarts and updates;
merge later changes from the repository's skill file yourself rather than silently
replacing local instructions. This does not restart an already-running VM.

## Networking: bind address versus VM interface

DSH intentionally rejects `dsh web --host 0.0.0.0`. We don't patch around its
browser protections: it listens on **guest `127.0.0.1:3080`**, and the shell launcher
publishes an **SSH local forward** on your chosen **host** IPv4 address. By default
it tries **3080 through 3100, in ascending order**, and keeps the first port SSH
successfully binds. There is no separate free-port probe that could race another
process. The printed login URL and `nix run .#agent -- url` use the chosen port,
recorded in the project's private runtime state. Each new launch starts at 3080
again; shutdown clears the selection. If the range is full, launch fails clearly
and cleans up its VM/tunnel instead of leaving an inaccessible instance running.
DSH's random launch-token → signed-cookie authentication and Host/Origin checks
remain in use. Only SSH is forwarded by QEMU, always on host loopback.

```nix
agentVM.network = {
  hostAddress = "127.0.0.1"; # default: this computer only
  sshPort = 2222;
  webPort = 3080;     # First candidate.
  webPortEnd = 3100;  # Last candidate, inclusive.
};
```

Set both values to the same port for a fixed listener. For compatibility, setting
only a nondefault `webPort` still means that single fixed port; give `webPortEnd`
explicitly to select a different range. Keep the SSH port outside the Web range.

- **One LAN/VPN interface:** set `hostAddress = "192.168.1.20"` (an IP actually
  assigned to this host). Its exact authorities across the configured port range
  are automatically trusted.
- **All IPv4 interfaces:** set `hostAddress = "0.0.0.0"` and
  `trustedHosts = [ "192.168.1.20" "laptop.example" ];`. Port-less entries accept
  that exact host on any port; an explicit `host:port` accepts only that port.
  Use a real address, not `0.0.0.0`, in your browser. The printed local URL can
  have its host replaced with one of those authorities. This includes public
  interfaces too; it is not shorthand for “LAN only.”
- Multiple project VMs still need distinct **SSH** ports. Web ports are selected
  automatically from the range; SSH port selection is unchanged.
- Binding a host IP controls the **incoming listener**, not outgoing routing or
  which NIC reaches DeepSeek. Outgoing traffic follows host routes/VPN policy.
- No host firewall is changed. For LAN access, explicitly allow the selected Web
  port (or intended Web range) on the intended host interface. Do not open the SSH
  forward. Use a fixed port if a reverse proxy needs a stable upstream.

**Use a VPN or a TLS reverse proxy for off-host access.** The forward is encrypted
between host and guest, but browser → host remains HTTP. A token/cookie on an
untrusted network can be stolen. Static assets and third-party plugin routes
may not share DSH's RPC authentication. Never expose this developer-preview
service directly to the public Internet.

### Optional dedicated TAP interface

Default user networking needs no administrator setup. If you need your own guest
IP/interface rather than NAT, add:

```nix
agentVM.network = {
  mode = "tap";
  tapName = "agent0";
  mac = "02:00:00:00:00:10";
  guestAddress = "192.168.77.2";
  prefixLength = 24;
  gateway = "192.168.77.1";
  dns = [ "YOUR_REACHABLE_DNS_IP" ];
  hostAddress = "127.0.0.1"; # Web publication is still independently configurable.
};
```

An administrator must first provision `agent0`, owned by the launching user,
with `multi_queue` when using multiple vCPUs, and arrange the host's address,
routing/NAT/DNS/firewall. For example, the interface creation portion is
`sudo ip tuntap add agent0 mode tap user "$USER" multi_queue`. That command alone
**does not** establish routing. See microvm.nix's linked routed-network docs for
persistent NixOS setup. Do not substitute a physical Wi-Fi/Ethernet interface for
`tapName`, or run QEMU as root. TAP joins a less isolated network; the host's
loopback publication default does not hide guest SSH from other routed peers.

## What “latest” means

- **Nix:** moving `nixos-unstable` (latest tested rolling channel), microvm.nix's
  default branch, and `inputs.*.follows` to keep the project's package set coherent.
  `nix flake update` refreshes the resolved snapshots; restart to use them.
  `flake.lock` is retained because that is how flakes work, not a manually selected
  old package version. The helper's own lock and each consuming project's lock
  are independent.
- **DSH:** `npm exec --yes --package=@deepseek-ai/dsh@latest -- dsh ...` runs
  **inside the VM**. Each launch resolves the current npm `latest` dist-tag,
  using a persistent download cache. Network/registry availability is required;
  failed installs are visible in `journalctl -u agent`. There is no fixed DSH
  version, handwritten dependency hash, host `npm -g`, or claim of reproducibility
  for this mutable part. `latest` can itself be a release candidate. A two-line
  Node shim supplies `--expose-internals`, required by the current Cordis HMR
  dependency but missing from the published CLI's shebang.
- **Plugins:** explicitly opt in, then update with DSH/pnpm. No unreviewed community
  plugins are automatically installed or upgraded by this repository.
- **Workstation:** the root `/etc/nix` flake now also follows `nixos-unstable` and
  Home Manager `master`; CLI tools still use Nixpkgs `master`. Its existing daily
  updater refreshes those inputs and stages the tested result for next boot.
  `stateVersion = "26.05"` remains a compatibility setting, **not a package pin**.
  The existing separate Neovim-dotfile revision and manually packaged Element
  binary are unchanged; their documented update boundaries still apply.

## Plugins worth considering

DSH is still a developer preview. Popularity is not a security audit or a promise
of compatibility with tomorrow's `latest`. These are actual DSH plugins, not
OpenCode plugins relabeled as DeepSeek plugins. GitHub stars checked 2026-09-06:

| Plugin | Why consider it | Approx. repository stars |
| --- | --- | --- |
| [DSH better sidebar](https://github.com/omdsh-dev/DSH-better-sidebar) | File explorer/editor, Git and terminal alongside the conversation | 3.4k |
| [dsh-market](https://github.com/dsh-market/dsh-market) | Discover/manage plugins in the DSH settings UI | 3.3k |
| [dsh-agent-teams](https://github.com/NanmiCoder/dsh-agent-teams) | Multi-agent delegation; add only when you need it, as it can multiply API cost | 1.4k |
| [dsh-context](https://github.com/bowenliang123/dsh-context) | Inspect context/token use and manage context | 1.3k |

Start with **dsh-context**, then optionally the sidebar. A marketplace and a
multi-agent orchestrator are not necessary to make the core harness useful.
Review their source first; native-addon build prerequisites vary. Example:

```sh
nix run .#agent -- ssh
# Now INSIDE the VM, with your real DSH home mounted RW:
dsh plugin --profile web add dsh-context@latest
# Optional, separately reviewed:
dsh plugin --profile web add dshmarket@latest
systemctl restart agent
exit
nix run .#agent -- url         # restart creates a fresh browser launch token
```

Use `dsh plugin --profile web update --latest` when you explicitly want to update
installed plugins. Review pnpm's build-script approval requests rather than
blanket-approving everything. The built-in MCP bridge can also connect to popular
projects such as [Context7](https://github.com/upstash/context7) and
[Playwright MCP](https://github.com/microsoft/playwright-mcp); those are separate
MCP services, not evidence that a particular DSH adapter is widely deployed.
The bundled Firefox **CLI + skill** above does not need Playwright MCP; use the
separate server only if you explicitly need that interface. No host browser
sessions, external MCP credentials or arbitrary host skill symlink targets are imported.

## Sandbox boundary and limitations

- Trust the project's flake and launcher before `nix run`: an arbitrary flake app
  is host code and can choose not to launch this sandbox at all.
- Separate KVM guest kernel; agent is root only there. Rootless QEMU is additionally
  confined by Bubblewrap: restricted filesystem, private process/IPC/UTS/user
  namespaces, dropped capabilities, no inherited host environment.
- No host home mount, Nix daemon/socket, SSH-agent forwarding, Docker socket,
  desktop session sockets, or full host Nix-store share **inside the guest**.
  QEMU itself needs read-only access to `/nix/store` to run its host binaries.
- Writable **cwd + DSH home + shared skills are intentional holes in the boundary**.
  A bad agent/plugin can delete those files, steal tokens, corrupt Git metadata,
  and plant malicious skills/plugins for future host runs. Back them up and use
  scoped/revocable API keys. Never execute the shared plugin state on the host
  without trusting changes made in the VM.
- Symlinks outside the shares do not grant those extra host directories. This
  also means external Git-worktree metadata, symlinked skills, local path flake
  inputs and host-built `node_modules` may not work. Use self-contained checkouts
  and Linux-compatible dependencies, not wider home mounts to make errors vanish.
- Outgoing networking is **not filtered**: API access, exfiltration, host/LAN
  services and cloud metadata can be reachable. This is filesystem/process
  isolation, not an egress-security appliance. Use a separate filtered network
  or machine for hostile code and don't give it real shared credentials.
- 9p favors a small rootless setup over maximum filesystem throughput. Remote
  host edits may require a DSH refresh/restart for watchers to notice them.
- Latest code, kernels, QEMU and mounts can contain vulnerabilities. This is
  defense in depth, not a claim of an audited or escape-proof sandbox.

## Checks and sources

```sh
nix flake check path:/etc/nix/agent-vm --no-build
nix build path:/etc/nix/agent-vm#checks.x86_64-linux.config \
  path:/etc/nix/agent-vm#checks.x86_64-linux.shell \
  path:/etc/nix/agent-vm#checks.x86_64-linux.playwright --no-link
# Actual offline microVM boot/mount/SSH/browser test, with a fake harness (no API calls):
nix build path:/etc/nix/agent-vm#checks.x86_64-linux.boot --no-link
# Real port contention, range exhaustion and remembered-URL checks:
nix build path:/etc/nix/agent-vm#checks.x86_64-linux.ports --no-link
```

The boot and port tests require KVM and nested user namespaces in the Nix build sandbox.
The Playwright check launches two real Firefox instances concurrently against a
local HTTP fixture, checks headless/default browser selection, separate cookies,
DOM and localStorage, screenshots, close-one/keep-one behavior and profile expiry.
The boot check runs it inside the guest too, and checks writable skill seeding,
host ownership and preservation of a user edit across a harness restart. No live
websites, real credentials or model calls are used.
A real `dsh@latest` Web startup additionally requires network access and is not
silently replaced by the fake harness in normal usage.

Validated here: template/host/helper flake evaluation, ShellCheck, the real
microVM offline boot/mount/ownership/isolation test, and a separate live official
DSH Web launch with disposable config. The live check returned **401** without
a cookie, **200** after the token exchange, and **403** for an untrusted Host;
DSH stayed running without restarts. No real API credentials, model requests,
community plugins, TAP network provisioning, or host activation were involved.
The Firefox two-session regression also passed natively and in the real headless
microVM, including screenshot generation and writable, non-clobbering skill seeding.

Research used the **new official wiki**, plus upstream sources:

- [NixOS wiki: Flakes](https://wiki.nixos.org/wiki/Flakes) — lockfiles, pure inputs,
  dev shells, apps, and Git-tracked source.
- [NixOS wiki: Virtualization](https://wiki.nixos.org/wiki/Virtualization) — points
  to [microvm.nix](https://microvm-nix.github.io/microvm.nix/declaring.html).
- [microvm interfaces](https://microvm-nix.github.io/microvm.nix/interfaces.html),
  [shares](https://microvm-nix.github.io/microvm.nix/shares.html), and
  [routed networking](https://microvm-nix.github.io/microvm.nix/routed-network.html).
- [DSH CLI reference](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md),
  [Web guide](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/index.md),
  [skill paths](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/skill/skill-filesystem/README.md),
  [browser auth](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/connection/README.md),
  [safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md).
- [Official Playwright CLI](https://github.com/microsoft/playwright-cli), its
  [session-management reference](https://github.com/microsoft/playwright-cli/blob/main/skills/playwright-cli/references/session-management.md),
  and the CLI/core implementation shipped in the locked Nixpkgs Playwright package.
- [Awesome DSH plugins](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin)
  plus the individual repositories above; no third-party plugin was installed.
