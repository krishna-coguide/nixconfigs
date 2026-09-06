"""Test manual switching for both hosts without Nix builds or host activation."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(sys.argv[1]).resolve()
if os.geteuid() == 0:
    raise SystemExit("Run this check as an unprivileged user (or through nix flake check).")

mock = r'''import fcntl, json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CALLS"], "a") as f:
    f.write(json.dumps([name, *args]) + "\n")
if name in ("nix", "sudo"):
    # Model sudo's descriptor cleanup: the parent shell must retain the lock.
    try: os.close(9)
    except OSError: pass
    with open(pathlib.Path(os.environ["CACHE_DIRECTORY"]) / "lock", "a") as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: pass
        else: raise AssertionError("Updater lock was released before activation completed")
if name == "nix":
    assert pathlib.Path.cwd() == pathlib.Path(os.environ["NIXOS_CONFIG_REPO"])
    assert args == ["build", f'.#nixosConfigurations.{os.environ["NIXOS_UPDATE_HOST"]}.config.system.build.toplevel', "--no-update-lock-file", "--no-link", "--print-out-paths"]
    if os.environ["SCENARIO"] == "build-failure": sys.exit(42)
    print(os.environ["BUILT"])
elif name == "sudo":
    # No sudo -v: its verifypw=all policy can demand a password even when
    # the actual command is NOPASSWD (the user also has a wheel rule).
    assert args[0] == os.environ["BUILT"] + "/sw/bin/nixos-rebuild"
    assert args[2:] == ["--no-reexec", "--store-path", os.environ["BUILT"]]
    if os.environ["SCENARIO"] == "sudo-failure": sys.exit(43)
    if os.environ["SCENARIO"] == "activation-failure": sys.exit(44)
else:
    raise AssertionError(name)
'''

with tempfile.TemporaryDirectory(prefix="switch-test-") as directory:
    root = Path(directory)
    repo = root / "repo with spaces"
    binaries = root / "bin"
    calls = root / "calls"
    repo.mkdir()
    binaries.mkdir()
    for name in ["nix", "sudo"]:
        executable = binaries / name
        executable.write_text("#!" + sys.executable + "\n" + mock)
        executable.chmod(0o755)
    env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ["PATH"],
               NIXOS_CONFIG_REPO=str(repo), CACHE_DIRECTORY=str(root / "cache"),
               CALLS=str(calls), BUILT=str(root / "built system"))
    cases = [([], "switch", "success", 0), (["dry-activate"], "dry-activate", "success", 0),
             (["boot"], "boot", "success", 0), (["test"], "test", "success", 0),
             (["--help"], None, "help", 0), (["invalid"], None, "invalid", 2),
             (["switch", "extra"], None, "invalid", 2),
             ([], None, "build-failure", 42), ([], "switch", "sudo-failure", 43),
             ([], "switch", "activation-failure", 44), ([], None, "invalid-host", 2)]
    for host in ["nixos", "dev"]:
        for args, action, scenario, expected_code in cases:
            calls.unlink(missing_ok=True)
            result = subprocess.run(
                ["bash", str(script), *args], cwd=root,
                env=env | {"NIXOS_UPDATE_HOST": "unknown" if scenario == "invalid-host" else host,
                           "SCENARIO": scenario}, text=True, capture_output=True,
            )
            assert result.returncode == expected_code, (host, scenario, result.stdout, result.stderr)
            log = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
            if action:
                assert [call[0] for call in log] == ["nix", "sudo"], log
                assert log[-1][2] == action, log
            elif scenario == "build-failure":
                assert [call[0] for call in log] == ["nix"], log
            else:
                assert not log, log
            print("PASS", host, args or ["default"], scenario)
