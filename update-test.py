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
        assert args[2:] == ["nixpkgs", "home-manager"]
        if scenario != "unchanged":
            pathlib.Path("flake.lock").write_text('{"revision":2}\n')
    elif args[:2] == ["flake", "check"]:
        if scenario == "evaluation-failure": sys.exit(42)
    elif args[0] == "build":
        if scenario == "build-failure": sys.exit(43)
        if scenario == "concurrent-edit":
            (pathlib.Path(os.environ["NIXOS_CONFIG_REPO"]) / "notes").write_text("user work\n")
        print(os.environ["BUILT"])
    else:
        raise AssertionError(args)
elif name == "sudo":
    assert "--no-reexec" in args and "--store-path" in args
    if scenario == "dry-activation-failure" and args[1] == "dry-activate": sys.exit(44)
    if scenario == "activation-failure" and args[1] == "switch" and args[-1] == os.environ["BUILT"]:
        sys.exit(45)
elif name == "readlink":
    assert args == ["-f", "/run/current-system"]
    print(os.environ["PREVIOUS"])
else:
    raise AssertionError(name)
'''


def run_case(scenario):
    with tempfile.TemporaryDirectory(prefix="update-test-") as directory:
        root = Path(directory)
        repo = root / "repo with spaces"
        cache = root / "cache"
        mocks = root / "bin"
        repo.mkdir()
        mocks.mkdir()
        calls_path = root / "calls.jsonl"
        env = dict(os.environ, HOME=str(root / "home"), CACHE_DIRECTORY=str(cache),
                   NIXOS_CONFIG_REPO=str(repo), SCENARIO=scenario,
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
        result = subprocess.run(
            [shutil.which("bash"), "-euo", "pipefail", str(script)],
            env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        calls = [json.loads(line) for line in calls_path.read_text().splitlines()] if calls_path.exists() else []
        sudo = [call for call in calls if call[0] == "sudo"]
        failed = scenario.endswith("failure")
        assert (result.returncode != 0) == failed, (scenario, result.stdout)
        if scenario == "success":
            assert json.loads((repo / "flake.lock").read_text())["revision"] == 2
            assert git("log", "-1", "--format=%an <%ae>") == "NixOS Updater <nixos-updater@localhost>"
            assert [call[2] for call in sudo] == ["dry-activate", "switch"]
            assert git("status", "--porcelain") == ""
        elif scenario == "activation-failure":
            assert json.loads((repo / "flake.lock").read_text())["revision"] == 1
            assert [call[2] for call in sudo] == ["dry-activate", "switch", "switch"]
            assert sudo[-1][-1] != env["BUILT"]
            assert git("log", "-1", "--format=%s").startswith("Revert")
        else:
            assert git("rev-parse", "HEAD") == baseline, (scenario, result.stdout)
            assert json.loads((repo / "flake.lock").read_text())["revision"] == 1
            assert not sudo or scenario == "dry-activation-failure"
        assert (repo / "unchanged-editor-input").read_text().strip() == "380eb86778a7c53a0f1c18e84f14037456155347"
        assert len(git("worktree", "list", "--porcelain").split("worktree ")) == 2
        if scenario in ["dirty", "concurrent-edit"]:
            assert (repo / "notes").read_text() == "user work\n"
        if scenario == "dirty":
            assert not calls
        print("PASS", scenario)


for scenario in ["dirty", "unchanged", "evaluation-failure", "build-failure", "concurrent-edit",
                 "dry-activation-failure", "activation-failure", "success"]:
    run_case(scenario)
