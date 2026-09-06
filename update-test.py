"""Test the real updater with real Git and mocked Nix/sudo; no host activation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

script = Path(sys.argv[1]).resolve()
python = sys.executable
mock = r'''import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
scenario = os.environ["SCENARIO"]
with open(os.environ["CALLS"], "a") as f:
    f.write(json.dumps([name, *args]) + "\n")
if name == "nix":
    if args[:2] == ["flake", "update"]:
        assert args[2:] == ["nixpkgs", "home-manager", "nixpkgs-latest"]
        if scenario != "unchanged":
            pathlib.Path("flake.lock").write_text('{"revision":2}\n')
    elif args[:2] == ["flake", "check"]:
        if scenario == "evaluation-failure": sys.exit(42)
    elif args[0] == "build":
        targets = [arg for arg in args if "nixosConfigurations." in arg]
        if targets:
            assert targets == [f'.#nixosConfigurations.{os.environ["NIXOS_UPDATE_HOST"]}.config.system.build.toplevel']
        if scenario == "build-failure": sys.exit(43)
        if scenario == "concurrent-edit":
            (pathlib.Path(os.environ["NIXOS_CONFIG_REPO"]) / "notes").write_text("user work\n")
        print(os.environ["BUILT"])
    else:
        raise AssertionError(args)
elif name == "sudo":
    assert "--no-reexec" in args and "--store-path" in args
    if scenario == "dry-activation-failure" and args[1] == "dry-activate": sys.exit(44)
    if scenario == "concurrent-dry-edit" and args[1] == "dry-activate":
        (pathlib.Path(os.environ["NIXOS_CONFIG_REPO"]) / "notes").write_text("user work\n")
    if scenario in ("activation-failure", "rollback-failure") and args[1] == os.environ["NIXOS_UPDATE_MODE"]:
        if args[-1] == os.environ["BUILT"] or scenario == "rollback-failure": sys.exit(45)
elif name == "readlink":
    previous = "/nix/var/nix/profiles/system" if os.environ["NIXOS_UPDATE_MODE"] == "boot" else "/run/current-system"
    assert args == ["-f", previous]
    print(os.environ["PREVIOUS"])
else:
    raise AssertionError(name)
'''


def run_case(scenario, host="dev", mode="switch"):
    with tempfile.TemporaryDirectory(prefix="update-test-") as directory:
        root = Path(directory)
        repo = root / "repo with spaces"
        cache = root / "cache"
        mocks = root / "bin"
        repo.mkdir()
        mocks.mkdir()
        calls_path = root / "calls.jsonl"
        env = dict(os.environ, HOME=str(root / "home"), CACHE_DIRECTORY=str(cache),
                   NIXOS_CONFIG_REPO=str(repo), NIXOS_UPDATE_HOST=host,
                   NIXOS_UPDATE_MODE=mode, SCENARIO=scenario,
                   CALLS=str(calls_path), BUILT=str(root / "candidate-system"),
                   PREVIOUS=str(root / "previous-system"),
                   GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null")
        Path(env["HOME"]).mkdir()
        for name in ["nix", "sudo", "readlink"]:
            executable = mocks / name
            executable.write_text("#!" + python + "\n" + mock)
            executable.chmod(0o755)
        env["PATH"] = str(mocks) + os.pathsep + os.environ["PATH"]

        def git(*args):
            return subprocess.check_output(
                ["git", "-C", str(repo), "-c", "user.name=Update Test",
                 "-c", "user.email=update-test@localhost", *args], env=env, text=True
            ).strip()

        git("init", "--quiet", "--initial-branch=main")
        (repo / "flake.lock").write_text('{"revision":1}\n')
        (repo / "unchanged-editor-input").write_text("380eb86778a7c53a0f1c18e84f14037456155347\n")
        git("add", ".")
        git("commit", "--quiet", "-m", "fixture")
        baseline = git("rev-parse", "HEAD")
        if scenario == "dirty":
            (repo / "notes").write_text("user work\n")
        if scenario == "detached":
            git("checkout", "--detach", "--quiet")
        result = subprocess.run(
            [shutil.which("bash"), "-euo", "pipefail", str(script)],
            env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        calls = [json.loads(line) for line in calls_path.read_text().splitlines()] if calls_path.exists() else []
        sudo = [call for call in calls if call[0] == "sudo"]
        failed = scenario.endswith("failure") or scenario == "invalid-host"
        assert (result.returncode != 0) == failed, (scenario, result.stdout)
        if scenario == "success":
            assert json.loads((repo / "flake.lock").read_text())["revision"] == 2
            assert git("log", "-1", "--format=%an <%ae>") == "NixOS Updater <nixos-updater@localhost>"
            assert [call[2] for call in sudo] == ["dry-activate", mode]
            assert (cache / "last-success").is_file()
            assert git("status", "--porcelain") == ""
        elif scenario == "activation-failure":
            assert json.loads((repo / "flake.lock").read_text())["revision"] == 1
            assert [call[2] for call in sudo] == ["dry-activate", mode, mode]
            assert sudo[-1][-1] != env["BUILT"]
            assert git("log", "-1", "--format=%s").startswith("Revert")
        elif scenario == "rollback-failure":
            # Keep the candidate commit for recovery, never claim rollback worked.
            assert json.loads((repo / "flake.lock").read_text())["revision"] == 2
            assert [call[2] for call in sudo] == ["dry-activate", mode, mode]
            assert not (cache / "last-success").exists()
        else:
            assert git("rev-parse", "HEAD") == baseline, (scenario, result.stdout)
            assert json.loads((repo / "flake.lock").read_text())["revision"] == 1
            assert not sudo or scenario in ("dry-activation-failure", "concurrent-dry-edit")
        assert (repo / "unchanged-editor-input").read_text().strip() == "380eb86778a7c53a0f1c18e84f14037456155347"
        assert len(git("worktree", "list", "--porcelain").split("worktree ")) == 2
        if scenario in ["dirty", "concurrent-edit", "concurrent-dry-edit"]:
            assert (repo / "notes").read_text() == "user work\n"
        if scenario in ("dirty", "detached", "invalid-host"):
            assert not calls
        print("PASS", host, mode, scenario)


for host, mode in [("dev", "switch"), ("nixos", "boot")]:
    for scenario in ["dirty", "detached", "unchanged", "evaluation-failure", "build-failure",
                     "concurrent-edit", "concurrent-dry-edit", "dry-activation-failure",
                     "activation-failure", "rollback-failure", "success"]:
        run_case(scenario, host, mode)
run_case("invalid-host", "nixos", "switch")
