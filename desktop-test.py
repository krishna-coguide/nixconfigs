import json
import shlex


def as_user(command):
    return "runuser --login dev --command " + shlex.quote(
        "export XDG_RUNTIME_DIR=/run/user/1001 "
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus; " + command
    )


def user(command):
    return machine.succeed(as_user(command), timeout=90)


def in_session(command):
    return as_user("systemd-run --quiet --user --wait --pipe --collect sh -c " + shlex.quote(command))


def session(command):
    return machine.succeed(in_session(command), timeout=90)


def wait_layer(namespace):
    machine.wait_until_succeeds(in_session(
        "hyprctl -j layers | jq -e " + shlex.quote('.. | objects | select(.namespace? == ' + json.dumps(namespace) + ')')
    ), timeout=180)


def screenshot(name):
    # Capture through Wayland; QEMU's framebuffer dump cannot read VirGL surfaces.
    path = "/tmp/" + name + ".png"
    session("grim " + shlex.quote(path))
    machine.copy_from_vm(path)


def launch(name, command):
    # Match UWSM's application lifetime: clipboard owners can outlive main PID.
    user("systemd-run --quiet --user --collect --property=ExitType=cgroup --unit=audit-" + name + " " + command)


machine.start()
machine.wait_for_unit("home-manager-dev.service", timeout=360)
try:
    machine.wait_until_succeeds(
        "runuser -u dev -- env XDG_RUNTIME_DIR=/run/user/1001 "
        "systemctl --user is-active graphical-session.target", timeout=180
    )
    for unit in ["ashell", "awww", "hypridle", "hyprpolkitagent", "pipewire", "wireplumber", "swaync", "hyprsunset", "desktop-clipboard", "anyrun"]:
        machine.wait_until_succeeds(
            "runuser -u dev -- env XDG_RUNTIME_DIR=/run/user/1001 "
            "systemctl --user is-active " + unit + ".service", timeout=60
        )
except Exception:
    print(machine.succeed("journalctl -b --no-pager _UID=1001"))
    print(machine.execute("find /home/dev/.cache/hyprland -maxdepth 2 -type f -exec tail -n 100 {} ';'"))
    machine.screenshot("startup-failed")
    raise

wait_layer("ashell-main-layer")
screenshot("startup")
assert session("hyprctl configerrors").strip() in ("", "ok")
assert "JetBrainsMono" in user("fc-match 'JetBrainsMono Nerd Font'")
assert "Inter" in user("fc-match Inter")
# Pi's real --version is checked natively; avoid costly Node startup under TCG.
user("test -x /run/current-system/sw/bin/pi")
assert "zsh" in user("getent passwd dev")
# QEMU emulates HDA with a silent host backend; exercise real ALSA/PipeWire nodes.
machine.wait_until_succeeds(in_session("wpctl inspect @DEFAULT_AUDIO_SINK@ | grep -q alsa_output"), timeout=90)
session("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.42")
assert "0.42" in session("wpctl get-volume @DEFAULT_AUDIO_SINK@")
session("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1")
assert "MUTED" in session("wpctl get-volume @DEFAULT_AUDIO_SOURCE@")
session("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0")
machine.succeed("systemctl is-active systemd-resolved")

launch("terminal", "kitty --title 'Workspace ready' sh -c " + shlex.quote(
    "printf '\\n  WORKSPACE READY\\n\\n'; "
    "zsh --version; kitty --version; git --version; printf 'Pi: '; command -v pi; "
    "printf '\\n  Ctrl-R history  |  Ctrl-T files\\n'; "
    "printf '  Alt-C directories  |  Super-D launcher\\n'; "
    "printf '  Super-Enter terminal  |  Super-F fullscreen\\n\\n'; exec zsh -i"
))
launch("monitor", "kitty --title 'System monitor' -e btop")
machine.wait_until_succeeds("pgrep -u dev btop")
machine.sleep(5)
screenshot("desktop-100")

launch("launcher", "anyrun")
wait_layer("anyrun")
machine.sleep(2)
screenshot("launcher-empty-100")
machine.send_chars("kitty", delay=0.1)
machine.sleep(5)
screenshot("launcher-100")
machine.send_key("esc")

# Exercise clipboard through the actual picker, not only mocked byte handling.
session("desktop clipboard-clear")
launch("clipboard-source", "sh -c " + shlex.quote("printf 'clipboard audit marker' | wl-copy --foreground"))
machine.wait_until_succeeds(as_user("test -s /run/user/1001/workstation/clipboard.db"), timeout=30)
launch("clipboard", "desktop clipboard")
wait_layer("launcher")
machine.send_key("ret")
machine.sleep(1)
assert session("wl-paste --no-newline") == "clipboard audit marker"

