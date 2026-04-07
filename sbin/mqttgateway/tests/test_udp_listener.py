import pytest
from mqttgateway.udp_listener import parse_udp_message, UdpCommand


class TestParseUdpMessage:
    def test_save_relayed_states(self):
        cmd = parse_udp_message("save_relayed_states")
        assert cmd.command == "save_relayed_states"

    def test_reconnect(self):
        cmd = parse_udp_message("reconnect")
        assert cmd.command == "reconnect"

    def test_publish_simple(self):
        cmd = parse_udp_message("publish my/topic hello world")
        assert cmd.command == "publish"
        assert cmd.topic == "my/topic"
        assert cmd.message == "hello world"
        assert cmd.transformer is None

    def test_retain_simple(self):
        cmd = parse_udp_message("retain my/topic somevalue")
        assert cmd.command == "retain"
        assert cmd.topic == "my/topic"
        assert cmd.message == "somevalue"

    def test_publish_with_transformer(self):
        cmd = parse_udp_message("publish http2mqtt my/topic somedata", known_transformers={"http2mqtt"})
        assert cmd.command == "publish"
        assert cmd.transformer == "http2mqtt"
        assert cmd.topic == "my/topic"
        assert cmd.message == "somedata"

    def test_json_message(self):
        cmd = parse_udp_message('{"topic":"test/topic","value":"42","retain":true}')
        assert cmd.command == "retain"
        assert cmd.topic == "test/topic"
        assert cmd.message == "42"

    def test_json_with_transform(self):
        cmd = parse_udp_message('{"topic":"test/topic","value":"data","transform":"http2mqtt"}')
        assert cmd.command == "publish"
        assert cmd.transformer == "http2mqtt"

    def test_loxone_logger_format(self):
        cmd = parse_udp_message("2026-04-07 14:23:01;DeviceName;42.5")
        assert cmd.command == "retain"
        assert "logger/" in cmd.topic
        assert cmd.message == "42.5"

    def test_legacy_format(self):
        cmd = parse_udp_message("my/topic 42.5")
        assert cmd.command == "publish"
        assert cmd.topic == "my/topic"
        assert cmd.message == "42.5"
