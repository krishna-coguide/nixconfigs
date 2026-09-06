"""Read-only shortcut search from Hyprland's running binding registry.

Descriptions come from native Lua bindings, not a second hand-maintained cheat
sheet. Choosing a row does NOT execute its command (in particular power/close).
"""
import json
import subprocess
import sys


def rows(bindings):
    modifiers = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]
    result = []
    for binding in bindings:
        description = binding.get("description", "")
        if not description:
            continue
        keys = [name for bit, name in modifiers if binding.get("modmask", 0) & bit]
        keys.append(binding.get("key") or f"code:{binding.get('keycode', 0)}")
        submap = binding.get("submap")
        context = f" [{submap}]" if submap else ""
        result.append(f"{description}{context}    {' + '.join(keys)}")
    return sorted(set(result), key=str.casefold)


def main():
    try:
        data = json.loads(subprocess.check_output(["hyprctl", "-j", "binds"], text=True))
        entries = rows(data)
        if "--print" in sys.argv:
            print("\n".join(entries))
            return
        if not entries:
            raise ValueError("No described shortcuts; reload the managed Hyprland configuration.")
        result = subprocess.run(
            ["fuzzel", "--dmenu", "--prompt", "Shortcuts  ", "--width", "68", "--lines", "12"],
            input="\n".join(entries), text=True, stdout=subprocess.DEVNULL,
        )
        if result.returncode not in (0, 1):
            raise RuntimeError(f"Shortcut picker exited with {result.returncode}")
    except (OSError, ValueError, subprocess.CalledProcessError, RuntimeError) as error:
        print(f"desktop-help: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