# Record only this disposable desktop; no host screen/audio is captured.
launch("record", "desktop record")
wait_layer("launcher")
machine.send_key("down")  # current output, no audio
machine.send_key("ret")
machine.wait_until_succeeds(as_user("systemctl --user is-active desktop-recording.service"))
machine.sleep(3)
assert session("swaync-client -I -sw").strip() == "true"
screenshot("recording-indicator-100")
session("desktop record")
assert session("swaync-client -I -sw").strip() == "false"
video = session('cat "$XDG_RUNTIME_DIR/workstation/recording-file"').strip()
probe = json.loads(session("ffprobe -v error -show_streams -of json " + shlex.quote(video)))
assert any(stream["codec_type"] == "video" for stream in probe["streams"])
assert not any(stream["codec_type"] == "audio" for stream in probe["streams"])

session("notify-send 'Desktop ready' 'Readable text, working audio and native Wayland services.'")
assert "sway" in user("busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications GetServerInformation").lower()
assert "Clipboard" in session("desktop-help --print")
session("swaync-client -t -sw")
machine.sleep(1)
screenshot("notification-center-100")
session("swaync-client -t -sw")
machine.sleep(1)
screenshot("notification-100")

monitors = json.loads(session("hyprctl -j monitors"))
output = monitors[0]["name"]
session("hyprctl eval " + shlex.quote(
    'hl.monitor({output=' + json.dumps(output) + ',mode="1920x1080@60",position="0x0",scale=1.5})'
))
machine.sleep(4)
assert json.loads(session("hyprctl -j monitors"))[0]["scale"] == 1.5
launch("launcher150", "anyrun")
wait_layer("anyrun")
machine.sleep(2)
screenshot("launcher-empty-150")
# closeOnClick uses a transparent full-screen catcher; its IPC dimensions are
# not the visible palette's bounds. Audit the rendered six-result screenshot.
machine.send_chars("e")
machine.sleep(1)
screenshot("launcher-results-150")
session("anyrun close")
launch("help150", "desktop-help")
wait_layer("launcher")
machine.sleep(1)
screenshot("help-150")
machine.send_key("esc")
launch("actions150", "desktop menu")
wait_layer("launcher")
machine.sleep(1)
screenshot("actions-150")
machine.send_key("esc")
# At 150%, a half-screen btop is below its 80-column minimum: use Super-F.
# Closing the launcher can restore focus to either terminal; select btop explicitly.
monitor = next(c for c in json.loads(session("hyprctl -j clients")) if c["initialTitle"] == "System monitor")
session("hyprctl dispatch " + shlex.quote('hl.dsp.focus({window="address:' + monitor["address"] + '"})'))
assert json.loads(session("hyprctl -j activewindow"))["address"] == monitor["address"]
machine.send_key("meta_l-f")
machine.sleep(3)
screenshot("desktop-150")
machine.send_key("meta_l-f")

# Exercise real PAM/session locking using the disposable fixture password.
session("loginctl lock-session")
machine.wait_until_succeeds("pgrep -u dev hyprlock")
machine.sleep(8)
screenshot("lock-150")
machine.send_chars("incorrect")
machine.send_key("ret")
machine.sleep(3)
machine.succeed("pgrep -u dev hyprlock")
machine.send_chars("desktop-test")
machine.send_key("ret")
machine.wait_until_fails("pgrep -u dev hyprlock", timeout=30)
assert user('test ! -e /run/user/1001/workstation/locked; test ! -e /run/user/1001/workstation/clipboard.db') == ""

# Restore scale before inspecting settings and ordinary application windows.
session("hyprctl eval " + shlex.quote(
    'hl.monitor({output=' + json.dumps(output) + ',mode="1920x1080@60",position="0x0",scale=1})'
))
launch("audio", "pavucontrol")
machine.wait_until_succeeds(in_session(
    "hyprctl -j clients | jq -e '.[] | select(.class | ascii_downcase | contains(\"pavucontrol\"))'"
), timeout=180)
machine.sleep(5)
screenshot("audio-controls")

# Preferences must not be a read-only Home Manager symlink.
user("test -w ~/.config/keepassxc/keepassxc.ini && test ! -L ~/.config/keepassxc/keepassxc.ini")
user("grep -q 'UpdateBinaryPath=false' ~/.config/keepassxc/keepassxc.ini")
user("grep -q -- '--password-store=gnome-libsecret' \"$(command -v element-desktop-nightly)\"")
user("test -f /etc/profiles/per-user/dev/share/applications/element-desktop-nightly.desktop")
user("test ! -e /etc/profiles/per-user/dev/share/applications/element-desktop.desktop")
user("grep -Eq 'fade_on_empty *= *false' ~/.config/hypr/hyprlock.conf")
assert "libapplications.so" in user("cat ~/.config/anyrun/config.ron")
session("hyprctl clients")
machine.succeed("journalctl -b -p err --no-pager > /tmp/desktop-errors.log")
machine.copy_from_vm("/tmp/desktop-errors.log")
