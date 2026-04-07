"""Tests for StateManager — Task 10."""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

import pytest

from mqttgateway.state import StateManager, _24H


# ---------------------------------------------------------------------------
# record_http
# ---------------------------------------------------------------------------

def test_record_http_basic(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_http("sensor_temp", "22.5", "sensor/temp")

    assert "sensor_temp" in mgr._http_topics
    entry = mgr._http_topics["sensor_temp"]
    assert entry["message"] == "22.5"
    assert entry["originaltopic"] == "sensor/temp"
    assert "timestamp" in entry


def test_record_http_with_ms(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_http("sensor_temp", "22.5", "sensor/temp", ms_nr=1, code=200)

    entry = mgr._http_topics["sensor_temp"]
    assert "toMS" in entry
    assert "1" in entry["toMS"]
    assert entry["toMS"]["1"]["code"] == 200


def test_record_http_updates_existing(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_http("sensor_temp", "22.5", "sensor/temp")
    mgr.record_http("sensor_temp", "23.0", "sensor/temp")

    assert mgr._http_topics["sensor_temp"]["message"] == "23.0"


def test_record_http_without_ms_no_toms(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_http("t", "v", "t/v")
    assert "toMS" not in mgr._http_topics["t"]


# ---------------------------------------------------------------------------
# record_udp
# ---------------------------------------------------------------------------

def test_record_udp_basic(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_udp("udp/sensor", "hello", "udp/sensor")

    assert "udp/sensor" in mgr._udp_topics
    entry = mgr._udp_topics["udp/sensor"]
    assert entry["message"] == "hello"
    assert entry["originaltopic"] == "udp/sensor"
    assert "timestamp" in entry


def test_record_udp_updates_existing(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_udp("t", "old", "t")
    mgr.record_udp("t", "new", "t")
    assert mgr._udp_topics["t"]["message"] == "new"


# ---------------------------------------------------------------------------
# cleanup
# ---------------------------------------------------------------------------

def test_cleanup_removes_old_entries(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_http("old_topic", "val", "old/topic")
    # Manually set timestamp to >24h ago
    mgr._http_topics["old_topic"]["timestamp"] = time.time() - _24H - 1

    mgr._cleanup()
    assert "old_topic" not in mgr._http_topics


def test_cleanup_keeps_recent_entries(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_http("fresh", "val", "fresh/topic")
    mgr._cleanup()
    assert "fresh" in mgr._http_topics


def test_cleanup_removes_entries_without_message(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr._http_topics["no_msg"] = {"timestamp": time.time(), "message": ""}
    mgr._cleanup()
    assert "no_msg" not in mgr._http_topics


def test_cleanup_also_cleans_udp(tmp_path):
    mgr = StateManager(datafile=str(tmp_path / "state.json"))
    mgr.record_udp("old_udp", "v", "t")
    mgr._udp_topics["old_udp"]["timestamp"] = time.time() - _24H - 1
    mgr._cleanup()
    assert "old_udp" not in mgr._udp_topics


# ---------------------------------------------------------------------------
# save / load
# ---------------------------------------------------------------------------

def test_save_creates_file(tmp_path):
    datafile = str(tmp_path / "state.json")
    mgr = StateManager(datafile=datafile)
    mgr.record_http("t", "v", "t/v")
    mgr.save()

    assert os.path.exists(datafile)


def test_save_file_is_valid_json(tmp_path):
    datafile = str(tmp_path / "state.json")
    mgr = StateManager(datafile=datafile)
    mgr.record_http("sensor", "42", "sensor/value")
    mgr.record_udp("udp_t", "hello", "udp/t")
    mgr.save()

    with open(datafile) as f:
        data = json.load(f)

    assert "http" in data
    assert "udp" in data
    assert "health_state" in data
    assert "subscriptionfilters" in data
    assert "Noncached" in data
    assert "resetAfterSend" in data
    assert "doNotForward" in data


def test_save_health_state_stats(tmp_path):
    datafile = str(tmp_path / "state.json")
    mgr = StateManager(datafile=datafile)
    mgr.record_http("t1", "v1", "t/1", ms_nr=1, code=200)
    mgr.record_http("t2", "v2", "t/2", ms_nr=2, code=200)
    mgr.record_http("t3", "v3", "t/3", ms_nr=1, code=500)
    mgr.record_udp("u1", "x", "u/1")
    mgr.save()

    with open(datafile) as f:
        data = json.load(f)

    stats = data["health_state"]["stats"]
    assert stats["http_relayedcount"] == 3
    assert stats["udp_relayedcount"] == 1
    assert "200" in stats["httpresp"]
    assert stats["httpresp"]["200"] == 2
    assert "500" in stats["httpresp"]
    assert stats["httpresp"]["500"] == 1


def test_save_health_state_included(tmp_path):
    datafile = str(tmp_path / "state.json")
    mgr = StateManager(datafile=datafile)
    mgr.health_state["broker"] = "connected"
    mgr.save()

    with open(datafile) as f:
        data = json.load(f)

    assert data["health_state"]["broker"] == "connected"


def test_save_subscription_filters(tmp_path):
    datafile = str(tmp_path / "state.json")
    mgr = StateManager(datafile=datafile)
    mgr.subscription_filters = ["topic/#", "other/+/sensor"]
    mgr.save()

    with open(datafile) as f:
        data = json.load(f)

    assert data["subscriptionfilters"] == ["topic/#", "other/+/sensor"]


def test_save_uses_atomic_replace(tmp_path):
    """Verify no .tmp file is left over after save."""
    datafile = str(tmp_path / "state.json")
    mgr = StateManager(datafile=datafile)
    mgr.save()

    assert not os.path.exists(datafile + ".tmp")
    assert os.path.exists(datafile)


def test_save_error_on_invalid_path():
    """save() must not raise — it logs errors silently."""
    mgr = StateManager(datafile="/nonexistent_dir/state.json")
    # Must not raise
    mgr.save()


def test_save_cleans_old_before_saving(tmp_path):
    datafile = str(tmp_path / "state.json")
    mgr = StateManager(datafile=datafile)
    mgr.record_http("stale", "v", "stale/t")
    mgr._http_topics["stale"]["timestamp"] = time.time() - _24H - 1
    mgr.save()

    with open(datafile) as f:
        data = json.load(f)

    assert "stale" not in data["http"]
