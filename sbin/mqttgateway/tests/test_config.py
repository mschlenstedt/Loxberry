"""Tests for mqttgateway.config — TDD, written before implementation."""
import json
import os
import re
import time
import pytest

from mqttgateway.config import (
    parse_aa_path,
    extract_by_path,
    JsonField,
    Subscription,
    GatewayConfig,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


def make_config(tmpdir, general=None, gateway=None):
    """Write config dicts as JSON files into tmpdir, return (gen_path, gw_path)."""
    if general is None:
        with open(os.path.join(FIXTURES_DIR, "general.json")) as f:
            general = json.load(f)
    if gateway is None:
        with open(os.path.join(FIXTURES_DIR, "mqttgateway.json")) as f:
            gateway = json.load(f)

    gen_path = os.path.join(tmpdir, "general.json")
    gw_path = os.path.join(tmpdir, "mqttgateway.json")

    with open(gen_path, "w") as f:
        json.dump(general, f)
    with open(gw_path, "w") as f:
        json.dump(gateway, f)

    return gen_path, gw_path


# ---------------------------------------------------------------------------
# TestParseAAPath
# ---------------------------------------------------------------------------

class TestParseAAPath:
    def test_simple_key(self):
        assert parse_aa_path("temperature") == ["temperature"]

    def test_two_levels(self):
        assert parse_aa_path("settings@@led_indication") == ["settings", "led_indication"]

    def test_array_index_in_middle(self):
        assert parse_aa_path("rollen@@[3]@@rolle") == ["rollen", 3, "rolle"]

    def test_leading_array_index(self):
        assert parse_aa_path("@@[0]@@id") == [0, "id"]

    def test_deep_path(self):
        assert parse_aa_path("sys@@available_updates@@stable@@version") == [
            "sys", "available_updates", "stable", "version"
        ]

    def test_multiple_array_indices(self):
        assert parse_aa_path("data@@[0]@@items@@[2]@@name") == [
            "data", 0, "items", 2, "name"
        ]


# ---------------------------------------------------------------------------
# TestExtractByPath
# ---------------------------------------------------------------------------

class TestExtractByPath:
    def test_simple_key(self):
        data = {"temperature": 21.5}
        assert extract_by_path(data, ["temperature"]) == 21.5

    def test_nested_key(self):
        data = {"settings": {"led_indication": True}}
        assert extract_by_path(data, ["settings", "led_indication"]) is True

    def test_array_index(self):
        data = {"rollen": [{"rolle": "A"}, {"rolle": "B"}, {"rolle": "C"}, {"rolle": "D"}]}
        assert extract_by_path(data, ["rollen", 3, "rolle"]) == "D"

    def test_missing_key_returns_sentinel(self):
        data = {"temperature": 21.5}
        result = extract_by_path(data, ["humidity"])
        assert result is None  # missing key → None (KeyError caught)

    def test_missing_nested_returns_none(self):
        data = {"settings": {}}
        result = extract_by_path(data, ["settings", "led_indication"])
        assert result is None


# ---------------------------------------------------------------------------
# TestGatewayConfig — main config loading
# ---------------------------------------------------------------------------

class TestGatewayConfig:
    def test_broker_host(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.broker_host == "localhost"

    def test_broker_port(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.broker_port == 1883

    def test_broker_credentials(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.broker_user == "loxberry"
        assert cfg.broker_pass == "testpass"

    def test_miniserver_list(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert len(cfg.miniservers) == 2
        ms1 = cfg.miniservers[1]
        assert ms1["Ipaddress"] == "192.168.30.11"
        assert ms1["Name"] == "MS_Gen2"

    def test_miniserver_keys_are_ints(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        # Keys must be ints for consistent Toms lookup
        assert 1 in cfg.miniservers
        assert 2 in cfg.miniservers

    def test_v2_subscription_count(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert len(cfg.subscriptions) == 3

    def test_v2_subscription_topic(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        sub = cfg.subscriptions[0]
        assert sub.topic == "tasmota/sensor/temperature"

    def test_v2_subscription_toms(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        sub = cfg.subscriptions[0]
        assert sub.toms == [1]

    def test_v2_subscription_json_expand(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        # First sub: no JSON expand
        assert cfg.subscriptions[0].json_expand is False
        # Second sub: JSON expand
        assert cfg.subscriptions[1].json_expand is True

    def test_toms_empty_defaults_to_default_ms(self, tmp_path):
        """Empty Toms[] must be replaced with [Main.msno]."""
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        # Third subscription (shelly/+/status) has Toms: []
        shelly_sub = cfg.subscriptions[2]
        assert shelly_sub.toms == [1]  # Main.msno == 1

    def test_json_fields_parsed(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        zigbee_sub = cfg.subscriptions[1]
        assert len(zigbee_sub.json_fields) == 3

    def test_json_field_id_raw(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        zigbee_sub = cfg.subscriptions[1]
        led_field = zigbee_sub.json_fields[2]
        assert led_field.id_raw == "settings@@led_indication"

    def test_json_field_path_parsed(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        zigbee_sub = cfg.subscriptions[1]
        led_field = zigbee_sub.json_fields[2]
        assert led_field.path == ["settings", "led_indication"]

    def test_json_field_toms_empty_defaults(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        # settings@@led_indication has Toms: [] → default MS
        zigbee_sub = cfg.subscriptions[1]
        led_field = zigbee_sub.json_fields[2]
        assert led_field.toms == [1]

    def test_json_field_noncached(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        zigbee_sub = cfg.subscriptions[1]
        humidity_field = zigbee_sub.json_fields[1]
        assert humidity_field.noncached is True

    def test_json_field_reset_after_send(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        zigbee_sub = cfg.subscriptions[1]
        led_field = zigbee_sub.json_fields[2]
        assert led_field.reset_after_send is True

    def test_conversions_parsed(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.conversions == {"ON": "1", "OFF": "0", "online": "1", "offline": "0"}

    def test_subscription_filters_compiled(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert len(cfg.subscription_filters) == 1
        pat = cfg.subscription_filters[0]
        assert hasattr(pat, "match")  # compiled regex
        assert pat.search("tasmota_tele_sensor_STATE") is not None
        assert pat.search("tasmota/sensor/temperature") is None

    def test_do_not_forward(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert "tasmota_debug_heap" in cfg.do_not_forward

    def test_default_ms_number(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.default_ms == 1

    def test_udp_in_port(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.udp_in_port == 11884

    def test_has_changed_false_immediately(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.has_changed() is False

    def test_has_changed_true_after_file_modified(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        # Advance mtime by touching the file
        time.sleep(0.05)
        new_mtime = time.time() + 1
        os.utime(gen, (new_mtime, new_mtime))
        assert cfg.has_changed() is True

    def test_reload_picks_up_changes(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.broker_host == "localhost"

        # Modify general.json
        with open(gen) as f:
            data = json.load(f)
        data["Mqtt"]["Brokerhost"] = "mqtt.example.com"
        with open(gen, "w") as f:
            json.dump(data, f)

        cfg.load()
        assert cfg.broker_host == "mqtt.example.com"

    def test_missing_subscriptions_v2_gives_empty_list(self, tmp_path):
        with open(os.path.join(FIXTURES_DIR, "mqttgateway.json")) as f:
            gw_data = json.load(f)
        del gw_data["subscriptions_v2"]
        gen, gw = make_config(str(tmp_path), gateway=gw_data)
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.subscriptions == []

    def test_missing_conversions_gives_empty_dict(self, tmp_path):
        with open(os.path.join(FIXTURES_DIR, "mqttgateway.json")) as f:
            gw_data = json.load(f)
        del gw_data["conversions"]
        gen, gw = make_config(str(tmp_path), gateway=gw_data)
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.conversions == {}

    def test_missing_filters_gives_empty_list(self, tmp_path):
        with open(os.path.join(FIXTURES_DIR, "mqttgateway.json")) as f:
            gw_data = json.load(f)
        del gw_data["subscriptionfilters"]
        gen, gw = make_config(str(tmp_path), gateway=gw_data)
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.subscription_filters == []

    # -- Main-section properties (5 missing fields) --------------------------

    def test_udp_port(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.udp_port == 11883

    def test_use_http(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.use_http is True

    def test_use_udp(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.use_udp is False

    def test_convert_booleans(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.convert_booleans is True

    def test_reset_after_send_ms(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.reset_after_send_ms == 13

    def test_main_section_defaults_when_empty(self, tmp_path):
        with open(os.path.join(FIXTURES_DIR, "mqttgateway.json")) as f:
            gw_data = json.load(f)
        gw_data["Main"] = {}
        gen, gw = make_config(str(tmp_path), gateway=gw_data)
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.udp_port == 11883
        assert cfg.use_http is True
        assert cfg.use_udp is False
        assert cfg.convert_booleans is True
        assert cfg.reset_after_send_ms == 13

    def test_reset_after_send_ms_min_is_1(self, tmp_path):
        """reset_after_send_ms must never go below 1."""
        with open(os.path.join(FIXTURES_DIR, "mqttgateway.json")) as f:
            gw_data = json.load(f)
        gw_data["Main"]["resetaftersendms"] = 0
        gen, gw = make_config(str(tmp_path), gateway=gw_data)
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert cfg.reset_after_send_ms == 1

    # -- Type checks ---------------------------------------------------------

    def test_do_not_forward_is_set(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert isinstance(cfg.do_not_forward, set)

    def test_do_not_forward_contains_enabled_keys(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert "tasmota_debug_heap" in cfg.do_not_forward

    def test_do_not_forward_excludes_disabled_keys(self, tmp_path):
        with open(os.path.join(FIXTURES_DIR, "mqttgateway.json")) as f:
            gw_data = json.load(f)
        gw_data["doNotForward"]["some_topic"] = "false"
        gen, gw = make_config(str(tmp_path), gateway=gw_data)
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert "some_topic" not in cfg.do_not_forward

    def test_plugin_reset_after_send_is_set(self, tmp_path):
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw)
        cfg.load()
        assert isinstance(cfg.plugin_reset_after_send, set)


# ---------------------------------------------------------------------------
# TestPluginConfigs
# ---------------------------------------------------------------------------

class TestPluginConfigs:
    def _make_plugin_cfg(self, tmpdir, plugin_name, filename, lines):
        """Create a plugin config file in a fake plugin cfg dir structure."""
        plugin_dir = os.path.join(tmpdir, "plugins", plugin_name, "cfg")
        os.makedirs(plugin_dir, exist_ok=True)
        filepath = os.path.join(plugin_dir, filename)
        with open(filepath, "w") as f:
            f.write("\n".join(lines) + "\n")
        return filepath

    def test_plugin_subscriptions_loaded(self, tmp_path):
        plugins_root = os.path.join(str(tmp_path), "plugins")
        self._make_plugin_cfg(
            str(tmp_path), "myplugin", "mqtt_subscriptions.cfg",
            ["home/sensors/temp", "home/sensors/humidity", "# comment line", ""]
        )
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw, plugin_config_dir=plugins_root)
        cfg.load()
        subs = cfg.plugin_subscriptions
        assert "home/sensors/temp" in subs
        assert "home/sensors/humidity" in subs

    def test_plugin_subscriptions_skip_comments(self, tmp_path):
        plugins_root = os.path.join(str(tmp_path), "plugins")
        self._make_plugin_cfg(
            str(tmp_path), "myplugin", "mqtt_subscriptions.cfg",
            ["# this is a comment", "home/sensors/temp"]
        )
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw, plugin_config_dir=plugins_root)
        cfg.load()
        assert "# this is a comment" not in cfg.plugin_subscriptions

    def test_plugin_subscriptions_skip_empty_lines(self, tmp_path):
        plugins_root = os.path.join(str(tmp_path), "plugins")
        self._make_plugin_cfg(
            str(tmp_path), "myplugin", "mqtt_subscriptions.cfg",
            ["", "home/sensors/temp", ""]
        )
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw, plugin_config_dir=plugins_root)
        cfg.load()
        assert "" not in cfg.plugin_subscriptions

    def test_plugin_conversions_loaded(self, tmp_path):
        plugins_root = os.path.join(str(tmp_path), "plugins")
        self._make_plugin_cfg(
            str(tmp_path), "myplugin", "mqtt_conversions.cfg",
            ["OPEN=1", "CLOSED=0"]
        )
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw, plugin_config_dir=plugins_root)
        cfg.load()
        assert cfg.plugin_conversions.get("OPEN") == "1"
        assert cfg.plugin_conversions.get("CLOSED") == "0"

    def test_plugin_reset_after_send_loaded(self, tmp_path):
        plugins_root = os.path.join(str(tmp_path), "plugins")
        self._make_plugin_cfg(
            str(tmp_path), "myplugin", "mqtt_resetaftersend.cfg",
            ["home/sensors/motion"]
        )
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw, plugin_config_dir=plugins_root)
        cfg.load()
        assert "home/sensors/motion" in cfg.plugin_reset_after_send

    def test_multiple_plugins_merged(self, tmp_path):
        plugins_root = os.path.join(str(tmp_path), "plugins")
        self._make_plugin_cfg(
            str(tmp_path), "plugin_a", "mqtt_subscriptions.cfg",
            ["home/a/topic"]
        )
        self._make_plugin_cfg(
            str(tmp_path), "plugin_b", "mqtt_subscriptions.cfg",
            ["home/b/topic"]
        )
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw, plugin_config_dir=plugins_root)
        cfg.load()
        assert "home/a/topic" in cfg.plugin_subscriptions
        assert "home/b/topic" in cfg.plugin_subscriptions

    def test_no_plugins_dir_gives_empty(self, tmp_path):
        nonexistent = os.path.join(str(tmp_path), "no_plugins_here")
        gen, gw = make_config(str(tmp_path))
        cfg = GatewayConfig(gen, gw, plugin_config_dir=nonexistent)
        cfg.load()
        assert cfg.plugin_subscriptions == []
        assert cfg.plugin_conversions == {}
        assert cfg.plugin_reset_after_send == set()
