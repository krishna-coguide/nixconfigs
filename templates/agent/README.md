# Project + DeepSeek Harness microVM

`project.nix` is the shared toolchain for `nix develop` and the guest.
`flake.nix` sets RAM, vCPUs and networking. Run from the project directory:

```sh
nix run .#agent               # boots with cwd mounted read-write at its original path
# Another terminal in the same directory:
nix run .#agent -- url        # private browser login URL
nix run .#agent -- ssh        # root shell, starting in the same project cwd
nix run .#agent -- stop
```

`$DSH_HOME` (default `~/.dsh`) and `${DSH_AGENTS_HOME:-~/.agents}/skills` are
also mounted **read-write**. No other home directories or host sockets are shared.
The first run creates missing DSH/skills directories. Existing DSH home must be
private (`chmod 700 ~/.dsh`). Credentials, settings, profiles and skills are live
shared files, not copied into the Nix store. Select the project's original
absolute path in the DSH UI; `/workspace` is also an alias.

The VM stays **headless by default**. It includes `playwright-cli` and matching
Playwright-patched Firefox for browser automation. The `playwright-firefox` skill
is seeded once into your actual shared skills directory as a writable file;
existing skills/user edits are not overwritten. Ask each subagent to use its own
unique `-s=NAME` on every command, its own `.playwright-cli/NAME/` artifacts, and
close only its own session—never `close-all` or `kill-all`. No host browser
profiles or display sockets are imported.

DSH resolves `@deepseek-ai/dsh@latest` inside the VM on startup. Nix packages,
including the CLI and its matching Firefox, follow the rolling Nixpkgs input:
`nix flake update`, then restart the VM. Merge changes to an already-seeded skill
manually if you want the newer instructions; local edits are preserved.

See `/etc/nix/AGENT-VM.md` for the full guide and security boundaries. The reusable
input lives at `/etc/nix/agent-vm`; replace the local input with your Git remote
when sharing this project. Keep backups: the agent can modify/delete the mounted
project and its shared DSH configuration/credentials/skills.
