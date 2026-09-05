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
    user("systemd-run --quiet --user --collect --unit=audit-" + name + " " + command)


machine.start()
machine.wait_for_unit("home-manager-dev.service", timeout=360)
try:
    machine.wait_until_succeeds(
        "runuser -u dev -- env XDG_RUNTIME_DIR=/run/user/1001 "
        "systemctl --user is-active graphical-session.target", timeout=180
    )
    # Mako is D-Bus activated on the first notification, not eagerly started.
    for unit in ["ashell", "awww", "hypridle", "hyprpolkitagent", "pipewire", "wireplumber"]:
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
assert "test-speakers" in session("wpctl status --name")
machine.succeed("systemctl is-active systemd-resolved")

launch("terminal", "kitty --title 'Workspace ready' sh -c " + shlex.quote(
    "printf '\\n  WORKSPACE READY\\n\\n'; "
    "zsh --version; kitty --version; git --version; printf 'Pi: '; command -v pi; "
    "printf '\\n  Ctrl-R history  |  Ctrl-T files  |  Alt-C directories\\n'; "
    "printf '  Super-Space launcher  |  Super-Enter terminal\\n\\n'; exec zsh -i"
))
launch("monitor", "kitty --title 'System monitor' -e btop")
machine.wait_until_succeeds("pgrep -u dev btop")
machine.sleep(5)
screenshot("desktop-100")

launch("launcher", "anyrun")
wait_layer("anyrun")
machine.sleep(2)
machine.send_chars("kitty")
machine.sleep(2)
screenshot("launcher-100")
machine.send_key("esc")
session("notify-send 'Desktop ready' 'Readable text, working audio and native Wayland services.'")
assert '"mako"' in user("busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications GetServerInformation")
machine.sleep(1)
screenshot("notification-100")

monitors = json.loads(session("hyprctl -j monitors"))
output = monitors[0]["name"]
session("hyprctl eval " + shlex.quote(
    'hl.monitor({output=' + json.dumps(output) + ',mode="1920x1080@60",position="0x0",scale=1.5})'
))
machine.sleep(4)
assert json.loads(session("hyprctl -j monitors"))[0]["scale"] == 1.5
screenshot("desktop-150")

# Exercise real PAM/session locking using the disposable fixture password.
session("loginctl lock-session")
machine.wait_until_succeeds("pgrep -u dev hyprlock")
machine.sleep(2)
screenshot("lock-150")
machine.send_chars("incorrect")
machine.send_key("ret")
machine.sleep(3)
machine.succeed("pgrep -u dev hyprlock")
machine.send_chars("desktop-test")
machine.send_key("ret")
machine.wait_until_fails("pgrep -u dev hyprlock", timeout=30)

# Restore scale before inspecting settings and ordinary application windows.
session("hyprctl eval " + shlex.quote(
    'hl.monitor({output=' + json.dumps(output) + ',mode="1920x1080@60",position="0x0",scale=1})'
))
launch("audio", "pavucontrol")
machine.sleep(3)
screenshot("audio-controls")

# Preferences must not be a read-only Home Manager symlink.
user("test -w ~/.config/keepassxc/keepassxc.ini && test ! -L ~/.config/keepassxc/keepassxc.ini")
user("grep -q 'UpdateBinaryPath=false' ~/.config/keepassxc/keepassxc.ini")
assert "libapplications.so" in user("cat ~/.config/anyrun/config.ron")
session("hyprctl clients")
machine.succeed("journalctl -b -p err --no-pager > /tmp/desktop-errors.log")
machine.copy_from_vm("/tmp/desktop-errors.log")
