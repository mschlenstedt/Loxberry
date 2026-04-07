"""Tests for mqttgateway.pipeline — TDD, written before implementation."""
from __future__ import annotations

import re
import pytest

from mqttgateway.config import JsonField, Subscription, parse_aa_path
from mqttgateway.pipeline import (
    Pipeline,
    PipelineResult,
    SendItem,
    _underline_topic,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_sub(
    topic: str,
    toms: list[int] | None = None,
    noncached: bool = False,
    reset_after_send: bool = False,
    json_expand: bool = False,
    json_fields: list[JsonField] | None = None,
) -> Subscription:
    return Subscription(
        topic=topic,
        toms=toms if toms is not None else [1],
        noncached=noncached,
        reset_after_send=reset_after_send,
        json_expand=json_expand,
        json_fields=json_fields or [],
    )


def make_jf(
    id_raw: str,
    toms: list[int] | None = None,
    noncached: bool = False,
    reset_after_send: bool = False,
) -> JsonField:
    return JsonField(
        id_raw=id_raw,
        path=parse_aa_path(id_raw),
        toms=toms if toms is not None else [1],
        noncached=noncached,
        reset_after_send=reset_after_send,
    )


def make_pipeline(**kwargs) -> Pipeline:
    """Create a Pipeline with sensible defaults, overridable via kwargs."""
    defaults = dict(
        hostname="loxberry",
        do_not_forward=None,
        subscription_filters=None,
        convert_booleans=False,
        conversions=None,
        subscriptions=None,
        default_ms=1,
    )
    defaults.update(kwargs)
    return Pipeline(**defaults)


# ---------------------------------------------------------------------------
# TestEarlyFilter
# ---------------------------------------------------------------------------

class TestEarlyFilter:
    def test_filters_gateway_own_topic(self):
        p = make_pipeline()
        assert p.process("loxberry/mqttgateway/pollms", "1000") is None

    def test_filters_gateway_status(self):
        p = make_pipeline()
        assert p.process("loxberry/mqttgateway/status", "online") is None

    def test_passes_normal_topic(self):
        p = make_pipeline()
        result = p.process("sensors/temperature", "23.5")
        assert result is not None

    def test_filters_do_not_forward(self):
        # topic "tasmota/debug/heap" → underlined "tasmota_debug_heap"
        p = make_pipeline(do_not_forward={"tasmota_debug_heap"})
        assert p.process("tasmota/debug/heap", "1234") is None

    def test_filters_regex_match(self):
        # tasmota/tele/plug1/STATE → underlined tasmota_tele_plug1_STATE
        p = make_pipeline(
            subscription_filters=[re.compile(r"tasmota_tele_.*_STATE")]
        )
        assert p.process("tasmota/tele/plug1/STATE", "{}") is None

    def test_passes_regex_non_match(self):
        p = make_pipeline(
            subscription_filters=[re.compile(r"tasmota_tele_.*_STATE")]
        )
        result = p.process("sensors/temperature", "22.0")
        assert result is not None


# ---------------------------------------------------------------------------
# TestDebounce
# ---------------------------------------------------------------------------

class TestDebounce:
    def test_first_message_passes(self):
        p = make_pipeline()
        result = p.process("home/temp", "20.0")
        assert result is not None

    def test_duplicate_message_filtered(self):
        p = make_pipeline()
        p.process("home/temp", "20.0")
        result = p.process("home/temp", "20.0")
        assert result is None

    def test_changed_value_passes(self):
        p = make_pipeline()
        p.process("home/temp", "20.0")
        result = p.process("home/temp", "21.0")
        assert result is not None

    def test_different_topic_passes(self):
        p = make_pipeline()
        p.process("home/temp", "20.0")
        result = p.process("home/humidity", "20.0")
        assert result is not None

    def test_cache_independent_per_topic(self):
        p = make_pipeline()
        p.process("home/temp", "20.0")
        p.process("home/humidity", "55.0")
        # Both topics saw "20.0" and "55.0" — changing one doesn't affect other
        assert p.process("home/temp", "20.0") is None
        assert p.process("home/humidity", "55.0") is None
        assert p.process("home/temp", "21.0") is not None
        assert p.process("home/humidity", "56.0") is not None


# ---------------------------------------------------------------------------
# TestJsonExpansion
# ---------------------------------------------------------------------------

class TestJsonExpansion:
    def test_no_expansion_when_disabled(self):
        sub = make_sub("sensors/weather", json_expand=False)
        p = make_pipeline(subscriptions=[sub])
        payload = '{"temperature": 23.5, "humidity": 60}'
        result = p.process("sensors/weather", payload)
        assert result is not None
        assert len(result.items) == 1
        assert result.items[0].value == payload

    def test_expand_specific_fields(self):
        """Extract temperature + humidity but NOT battery."""
        sub = make_sub(
            "sensors/weather",
            json_expand=True,
            json_fields=[
                make_jf("temperature"),
                make_jf("humidity"),
            ],
        )
        p = make_pipeline(subscriptions=[sub])
        payload = '{"temperature": 23.5, "humidity": 60, "battery": 95}'
        result = p.process("sensors/weather", payload)
        assert result is not None
        assert len(result.items) == 2
        topics = {item.original_topic for item in result.items}
        assert "sensors/weather/temperature" in topics
        assert "sensors/weather/humidity" in topics
        # battery must NOT be present
        assert all("battery" not in t for t in topics)
        values = {item.original_topic: item.value for item in result.items}
        assert values["sensors/weather/temperature"] == "23.5"
        assert values["sensors/weather/humidity"] == "60"

    def test_expand_nested_field(self):
        """sys@@available_updates@@stable@@version digs into nested dicts."""
        sub = make_sub(
            "system/info",
            json_expand=True,
            json_fields=[make_jf("sys@@available_updates@@stable@@version")],
        )
        p = make_pipeline(subscriptions=[sub])
        payload = '{"sys": {"available_updates": {"stable": {"version": "3.1.0"}}}}'
        result = p.process("system/info", payload)
        assert result is not None
        assert len(result.items) == 1
        item = result.items[0]
        assert item.original_topic == "system/info/sys/available_updates/stable/version"
        assert item.value == "3.1.0"

    def test_expand_array_index(self):
        """rollen@@[0] and rollen@@[1]@@name access list elements."""
        sub = make_sub(
            "device/state",
            json_expand=True,
            json_fields=[
                make_jf("rollen@@[0]"),
                make_jf("rollen@@[1]@@name"),
            ],
        )
        p = make_pipeline(subscriptions=[sub])
        payload = '{"rollen": ["alpha", {"name": "beta"}]}'
        result = p.process("device/state", payload)
        assert result is not None
        assert len(result.items) == 2
        by_topic = {item.original_topic: item.value for item in result.items}
        assert by_topic["device/state/rollen/0"] == "alpha"
        assert by_topic["device/state/rollen/1/name"] == "beta"

    def test_missing_field_silently_skipped(self):
        """A json_field that doesn't exist in payload is silently skipped."""
        sub = make_sub(
            "sensors/weather",
            json_expand=True,
            json_fields=[
                make_jf("temperature"),
                make_jf("nonexistent_field"),
            ],
        )
        p = make_pipeline(subscriptions=[sub])
        payload = '{"temperature": 22.0}'
        result = p.process("sensors/weather", payload)
        assert result is not None
        assert len(result.items) == 1
        assert result.items[0].original_topic == "sensors/weather/temperature"

    def test_non_json_passed_through_when_expansion_enabled(self):
        """If payload is not valid JSON but json_expand=True, pass through as-is."""
        sub = make_sub("sensors/raw", json_expand=True, json_fields=[make_jf("val")])
        p = make_pipeline(subscriptions=[sub])
        result = p.process("sensors/raw", "not-json-at-all")
        assert result is not None
        assert len(result.items) == 1
        assert result.items[0].value == "not-json-at-all"

    def test_per_field_toms(self):
        """Each JsonField carries its own toms list."""
        sub = make_sub(
            "sensors/multi",
            toms=[1],
            json_expand=True,
            json_fields=[
                make_jf("fast_sensor", toms=[1, 2]),
                make_jf("slow_sensor", toms=[3]),
            ],
        )
        p = make_pipeline(subscriptions=[sub])
        payload = '{"fast_sensor": "A", "slow_sensor": "B"}'
        result = p.process("sensors/multi", payload)
        assert result is not None
        by_topic = {item.original_topic: item for item in result.items}
        assert by_topic["sensors/multi/fast_sensor"].toms == [1, 2]
        assert by_topic["sensors/multi/slow_sensor"].toms == [3]

    def test_per_field_noncached_and_reset(self):
        """noncached and reset_after_send come from the JsonField."""
        sub = make_sub(
            "sensors/flags",
            json_expand=True,
            json_fields=[
                make_jf("always_send", noncached=True, reset_after_send=True),
                make_jf("normal_send", noncached=False, reset_after_send=False),
            ],
        )
        p = make_pipeline(subscriptions=[sub])
        payload = '{"always_send": "x", "normal_send": "y"}'
        result = p.process("sensors/flags", payload)
        assert result is not None
        by_topic = {item.original_topic: item for item in result.items}
        assert by_topic["sensors/flags/always_send"].noncached is True
        assert by_topic["sensors/flags/always_send"].reset_after_send is True
        assert by_topic["sensors/flags/normal_send"].noncached is False
        assert by_topic["sensors/flags/normal_send"].reset_after_send is False

    def test_wildcard_star_expands_all_top_level_keys(self):
        """id_raw == '*' expands every top-level key in the dict."""
        sub = make_sub(
            "sensors/all",
            json_expand=True,
            json_fields=[make_jf("*")],
        )
        p = make_pipeline(subscriptions=[sub])
        payload = '{"temp": 22, "hum": 55, "co2": 400}'
        result = p.process("sensors/all", payload)
        assert result is not None
        assert len(result.items) == 3
        topics = {item.original_topic for item in result.items}
        assert topics == {
            "sensors/all/temp",
            "sensors/all/hum",
            "sensors/all/co2",
        }
        values = {item.original_topic: item.value for item in result.items}
        assert values["sensors/all/temp"] == "22"
        assert values["sensors/all/hum"] == "55"
        assert values["sensors/all/co2"] == "400"


# ---------------------------------------------------------------------------
# TestConversions
# ---------------------------------------------------------------------------

class TestConversions:
    def test_boolean_true_to_1(self):
        p = make_pipeline(convert_booleans=True)
        result = p.process("home/switch", "true")
        assert result is not None
        assert result.items[0].value == "1"

    def test_boolean_false_to_0(self):
        p = make_pipeline(convert_booleans=True)
        result = p.process("home/switch", "FALSE")
        assert result is not None
        assert result.items[0].value == "0"

    def test_boolean_conversion_disabled(self):
        p = make_pipeline(convert_booleans=False)
        result = p.process("home/switch", "true")
        assert result is not None
        assert result.items[0].value == "true"

    def test_user_conversion_on_to_1(self):
        p = make_pipeline(conversions={"ON": "1"})
        result = p.process("home/switch", "ON")
        assert result is not None
        assert result.items[0].value == "1"

    def test_user_conversion_off_to_0(self):
        p = make_pipeline(conversions={"OFF": "0"})
        result = p.process("home/switch", "OFF")
        assert result is not None
        assert result.items[0].value == "0"

    def test_no_conversion_for_unknown_values(self):
        p = make_pipeline(conversions={"ON": "1"}, convert_booleans=True)
        result = p.process("home/sensor", "42.5")
        assert result is not None
        assert result.items[0].value == "42.5"

    def test_boolean_before_user_conversion(self):
        """true → '1' (boolean) → '100' (user conversion)."""
        p = make_pipeline(convert_booleans=True, conversions={"1": "100"})
        result = p.process("home/switch", "true")
        assert result is not None
        assert result.items[0].value == "100"

    def test_conversion_applied_to_expanded_json_fields(self):
        """Conversions run on each expanded JSON field value."""
        sub = make_sub(
            "device/status",
            json_expand=True,
            json_fields=[make_jf("power"), make_jf("mode")],
        )
        p = make_pipeline(
            subscriptions=[sub],
            conversions={"ON": "1", "OFF": "0"},
            convert_booleans=False,
        )
        payload = '{"power": "ON", "mode": "OFF"}'
        result = p.process("device/status", payload)
        assert result is not None
        by_topic = {item.original_topic: item.value for item in result.items}
        assert by_topic["device/status/power"] == "1"
        assert by_topic["device/status/mode"] == "0"


# ---------------------------------------------------------------------------
# TestTopicMatching
# ---------------------------------------------------------------------------

class TestTopicMatching:
    def test_exact_match(self):
        sub = make_sub("home/living/temperature")
        p = make_pipeline(subscriptions=[sub])
        result = p.process("home/living/temperature", "22")
        assert result is not None

    def test_exact_no_match(self):
        sub = make_sub("home/living/temperature")
        p = make_pipeline(subscriptions=[sub])
        # Different topic → no subscription found, falls back to defaults
        result = p.process("home/kitchen/temperature", "22")
        assert result is not None  # still passes through (no subscription needed)

    def test_plus_wildcard_matches_single_level(self):
        sub = make_sub("home/+/temperature", toms=[5])
        p = make_pipeline(subscriptions=[sub])
        result = p.process("home/living/temperature", "22")
        assert result is not None
        assert result.items[0].toms == [5]

    def test_plus_wildcard_does_not_match_multiple_levels(self):
        sub = make_sub("home/+/temperature", toms=[5])
        p = make_pipeline(subscriptions=[sub])
        # "home/floor1/room/temperature" has an extra level — + should not match
        result = p.process("home/floor1/room/temperature", "22")
        # No matching subscription, so default toms apply
        assert result is not None
        assert result.items[0].toms == [1]  # default_ms=1

    def test_hash_at_end_matches_everything_below(self):
        sub = make_sub("tasmota/#", toms=[7])
        p = make_pipeline(subscriptions=[sub])
        result = p.process("tasmota/tele/sensor/RESULT", "data")
        assert result is not None
        assert result.items[0].toms == [7]

    def test_hash_alone_matches_all(self):
        sub = make_sub("#", toms=[9])
        p = make_pipeline(subscriptions=[sub])
        result = p.process("any/topic/at/all", "v")
        assert result is not None
        assert result.items[0].toms == [9]

    def test_find_subscription_returns_none_for_no_match_when_no_subs(self):
        p = make_pipeline(subscriptions=[])
        # No subscriptions — _find_subscription returns None, pipeline still produces output
        result = p.process("some/topic", "val")
        assert result is not None
        assert result.items[0].toms == [1]  # default_ms


# ---------------------------------------------------------------------------
# TestUnderlineTopic
# ---------------------------------------------------------------------------

class TestUnderlineTopic:
    def test_slash_replaced(self):
        assert _underline_topic("a/b/c") == "a_b_c"

    def test_percent_replaced(self):
        assert _underline_topic("a%b") == "a_b"

    def test_both_replaced(self):
        assert _underline_topic("a/b%c/d") == "a_b_c_d"

    def test_no_special_chars(self):
        assert _underline_topic("abc") == "abc"


# ---------------------------------------------------------------------------
# TestSendItemStructure
# ---------------------------------------------------------------------------

class TestSendItemStructure:
    def test_send_item_fields(self):
        """SendItem carries all required fields."""
        item = SendItem(
            topic_underlined="home_temp",
            original_topic="home/temp",
            value="22.5",
            toms=[1, 2],
            noncached=False,
            reset_after_send=True,
        )
        assert item.topic_underlined == "home_temp"
        assert item.original_topic == "home/temp"
        assert item.value == "22.5"
        assert item.toms == [1, 2]
        assert item.noncached is False
        assert item.reset_after_send is True

    def test_pipeline_result_contains_items(self):
        p = make_pipeline()
        result = p.process("home/temp", "22.5")
        assert isinstance(result, PipelineResult)
        assert len(result.items) == 1
        item = result.items[0]
        assert item.original_topic == "home/temp"
        assert item.topic_underlined == "home_temp"
        assert item.value == "22.5"
