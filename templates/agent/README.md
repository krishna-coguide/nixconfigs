# DeepSeek Harness: plain project flake example

[`flake.nix`](flake.nix) is just an example `devShell` to copy or borrow from when
writing your project flake. Replace the sample project tools with your own. No
launcher scripts, apps, helper inputs, VM, SSH keys, disk images or services.
`nix develop` supplies tools; **it does not itself sandbox anything**.

## Run upstream DSH directly

On Linux, as your normal user, from the project you want DSH to edit:

1. Copy `flake.nix` into a project **without an existing flake**, or merge its
   packages and environment into your existing `devShell`. On ARM change
   `system` to `aarch64-linux`. Optionally, `nix flake init -t path:/etc/nix#agent`
   copies this same example into a new project.
2. In a Git project, add `flake.nix` before evaluating it. Run `nix flake lock`
   and commit the project's `flake.lock`; then enter `nix develop`.
3. Run the command below. It follows the **latest release on the alpha channel**;
   `--prefer-online` revalidates npm's cached metadata. npm installs into its
   user cache, not globally and not into the Nix store.

```sh
npm exec --yes --prefer-online --package=@deepseek-ai/dsh@alpha --call \
  'node --expose-internals "$(command -v dsh)" web --no-open --host 127.0.0.1 --port 3080'
```

`--expose-internals` is passed to Node itself (the NixOS-compatible invocation),
not placed in `NODE_OPTIONS`. Open the private login URL DSH prints. Stop with
Ctrl-C. Use another port, or `--port 0` for an OS-selected port, if 3080 is busy.
On a remote host, forward that port with your existing SSH connection, e.g.
`ssh -N -L 3080:127.0.0.1:3080 dev@HOST`; no guest SSH server is involved.
No firewall port is opened and no browser is launched automatically.

DSH uses your usual `${DSH_HOME:-~/.dsh}` and
`${DSH_AGENTS_HOME:-~/.agents}/skills` directly. Keep credentials outside the
project and out of Nix, with a private DSH home (700) and credential files (600).
There are no guest copies or shared mounts. Avoid concurrent servers writing
one profile. The Web UI's session workspace determines the writable root;
start from the intended project, **not `/`, your whole home or a credentials
directory**. Choose **workspace-write** in Permissions and keep approval enabled.
The example sets the deployment default, but existing settings, profile patches
and resumed sessions can override it. Do not assume an old full-access session
becomes confined just because you entered this shell.

For tools that need writable caches, use a location inside the project, e.g.
`UV_CACHE_DIR="$PWD/.cache/uv" uv sync` or
`npm --cache "$PWD/.cache/npm" install` in the agent's command. Ignore `.cache/`
in Git. Do not grant the entire home write access just to fix a cache error.
Bwrap's `/tmp` is temporary; keep artifacts needed across calls in the workspace.

## Opt in to a `0.0.0.0` listener from the CLI

The current alpha **rejects the literal `--host 0.0.0.0` flag**, even though its
HTTP server supports that address in configuration. Without patching DSH or
adding a wrapper, use its native **`--patch` CLI argument** instead. Copy the
optional [`web-network.patch.yml`](web-network.patch.yml) beside your project
flake, then run:

```sh
npm exec --yes --prefer-online --package=@deepseek-ai/dsh@alpha --call \
  'node --expose-internals "$(command -v dsh)" web --patch ./web-network.patch.yml --no-open --port 3080 --trusted-host dsh.example.test:3080'
```

Replace `dsh.example.test:3080` with the actual DNS name or IP and port you use
in the browser; do not use `0.0.0.0`, a URL or a wildcard as a trusted host.
Repeat `--trusted-host` for additional names. DSH also automatically trusts the
server's detected LAN IPv4 addresses on this bind. `--port 0` still selects a
free port; in that case a port-less trusted host allows the selected port.

This binds **all IPv4 interfaces for this invocation only**. Without `--patch`,
the normal command stays on loopback. `--host 127.0.0.1` can also override the
patch back to loopback. Keep `--patch` before the Web app flags. Use the printed
LAN login URL, or replace the loopback host in the login URL with your trusted
server address while retaining its token and actual port.

**Deliberate network exposure:** API authentication and Host/Origin checks stay
enabled, but not every static or plugin route is authenticated, and DSH serves
plain HTTP, not TLS. A trusted host is a browser authority check, **not a client
IP allowlist**. Restrict access with a private VPN, firewall/security group or
an appropriately secured HTTPS reverse proxy; do not expose this directly to
the public Internet. No firewall/security-group rules are changed here. On an
untrusted network, prefer the loopback command with SSH forwarding instead.

## Which plugin, and what it actually guarantees

