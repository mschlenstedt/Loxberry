import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SBIN = Path(__file__).resolve().parents[1]
HELPER_CODE = (SBIN / "serviceshelper").read_text().split("<<'PYTHON'\n", 1)[1].split("\nPYTHON", 1)[0]


class WatchdogLoggingTests(unittest.TestCase):
    def configure(self, content, enabled):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "watchdog"
            config.write_text(content)
            code = HELPER_CODE.replace("/etc/default/watchdog", str(config))
            result = subprocess.run(
                ["python3", "-c", code, enabled], capture_output=True, text=True
            )
            return result, config.read_text()

    def test_disabling_preserves_other_settings(self):
        before = '# Settings\nrun_watchdog=1\nwatchdog_options="-v -c /etc/watchdog.conf --verbose -vv -s"\n'
        result, after = self.configure(before, "0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(after, '# Settings\nrun_watchdog=1\nwatchdog_options="-c /etc/watchdog.conf -s"\n')

    def test_enabling_and_disabling_are_idempotent(self):
        for enabled, expected in (("1", "-s -v"), ("0", "-s")):
            result, after = self.configure('watchdog_options="-s -v"\n', enabled)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(after, 'watchdog_options="' + expected + '"\n')
            result, repeated = self.configure(after, enabled)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(repeated, after)

    def test_missing_assignment(self):
        for enabled, expected in (("0", ""), ("1", "-v")):
            result, after = self.configure("run_watchdog=1\n", enabled)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(after, 'run_watchdog=1\nwatchdog_options="' + expected + '"\n')

    def test_single_quotes_and_comment(self):
        result, after = self.configure("watchdog_options='-v -s' # Debug\n", "0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(after, 'watchdog_options="-s"\n')

    def test_invalid_input_leaves_file_unchanged(self):
        for content, enabled in (
            ('watchdog_options="-v"\n', "invalid"),
            ('watchdog_options="-v"\nwatchdog_options="-s"\n', "0"),
            ('watchdog_options="-v\n', "0"),
            ('watchdog_options=-v -s\n', "0"),
        ):
            result, after = self.configure(content, enabled)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(result.stderr)
            self.assertEqual(after, content)

    def run_cron(self, logging):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / "config/system").mkdir(parents=True)
            (home / "log/system").mkdir(parents=True)
            sensor = home / "temperature"
            sensor.write_text("70000\n")
            settings = {"Tempsensor": str(sensor), "Maxtemp": "85"}
            if logging is not None:
                settings["Logging"] = logging
            (home / "config/system/general.json").write_text(
                json.dumps({"Watchdog": settings})
            )
            result = subprocess.run(
                ["perl", str(SBIN / "watchdog_cron.pl")],
                env=dict(os.environ, LBHOMEDIR=str(home)),
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            logfile = home / "log/system/watchdogdata.log"
            return logfile.read_text() if logfile.exists() else None

    def test_disabled_cron_does_not_create_log(self):
        for logging in ("0", "false", None):
            with self.subTest(logging=logging):
                self.assertIsNone(self.run_cron(logging))

    def test_enabled_cron_keeps_temperature_logging(self):
        log = self.run_cron("1")
        self.assertIn("<WARNING> CPU Temperature is 70.0 C.", log)
        self.assertEqual(len(log.splitlines()), 2)


if __name__ == "__main__":
    unittest.main()
