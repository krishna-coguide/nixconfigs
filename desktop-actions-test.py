"""Offline safety/behavior tests for desktop actions: no host desktop or power calls."""
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("actions", sys.argv.pop(1))
actions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(actions)


class ActionsTest(unittest.TestCase):
    def test_picker_cancel_and_untrusted_output(self):
        for code, text in [(1, "0"), (0, "$(touch /oops)"), (0, "-1"), (0, "9")]:
            with patch.object(actions, "run", return_value=subprocess.CompletedProcess([], code, text)):
                self.assertIsNone(actions.pick("Test", ["only item"]))

    def test_picker_uses_index_and_sanitizes_labels(self):
        with patch.object(actions, "run", return_value=subprocess.CompletedProcess([], 0, "0\n")) as run:
            self.assertEqual(actions.pick("Test", ["title\nsecond\x00row"]), 0)
            self.assertEqual(run.call_args.kwargs["input"], "title second row")
            self.assertIn("--index", run.call_args.args)

    def test_address_validation(self):
        self.assertEqual(actions.address("0xabc123"), "address:0xabc123")
        for value in ["", "0xABC; os.execute('bad')", "123", '"}']:
            with self.assertRaises(ValueError):
                actions.address(value)

    def test_no_power_action_on_cancel(self):
        with patch.object(actions, "pick", return_value=None), patch.object(actions, "run") as run:
            actions.power()
            run.assert_not_called()
        with patch.object(actions, "pick", return_value=4), patch.object(actions, "confirm", return_value=False), patch.object(actions, "run") as run:
            actions.power()
            run.assert_not_called()

    def test_screenshot_cancellation(self):
        with patch.object(actions, "capture_geometry", return_value=None), patch.object(actions, "run") as run:
            actions.screenshot()
            run.assert_not_called()

    def test_sensitive_and_locked_clipboard_not_stored(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {"XDG_RUNTIME_DIR": directory, "CLIPBOARD_STATE": "sensitive"}), patch.object(actions, "run") as run:
                actions.clipboard("store")
                run.assert_not_called()
            with patch.dict(os.environ, {"XDG_RUNTIME_DIR": directory, "CLIPBOARD_STATE": "data"}), patch.object(actions, "run") as run:
                (actions.runtime() / "locked").touch()
                actions.clipboard("store")
                run.assert_not_called()

    def test_clear_removes_database_not_just_entries(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_RUNTIME_DIR": directory}):
            database = actions.runtime() / "clipboard.db"
            database.write_bytes(b"old history pages")
            actions.clipboard("clear")
            self.assertFalse(database.exists())

    def test_clipboard_roundtrip_preserves_bytes(self):
        data = b" leading\ntrailing \x00\xff"
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_RUNTIME_DIR": directory}):
            (actions.runtime() / "clipboard.db").touch()
            calls = []
            def fake(*args, **kwargs):
                calls.append((args, kwargs))
                value = "4\tpreview\n" if args == ("cliphist", "list") else data
                return subprocess.CompletedProcess(args, 0, value)
            with patch.object(actions, "run", side_effect=fake), patch.object(actions, "pick", return_value=0):
                actions.clipboard("pick")
            self.assertEqual(calls[-1][0], ("wl-copy",))
            self.assertEqual(calls[-1][1]["input"], data)

    def test_web_search_is_url_encoded_not_shell(self):
        result = subprocess.CompletedProcess([], 0, "hello; $(bad) & stuff")
        with patch.object(actions, "run", return_value=result) as run:
            actions.web_search()
            self.assertEqual(run.call_args.args[:4], ("uwsm", "app", "--", "xdg-open"))
            self.assertIn("hello%3B+%24%28bad%29+%26+stuff", run.call_args.args[4])

    def test_lua_strings_do_not_use_json_control_escapes(self):
        self.assertEqual(actions.lua('a"\n\x00'), '"\\097\\034\\010\\000"')

    def test_lock_still_runs_when_clipboard_wipe_fails(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_RUNTIME_DIR": directory}):
            with patch.object(actions, "clipboard", side_effect=subprocess.CalledProcessError(1, "cliphist")), patch.object(actions, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
                actions.lock_start()
                run.assert_called_once_with("hyprlock", check=False)
                self.assertFalse((actions.runtime() / "locked").exists())

    def test_record_inhibitor_is_removed_on_failure(self):
        calls = []
        def fake(*args, **kwargs):
            calls.append(args)
            if args[0] == "wf-recorder":
                raise subprocess.CalledProcessError(1, args)
            return subprocess.CompletedProcess(args, 0)
        with patch.object(actions.signal, "signal"), patch.object(actions, "run", side_effect=fake):
            with self.assertRaises(subprocess.CalledProcessError):
                actions.record_run(["-f", "test.mkv"])
        self.assertEqual(calls[-1], ("swaync-client", "-Ir", "workstation-recording", "-sw"))

    def test_only_osd_notifications_are_transient(self):
        with patch.object(actions, "run") as run:
            actions.notify("Saved", "Screenshot")
            self.assertNotIn("int:transient:1", run.call_args.args)
            actions.notify("Volume", "50%", 50)
            self.assertIn("int:transient:1", run.call_args.args)

    def test_display_timeout_restores_scale(self):
        monitor = '[{"name":"eDP-1","width":1920,"height":1200,"scale":1.5}]'
        calls = []
        def fake(*args, **kwargs):
            calls.append(args)
            if args[0] == "fuzzel":
                raise subprocess.TimeoutExpired(args, 15)
            return subprocess.CompletedProcess(args, 0, "ok")
        with patch.object(actions, "output", return_value=monitor), patch.object(actions, "pick", side_effect=[0, 0]), patch.object(actions, "run", side_effect=fake):
            actions.displays()
        self.assertIn("scale=1}", calls[0][-1])
        self.assertIn("scale=1.5}", calls[-1][-1])


unittest.main()