Research checked npm **2026-09-12**, the **`alpha` channel** (then
**0.1.5-alpha.2**), and upstream source
[`c291e796`](https://github.com/deepseek-ai/deepseek-harness/tree/c291e7961a515f6d7af9304e7fd1d257929aef26).
The tags are independent: `latest` was **0.1.5-rc.1**, and `next` was
**0.1.5-rc.2**, newer than alpha by publication time. This example deliberately
follows **`@alpha`**, not `@latest`, `@next` or a fixed version. Inspect the
current tags with `npm view @deepseek-ai/dsh dist-tags --json`.

The official packages are scoped **`@deepseek-ai/…`**. The unrelated unscoped
`dsh-sandbox@0.0.1` is only a reserved-name placeholder; do **not** install it.

The shipped `web`/base profile already wires these together; no `dsh plugin add`
is needed and duplicate providers can break profile loading:

| Component | Role |
| --- | --- |
| `@deepseek-ai/dsh-sandbox` | Process confinement contract, not a backend on its own |
| `@deepseek-ai/dsh-sandbox-local` | Probes Linux **bwrap first**, then the npm-supplied Landlock runner |
| `@deepseek-ai/dsh-sandbox-policy` | Shared per-session mode and workspace boundary |
| `@deepseek-ai/dsh-bash-sandbox` | Applies confinement to shell commands and descendants |
| `@deepseek-ai/dsh-fs-sandbox` | In-process write/edit fence for filesystem tools; not a kernel sandbox |
| Permission/approval plugins | Workspace-write default, human-approved wider calls and explicit full-access mode |

With bwrap, DSH uses a **read-only host root**, fresh `/dev`, private PID
namespace and `/proc`. `workspace-write` adds a writable bind of the session
workspace and an ephemeral `/tmp`. `read-only` denies ordinary file writes;
`danger-full-access` **bypasses the sandbox entirely**. Wider calls can be
requested with a justification and approved by you—review them, rather than
approving blindly.

If no backend works, confined calls fail with `SANDBOX_UNAVAILABLE`, not an
unconfined fallback. Landlock is still confinement, but its process/temp
behavior differs and older kernel ABIs can provide only partial enforcement.
Keep the provider's automatic functional probes; setting `runnerCommand`
skips them and asserts that your custom runner enforces the policy.

**This replaces the microVM with a weaker, host-local boundary:**

- Host files readable by your user—including credentials—remain readable.
  Read-only mounts do not protect secrets from being copied or sent out.
- Network access, localhost services and accessible host sockets are not
  blocked. A read-only bind does not make a daemon socket harmless.
- DSH itself, plugins and other host-side integrations run with your user's
  authority. This is not a sandbox around the whole harness or arbitrary MCP,
  browser or external-agent plugins. Only sandbox-consuming capabilities are
  covered. Do not run DSH with sudo, especially on this sudo-capable account.
- The workspace is live and writable, including its Git metadata. The agent
  can delete it. Keep backups. Shared skills outside it are normally readable
  but not writable by confined tools, unlike the old VM's RW skills mount.
- Filesystem tools use an in-process path fence and may write to host temp
  roots; they do not run inside bwrap's private `/tmp`. This is not a uniform
  isolated filesystem across all capabilities.
- Nix builds, daemons and package managers that need host-side writes may need
  deliberate approval or to be run by you outside DSH. The devShell does not
  provide a private writable Nix store.

## Inspect and troubleshoot

Inside `nix develop`, this tests whether DSH's bwrap read-only profile can start
on your host as your normal user:

```sh
bwrap --ro-bind / / --dev /dev --unshare-pid --proc /proc --die-with-parent -- true
```

No KVM, nested virtualization or root is required; Linux must allow the user
namespaces bwrap needs. A failed probe may lead DSH to Landlock. Fix the host
restriction if you require bwrap; do not "fix" it by selecting full access.

To inspect the real composed Web profile without starting the server, replace
the final invocation in the npm command with:

```sh
node --expose-internals "$(command -v dsh)" web --dump-config
```

Look for the scoped sandbox, sandbox-policy, bash-sandbox and fs-sandbox rows,
without disabling overrides or a custom runner. This initializes missing
profile files, but does not boot the app; expressions remain unevaluated in the
dump. Check effective Permissions in the UI as well. Plugin selection is cached
until reload/restart, so restart DSH after repairing bwrap.

## Migration and updates

Stop any old project microVM manually, preserve any data you still need from
its state image, and replace its VM definitions with the devShell example.
Remove the project's `microvm`/`agent-vm` input and obsolete VM outputs, then
regenerate its lock. Existing workspaces and host DSH credentials/skills do not
need moving. Nothing here deletes VM images, keys, profiles or credentials.
`nix build .#agent` and `nix run .#agent -- url/ssh/stop` are no longer provided.

`nix flake update` updates Nix tools, including bwrap. DSH is fetched at runtime:
**each launch checks the rolling `@alpha` tag**. Neither that release nor its npm
dependency ranges are locked by `flake.lock`; new versions need registry access
and a running server does not upgrade until restarted. Recheck sandbox behavior
after updates. Additional plugins and browser tooling remain opt-in; no
third-party plugin is installed.

Upstream references used for the migration:

- [Base profile wiring](https://github.com/deepseek-ai/deepseek-harness/blob/c291e7961a515f6d7af9304e7fd1d257929aef26/packages/bundle/base/cordis.patch.yml)
- [Local provider and selection](https://github.com/deepseek-ai/deepseek-harness/blob/c291e7961a515f6d7af9304e7fd1d257929aef26/packages/sandbox/sandbox-local/README.md)
- [Exact bwrap/Landlock profiles](https://github.com/deepseek-ai/deepseek-harness/blob/c291e7961a515f6d7af9304e7fd1d257929aef26/packages/sandbox/sandbox-local/src/profiles.ts)
- [Per-session policy](https://github.com/deepseek-ai/deepseek-harness/blob/c291e7961a515f6d7af9304e7fd1d257929aef26/packages/sandbox/sandbox-policy/README.md)
- [Filesystem fence and its limits](https://github.com/deepseek-ai/deepseek-harness/blob/c291e7961a515f6d7af9304e7fd1d257929aef26/packages/fs/fs-sandbox/README.md)
- [CLI/profile behavior](https://github.com/deepseek-ai/deepseek-harness/blob/c291e7961a515f6d7af9304e7fd1d257929aef26/apps/cli/reference/README.md)
