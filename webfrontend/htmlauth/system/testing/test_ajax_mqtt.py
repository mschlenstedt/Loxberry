import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ENDPOINT = Path(__file__).resolve().parents[1] / "ajax/ajax-mqtt.php"
DRIVER = r"""
set_error_handler(function($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});
$_SERVER['HTTP_HOST'] = 'localhost';
$_GET = json_decode($argv[1], true);
$_POST = json_decode($argv[2], true);
require $argv[3];
"""


class AjaxMqttTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / "loxberry_system.php").write_text(
            "<?php define('LBSCONFIGDIR', " + json.dumps(str(self.home)) + ");"
        )
        (self.home / "mqttgateway.json").write_text(
            json.dumps({"subscriptions_v2": [{"topic": "test/v2"}]})
        )
        (self.home / "subscriptions.json").write_text(
            json.dumps({"Subscriptions": [{"topic": "test/current"}]})
        )

    def request(self, get=None, post=None):
        result = subprocess.run(
            ["php", "-d", "include_path=" + str(self.home), "-r", DRIVER,
             json.dumps(get or {}), json.dumps(post or {}), str(ENDPOINT)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Undefined", result.stderr)
        return result

    def test_subscription_get_and_post_dispatch(self):
        for action, key, topic in (
            ("get_subscriptions", "Subscriptions", "test/current"),
            ("get_subscriptions_v2", "subscriptions_v2", "test/v2"),
        ):
            for method in ("get", "post"):
                with self.subTest(action=action, method=method):
                    result = self.request(**{method: {"ajax": action}})
                    self.assertEqual(json.loads(result.stdout)[key][0]["topic"], topic)
                    self.assertEqual(result.stderr, "")

    def test_subscription_save_dispatch_validates_body(self):
        for action, key in (
            ("save_subscriptions", "Subscriptions"),
            ("save_subscriptions_v2", "subscriptions_v2"),
        ):
            for method in ("get", "post"):
                with self.subTest(action=action, method=method):
                    result = self.request(**{method: {"ajax": action}})
                    self.assertEqual(json.loads(result.stdout), {"error": "Missing " + key + " data"})
                    self.assertEqual(result.stderr, "")

    def test_later_action_does_not_access_missing_indexes(self):
        for method in ("get", "post"):
            result = self.request(**{method: {"ajax": "mqtt_external_ca_status"}})
            self.assertEqual(json.loads(result.stdout), {"exists": False})
            self.assertEqual(result.stderr, "")

    def test_post_takes_precedence(self):
        result = self.request(
            get={"ajax": "get_subscriptions_v2"},
            post={"ajax": "get_subscriptions"},
        )
        self.assertIn("Subscriptions", json.loads(result.stdout))

    def test_missing_action_is_reported_without_notice(self):
        result = self.request()
        self.assertIn("ajax not set", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_cli_without_argument_is_reported_without_notice(self):
        result = subprocess.run(
            ["php", "-d", "include_path=" + str(self.home), str(ENDPOINT)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ajax not set", result.stderr)
        self.assertNotIn("Undefined", result.stderr)


if __name__ == "__main__":
    unittest.main()
