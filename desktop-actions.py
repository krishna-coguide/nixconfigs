"""Small desktop actions, not a shell framework. No selected text is executed.

Control state is session-local; explicit captures use XDG media directories.
Dependencies are supplied by desktop.nix.
"""
import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess as sp
import sys
import time
from urllib.parse import quote_plus


def run(*args, check=True, **kwargs):
    return sp.run(list(args), check=check, **kwargs)


def output(*args):
    return run(*args, capture_output=True, text=True).stdout.strip()


def notify(title, body="", value=None):
    args = ["notify-send", "-a", "Workstation"]
    if value is not None:
        # OSD replaces only OSD, never a saved screenshot or action failure.
        args += ["-h", "string:x-canonical-private-synchronous:workstation-osd",
                 "-h", "int:transient:1", "-h", f"int:value:{max(0, min(100, int(value)))}", "-t", "1500"]
    run(*args, title, body, check=False)


def pick(prompt, choices):
    """Return a validated index; Escape/custom unmatched input never acts."""
    if not choices:
        notify(prompt, "Nothing available")
        return None
    labels = [re.sub(r"[\x00-\x1f\x7f]", " ", str(x)) for x in choices]
    result = run("fuzzel", "--dmenu", "--index", "--prompt", prompt + "  ",
                 input="\n".join(labels), text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return None
    try:
        index = int(result.stdout.strip())
    except ValueError:
        return None
    return index if 0 <= index < len(choices) else None


def confirm(action):
    return pick(action + "?", ["Cancel", action]) == 1


def runtime():
    path = Path(os.environ["XDG_RUNTIME_DIR"]) / "workstation"
    path.mkdir(mode=0o700, exist_ok=True)
    return path


def clients():
    return json.loads(output("hyprctl", "-j", "clients"))


def dispatch(expression):
    response = output("hyprctl", "dispatch", expression)
    if response not in ("", "ok"):
        raise RuntimeError(response)


def lua(value):
    if isinstance(value, str):
        # Lua does not support JSON's \\uXXXX escapes. Fixed-width decimal byte
        # escapes also keep newlines, quotes and arbitrary device names inert.
        return '"' + ''.join(f'\\{byte:03d}' for byte in value.encode()) + '"'
    return json.dumps(value, allow_nan=False)


def address(value):
    if not re.fullmatch(r"0x[0-9a-fA-F]+", value):
        raise ValueError("Invalid compositor window address")
    return "address:" + value


def window_picker():
    windows = sorted(clients(), key=lambda c: (c["workspace"]["id"], c.get("focusHistoryID", 0)))
    labels = [f'{c["workspace"]["name"]}  ·  {c["class"]}  —  {c["title"]}' for c in windows]
    index = pick("Windows", labels)
    if index is not None:
        dispatch("hl.dsp.focus({window=" + lua(address(windows[index]["address"])) + "})")


def scratch():
    existing = any(c["class"] == "dropterminal" for c in clients())
    dispatch('hl.dsp.workspace.toggle_special("terminal")')
    if not existing:
        run("uwsm", "app", "--", "kitty", "--class", "dropterminal")


def clipboard(action):
    # Lock checks and database writes together: an in-flight store cannot put
    # a clipboard item back AFTER the lock-screen wipe has completed.
    if action not in {"store", "clear"}:
        _clipboard(action)
        return
    with (runtime() / "clipboard.lock").open("w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        _clipboard(action)


def _clipboard(action):
    root = runtime()
    env = dict(os.environ, CLIPHIST_DB_PATH=str(root / "clipboard.db"), CLIPHIST_MAX_ITEMS="200")
    database = root / "clipboard.db"
    if action == "store":
        if os.environ.get("CLIPBOARD_STATE") in ("sensitive", "nil", "clear"):
            return
        if (root / "clipboard-paused").exists() or (root / "locked").exists():
            return
        run("cliphist", "store", env=env)
    elif action == "clear":
        # cliphist wipe leaves its database file (and free pages) behind.
        # Stores are serialized above, so remove the session database itself.
        database.unlink(missing_ok=True)
    elif action == "pause":
        marker = root / "clipboard-paused"
        if marker.exists():
            marker.unlink()
            notify("Clipboard history resumed")
        else:
            marker.touch(mode=0o600)
            notify("Clipboard history paused")
    elif action in ("pick", "delete"):
        if not database.exists():
            notify("Clipboard history", "No items in this session")
            return
        rows = run("cliphist", "list", env=env, capture_output=True, text=True).stdout.splitlines()
        index = pick("Clipboard" if action == "pick" else "Delete clipboard item", rows)
        if index is None:
            return
        row = rows[index] + "\n"
        if action == "delete":
            run("cliphist", "delete", env=env, input=row, text=True)
        else:
            data = run("cliphist", "decode", env=env, input=row.encode(), capture_output=True).stdout
            run("wl-copy", input=data)


def lock_start():
    root = runtime()
    with (root / "locker.lock").open("w") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        (root / "locked").touch(mode=0o600)
        try:
            clipboard("clear")
        except (OSError, sp.SubprocessError) as error:
            # Clipboard trouble must NEVER prevent the screen from locking.
            print(f"Clipboard wipe failed before lock: {error}", file=sys.stderr)
        result = run("hyprlock", check=False)
        # A crash must not resume clipboard collection on a still-locked session.
        if result.returncode == 0:
            (root / "locked").unlink(missing_ok=True)
        else:
            raise RuntimeError("Locker failed; clipboard history remains paused")


def power():
    choices = ["Lock", "Suspend", "Log out", "Reboot", "Shut down"]
    index = pick("Session", choices)
    if index is None:
        return
    if index == 0:
        run("loginctl", "lock-session")
    elif confirm(choices[index]):
        if index == 2:
            run("uwsm", "stop")
        else:
            run("systemctl", {1: "suspend", 3: "reboot", 4: "poweroff"}[index])


def capture_geometry(mode):
    if mode == "area":
        result = run("slurp", capture_output=True, text=True, check=False)
        if result.returncode != 0 or not result.stdout.strip():
            return None
        return ["-g", result.stdout.strip()]
    if mode == "window":
        window = json.loads(output("hyprctl", "-j", "activewindow"))
        if not window.get("address"):
            return None
        x, y = map(int, window["at"])
        w, h = map(int, window["size"])
        if w <= 0 or h <= 0:
            return None
        return ["-g", f"{x},{y} {w}x{h}"]
    if mode == "output":
        monitors = json.loads(output("hyprctl", "-j", "monitors"))
        return ["-o", next(m["name"] for m in monitors if m["focused"])]
    if mode == "all":
        return []
    raise ValueError("Unknown capture mode")


def destination(kind, extension):
    # User's XDG directory setting, with a conventional fallback.
    key = "PICTURES" if kind == "Screenshots" else "VIDEOS"
    base = Path(output("xdg-user-dir", key))
    folder = base / kind
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S_%f")
    return folder / (stamp + extension)


def screenshot(mode="area", annotate=False, delay=0, copy_only=False):
    if delay:
        notify("Screenshot", f"Capturing in {delay} seconds")
        time.sleep(delay)
    geometry = capture_geometry(mode)
    if geometry is None:
        return
    image = run("grim", *geometry, "-", capture_output=True).stdout
    if annotate:
        target = destination("Screenshots", ".png")
        run("satty", "--filename", "-", "--copy-command", "wl-copy",
            "--output-filename", str(target), input=image)
    else:
        run("wl-copy", "--type", "image/png", input=image)
        if not copy_only:
            target = destination("Screenshots", ".png")
            target.write_bytes(image)
            notify("Screenshot saved and copied", str(target))
        else:
            notify("Screenshot copied")


def screenshot_menu():
    actions = [("Region · annotate", "area", True, 0, False),
               ("Region · copy only", "area", False, 0, True),
               ("Active window", "window", False, 0, False),
               ("Current display", "output", False, 0, False),
               ("All displays", "all", False, 0, False),
               ("Current display · 5 second delay", "output", False, 5, False),
               ("Current display · 10 second delay", "output", False, 10, False)]
    index = pick("Screenshot", [a[0] for a in actions])
    if index is not None:
        screenshot(*actions[index][1:])


def recording():
    return run("systemctl", "--user", "is-active", "--quiet", "desktop-recording.service", check=False).returncode == 0


def record():
    root = runtime()
    # Serialize two rapid keypresses so they cannot start competing recorders.
    with (root / "record.lock").open("w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        if recording():
            run("systemctl", "--user", "stop", "desktop-recording.service")
            notify("Recording saved", (root / "recording-file").read_text() if (root / "recording-file").exists() else "")
            return
        index = pick("Record", ["Region · no audio", "Display · no audio", "Display · desktop audio"])
        if index is None:
            return
        geometry = capture_geometry("area" if index == 0 else "output")
        if geometry is None:
            return
        args = list(geometry)
        if index == 2:
            # Explicit monitor source: never silently record the microphone.
            sink = output("pactl", "get-default-sink")
            args += ["--audio=" + sink + ".monitor"]
        target = destination("Recordings", ".mkv")
        run("systemd-run", "--user", "--collect", "--unit=desktop-recording",
            "--property=KillSignal=SIGINT", "--property=TimeoutStopSec=20",
            "--property=PartOf=graphical-session.target", "--property=UMask=0077",
            "--setenv=PATH=" + os.environ["PATH"], "--",
            shutil.which("desktop"), "record-run", *args, "-f", str(target))
        (root / "recording-file").write_text(str(target))
        # The REC bar indicator is the start feedback. A popup here can race
        # the recorder's inhibitor and end up embedded in the captured video.


def record_run(args):
    # A separate inhibitor does not overwrite the user's DND preference. The
    # unit sends SIGINT to both processes; let wf-recorder finish its container.
    signal.signal(signal.SIGINT, lambda *_: None)
    run("swaync-client", "-Ia", "workstation-recording", "-sw")
    try:
        run("wf-recorder", *args)
    finally:
        run("swaync-client", "-Ir", "workstation-recording", "-sw", check=False)


def osd(kind, change):
    if kind in ("volume", "microphone"):
        device = "@DEFAULT_AUDIO_SOURCE@" if kind == "microphone" else "@DEFAULT_AUDIO_SINK@"
        if change == "mute":
            run("wpctl", "set-mute", device, "toggle")
        else:
            run("wpctl", "set-volume", "-l", "1", device, "5%+" if change == "up" else "5%-")
        value = output("wpctl", "get-volume", device)
        percent = round(float(value.split()[1]) * 100)
        notify("Microphone" if kind == "microphone" else "Volume", "Muted" if "MUTED" in value else f"{percent}%", percent)
    else:
        selector = ["-c", "leds", "-d", "*kbd_backlight*"] if kind == "keyboard" else ["-c", "backlight"]
        run("brightnessctl", *selector, "--min-value=1", "set", "+5%" if change == "up" else "5%-")
        value = output("brightnessctl", *selector, "-m")
        percent = int(value.split(",")[3].rstrip("%"))
        notify("Keyboard backlight" if kind == "keyboard" else "Brightness", f"{percent}%", percent)


def night():
    current = output("hyprctl", "hyprsunset", "temperature")
    temperature = int(current)
    run("hyprctl", "hyprsunset", "identity" if temperature < 6000 else "temperature", *([] if temperature < 6000 else ["4200"]))
    notify("Night light", "Off" if temperature < 6000 else "4200 K")


def displays():
    monitors = json.loads(output("hyprctl", "-j", "monitors"))
    choices = [f'{m["name"]} · {m["width"]}×{m["height"]} · {m["scale"]:g}×' for m in monitors]
    index = pick("Display", choices)
    if index is None:
        return
    m = monitors[index]
    actions = ["Scale 100%", "Scale 125%", "Scale 150%", "Scale 175%", "Scale 200%", "Restore declared configuration"]
    action = pick(m["name"], actions)
    if action is None:
        return
    if action == 5:
        run("hyprctl", "reload")
        return
    scale = [1, 1.25, 1.5, 1.75, 2][action]
    def set_scale(value):
        # Scaling must not silently change refresh rate, dock position or rotation.
        mode = f'{m["width"]}x{m["height"]}@{m.get("refreshRate", 60)}'
        position = f'{m.get("x", 0)}x{m.get("y", 0)}'
        run("hyprctl", "eval", 'hl.monitor({output=' + lua(m["name"]) + ',mode=' + lua(mode)
            + ',position=' + lua(position) + ',transform=' + str(m.get("transform", 0))
            + ',scale=' + str(value) + '})')
    set_scale(scale)
    # An unattended or invisible confirmation must revert, not strand the user.
    try:
        result = run("fuzzel", "--dmenu", "--index", "--prompt", "Keep display scale?  ",
                     input="Revert\nKeep\n", text=True, capture_output=True, check=False, timeout=15)
        keep = result.returncode == 0 and result.stdout.strip() == "1"
    except sp.TimeoutExpired:
        keep = False
    if not keep:
        set_scale(m["scale"])


def web_search():
    result = run("fuzzel", "--dmenu", "--prompt", "Search web  ", input="", text=True, capture_output=True, check=False)
    if result.returncode == 0 and result.stdout.strip():
        run("uwsm", "app", "--", "xdg-open", "https://duckduckgo.com/?q=" + quote_plus(result.stdout.strip()))


def emoji():
    entries = []
    for line in Path(os.environ["DESKTOP_EMOJI_FILE"]).read_text().splitlines():
        if "; fully-qualified" not in line:
            continue
        code, detail = line.split("#", 1)
        character = "".join(chr(int(c, 16)) for c in code.split(";", 1)[0].split())
        description = re.sub(r"^\S+\s+E[\d.]+\s+", "", detail.strip())
        entries.append((character, character + "  " + description))
    index = pick("Emoji", [entry[1] for entry in entries])
    if index is not None:
        run("wl-copy", input=entries[index][0].encode())
        notify("Emoji copied")


def touchpad():
    devices = json.loads(output("hyprctl", "-j", "devices"))
    pads = [device["name"] for device in devices["mice"] if re.search("touchpad|trackpad", device["name"], re.I)]
    if not pads:
        notify("Touchpad", "No touchpad detected")
        return
    marker = runtime() / "touchpad-disabled"
    enabled = marker.exists()
    for name in pads:
        run("hyprctl", "eval", "hl.device({name=" + lua(name) + ",enabled=" + lua(enabled) + "})")
    if enabled:
        marker.unlink()
    else:
        marker.touch(mode=0o600)
    notify("Touchpad", "Enabled" if enabled else "Disabled")


def airplane():
    disabled = output("nmcli", "radio", "wifi") == "disabled"
    if not disabled and not confirm("Disable wireless radios"):
        return
    run("nmcli", "radio", "wifi", "on" if disabled else "off")
    run("rfkill", "unblock" if disabled else "block", "bluetooth")
    notify("Airplane mode", "Off" if disabled else "On")


def battery():
    last = None
    while True:
        for path in Path("/sys/class/power_supply").glob("*"):
            if (path / "type").read_text().strip() != "Battery" or not (path / "capacity").exists():
                continue
            capacity = int((path / "capacity").read_text())
            discharging = (path / "status").read_text().strip() == "Discharging"
            level = "critical" if capacity <= 10 else "low" if capacity <= 20 else None
            if discharging and level and level != last:
                run("notify-send", "-u", "critical", "Battery " + level, f"{capacity}% remaining — connect power")
            last = level if discharging else None
        time.sleep(60)


def health():
    print("WORKSTATION HEALTH\n")
    for label, path in [("Running", "/run/current-system"), ("Booted", "/run/booted-system"),
                        ("Selected for boot", "/nix/var/nix/profiles/system")]:
        print(f"{label}: {Path(path).resolve()}")
    if Path("/run/booted-system").resolve() != Path("/nix/var/nix/profiles/system").resolve():
        print("\nA different generation is selected for the next boot. No automatic reboot.")
    run("systemctl", "show", "nixos-update.service", "-p", "ActiveState", "-p", "Result", "-p", "ExecMainStatus")
    run("systemctl", "list-timers", "nixos-update.timer", "--no-pager")
    run("systemctl", "--failed", "--no-pager")
    run("systemctl", "--user", "--failed", "--no-pager")
    print("\nRecent update journal (not a package-availability count):", flush=True)
    run("journalctl", "-u", "nixos-update.service", "-n", "30", "--no-pager", check=False)


def status():
    while True:
        active = recording()
        print(json.dumps({"text": "REC" if active else "", "alt": "recording" if active else "idle"}), flush=True)
        time.sleep(2)


def menu():
    entries = [
        ("Applications / calculator", ["anyrun"]),
        ("Help · all shortcuts", ["desktop-help"]),
        ("Windows · overview", ["desktop", "windows"]),
        ("Notifications", ["desktop", "notifications"]),
        ("Do not disturb · toggle", ["desktop", "dnd"]),
        ("Clipboard history", ["desktop", "clipboard"]),
        ("Clipboard · delete an item", ["desktop", "clipboard-delete"]),
        ("Clipboard · clear", ["desktop", "clipboard-clear"]),
        ("Clipboard · pause/resume", ["desktop", "clipboard-pause"]),
        ("Screenshot", ["desktop", "screenshot-menu"]),
        ("Recording · start/stop", ["desktop", "record"]),
        ("Color picker · copy HEX", ["hyprpicker", "--autocopy"]),
        ("Emoji · copy", ["desktop", "emoji"]),
        ("Search web", ["desktop", "search"]),
        ("Audio · outputs and per-app volume", ["pavucontrol"]),
        ("Microphone · input devices", ["pavucontrol", "-t", "4"]),
        ("Network / VPN connections", ["nm-connection-editor"]),
        ("Bluetooth devices", ["blueman-manager"]),
        ("Airplane mode · toggle", ["desktop", "airplane"]),
        ("Touchpad · toggle", ["desktop", "touchpad"]),
        ("Night light · toggle", ["desktop", "night"]),
        ("Display scale · temporary", ["desktop", "displays"]),
        ("Power profile", ["desktop", "power-profile"]),
        ("File manager", ["thunar"]),
        ("System monitor", ["kitty", "-e", "btop"]),
        ("System / update health", ["kitty", "--hold", "-e", "desktop", "health"]),
        ("Session / power", ["desktop", "power"]),
    ]
    index = pick("Workstation", [entry[0] for entry in entries])
    if index is not None:
        run("uwsm", "app", "--", *entries[index][1])


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "menu"
    if command in {"clipboard", "clipboard-store", "clipboard-clear", "clipboard-delete", "clipboard-pause"}:
        clipboard({"clipboard": "pick"}.get(command, command.removeprefix("clipboard-")))
    elif command == "screenshot":
        screenshot(sys.argv[2] if len(sys.argv) > 2 else "area", annotate="--annotate" in sys.argv,
                   delay=10 if "--delay10" in sys.argv else 5 if "--delay5" in sys.argv else 0)
    elif command == "record-run":
        record_run(sys.argv[2:])
    elif command == "health":
        health()
    elif command == "osd":
        osd(*sys.argv[2:4])
    elif command == "notifications":
        run("swaync-client", "-t", "-sw")
    elif command == "dnd":
        run("swaync-client", "-d", "-sw")
    elif command == "power-profile":
        profiles = output("powerprofilesctl", "list").splitlines()
        names = [p.strip().strip("* ").rstrip(":") for p in profiles if p.rstrip().endswith(":") and p.strip().strip("* ").rstrip(":") in ("balanced", "power-saver", "performance")]
        index = pick("Power profile", names)
        if index is not None:
            run("powerprofilesctl", "set", names[index])
    elif command in {"menu", "windows", "scratch", "power", "screenshot-menu", "record", "night", "displays", "search", "lock-start", "battery", "status", "emoji", "touchpad", "airplane"}:
        {"menu": menu, "windows": window_picker, "scratch": scratch, "power": power,
         "screenshot-menu": screenshot_menu, "record": record, "night": night,
         "displays": displays, "search": web_search, "lock-start": lock_start,
         "battery": battery, "status": status, "emoji": emoji,
         "touchpad": touchpad, "airplane": airplane}[command]()
    else:
        raise ValueError("Unknown desktop action: " + command)


if __name__ == "__main__":
    try:
        os.umask(0o077)
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sp.SubprocessError) as error:
        print(f"desktop: {error}", file=sys.stderr)
        if len(sys.argv) < 2 or sys.argv[1] not in ("clipboard-store", "status"):
            notify("Desktop action failed", str(error))
        sys.exit(1)
