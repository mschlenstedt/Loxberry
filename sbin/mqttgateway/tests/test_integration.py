"""Integration test — verifies pipeline with real config fixtures."""
import json
import os
import tempfile
import pytest
from pathlib import Path
from mqttgateway.config import GatewayConfig
from mqttgateway.pipeline import Pipeline
from mqttgateway.state import StateManager

FIXTURES = Path(__file__).parent / "fixtures"


class TestEndToEnd:
    def _setup(self, tmpdir):
        gen_path = os.path.join(tmpdir, "general.json")
        gw_path = os.path.join(tmpdir, "mqttgateway.json")
        with open(gen_path, "w") as f:
            json.dump(json.load(open(FIXTURES / "general.json")), f)
        with open(gw_path, "w") as f:
            json.dump(json.load(open(FIXTURES / "mqttgateway.json")), f)

        cfg = GatewayConfig(general_json_path=gen_path, gateway_json_path=gw_path)
        cfg.load()

        pipeline = Pipeline(
            hostname="loxberry",
            do_not_forward=cfg.do_not_forward,
            subscription_filters=cfg.subscription_filters,
            convert_booleans=cfg.convert_booleans,
            conversions=cfg.conversions,
            subscriptions=cfg.subscriptions,
            default_ms=cfg.default_ms,
        )

        state = StateManager(datafile=os.path.join(tmpdir, "topics.json"))
        return cfg, pipeline, state

    def test_simple_topic_pass_through(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            result = pipeline.process("tasmota/sensor/temperature", "22.5")
            assert result is not None
            assert len(result.items) == 1
            assert result.items[0].value == "22.5"
            assert result.items[0].toms == [1]

    def test_json_expand_and_route(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            payload = '{"temperature": 22.5, "humidity": 55, "battery": 98}'
            result = pipeline.process("zigbee2mqtt/livingroom", payload)
            assert result is not None
            topics = {i.topic_underlined: i for i in result.items}
            assert "zigbee2mqtt_livingroom_temperature" in topics
            assert "zigbee2mqtt_livingroom_humidity" in topics
            assert "zigbee2mqtt_livingroom_battery" not in topics
            hum = topics["zigbee2mqtt_livingroom_humidity"]
            assert hum.toms == [1, 2]
            assert hum.noncached is True

    def test_nested_json_expansion(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            payload = json.dumps({"sys": {"available_updates": {"stable": {"version": "2.0.0"}}}})
            result = pipeline.process("shelly/device1/status", payload)
            assert result is not None
            assert len(result.items) == 1
            assert result.items[0].value == "2.0.0"

    def test_boolean_conversion(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            result = pipeline.process("tasmota/sensor/temperature", "true")
            assert result.items[0].value == "1"

    def test_user_conversion(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            result = pipeline.process("tasmota/sensor/temperature", "ON")
            assert result.items[0].value == "1"

    def test_do_not_forward_filtered(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            result = pipeline.process("tasmota/debug/heap", "12345")
            assert result is None

    def test_regex_filter(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            result = pipeline.process("tasmota/tele/plug1/STATE", '{"POWER":"ON"}')
            assert result is None

    def test_gateway_own_topic_filtered(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            result = pipeline.process("loxberry/mqttgateway/pollms", "50")
            assert result is None

    def test_debounce(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            r1 = pipeline.process("tasmota/sensor/temperature", "22.5")
            r2 = pipeline.process("tasmota/sensor/temperature", "22.5")
            assert r1 is not None
            assert r2 is None

    def test_state_save(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            result = pipeline.process("tasmota/sensor/temperature", "22.5")
            for item in result.items:
                state.record_http(item.topic_underlined, item.value, item.original_topic, ms_nr=1, code=200)
            state.save()
            data = json.load(open(os.path.join(tmpdir, "topics.json")))
            assert "tasmota_sensor_temperature" in data["http"]
