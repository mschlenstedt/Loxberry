# MQTT Gateway Python Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the MQTT Gateway daemon from Perl to Python with asyncio, V2-only, keeping full compatibility with the existing WebUI and PHP-AJAX backend.

**Architecture:** Single-process async daemon using asyncio event loop. aiomqtt for MQTT, httpx for async HTTP to Miniservers, asyncio.DatagramProtocol for UDP. Message pipeline with early filtering, debounce, targeted JSON expansion via @@-notation, and delta-cached sends.

**Tech Stack:** Python 3.11+, aiomqtt, httpx, sdnotify, pytest, pytest-asyncio

---

## File Structure

| File | Responsibility |
|---|---|
| `sbin/mqttgateway/__main__.py` | Entry point, wires all components, runs event loop |
| `sbin/mqttgateway/config.py` | Load general.json + mqttgateway.json, parse V2 subs, file-watcher |
| `sbin/mqttgateway/logging_compat.py` | LoxBerry-compatible log formatter to /dev/shm/ |
| `sbin/mqttgateway/pipeline.py` | Message pipeline: filter, debounce, expand, convert, route |
| `sbin/mqttgateway/miniserver.py` | HTTP delta-send + UDP send to Miniserver |
| `sbin/mqttgateway/mqtt_client.py` | aiomqtt subscription management |
| `sbin/mqttgateway/udp_listener.py` | UDP listener for MS-to-MQTT reverse channel |
| `sbin/mqttgateway/transformer.py` | Async subprocess calls to PHP/Perl transformer scripts |
| `sbin/mqttgateway/state.py` | Periodic topic snapshot to /dev/shm/ for WebUI |
| `sbin/mqttgateway/tests/__init__.py` | Test package |
| `sbin/mqttgateway/tests/test_config.py` | Config loading + V2 parsing tests |
| `sbin/mqttgateway/tests/test_pipeline.py` | Pipeline stage tests |
| `sbin/mqttgateway/tests/test_miniserver.py` | HTTP/UDP send tests |
| `sbin/mqttgateway/tests/test_transformer.py` | Transformer subprocess tests |
| `sbin/mqttgateway/tests/test_udp_listener.py` | UDP listener tests |
| `sbin/mqttgateway/tests/test_state.py` | State snapshot tests |
| `sbin/mqttgateway/tests/test_logging_compat.py` | Logging format tests |
| `system/daemons/system/mqttgateway.service` | systemd service unit |

---

### Task 1: Project scaffolding and dependencies

**Files:**
- Create: `sbin/mqttgateway/__init__.py`
- Create: `sbin/mqttgateway/__main__.py` (placeholder)
- Create: `sbin/mqttgateway/tests/__init__.py`
- Create: `sbin/mqttgateway/requirements.txt`

- [ ] **Step 1: Create package structure**

```bash
mkdir -p sbin/mqttgateway/tests
```

- [ ] **Step 2: Create `sbin/mqttgateway/__init__.py`**

```python
"""LoxBerry MQTT Gateway V2 — async Python daemon."""
__version__ = "4.0.0.1"
```

- [ ] **Step 3: Create `sbin/mqttgateway/tests/__init__.py`**

```python
```

(Empty file.)

- [ ] **Step 4: Create `sbin/mqttgateway/requirements.txt`**

```
aiomqtt>=2.0.0
httpx>=0.27.0
sdnotify>=0.3.2
pytest>=8.0
pytest-asyncio>=0.23
```

- [ ] **Step 5: Create placeholder `sbin/mqttgateway/__main__.py`**

```python
"""Entry point: python3 -m mqttgateway or python3 /opt/loxberry/sbin/mqttgateway."""
import asyncio
import sys


async def main() -> None:
    print("MQTT Gateway V2 starting...")
    # Components will be wired here in later tasks
    await asyncio.sleep(1)
    print("MQTT Gateway V2 placeholder — not yet implemented.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
```

- [ ] **Step 6: Verify the package runs**

Run: `cd sbin && python3 -m mqttgateway`
Expected: Prints "MQTT Gateway V2 starting..." then "MQTT Gateway V2 placeholder — not yet implemented."

- [ ] **Step 7: Install test dependencies**

Run: `pip install pytest pytest-asyncio`
Expected: Successfully installed.

- [ ] **Step 8: Commit**

```bash
git add sbin/mqttgateway/
git commit -m "feat(mqtt-gw): project scaffolding for Python rewrite"
```

---

### Task 2: Logging compatibility layer

**Files:**
- Create: `sbin/mqttgateway/logging_compat.py`
- Create: `sbin/mqttgateway/tests/test_logging_compat.py`

The Perl daemon uses `LoxBerry::Log` which writes lines like:
```
<OK> 2026-04-07 14:23:01 MQTT connected to localhost:1883
<ERROR> 2026-04-07 14:23:05 Something failed
```

The WebUI Logs-Tab reads this file and parses these tags. We must match the format exactly.

LoxBerry log levels: 0=Off, 3=Errors, 4=Warning, 6=Info, 7=Debug. These map to custom prefixes:
- `<OK>` for success messages (INFO level, explicit)
- `<INFO>` for informational
- `<WARNING>` for warnings
- `<ERROR>` for errors
- `<DEBUG>` for debug (only at loglevel 7)

- [ ] **Step 1: Write failing tests**

```python
# sbin/mqttgateway/tests/test_logging_compat.py
import logging
import re
import tempfile
import os
import pytest
from mqttgateway.logging_compat import setup_logging, LOGLEVEL_MAP, LoxBerryFormatter


class TestLoxBerryFormatter:
    def test_format_info_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.INFO,
            pathname="", lineno=0, msg="Test message",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<INFO>")
        assert "Test message" in result
        # Check timestamp format: <TAG> YYYY-MM-DD HH:MM:SS message
        assert re.match(r"<INFO> \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} Test message", result)

    def test_format_error_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.ERROR,
            pathname="", lineno=0, msg="Something broke",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<ERROR>")

    def test_format_warning_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.WARNING,
            pathname="", lineno=0, msg="Watch out",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<WARNING>")

    def test_format_debug_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.DEBUG,
            pathname="", lineno=0, msg="Debug info",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<DEBUG>")

    def test_format_ok_message(self):
        """OK is a custom level between INFO and WARNING (level 25)."""
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=25,  # OK level
            pathname="", lineno=0, msg="Success",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<OK>")


class TestSetupLogging:
    def test_creates_log_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            logfile = os.path.join(tmpdir, "mqttgateway.log")
            logger = setup_logging(logfile=logfile, loglevel=7)
            logger.info("Test")
            # Flush handlers
            for h in logger.handlers:
                h.flush()
            assert os.path.exists(logfile)
            content = open(logfile).read()
            assert "<INFO>" in content
            assert "Test" in content

    def test_loglevel_3_filters_info(self):
        """Loglevel 3 = Errors only. INFO should be filtered."""
        with tempfile.TemporaryDirectory() as tmpdir:
            logfile = os.path.join(tmpdir, "mqttgateway.log")
            logger = setup_logging(logfile=logfile, loglevel=3)
            logger.info("should not appear")
            logger.error("should appear")
            for h in logger.handlers:
                h.flush()
            content = open(logfile).read()
            assert "should not appear" not in content
            assert "should appear" in content

    def test_loglevel_map(self):
        assert LOGLEVEL_MAP[0] == logging.CRITICAL + 10  # Off
        assert LOGLEVEL_MAP[3] == logging.ERROR
        assert LOGLEVEL_MAP[4] == logging.WARNING
        assert LOGLEVEL_MAP[6] == logging.INFO
        assert LOGLEVEL_MAP[7] == logging.DEBUG
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_logging_compat.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'mqttgateway.logging_compat'`

- [ ] **Step 3: Implement `sbin/mqttgateway/logging_compat.py`**

```python
"""LoxBerry-compatible logging — matches <TAG> YYYY-MM-DD HH:MM:SS format."""
import logging
import os
from datetime import datetime
from logging.handlers import RotatingFileHandler

# Custom log level for <OK> (between INFO=20 and WARNING=30)
OK = 25
logging.addLevelName(OK, "OK")

# LoxBerry loglevel (0-7) → Python logging level
LOGLEVEL_MAP = {
    0: logging.CRITICAL + 10,  # Off — nothing passes
    3: logging.ERROR,
    4: logging.WARNING,
    6: logging.INFO,
    7: logging.DEBUG,
}

_TAG_MAP = {
    logging.DEBUG: "DEBUG",
    logging.INFO: "INFO",
    OK: "OK",
    logging.WARNING: "WARNING",
    logging.ERROR: "ERROR",
    logging.CRITICAL: "ERROR",
}


class LoxBerryFormatter(logging.Formatter):
    """Format: <TAG> YYYY-MM-DD HH:MM:SS message"""

    def format(self, record: logging.LogRecord) -> str:
        tag = _TAG_MAP.get(record.levelno, "INFO")
        ts = datetime.fromtimestamp(record.created).strftime("%Y-%m-%d %H:%M:%S")
        msg = record.getMessage()
        return f"<{tag}> {ts} {msg}"


def setup_logging(
    logfile: str = "/dev/shm/mqttgateway.log",
    loglevel: int = 7,
) -> logging.Logger:
    """Configure logging with LoxBerry-compatible file output.

    Args:
        logfile: Path to log file (default: /dev/shm/mqttgateway.log)
        loglevel: LoxBerry log level (0=Off, 3=Error, 4=Warn, 6=Info, 7=Debug)

    Returns:
        Configured logger instance.
    """
    logger = logging.getLogger("mqttgateway")
    logger.handlers.clear()

    py_level = LOGLEVEL_MAP.get(loglevel, logging.DEBUG)
    logger.setLevel(py_level)

    formatter = LoxBerryFormatter()

    # File handler with rotation (5 MB, 3 backups)
    os.makedirs(os.path.dirname(logfile), exist_ok=True) if os.path.dirname(logfile) else None
    fh = RotatingFileHandler(logfile, maxBytes=5 * 1024 * 1024, backupCount=3)
    fh.setFormatter(formatter)
    fh.setLevel(py_level)
    logger.addHandler(fh)

    # Stdout handler for systemd journal
    sh = logging.StreamHandler()
    sh.setFormatter(formatter)
    sh.setLevel(py_level)
    logger.addHandler(sh)

    return logger
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_logging_compat.py -v`
Expected: All 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/logging_compat.py sbin/mqttgateway/tests/test_logging_compat.py
git commit -m "feat(mqtt-gw): LoxBerry-compatible logging layer"
```

---

### Task 3: Config loading and V2 parsing

**Files:**
- Create: `sbin/mqttgateway/config.py`
- Create: `sbin/mqttgateway/tests/test_config.py`
- Create: `sbin/mqttgateway/tests/fixtures/general.json`
- Create: `sbin/mqttgateway/tests/fixtures/mqttgateway.json`

The config module reads two JSON files:
- `general.json` — broker host/port/credentials, Miniserver list, UDP ports
- `mqttgateway.json` — V2 subscriptions with @@-notation, conversions, filters

Key behavior:
- Parse `subscriptions_v2[]` array with @@-path notation into lookup structures
- Compile subscription filter regexes at load time
- Build routing map: topic → list of Miniserver numbers
- Detect file changes via mtime polling
- Read plugin configs from `/config/plugins/<name>/mqtt_*.cfg`

- [ ] **Step 1: Create test fixtures**

`sbin/mqttgateway/tests/fixtures/general.json`:
```json
{
    "Mqtt": {
        "Brokerhost": "localhost",
        "Brokerport": "1883",
        "Brokeruser": "loxberry",
        "Brokerpass": "testpass",
        "Udpinport": 11884,
        "Websocketport": "9001",
        "GatewayVersion": 2
    },
    "Miniserver": {
        "1": {
            "Name": "MS_Gen2",
            "Ipaddress": "192.168.30.11",
            "Port": "80",
            "Admin": "admin",
            "Pass": "pass123"
        },
        "2": {
            "Name": "MS_Test",
            "Ipaddress": "192.168.30.12",
            "Port": "80",
            "Admin": "admin",
            "Pass": "pass456"
        }
    }
}
```

`sbin/mqttgateway/tests/fixtures/mqttgateway.json`:
```json
{
    "Main": {
        "msno": 1,
        "udpport": 11883,
        "use_http": "true",
        "use_udp": "false",
        "convert_booleans": "true",
        "resetaftersendms": 13
    },
    "subscriptions_v2": [
        {
            "Id": "tasmota/sensor/temperature",
            "Toms": [1],
            "Noncached": false,
            "resetaftersend": false,
            "Jsonexpand": false,
            "Json": []
        },
        {
            "Id": "zigbee2mqtt/livingroom",
            "Toms": [1, 2],
            "Noncached": false,
            "resetaftersend": false,
            "Jsonexpand": true,
            "Json": [
                {
                    "Id": "temperature",
                    "Toms": [1],
                    "Noncached": false,
                    "resetaftersend": false
                },
                {
                    "Id": "humidity",
                    "Toms": [1, 2],
                    "Noncached": true,
                    "resetaftersend": false
                },
                {
                    "Id": "settings@@led_indication",
                    "Toms": [],
                    "Noncached": false,
                    "resetaftersend": true
                }
            ]
        },
        {
            "Id": "shelly/+/status",
            "Toms": [],
            "Noncached": false,
            "resetaftersend": false,
            "Jsonexpand": true,
            "Json": [
                {
                    "Id": "sys@@available_updates@@stable@@version",
                    "Toms": [1],
                    "Noncached": false,
                    "resetaftersend": false
                }
            ]
        }
    ],
    "conversions": ["ON=1", "OFF=0", "online=1", "offline=0"],
    "subscriptionfilters": ["^tasmota_tele_.*_STATE$"],
    "doNotForward": {
        "tasmota_debug_heap": "true"
    },
    "Noncached": {},
    "resetAfterSend": {}
}
```

- [ ] **Step 2: Write failing tests**

```python
# sbin/mqttgateway/tests/test_config.py
import json
import os
import re
import tempfile
import time
import pytest
from pathlib import Path
from mqttgateway.config import GatewayConfig, parse_aa_path, Subscription, JsonField


FIXTURES = Path(__file__).parent / "fixtures"


class TestParseAAPath:
    """Test the @@-path notation parser."""

    def test_simple_key(self):
        assert parse_aa_path("temperature") == ["temperature"]

    def test_nested_key(self):
        assert parse_aa_path("settings@@led_indication") == ["settings", "led_indication"]

    def test_array_index(self):
        assert parse_aa_path("rollen@@[3]@@rolle") == ["rollen", 3, "rolle"]

    def test_top_level_array(self):
        assert parse_aa_path("@@[0]@@id") == [0, "id"]

    def test_deep_nesting(self):
        assert parse_aa_path("sys@@available_updates@@stable@@version") == [
            "sys", "available_updates", "stable", "version"
        ]

    def test_consecutive_arrays(self):
        assert parse_aa_path("data@@[0]@@[1]") == ["data", 0, 1]


class TestGatewayConfig:
    def _make_config(self, tmpdir, general=None, gateway=None):
        """Helper to create config files in tmpdir."""
        gen_path = os.path.join(tmpdir, "general.json")
        gw_path = os.path.join(tmpdir, "mqttgateway.json")

        gen_data = general or json.load(open(FIXTURES / "general.json"))
        gw_data = gateway or json.load(open(FIXTURES / "mqttgateway.json"))

        with open(gen_path, "w") as f:
            json.dump(gen_data, f)
        with open(gw_path, "w") as f:
            json.dump(gw_data, f)

        return gen_path, gw_path

    def test_load_broker_config(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert cfg.broker_host == "localhost"
            assert cfg.broker_port == 1883
            assert cfg.broker_user == "loxberry"
            assert cfg.broker_pass == "testpass"

    def test_load_miniserver_list(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert 1 in cfg.miniservers
            assert cfg.miniservers[1]["Name"] == "MS_Gen2"
            assert cfg.miniservers[1]["Ipaddress"] == "192.168.30.11"

    def test_load_v2_subscriptions(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert len(cfg.subscriptions) == 3
            assert cfg.subscriptions[0].topic == "tasmota/sensor/temperature"
            assert cfg.subscriptions[0].json_expand is False

    def test_subscription_toms_default(self):
        """Empty Toms should default to Main.msno."""
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            # shelly/+/status has Toms: [] — should default to [1]
            shelly = cfg.subscriptions[2]
            assert shelly.toms == [1]

    def test_subscription_json_fields_parsed(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            zigbee = cfg.subscriptions[1]
            assert len(zigbee.json_fields) == 3
            assert zigbee.json_fields[0].path == ["temperature"]
            assert zigbee.json_fields[2].path == ["settings", "led_indication"]
            assert zigbee.json_fields[2].reset_after_send is True

    def test_conversions_parsed(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert cfg.conversions["ON"] == "1"
            assert cfg.conversions["OFF"] == "0"
            assert cfg.conversions["online"] == "1"

    def test_subscription_filters_compiled(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert len(cfg.subscription_filters) == 1
            pattern = cfg.subscription_filters[0]
            assert isinstance(pattern, re.Pattern)
            assert pattern.match("tasmota_tele_abc_STATE")
            assert not pattern.match("zigbee2mqtt_something")

    def test_do_not_forward(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert "tasmota_debug_heap" in cfg.do_not_forward

    def test_default_values(self):
        """Missing Main fields should get defaults."""
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_data = json.load(open(FIXTURES / "general.json"))
            gw_data = {"Main": {}, "subscriptions_v2": []}
            gen_path, gw_path = self._make_config(tmpdir, gen_data, gw_data)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert cfg.default_ms == 1
            assert cfg.udp_port == 11883
            assert cfg.reset_after_send_ms == 13
            assert cfg.convert_booleans is True

    def test_has_changed_detects_mtime(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert cfg.has_changed() is False
            # Touch the gateway config
            time.sleep(0.05)
            Path(gw_path).touch()
            assert cfg.has_changed() is True

    def test_reload_picks_up_changes(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            gen_path, gw_path = self._make_config(tmpdir)
            cfg = GatewayConfig(gen_path, gw_path)
            cfg.load()
            assert len(cfg.subscriptions) == 3
            # Modify config
            gw_data = json.load(open(gw_path))
            gw_data["subscriptions_v2"] = []
            with open(gw_path, "w") as f:
                json.dump(gw_data, f)
            cfg.load()
            assert len(cfg.subscriptions) == 0


class TestPluginConfigs:
    def test_read_plugin_subscriptions(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create plugin config dir
            plugin_dir = os.path.join(tmpdir, "plugins", "myplugin")
            os.makedirs(plugin_dir)
            with open(os.path.join(plugin_dir, "mqtt_subscriptions.cfg"), "w") as f:
                f.write("myplugin/sensor/#\nmyplugin/status\n")
            with open(os.path.join(plugin_dir, "mqtt_conversions.cfg"), "w") as f:
                f.write("yes=1\nno=0\n")
            with open(os.path.join(plugin_dir, "mqtt_resetaftersend.cfg"), "w") as f:
                f.write("myplugin/trigger\n")

            gen_path, gw_path = TestGatewayConfig._make_config(
                None, tmpdir,
                json.load(open(FIXTURES / "general.json")),
                json.load(open(FIXTURES / "mqttgateway.json")),
            )
            cfg = GatewayConfig(gen_path, gw_path, plugin_config_dir=plugin_dir + "/..")
            cfg.load()
            assert "myplugin/sensor/#" in cfg.plugin_subscriptions
            assert cfg.conversions["yes"] == "1"
            assert "myplugin/trigger" in cfg.plugin_reset_after_send
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_config.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'mqttgateway.config'`

- [ ] **Step 4: Implement `sbin/mqttgateway/config.py`**

```python
"""Config loading for MQTT Gateway V2.

Reads general.json and mqttgateway.json, parses V2 subscriptions with
@@-path notation, compiles regex filters, builds routing maps.
"""
from __future__ import annotations

import json
import logging
import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

log = logging.getLogger("mqttgateway")


def parse_aa_path(path_str: str) -> list[str | int]:
    """Parse @@-delimited path notation into list of keys/indices.

    Examples:
        "temperature"                        -> ["temperature"]
        "settings@@led_indication"           -> ["settings", "led_indication"]
        "rollen@@[3]@@rolle"                 -> ["rollen", 3, "rolle"]
        "@@[0]@@id"                          -> [0, "id"]
    """
    parts: list[str | int] = []
    for segment in path_str.split("@@"):
        if not segment:
            continue
        if segment.startswith("[") and segment.endswith("]"):
            parts.append(int(segment[1:-1]))
        else:
            parts.append(segment)
    return parts


def extract_by_path(data: Any, path: list[str | int]) -> Any:
    """Navigate into nested JSON using a parsed @@-path.

    Returns the value at the path, or raises KeyError/IndexError/TypeError.
    """
    current = data
    for key in path:
        if isinstance(key, int):
            current = current[key]
        else:
            current = current[key]
    return current


@dataclass
class JsonField:
    """A single JSON field selector within a V2 subscription."""
    id_raw: str
    path: list[str | int]
    toms: list[int]
    noncached: bool = False
    reset_after_send: bool = False


@dataclass
class Subscription:
    """A V2 subscription entry."""
    topic: str
    toms: list[int]
    noncached: bool = False
    reset_after_send: bool = False
    json_expand: bool = False
    json_fields: list[JsonField] = field(default_factory=list)


def _is_enabled(val: Any) -> bool:
    """Match LoxBerry's is_enabled() behavior."""
    if isinstance(val, bool):
        return val
    if isinstance(val, str):
        return val.lower() in ("true", "yes", "on", "1", "enabled")
    if isinstance(val, (int, float)):
        return val != 0
    return False


class GatewayConfig:
    """Loads and caches MQTT Gateway configuration."""

    def __init__(
        self,
        general_json_path: str,
        gateway_json_path: str,
        plugin_config_dir: str | None = None,
    ):
        self._general_path = general_json_path
        self._gateway_path = gateway_json_path
        self._plugin_config_dir = plugin_config_dir

        # Broker
        self.broker_host: str = "localhost"
        self.broker_port: int = 1883
        self.broker_user: str = ""
        self.broker_pass: str = ""
        self.udp_in_port: int = 11884

        # Miniservers
        self.miniservers: dict[int, dict] = {}

        # Gateway main settings
        self.default_ms: int = 1
        self.udp_port: int = 11883
        self.use_http: bool = True
        self.use_udp: bool = False
        self.convert_booleans: bool = True
        self.reset_after_send_ms: int = 13

        # V2 subscriptions
        self.subscriptions: list[Subscription] = []

        # Conversions: text -> replacement
        self.conversions: dict[str, str] = {}

        # Compiled regex filters
        self.subscription_filters: list[re.Pattern] = []

        # Do-not-forward set (topic_underlined -> True)
        self.do_not_forward: set[str] = set()

        # Plugin data
        self.plugin_subscriptions: list[str] = []
        self.plugin_reset_after_send: set[str] = set()

        # mtime tracking for change detection
        self._mtimes: dict[str, float] = {}

    def load(self) -> None:
        """Load or reload all config files."""
        self._load_general()
        self._load_gateway()
        self._load_plugins()
        self._snapshot_mtimes()

    def has_changed(self) -> bool:
        """Check if any config file has been modified since last load."""
        for path, old_mtime in self._mtimes.items():
            try:
                if os.path.getmtime(path) != old_mtime:
                    return True
            except OSError:
                return True
        return False

    def _snapshot_mtimes(self) -> None:
        for path in [self._general_path, self._gateway_path]:
            try:
                self._mtimes[path] = os.path.getmtime(path)
            except OSError:
                self._mtimes[path] = 0

    def _load_general(self) -> None:
        with open(self._general_path) as f:
            data = json.load(f)

        mqtt = data.get("Mqtt", {})
        self.broker_host = mqtt.get("Brokerhost", "localhost")
        self.broker_port = int(mqtt.get("Brokerport", 1883))
        self.broker_user = mqtt.get("Brokeruser", "")
        self.broker_pass = mqtt.get("Brokerpass", "")
        self.udp_in_port = int(mqtt.get("Udpinport", 11884))

        # Miniservers
        self.miniservers = {}
        for key, ms_data in data.get("Miniserver", {}).items():
            self.miniservers[int(key)] = ms_data

    def _load_gateway(self) -> None:
        try:
            with open(self._gateway_path) as f:
                data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            data = {}

        main = data.get("Main", {})
        self.default_ms = int(main.get("msno", 1))
        self.udp_port = int(main.get("udpport", 11883))
        self.use_http = _is_enabled(main.get("use_http", True))
        self.use_udp = _is_enabled(main.get("use_udp", False))
        self.convert_booleans = _is_enabled(main.get("convert_booleans", True))
        ras_ms = main.get("resetaftersendms", 13)
        self.reset_after_send_ms = max(1, int(ras_ms)) if ras_ms else 13

        # V2 Subscriptions
        self.subscriptions = []
        for sub_data in data.get("subscriptions_v2", []):
            json_fields = []
            for jf in sub_data.get("Json", []):
                jf_toms = jf.get("Toms", [])
                if not jf_toms:
                    jf_toms = [self.default_ms]
                json_fields.append(JsonField(
                    id_raw=jf["Id"],
                    path=parse_aa_path(jf["Id"]),
                    toms=jf_toms,
                    noncached=_is_enabled(jf.get("Noncached", False)),
                    reset_after_send=_is_enabled(jf.get("resetaftersend", False)),
                ))

            toms = sub_data.get("Toms", [])
            if not toms:
                toms = [self.default_ms]

            self.subscriptions.append(Subscription(
                topic=sub_data["Id"],
                toms=toms,
                noncached=_is_enabled(sub_data.get("Noncached", False)),
                reset_after_send=_is_enabled(sub_data.get("resetaftersend", False)),
                json_expand=_is_enabled(sub_data.get("Jsonexpand", False)),
                json_fields=json_fields,
            ))

        # Conversions
        self.conversions = {}
        for entry in data.get("conversions", []):
            if "=" in entry:
                text, value = entry.split("=", 1)
                self.conversions[text.strip()] = value.strip()

        # Subscription filters — compile regexes
        self.subscription_filters = []
        for pattern in data.get("subscriptionfilters", []):
            pattern = pattern.strip()
            if not pattern:
                continue
            try:
                self.subscription_filters.append(re.compile(pattern))
            except re.error:
                log.warning("Invalid subscription filter regex: %s", pattern)

        # Do-not-forward
        self.do_not_forward = set()
        for topic, enabled in data.get("doNotForward", {}).items():
            if _is_enabled(enabled):
                self.do_not_forward.add(topic)

    def _load_plugins(self) -> None:
        """Read plugin mqtt_*.cfg files."""
        self.plugin_subscriptions = []
        self.plugin_reset_after_send = set()

        if not self._plugin_config_dir:
            return

        plugin_base = Path(self._plugin_config_dir)
        if not plugin_base.exists():
            return

        for plugin_dir in plugin_base.iterdir():
            if not plugin_dir.is_dir():
                continue

            # Subscriptions
            sub_file = plugin_dir / "mqtt_subscriptions.cfg"
            if sub_file.exists():
                for line in sub_file.read_text().splitlines():
                    line = line.strip()
                    if line:
                        self.plugin_subscriptions.append(line)

            # Conversions
            conv_file = plugin_dir / "mqtt_conversions.cfg"
            if conv_file.exists():
                for line in conv_file.read_text().splitlines():
                    line = line.strip()
                    if line and "=" in line:
                        text, value = line.split("=", 1)
                        self.conversions[text.strip()] = value.strip()

            # Reset after send
            ras_file = plugin_dir / "mqtt_resetaftersend.cfg"
            if ras_file.exists():
                for line in ras_file.read_text().splitlines():
                    line = line.strip()
                    if line:
                        self.plugin_reset_after_send.add(line)
```

- [ ] **Step 5: Fix test helper to work as staticmethod**

The `TestPluginConfigs` test calls `TestGatewayConfig._make_config` — update the `_make_config` method signature to also accept being called as a static helper (first param `self` or `cls` optional). Simplest: make it a standalone function:

Move `_make_config` to a module-level helper in the test file:

```python
def make_config(tmpdir, general=None, gateway=None):
    """Helper to create config files in tmpdir."""
    gen_path = os.path.join(tmpdir, "general.json")
    gw_path = os.path.join(tmpdir, "mqttgateway.json")

    gen_data = general or json.load(open(FIXTURES / "general.json"))
    gw_data = gateway or json.load(open(FIXTURES / "mqttgateway.json"))

    with open(gen_path, "w") as f:
        json.dump(gen_data, f)
    with open(gw_path, "w") as f:
        json.dump(gw_data, f)

    return gen_path, gw_path
```

Replace all `self._make_config(tmpdir)` calls with `make_config(tmpdir)` and `TestGatewayConfig._make_config(None, tmpdir, ...)` with `make_config(tmpdir, ...)`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_config.py -v`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add sbin/mqttgateway/config.py sbin/mqttgateway/tests/test_config.py sbin/mqttgateway/tests/fixtures/
git commit -m "feat(mqtt-gw): config loading with V2 subscription parsing"
```

---

### Task 4: Message pipeline — early filter and debounce

**Files:**
- Create: `sbin/mqttgateway/pipeline.py`
- Create: `sbin/mqttgateway/tests/test_pipeline.py`

The pipeline processes incoming MQTT messages through stages. This task implements stages 1 (Early Filter) and 2 (Topic Debounce).

- [ ] **Step 1: Write failing tests**

```python
# sbin/mqttgateway/tests/test_pipeline.py
import re
import pytest
from mqttgateway.pipeline import Pipeline, PipelineResult


class TestEarlyFilter:
    def _make_pipeline(self, **kwargs):
        return Pipeline(
            hostname=kwargs.get("hostname", "loxberry"),
            do_not_forward=kwargs.get("do_not_forward", set()),
            subscription_filters=kwargs.get("subscription_filters", []),
        )

    def test_filters_gateway_own_topics(self):
        p = self._make_pipeline()
        result = p.process("loxberry/mqttgateway/pollms", "42")
        assert result is None

    def test_filters_gateway_status(self):
        p = self._make_pipeline()
        result = p.process("loxberry/mqttgateway/status", "Connected")
        assert result is None

    def test_passes_normal_topic(self):
        p = self._make_pipeline()
        result = p.process("tasmota/sensor/temp", "22.5")
        assert result is not None

    def test_filters_do_not_forward(self):
        p = self._make_pipeline(do_not_forward={"tasmota_debug_heap"})
        result = p.process("tasmota/debug/heap", "12345")
        assert result is None

    def test_filters_regex_match(self):
        filters = [re.compile(r"^tasmota_tele_.*_STATE$")]
        p = self._make_pipeline(subscription_filters=filters)
        result = p.process("tasmota/tele/plug1/STATE", '{"POWER":"ON"}')
        assert result is None

    def test_passes_regex_non_match(self):
        filters = [re.compile(r"^tasmota_tele_.*_STATE$")]
        p = self._make_pipeline(subscription_filters=filters)
        result = p.process("tasmota/stat/plug1/POWER", "ON")
        assert result is not None


class TestDebounce:
    def _make_pipeline(self):
        return Pipeline(hostname="loxberry")

    def test_first_message_passes(self):
        p = self._make_pipeline()
        result = p.process("sensor/temp", "22.5")
        assert result is not None

    def test_duplicate_message_filtered(self):
        p = self._make_pipeline()
        p.process("sensor/temp", "22.5")
        result = p.process("sensor/temp", "22.5")
        assert result is None

    def test_changed_value_passes(self):
        p = self._make_pipeline()
        p.process("sensor/temp", "22.5")
        result = p.process("sensor/temp", "23.0")
        assert result is not None

    def test_different_topic_passes(self):
        p = self._make_pipeline()
        p.process("sensor/temp", "22.5")
        result = p.process("sensor/humidity", "22.5")
        assert result is not None

    def test_debounce_cache_independent_topics(self):
        p = self._make_pipeline()
        p.process("a", "1")
        p.process("b", "2")
        # Resending same values
        assert p.process("a", "1") is None
        assert p.process("b", "2") is None
        # Changed values
        assert p.process("a", "2") is not None
        assert p.process("b", "3") is not None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_pipeline.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'mqttgateway.pipeline'`

- [ ] **Step 3: Implement pipeline with early filter and debounce**

```python
"""Message pipeline: processes incoming MQTT messages through filter/debounce/expand/convert/route stages."""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Any

log = logging.getLogger("mqttgateway")


@dataclass
class SendItem:
    """A single value to send to a Miniserver."""
    topic_underlined: str  # Topic with / and % replaced by _
    original_topic: str
    value: str
    toms: list[int]
    noncached: bool = False
    reset_after_send: bool = False


@dataclass
class PipelineResult:
    """Result of processing one MQTT message through the pipeline."""
    items: list[SendItem] = field(default_factory=list)


def _underline_topic(topic: str) -> str:
    """Replace / and % with _ for Miniserver VI names."""
    return topic.replace("/", "_").replace("%", "_")


class Pipeline:
    """Stateful message processing pipeline.

    Holds debounce cache and filter config. Instantiated once,
    called per message.
    """

    def __init__(
        self,
        hostname: str = "loxberry",
        do_not_forward: set[str] | None = None,
        subscription_filters: list[re.Pattern] | None = None,
        convert_booleans: bool = True,
        conversions: dict[str, str] | None = None,
        subscriptions: list | None = None,
        default_ms: int = 1,
    ):
        self.hostname = hostname
        self.do_not_forward = do_not_forward or set()
        self.subscription_filters = subscription_filters or []
        self.convert_booleans = convert_booleans
        self.conversions = conversions or {}
        self.subscriptions = subscriptions or []
        self.default_ms = default_ms

        # Debounce cache: topic -> last payload
        self._debounce: dict[str, str] = {}

    def process(self, topic: str, payload: str) -> PipelineResult | None:
        """Run a message through all pipeline stages.

        Returns None if the message was filtered/debounced.
        """
        # --- Stage 1: Early Filter ---
        gw_prefix = f"{self.hostname}/mqttgateway/"
        if topic.startswith(gw_prefix):
            return None

        topic_underlined = _underline_topic(topic)

        if topic_underlined in self.do_not_forward:
            log.debug("Filtered (doNotForward): %s", topic)
            return None

        for pattern in self.subscription_filters:
            if pattern.search(topic_underlined):
                log.debug("Filtered (regex): %s", topic)
                return None

        # --- Stage 2: Debounce ---
        if self._debounce.get(topic) == payload:
            return None
        self._debounce[topic] = payload

        # --- Stages 3-5 are implemented in later tasks ---
        # For now, return a basic result
        result = PipelineResult()
        result.items.append(SendItem(
            topic_underlined=topic_underlined,
            original_topic=topic,
            value=payload,
            toms=[self.default_ms],
        ))
        return result
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_pipeline.py -v`
Expected: All 11 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/pipeline.py sbin/mqttgateway/tests/test_pipeline.py
git commit -m "feat(mqtt-gw): pipeline early filter + debounce"
```

---

### Task 5: Pipeline — JSON expansion with @@-notation

**Files:**
- Modify: `sbin/mqttgateway/pipeline.py`
- Modify: `sbin/mqttgateway/tests/test_pipeline.py`

Adds Stage 3: Targeted JSON field extraction using V2 @@-path notation. Instead of flattening the entire JSON payload, only configured fields are extracted.

- [ ] **Step 1: Write failing tests**

Append to `sbin/mqttgateway/tests/test_pipeline.py`:

```python
from mqttgateway.config import Subscription, JsonField, parse_aa_path


class TestJsonExpansion:
    def _make_pipeline(self, subscriptions):
        return Pipeline(
            hostname="loxberry",
            subscriptions=subscriptions,
            default_ms=1,
        )

    def test_no_expansion_when_disabled(self):
        subs = [Subscription(
            topic="sensor/temp", toms=[1], json_expand=False, json_fields=[],
        )]
        p = self._make_pipeline(subs)
        result = p.process("sensor/temp", '{"temperature": 22.5}')
        assert len(result.items) == 1
        assert result.items[0].value == '{"temperature": 22.5}'

    def test_expand_specific_fields(self):
        subs = [Subscription(
            topic="zigbee/living", toms=[1], json_expand=True,
            json_fields=[
                JsonField(id_raw="temperature", path=["temperature"], toms=[1]),
                JsonField(id_raw="humidity", path=["humidity"], toms=[1]),
            ],
        )]
        p = self._make_pipeline(subs)
        payload = '{"temperature": 22.5, "humidity": 55, "battery": 98}'
        result = p.process("zigbee/living", payload)
        # Should extract only temperature and humidity, not battery
        topics = {item.topic_underlined: item.value for item in result.items}
        assert "zigbee_living_temperature" in topics
        assert topics["zigbee_living_temperature"] == "22.5"
        assert "zigbee_living_humidity" in topics
        assert topics["zigbee_living_humidity"] == "55"
        assert "zigbee_living_battery" not in topics

    def test_expand_nested_field(self):
        subs = [Subscription(
            topic="shelly/status", toms=[1], json_expand=True,
            json_fields=[
                JsonField(
                    id_raw="sys@@available_updates@@stable@@version",
                    path=["sys", "available_updates", "stable", "version"],
                    toms=[1],
                ),
            ],
        )]
        p = self._make_pipeline(subs)
        payload = '{"sys": {"available_updates": {"stable": {"version": "1.2.3"}}}}'
        result = p.process("shelly/status", payload)
        assert len(result.items) == 1
        item = result.items[0]
        assert item.topic_underlined == "shelly_status_sys_available_updates_stable_version"
        assert item.value == "1.2.3"

    def test_expand_array_index(self):
        subs = [Subscription(
            topic="test/data", toms=[1], json_expand=True,
            json_fields=[
                JsonField(
                    id_raw="rollen@@[0]",
                    path=["rollen", 0],
                    toms=[1],
                ),
                JsonField(
                    id_raw="rollen@@[1]@@name",
                    path=["rollen", 1, "name"],
                    toms=[1],
                ),
            ],
        )]
        p = self._make_pipeline(subs)
        payload = '{"rollen": ["admin", {"name": "editor", "level": 2}]}'
        result = p.process("test/data", payload)
        topics = {item.topic_underlined: item.value for item in result.items}
        assert topics["test_data_rollen_0"] == "admin"
        assert topics["test_data_rollen_1_name"] == "editor"

    def test_expand_missing_field_skipped(self):
        """If a configured field doesn't exist in the payload, skip it."""
        subs = [Subscription(
            topic="sensor/data", toms=[1], json_expand=True,
            json_fields=[
                JsonField(id_raw="temperature", path=["temperature"], toms=[1]),
                JsonField(id_raw="missing_field", path=["missing_field"], toms=[1]),
            ],
        )]
        p = self._make_pipeline(subs)
        payload = '{"temperature": 22.5}'
        result = p.process("sensor/data", payload)
        assert len(result.items) == 1
        assert result.items[0].topic_underlined == "sensor_data_temperature"

    def test_expand_non_json_payload(self):
        """If expansion is enabled but payload is not JSON, pass through as-is."""
        subs = [Subscription(
            topic="sensor/temp", toms=[1], json_expand=True,
            json_fields=[
                JsonField(id_raw="value", path=["value"], toms=[1]),
            ],
        )]
        p = self._make_pipeline(subs)
        result = p.process("sensor/temp", "plain text value")
        assert len(result.items) == 1
        assert result.items[0].value == "plain text value"

    def test_expand_per_field_toms(self):
        """Each JSON field can route to different Miniservers."""
        subs = [Subscription(
            topic="multi/ms", toms=[1], json_expand=True,
            json_fields=[
                JsonField(id_raw="temp", path=["temp"], toms=[1]),
                JsonField(id_raw="hum", path=["hum"], toms=[2]),
            ],
        )]
        p = self._make_pipeline(subs)
        payload = '{"temp": 22.5, "hum": 55}'
        result = p.process("multi/ms", payload)
        toms_map = {item.topic_underlined: item.toms for item in result.items}
        assert toms_map["multi_ms_temp"] == [1]
        assert toms_map["multi_ms_hum"] == [2]

    def test_expand_per_field_noncached_and_ras(self):
        subs = [Subscription(
            topic="test/flags", toms=[1], json_expand=True,
            json_fields=[
                JsonField(id_raw="cached_val", path=["cached_val"], toms=[1],
                          noncached=False, reset_after_send=False),
                JsonField(id_raw="trigger", path=["trigger"], toms=[1],
                          noncached=True, reset_after_send=True),
            ],
        )]
        p = self._make_pipeline(subs)
        payload = '{"cached_val": "100", "trigger": "1"}'
        result = p.process("test/flags", payload)
        by_topic = {item.topic_underlined: item for item in result.items}
        assert by_topic["test_flags_cached_val"].noncached is False
        assert by_topic["test_flags_trigger"].noncached is True
        assert by_topic["test_flags_trigger"].reset_after_send is True

    def test_wildcard_json_expand_all(self):
        """Json: ["*"] should expand all top-level fields."""
        subs = [Subscription(
            topic="wildcard/test", toms=[1], json_expand=True,
            json_fields=[
                JsonField(id_raw="*", path=["*"], toms=[1]),
            ],
        )]
        p = self._make_pipeline(subs)
        payload = '{"a": 1, "b": 2, "c": 3}'
        result = p.process("wildcard/test", payload)
        topics = {item.topic_underlined for item in result.items}
        assert topics == {"wildcard_test_a", "wildcard_test_b", "wildcard_test_c"}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_pipeline.py::TestJsonExpansion -v`
Expected: FAIL — tests call methods/logic not yet implemented.

- [ ] **Step 3: Implement JSON expansion in pipeline**

Update `sbin/mqttgateway/pipeline.py` — modify the `process()` method to add Stage 3 between debounce and the final return. Add a helper `_find_subscription()` and `_expand_json()`:

```python
import json as json_module
from mqttgateway.config import Subscription, JsonField, extract_by_path

# Add to Pipeline class:

def _find_subscription(self, topic: str) -> Subscription | None:
    """Find the matching V2 subscription for a topic.

    Supports MQTT wildcards: + (single level) and # (multi level).
    """
    for sub in self.subscriptions:
        if self._topic_matches(sub.topic, topic):
            return sub
    return None

@staticmethod
def _topic_matches(pattern: str, topic: str) -> bool:
    """Check if an MQTT topic matches a subscription pattern."""
    if pattern == "#":
        return True
    pat_parts = pattern.split("/")
    top_parts = topic.split("/")
    for i, pat in enumerate(pat_parts):
        if pat == "#":
            return True  # # matches rest
        if i >= len(top_parts):
            return False
        if pat == "+":
            continue  # + matches one level
        if pat != top_parts[i]:
            return False
    return len(pat_parts) == len(top_parts)

def _expand_json(
    self, topic: str, payload: str, sub: Subscription,
) -> list[SendItem]:
    """Extract configured JSON fields from payload."""
    try:
        data = json_module.loads(payload)
    except (json_module.JSONDecodeError, TypeError):
        # Not valid JSON — pass through as-is
        return [SendItem(
            topic_underlined=_underline_topic(topic),
            original_topic=topic,
            value=payload,
            toms=sub.toms,
            noncached=sub.noncached,
            reset_after_send=sub.reset_after_send,
        )]

    if not isinstance(data, (dict, list)):
        return [SendItem(
            topic_underlined=_underline_topic(topic),
            original_topic=topic,
            value=str(data),
            toms=sub.toms,
        )]

    items: list[SendItem] = []

    for jf in sub.json_fields:
        # Wildcard: expand all top-level keys
        if jf.id_raw == "*" and isinstance(data, dict):
            for key, val in data.items():
                expanded_topic = f"{topic}/{key}"
                items.append(SendItem(
                    topic_underlined=_underline_topic(expanded_topic),
                    original_topic=expanded_topic,
                    value=str(val),
                    toms=jf.toms,
                    noncached=jf.noncached,
                    reset_after_send=jf.reset_after_send,
                ))
            continue

        # Extract specific path
        try:
            value = extract_by_path(data, jf.path)
        except (KeyError, IndexError, TypeError):
            log.debug("JSON field %s not found in %s", jf.id_raw, topic)
            continue

        # Build expanded topic: topic/path_part1/path_part2/...
        path_suffix = "/".join(str(p) for p in jf.path)
        expanded_topic = f"{topic}/{path_suffix}"

        items.append(SendItem(
            topic_underlined=_underline_topic(expanded_topic),
            original_topic=expanded_topic,
            value=str(value),
            toms=jf.toms,
            noncached=jf.noncached,
            reset_after_send=jf.reset_after_send,
        ))

    return items
```

Update the `process()` method — replace the placeholder Stage 3-5 section:

```python
# --- Stage 3: JSON Expansion ---
sub = self._find_subscription(topic)

if sub and sub.json_expand and sub.json_fields:
    items = self._expand_json(topic, payload, sub)
    if items:
        result = PipelineResult(items=items)
        return result
    return None

# No expansion — pass through as single item
result = PipelineResult()
toms = sub.toms if sub else [self.default_ms]
noncached = sub.noncached if sub else False
ras = sub.reset_after_send if sub else False
result.items.append(SendItem(
    topic_underlined=topic_underlined,
    original_topic=topic,
    value=payload,
    toms=toms,
    noncached=noncached,
    reset_after_send=ras,
))
return result
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_pipeline.py -v`
Expected: All tests PASS (early filter + debounce + json expansion).

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/pipeline.py sbin/mqttgateway/tests/test_pipeline.py
git commit -m "feat(mqtt-gw): pipeline JSON expansion with @@-notation"
```

---

### Task 6: Pipeline — boolean conversion and user conversions

**Files:**
- Modify: `sbin/mqttgateway/pipeline.py`
- Modify: `sbin/mqttgateway/tests/test_pipeline.py`

Adds Stage 4: Convert booleans (`true/false` -> `1/0`) and apply user-defined conversions (`ON=1`, `OFF=0` etc.).

- [ ] **Step 1: Write failing tests**

Append to `sbin/mqttgateway/tests/test_pipeline.py`:

```python
class TestConversions:
    def test_boolean_true_to_1(self):
        p = Pipeline(hostname="loxberry", convert_booleans=True)
        result = p.process("sensor/switch", "true")
        assert result.items[0].value == "1"

    def test_boolean_false_to_0(self):
        p = Pipeline(hostname="loxberry", convert_booleans=True)
        result = p.process("sensor/switch", "false")
        assert result.items[0].value == "0"

    def test_boolean_conversion_disabled(self):
        p = Pipeline(hostname="loxberry", convert_booleans=False)
        result = p.process("sensor/switch", "true")
        assert result.items[0].value == "true"

    def test_user_conversion(self):
        p = Pipeline(hostname="loxberry", conversions={"ON": "1", "OFF": "0"})
        result = p.process("tasmota/stat/power", "ON")
        assert result.items[0].value == "1"

    def test_user_conversion_off(self):
        p = Pipeline(hostname="loxberry", conversions={"ON": "1", "OFF": "0"})
        result = p.process("tasmota/stat/power", "OFF")
        assert result.items[0].value == "0"

    def test_no_conversion_for_unknown(self):
        p = Pipeline(hostname="loxberry", conversions={"ON": "1", "OFF": "0"})
        result = p.process("sensor/temp", "22.5")
        assert result.items[0].value == "22.5"

    def test_boolean_before_user_conversion(self):
        """Boolean conversion happens before user conversions."""
        p = Pipeline(hostname="loxberry", convert_booleans=True, conversions={"1": "100"})
        result = p.process("sensor/switch", "true")
        # true -> 1 (boolean) -> 100 (user conversion)
        assert result.items[0].value == "100"

    def test_conversion_applied_to_expanded_json(self):
        subs = [Subscription(
            topic="sensor/data", toms=[1], json_expand=True,
            json_fields=[
                JsonField(id_raw="status", path=["status"], toms=[1]),
            ],
        )]
        p = Pipeline(
            hostname="loxberry", subscriptions=subs,
            convert_booleans=True, conversions={"online": "1"},
        )
        result = p.process("sensor/data", '{"status": "online"}')
        assert result.items[0].value == "1"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_pipeline.py::TestConversions -v`
Expected: FAIL — boolean/user conversions not yet applied.

- [ ] **Step 3: Add conversion logic to pipeline**

Add a `_convert_value()` method to `Pipeline` and call it on every `SendItem.value` after JSON expansion:

```python
# Add to Pipeline class:

def _convert_value(self, value: str) -> str:
    """Apply boolean conversion and user-defined conversions."""
    if self.convert_booleans:
        low = value.lower().strip()
        if low in ("true", "yes", "on"):
            value = "1"
        elif low in ("false", "no", "off"):
            value = "0"

    stripped = value.strip()
    if stripped in self.conversions:
        value = self.conversions[stripped]

    return value
```

In `process()`, after building `result.items`, apply conversion to each item:

```python
for item in result.items:
    item.value = self._convert_value(item.value)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_pipeline.py -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/pipeline.py sbin/mqttgateway/tests/test_pipeline.py
git commit -m "feat(mqtt-gw): pipeline boolean + user conversions"
```

---

### Task 7: Miniserver HTTP delta-send

**Files:**
- Create: `sbin/mqttgateway/miniserver.py`
- Create: `sbin/mqttgateway/tests/test_miniserver.py`

Implements async HTTP delta-send with httpx. Only changed values are sent. Supports multiple Miniservers with per-MS connection pools and caches.

- [ ] **Step 1: Write failing tests**

```python
# sbin/mqttgateway/tests/test_miniserver.py
import asyncio
import pytest
import httpx
from unittest.mock import AsyncMock, patch, MagicMock
from mqttgateway.miniserver import MiniserverSender


@pytest.fixture
def ms_config():
    return {
        1: {
            "Name": "MS_Gen2",
            "Ipaddress": "192.168.30.11",
            "Port": "80",
            "Admin": "admin",
            "Pass": "pass123",
        },
    }


class TestDeltaCache:
    @pytest.mark.asyncio
    async def test_first_send_goes_through(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            mock_send.assert_called_once()

    @pytest.mark.asyncio
    async def test_duplicate_value_not_resent(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            await sender.send_cached(1, {"topic_a": "value1"})
            assert mock_send.call_count == 1

    @pytest.mark.asyncio
    async def test_changed_value_resent(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            mock_send.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value2"})
            assert mock_send.call_count == 2

    @pytest.mark.asyncio
    async def test_full_refresh_resends_all(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            sender.invalidate_cache(1)
            await sender.send_cached(1, {"topic_a": "value1"})
            assert mock_send.call_count == 2


class TestNoncachedSend:
    @pytest.mark.asyncio
    async def test_noncached_always_sends(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock_send:
            mock_send.return_value = {"topic_a": {"code": 200}}
            await sender.send_noncached(1, {"topic_a": "value1"})
            await sender.send_noncached(1, {"topic_a": "value1"})
            assert mock_send.call_count == 2


class TestTopicSanitization:
    def test_slash_and_percent_replaced(self):
        assert MiniserverSender.sanitize_topic("tasmota/sensor/temp") == "tasmota_sensor_temp"
        assert MiniserverSender.sanitize_topic("a%b/c") == "a_b_c"


class TestUdpSend:
    @pytest.mark.asyncio
    async def test_udp_send_format(self):
        """UDP sends topic=value format."""
        transport = MagicMock()
        sender = MiniserverSender({1: {"Ipaddress": "192.168.30.11"}})
        sender._udp_transports = {1: (transport, ("192.168.30.11", 11883))}
        await sender.send_udp(1, 11883, {"sensor_temp": "22.5"})
        transport.sendto.assert_called()
        sent_data = transport.sendto.call_args[0][0]
        assert b"sensor_temp=22.5" in sent_data
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_miniserver.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'mqttgateway.miniserver'`

- [ ] **Step 3: Implement `sbin/mqttgateway/miniserver.py`**

```python
"""Miniserver communication — async HTTP delta-send + UDP."""
from __future__ import annotations

import asyncio
import logging
import urllib.parse
from typing import Any

import httpx

log = logging.getLogger("mqttgateway")


class MiniserverSender:
    """Manages HTTP and UDP communication to Loxone Miniservers."""

    def __init__(self, miniservers: dict[int, dict]):
        self._miniservers = miniservers
        # Per-MS httpx clients (lazy-initialized)
        self._http_clients: dict[int, httpx.AsyncClient] = {}
        # Delta cache: ms_nr -> {topic: value}
        self._cache: dict[int, dict[str, str]] = {}
        # UDP transports
        self._udp_transports: dict[int, tuple[Any, tuple[str, int]]] = {}

    @staticmethod
    def sanitize_topic(topic: str) -> str:
        """Replace / and % with _ for Loxone VI names."""
        return topic.replace("/", "_").replace("%", "_")

    def _get_client(self, ms_nr: int) -> httpx.AsyncClient:
        if ms_nr not in self._http_clients:
            ms = self._miniservers[ms_nr]
            auth = None
            if ms.get("Admin") and ms.get("Pass"):
                auth = httpx.BasicAuth(ms["Admin"], ms["Pass"])
            self._http_clients[ms_nr] = httpx.AsyncClient(
                base_url=f"http://{ms['Ipaddress']}:{ms.get('Port', 80)}",
                auth=auth,
                timeout=10.0,
            )
        return self._http_clients[ms_nr]

    async def _http_send(
        self, ms_nr: int, values: dict[str, str]
    ) -> dict[str, dict[str, Any]]:
        """Send values to Miniserver via HTTP.

        Returns: {topic: {"code": int, "value": str}}
        """
        client = self._get_client(ms_nr)
        results: dict[str, dict[str, Any]] = {}

        for topic, value in values.items():
            encoded_topic = urllib.parse.quote(topic, safe="")
            encoded_value = urllib.parse.quote(str(value), safe="")
            url = f"/dev/sps/io/{encoded_topic}/{encoded_value}"
            try:
                resp = await client.get(url)
                results[topic] = {"code": resp.status_code, "value": resp.text}
            except httpx.HTTPError as e:
                log.warning("HTTP send to MS %d failed for %s: %s", ms_nr, topic, e)
                results[topic] = {"code": 0, "value": str(e)}

        return results

    async def send_cached(
        self, ms_nr: int, values: dict[str, str]
    ) -> dict[str, dict[str, Any]] | None:
        """Send only changed values (delta-send)."""
        if ms_nr not in self._cache:
            self._cache[ms_nr] = {}

        delta: dict[str, str] = {}
        for topic, value in values.items():
            if self._cache[ms_nr].get(topic) != value:
                delta[topic] = value
                self._cache[ms_nr][topic] = value

        if not delta:
            return None

        return await self._http_send(ms_nr, delta)

    async def send_noncached(
        self, ms_nr: int, values: dict[str, str]
    ) -> dict[str, dict[str, Any]]:
        """Send values without caching (always sends)."""
        return await self._http_send(ms_nr, values)

    def invalidate_cache(self, ms_nr: int | None = None) -> None:
        """Clear delta cache. If ms_nr is None, clear all."""
        if ms_nr is None:
            self._cache.clear()
        else:
            self._cache.pop(ms_nr, None)

    async def send_udp(
        self, ms_nr: int, port: int, values: dict[str, str]
    ) -> None:
        """Send values via UDP in topic=value format."""
        if ms_nr not in self._udp_transports:
            ms = self._miniservers.get(ms_nr, {})
            ip = ms.get("Ipaddress", "127.0.0.1")
            loop = asyncio.get_event_loop()
            transport, _ = await loop.create_datagram_endpoint(
                asyncio.DatagramProtocol,
                remote_addr=(ip, port),
            )
            self._udp_transports[ms_nr] = (transport, (ip, port))

        transport, addr = self._udp_transports[ms_nr]
        for topic, value in values.items():
            msg = f"{topic}={value}\n".encode("utf-8")
            transport.sendto(msg, addr)

    async def close(self) -> None:
        """Close all HTTP clients and UDP transports."""
        for client in self._http_clients.values():
            await client.aclose()
        self._http_clients.clear()
        for transport, _ in self._udp_transports.values():
            transport.close()
        self._udp_transports.clear()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_miniserver.py -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/miniserver.py sbin/mqttgateway/tests/test_miniserver.py
git commit -m "feat(mqtt-gw): async Miniserver HTTP delta-send + UDP"
```

---

### Task 8: UDP listener — Miniserver to MQTT

**Files:**
- Create: `sbin/mqttgateway/udp_listener.py`
- Create: `sbin/mqttgateway/tests/test_udp_listener.py`

Receives UDP messages from Miniservers (port 11884) and publishes them to MQTT. Supports multiple formats: plain text, JSON, Loxone logger, and transformer invocation.

- [ ] **Step 1: Write failing tests**

```python
# sbin/mqttgateway/tests/test_udp_listener.py
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
        cmd = parse_udp_message("publish http2mqtt my/topic somedata")
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
        assert cmd.topic == "test/topic"

    def test_loxone_logger_format(self):
        cmd = parse_udp_message("2026-04-07 14:23:01;DeviceName;42.5")
        assert cmd.command == "retain"
        assert "logger/" in cmd.topic
        assert cmd.message == "42.5"

    def test_legacy_format_two_parts(self):
        """Old format: topic value (no command keyword)."""
        cmd = parse_udp_message("my/topic 42.5")
        assert cmd.command == "publish"
        assert cmd.topic == "my/topic"
        assert cmd.message == "42.5"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_udp_listener.py -v`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `sbin/mqttgateway/udp_listener.py`**

```python
"""UDP Listener — receives messages from Miniservers, publishes to MQTT.

Supports formats:
- "save_relayed_states" / "reconnect" — control commands
- "publish [transformer] topic message" — publish to MQTT
- "retain [transformer] topic message" — publish with retain
- JSON: {"topic":"...", "value":"...", "retain":true, "transform":"..."}
- "YYYY-MM-DD HH:MM:SS;DeviceName;Value" — Loxone logger format
- "topic message" — legacy format (implicit publish)
"""
from __future__ import annotations

import asyncio
import json
import logging
import re
from dataclasses import dataclass

log = logging.getLogger("mqttgateway")

_LOGGER_RE = re.compile(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2});(.*);(.*)")
_COMMANDS = {"publish", "retain", "reconnect", "save_relayed_states"}


@dataclass
class UdpCommand:
    """Parsed UDP message."""
    command: str  # publish, retain, reconnect, save_relayed_states
    topic: str = ""
    message: str = ""
    transformer: str | None = None
    retain: bool = False


def parse_udp_message(
    raw: str, known_transformers: set[str] | None = None
) -> UdpCommand:
    """Parse incoming UDP message into structured command."""
    raw = raw.strip()

    # Control commands
    if raw in ("save_relayed_states", "reconnect"):
        return UdpCommand(command=raw)

    # Loxone logger format: "2026-04-07 14:23:01;DeviceName;Value"
    m = _LOGGER_RE.match(raw)
    if m:
        device = m.group(2)
        value = m.group(3).strip()
        host_short = device.split(".")[0]
        return UdpCommand(
            command="retain",
            topic=f"logger/{host_short}/{device}",
            message=value,
        )

    # JSON message
    if raw.startswith("{"):
        try:
            data = json.loads(raw)
            is_retain = str(data.get("retain", "")).lower() in (
                "true", "1", "yes", "on",
            )
            return UdpCommand(
                command="retain" if is_retain else "publish",
                topic=data.get("topic", ""),
                message=str(data.get("value", "")),
                transformer=data.get("transform") or None,
            )
        except json.JSONDecodeError:
            pass

    # Text format: "command [transformer] topic message"
    parts = raw.split(" ", 3)
    command = parts[0].lower()

    if command in ("publish", "retain"):
        transformers = known_transformers or set()
        if len(parts) >= 4 and parts[1] in transformers:
            # "publish transformer topic message"
            return UdpCommand(
                command=command,
                topic=parts[2],
                message=parts[3] if len(parts) > 3 else "",
                transformer=parts[1],
            )
        elif len(parts) >= 3:
            # "publish topic message"
            return UdpCommand(
                command=command,
                topic=parts[1],
                message=" ".join(parts[2:]),
            )
        elif len(parts) == 2:
            return UdpCommand(command=command, topic=parts[1])

    # Legacy format: "topic message" (no command keyword)
    legacy_parts = raw.split(" ", 1)
    return UdpCommand(
        command="publish",
        topic=legacy_parts[0],
        message=legacy_parts[1].strip() if len(legacy_parts) > 1 else "",
    )


class UdpListenerProtocol(asyncio.DatagramProtocol):
    """asyncio DatagramProtocol that queues parsed UDP commands."""

    def __init__(
        self,
        queue: asyncio.Queue[UdpCommand],
        known_transformers: set[str] | None = None,
    ):
        self._queue = queue
        self._known_transformers = known_transformers or set()

    def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
        try:
            raw = data.decode("utf-8").strip()
        except UnicodeDecodeError:
            log.warning("UDP: Could not decode message from %s", addr)
            return

        if raw != "save_relayed_states":
            log.info("UDP IN from %s: %s", addr[0], raw)

        cmd = parse_udp_message(raw, self._known_transformers)
        self._queue.put_nowait(cmd)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_udp_listener.py -v`
Expected: All 9 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/udp_listener.py sbin/mqttgateway/tests/test_udp_listener.py
git commit -m "feat(mqtt-gw): UDP listener with multi-format parser"
```

---

### Task 9: Transformer async subprocess

**Files:**
- Create: `sbin/mqttgateway/transformer.py`
- Create: `sbin/mqttgateway/tests/test_transformer.py`

Discovers and runs PHP/Perl transformer scripts via `asyncio.create_subprocess_exec()`.

- [ ] **Step 1: Write failing tests**

```python
# sbin/mqttgateway/tests/test_transformer.py
import asyncio
import os
import stat
import tempfile
import pytest
from mqttgateway.transformer import TransformerManager, TransformerResult


class TestTransformerDiscovery:
    def test_discovers_scripts(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            shipped = os.path.join(tmpdir, "shipped", "udpin")
            os.makedirs(shipped)
            # Create a dummy script
            script = os.path.join(shipped, "test_transform.php")
            with open(script, "w") as f:
                f.write("#!/usr/bin/env php\n<?php echo 'description=Test\\ninput=text\\noutput=text'; ?>")
            os.chmod(script, os.stat(script).st_mode | stat.S_IEXEC)

            mgr = TransformerManager(tmpdir)
            mgr.discover()
            assert "test_transform" in mgr.transformers
            assert mgr.transformers["test_transform"]["extension"] == "php"

    def test_empty_directory(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            os.makedirs(os.path.join(tmpdir, "shipped", "udpin"))
            os.makedirs(os.path.join(tmpdir, "custom", "udpin"))
            mgr = TransformerManager(tmpdir)
            mgr.discover()
            assert len(mgr.transformers) == 0


class TestTransformerExecution:
    @pytest.mark.asyncio
    async def test_text_output_parsing(self):
        """Test parsing text output format: topic#value per line."""
        with tempfile.TemporaryDirectory() as tmpdir:
            shipped = os.path.join(tmpdir, "shipped", "udpin")
            os.makedirs(shipped)
            # Create a script that echoes text format
            script = os.path.join(shipped, "echo_transform.sh")
            with open(script, "w") as f:
                f.write("#!/bin/bash\necho 'result/topic#42'\necho 'result/other#99'\n")
            os.chmod(script, os.stat(script).st_mode | stat.S_IEXEC)

            mgr = TransformerManager(tmpdir)
            mgr.transformers["echo_transform"] = {
                "filename": script,
                "extension": "sh",
                "input": "text",
                "output": "text",
            }

            results = await mgr.execute(
                "echo_transform", "my/topic", "data", command="publish"
            )
            assert len(results) == 2
            assert results[0].topic == "result/topic"
            assert results[0].value == "42"
            assert results[1].topic == "result/other"
            assert results[1].value == "99"

    @pytest.mark.asyncio
    async def test_timeout(self):
        """Script that hangs should be killed after timeout."""
        with tempfile.TemporaryDirectory() as tmpdir:
            shipped = os.path.join(tmpdir, "shipped", "udpin")
            os.makedirs(shipped)
            script = os.path.join(shipped, "slow.sh")
            with open(script, "w") as f:
                f.write("#!/bin/bash\nsleep 30\n")
            os.chmod(script, os.stat(script).st_mode | stat.S_IEXEC)

            mgr = TransformerManager(tmpdir, timeout=0.5)
            mgr.transformers["slow"] = {
                "filename": script,
                "extension": "sh",
                "input": "text",
                "output": "text",
            }

            results = await mgr.execute("slow", "test", "data")
            assert results == []

    @pytest.mark.asyncio
    async def test_unknown_transformer(self):
        mgr = TransformerManager("/nonexistent")
        results = await mgr.execute("nonexistent", "topic", "data")
        assert results == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_transformer.py -v`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `sbin/mqttgateway/transformer.py`**

```python
"""Transformer — async subprocess execution of PHP/Perl transform scripts."""
from __future__ import annotations

import asyncio
import json
import logging
import os
import shlex
from dataclasses import dataclass
from pathlib import Path

log = logging.getLogger("mqttgateway")


@dataclass
class TransformerResult:
    """One output item from a transformer."""
    topic: str
    value: str
    command: str = "publish"


class TransformerManager:
    """Discovers and executes transformer scripts."""

    def __init__(self, base_path: str, timeout: float = 10.0):
        self._base_path = Path(base_path)
        self._timeout = timeout
        self.transformers: dict[str, dict] = {}

    def discover(self) -> None:
        """Scan shipped/udpin and custom/udpin for transformer scripts."""
        self.transformers.clear()
        for subdir in ("shipped/udpin", "custom/udpin"):
            scan_dir = self._base_path / subdir
            if not scan_dir.exists():
                continue
            for filepath in scan_dir.rglob("*"):
                if not filepath.is_file() or filepath.stat().st_size == 0:
                    continue
                name = filepath.stem.lower().replace(" ", "_")
                ext = filepath.suffix.lstrip(".")
                self.transformers[name] = {
                    "filename": str(filepath),
                    "extension": ext,
                    "input": "text",
                    "output": "text",
                    "description": "",
                    "link": "",
                }
        log.info("Discovered %d transformers", len(self.transformers))

    async def load_skills(self) -> None:
        """Query each transformer for its skills metadata."""
        for name, info in self.transformers.items():
            try:
                proc = await asyncio.create_subprocess_exec(
                    info["filename"], "skills",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                stdout, _ = await asyncio.wait_for(
                    proc.communicate(), timeout=5.0
                )
                for line in stdout.decode("utf-8", errors="replace").splitlines():
                    if "=" in line:
                        key, val = line.split("=", 1)
                        key = key.strip().lower()
                        if key in ("input", "output", "description", "link"):
                            info[key] = val.strip()
                if info["input"] not in ("text", "json"):
                    info["input"] = "text"
                if info["output"] not in ("text", "json"):
                    info["output"] = "text"
            except Exception as e:
                log.debug("Could not load skills for %s: %s", name, e)

    async def execute(
        self,
        name: str,
        topic: str,
        message: str,
        command: str = "publish",
    ) -> list[TransformerResult]:
        """Execute a transformer script and parse output."""
        if name not in self.transformers:
            log.warning("Unknown transformer: %s", name)
            return []

        info = self.transformers[name]

        # Build input parameter
        if info["input"] == "json":
            param = json.dumps({topic: message})
        else:
            param = f"{topic}#{message}"

        try:
            proc = await asyncio.create_subprocess_exec(
                info["filename"], param,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            stdout, _ = await asyncio.wait_for(
                proc.communicate(), timeout=self._timeout
            )
        except asyncio.TimeoutError:
            log.error("Transformer %s timed out after %.1fs", name, self._timeout)
            try:
                proc.kill()
            except ProcessLookupError:
                pass
            return []
        except Exception as e:
            log.error("Error running transformer %s: %s", name, e)
            return []

        output = stdout.decode("utf-8", errors="replace").strip()
        if not output:
            return []

        # Parse output
        if info["output"] == "json":
            return self._parse_json_output(output, command)
        return self._parse_text_output(output, command)

    def _parse_text_output(
        self, output: str, command: str
    ) -> list[TransformerResult]:
        results = []
        for line in output.splitlines():
            line = line.strip()
            if "#" in line:
                topic, value = line.split("#", 1)
                results.append(TransformerResult(
                    topic=topic, value=value, command=command
                ))
        return results

    def _parse_json_output(
        self, output: str, command: str
    ) -> list[TransformerResult]:
        try:
            data = json.loads(output)
        except json.JSONDecodeError:
            log.error("Transformer JSON output invalid: %s", output[:200])
            return []

        results = []
        if isinstance(data, list):
            for item in data:
                if isinstance(item, dict):
                    for k, v in item.items():
                        results.append(TransformerResult(
                            topic=k, value=str(v), command=command
                        ))
        elif isinstance(data, dict):
            for k, v in data.items():
                results.append(TransformerResult(
                    topic=k, value=str(v), command=command
                ))

        return results

    @property
    def known_names(self) -> set[str]:
        return set(self.transformers.keys())
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_transformer.py -v`
Expected: All tests PASS (skip on Windows if bash not available — tests use shell scripts).

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/transformer.py sbin/mqttgateway/tests/test_transformer.py
git commit -m "feat(mqtt-gw): async transformer subprocess execution"
```

---

### Task 10: State snapshot for WebUI

**Files:**
- Create: `sbin/mqttgateway/state.py`
- Create: `sbin/mqttgateway/tests/test_state.py`

Periodically writes topic state to `/dev/shm/mqttgateway_topics.json` in the same format the WebUI Datenverkehr-Tab expects.

- [ ] **Step 1: Write failing tests**

```python
# sbin/mqttgateway/tests/test_state.py
import json
import os
import tempfile
import time
import pytest
from mqttgateway.state import StateManager


class TestStateManager:
    def test_record_http_topic(self):
        sm = StateManager()
        sm.record_http("sensor_temp", "22.5", "sensor/temp", ms_nr=1, code=200)
        assert "sensor_temp" in sm._http_topics
        assert sm._http_topics["sensor_temp"]["message"] == "22.5"
        assert sm._http_topics["sensor_temp"]["originaltopic"] == "sensor/temp"

    def test_record_udp_topic(self):
        sm = StateManager()
        sm.record_udp("sensor/temp", "22.5", "sensor/temp")
        assert "sensor/temp" in sm._udp_topics

    def test_save_and_load(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "topics.json")
            sm = StateManager(datafile=path)
            sm.record_http("sensor_temp", "22.5", "sensor/temp", ms_nr=1, code=200)
            sm.save()
            assert os.path.exists(path)
            data = json.load(open(path))
            assert "http" in data
            assert "sensor_temp" in data["http"]

    def test_cleanup_old_entries(self):
        sm = StateManager()
        sm._http_topics["old_topic"] = {
            "message": "1",
            "timestamp": time.time() - 90000,  # > 24h old
            "originaltopic": "old/topic",
        }
        sm._http_topics["new_topic"] = {
            "message": "2",
            "timestamp": time.time(),
            "originaltopic": "new/topic",
        }
        sm._cleanup()
        assert "old_topic" not in sm._http_topics
        assert "new_topic" in sm._http_topics

    def test_health_state_included(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "topics.json")
            sm = StateManager(datafile=path)
            sm.health_state["broker"] = {"message": "Connected", "error": 0}
            sm.save()
            data = json.load(open(path))
            assert data["health_state"]["broker"]["message"] == "Connected"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_state.py -v`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `sbin/mqttgateway/state.py`**

```python
"""State manager — topic snapshots for the WebUI Datenverkehr-Tab."""
from __future__ import annotations

import json
import logging
import os
import time
from typing import Any

log = logging.getLogger("mqttgateway")

_24H = 24 * 60 * 60


class StateManager:
    """Tracks relayed topics and writes periodic snapshots."""

    def __init__(self, datafile: str = "/dev/shm/mqttgateway_topics.json"):
        self._datafile = datafile
        self._http_topics: dict[str, dict[str, Any]] = {}
        self._udp_topics: dict[str, dict[str, Any]] = {}
        self.health_state: dict[str, Any] = {}
        self.subscription_filters: list[str] = []
        self.do_not_forward: dict[str, str] = {}
        self.noncached: dict[str, str] = {}
        self.reset_after_send: dict[str, int] = {}

    def record_http(
        self,
        topic_underlined: str,
        value: str,
        original_topic: str,
        ms_nr: int | None = None,
        code: int | None = None,
    ) -> None:
        entry = self._http_topics.setdefault(topic_underlined, {})
        entry["timestamp"] = time.time()
        entry["message"] = value
        entry["originaltopic"] = original_topic
        if ms_nr is not None and code is not None:
            toms = entry.setdefault("toMS", {})
            toms[str(ms_nr)] = {"code": code, "lastsent": time.time()}

    def record_udp(
        self, topic: str, value: str, original_topic: str
    ) -> None:
        entry = self._udp_topics.setdefault(topic, {})
        entry["timestamp"] = time.time()
        entry["message"] = value
        entry["originaltopic"] = original_topic

    def _cleanup(self) -> None:
        cutoff = time.time() - _24H
        for store in (self._http_topics, self._udp_topics):
            to_delete = [
                k for k, v in store.items()
                if v.get("timestamp", 0) < cutoff or not v.get("message")
            ]
            for k in to_delete:
                del store[k]

    def save(self) -> None:
        """Write state snapshot to disk."""
        self._cleanup()

        # Count HTTP response codes for health stats
        httpresp: dict[str, int] = {}
        for entry in self._http_topics.values():
            for ms_data in entry.get("toMS", {}).values():
                code = str(ms_data.get("code", 0))
                httpresp[code] = httpresp.get(code, 0) + 1

        self.health_state.setdefault("stats", {})
        self.health_state["stats"]["httpresp"] = httpresp
        self.health_state["stats"]["http_relayedcount"] = len(self._http_topics)
        self.health_state["stats"]["udp_relayedcount"] = len(self._udp_topics)

        data = {
            "http": self._http_topics,
            "udp": self._udp_topics,
            "Noncached": self.noncached,
            "resetAfterSend": self.reset_after_send,
            "doNotForward": self.do_not_forward,
            "health_state": self.health_state,
            "subscriptionfilters": self.subscription_filters,
        }

        try:
            tmp = self._datafile + ".tmp"
            with open(tmp, "w") as f:
                json.dump(data, f)
            os.replace(tmp, self._datafile)
        except OSError as e:
            log.error("Failed to write state file: %s", e)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_state.py -v`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sbin/mqttgateway/state.py sbin/mqttgateway/tests/test_state.py
git commit -m "feat(mqtt-gw): state manager for WebUI topic snapshots"
```

---

### Task 11: MQTT client wrapper

**Files:**
- Create: `sbin/mqttgateway/mqtt_client.py`

This wraps aiomqtt with gateway-specific logic: subscribe to V2 topics + plugin topics, publish LWT, receive messages into the pipeline. Since aiomqtt requires a real broker for meaningful tests, this task focuses on structure — integration tests come in Task 14.

- [ ] **Step 1: Implement `sbin/mqttgateway/mqtt_client.py`**

```python
"""MQTT client — aiomqtt wrapper with subscription management."""
from __future__ import annotations

import asyncio
import logging
from typing import Callable, Awaitable

import aiomqtt

log = logging.getLogger("mqttgateway")


class MqttClient:
    """Manages MQTT connection, subscriptions, and message routing."""

    def __init__(
        self,
        host: str,
        port: int = 1883,
        username: str = "",
        password: str = "",
        hostname: str = "loxberry",
    ):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.hostname = hostname
        self._gw_topic = f"{hostname}/mqttgateway/"
        self._client: aiomqtt.Client | None = None

    async def connect_and_run(
        self,
        topics: list[str],
        on_message: Callable[[str, str], Awaitable[None]],
    ) -> None:
        """Connect to broker, subscribe to topics, and run message loop.

        Args:
            topics: List of MQTT topics to subscribe to.
            on_message: Async callback(topic, payload) for each message.
        """
        while True:
            try:
                async with aiomqtt.Client(
                    hostname=self.host,
                    port=self.port,
                    username=self.username or None,
                    password=self.password or None,
                    will=aiomqtt.Will(
                        topic=self._gw_topic + "status",
                        payload="Disconnected",
                        retain=True,
                    ),
                ) as client:
                    self._client = client
                    log.info("Connected to MQTT broker %s:%d", self.host, self.port)

                    # Publish status
                    await client.publish(
                        self._gw_topic + "status", "Connected", retain=True
                    )

                    # Subscribe to all topics
                    all_topics = list(set(topics + [self._gw_topic + "#"]))
                    for topic in all_topics:
                        await client.subscribe(topic)
                        log.info("Subscribed: %s", topic)

                    # Message loop
                    async for message in client.messages:
                        topic_str = str(message.topic)
                        payload_str = (
                            message.payload.decode("utf-8", errors="replace")
                            if isinstance(message.payload, bytes)
                            else str(message.payload)
                        )
                        try:
                            await on_message(topic_str, payload_str)
                        except Exception as e:
                            log.error("Error processing %s: %s", topic_str, e)

            except aiomqtt.MqttError as e:
                log.warning("MQTT connection lost: %s. Reconnecting in 5s...", e)
                self._client = None
                await asyncio.sleep(5)
            except asyncio.CancelledError:
                log.info("MQTT client shutting down")
                self._client = None
                raise

    async def publish(
        self, topic: str, payload: str, retain: bool = False
    ) -> None:
        """Publish a message to the broker."""
        if self._client:
            await self._client.publish(topic, payload, retain=retain)
        else:
            log.warning("Cannot publish — not connected to broker")

    async def resubscribe(self, topics: list[str]) -> None:
        """Update subscriptions (e.g., after config reload)."""
        if not self._client:
            return
        all_topics = list(set(topics + [self._gw_topic + "#"]))
        for topic in all_topics:
            await self._client.subscribe(topic)
            log.debug("Re-subscribed: %s", topic)
```

- [ ] **Step 2: Commit**

```bash
git add sbin/mqttgateway/mqtt_client.py
git commit -m "feat(mqtt-gw): aiomqtt client wrapper"
```

---

### Task 12: Main entry point — wire everything together

**Files:**
- Modify: `sbin/mqttgateway/__main__.py`

Wires all components: config, logging, MQTT client, pipeline, miniserver sender, UDP listener, transformer, state manager. Runs the async event loop with systemd watchdog.

- [ ] **Step 1: Implement the full `__main__.py`**

```python
"""MQTT Gateway V2 — main entry point.

Usage: python3 -m mqttgateway
   or: python3 /opt/loxberry/sbin/mqttgateway
"""
from __future__ import annotations

import asyncio
import logging
import os
import signal
import socket
import sys
from pathlib import Path

from mqttgateway.config import GatewayConfig
from mqttgateway.logging_compat import setup_logging, OK
from mqttgateway.miniserver import MiniserverSender
from mqttgateway.mqtt_client import MqttClient
from mqttgateway.pipeline import Pipeline, PipelineResult
from mqttgateway.state import StateManager
from mqttgateway.transformer import TransformerManager
from mqttgateway.udp_listener import UdpListenerProtocol, UdpCommand

# LoxBerry paths (can be overridden via env)
LBHOME = os.environ.get("LBHOMEDIR", "/opt/loxberry")
LBSCONFIG = os.path.join(LBHOME, "config", "system")
LBSBIN = os.path.join(LBHOME, "sbin")
LBPLUGINCONFIG = os.path.join(LBHOME, "config", "plugins")

log: logging.Logger


class Gateway:
    """Main gateway orchestrator."""

    def __init__(self) -> None:
        self.config = GatewayConfig(
            general_json_path=os.path.join(LBSCONFIG, "general.json"),
            gateway_json_path=os.path.join(LBSCONFIG, "mqttgateway.json"),
            plugin_config_dir=LBPLUGINCONFIG,
        )
        self.state = StateManager()
        self.transformer = TransformerManager(
            os.path.join(LBSBIN, "mqtt", "transform")
        )
        self.ms_sender: MiniserverSender | None = None
        self.mqtt_client: MqttClient | None = None
        self.pipeline: Pipeline | None = None
        self._udp_queue: asyncio.Queue[UdpCommand] = asyncio.Queue()

    def _build_pipeline(self) -> Pipeline:
        return Pipeline(
            hostname=socket.gethostname(),
            do_not_forward=self.config.do_not_forward,
            subscription_filters=self.config.subscription_filters,
            convert_booleans=self.config.convert_booleans,
            conversions=self.config.conversions,
            subscriptions=self.config.subscriptions,
            default_ms=self.config.default_ms,
        )

    def _get_all_topics(self) -> list[str]:
        topics = [sub.topic for sub in self.config.subscriptions]
        topics.extend(self.config.plugin_subscriptions)
        return topics

    async def _on_mqtt_message(self, topic: str, payload: str) -> None:
        """Called for each incoming MQTT message."""
        result = self.pipeline.process(topic, payload)
        if result is None:
            return

        for item in result.items:
            for ms_nr in item.toms:
                if self.config.use_http:
                    self.state.record_http(
                        item.topic_underlined, item.value,
                        item.original_topic, ms_nr=ms_nr, code=0,
                    )
                    if item.noncached:
                        resp = await self.ms_sender.send_noncached(
                            ms_nr, {item.topic_underlined: item.value}
                        )
                    else:
                        resp = await self.ms_sender.send_cached(
                            ms_nr, {item.topic_underlined: item.value}
                        )
                    if resp:
                        for t, r in resp.items():
                            self.state.record_http(
                                t, item.value, item.original_topic,
                                ms_nr=ms_nr, code=r.get("code", 0),
                            )

                if self.config.use_udp:
                    self.state.record_udp(
                        item.original_topic, item.value, item.original_topic
                    )
                    if item.noncached:
                        await self.ms_sender.send_udp(
                            ms_nr, self.config.udp_port,
                            {item.original_topic: item.value},
                        )

                # Reset-after-send
                if item.reset_after_send:
                    asyncio.create_task(
                        self._reset_after_send(ms_nr, item.topic_underlined)
                    )

    async def _reset_after_send(self, ms_nr: int, topic: str) -> None:
        delay = self.config.reset_after_send_ms / 1000.0
        await asyncio.sleep(delay)
        if self.config.use_http:
            await self.ms_sender.send_noncached(ms_nr, {topic: "0"})
        if self.config.use_udp:
            await self.ms_sender.send_udp(
                ms_nr, self.config.udp_port, {topic: "0"}
            )

    async def _process_udp_commands(self) -> None:
        """Process UDP commands from Miniserver."""
        while True:
            cmd = await self._udp_queue.get()

            if cmd.command == "save_relayed_states":
                self.state.save()
            elif cmd.command == "reconnect":
                log.info("Reconnect requested — invalidating caches")
                self.ms_sender.invalidate_cache()
            elif cmd.command in ("publish", "retain"):
                retain = cmd.command == "retain"

                if cmd.transformer:
                    results = await self.transformer.execute(
                        cmd.transformer, cmd.topic, cmd.message,
                        command=cmd.command,
                    )
                    for r in results:
                        await self.mqtt_client.publish(
                            r.topic, r.value, retain=(r.command == "retain")
                        )
                else:
                    await self.mqtt_client.publish(
                        cmd.topic, cmd.message, retain=retain
                    )

    async def _config_watcher(self) -> None:
        """Periodically check for config changes and reload."""
        while True:
            await asyncio.sleep(5)
            if self.config.has_changed():
                log.info("Config changed — reloading")
                self.config.load()
                self.pipeline = self._build_pipeline()
                topics = self._get_all_topics()
                await self.mqtt_client.resubscribe(topics)

    async def _state_saver(self) -> None:
        """Periodically save state to disk."""
        while True:
            await asyncio.sleep(2)
            self.state.save()

    async def _watchdog(self) -> None:
        """Send systemd watchdog pings."""
        try:
            import sdnotify
            notifier = sdnotify.SystemdNotifier()
            notifier.notify("READY=1")
            while True:
                notifier.notify("WATCHDOG=1")
                await asyncio.sleep(30)
        except ImportError:
            log.debug("sdnotify not available — watchdog disabled")

    async def run(self) -> None:
        """Start all components and run forever."""
        # Load config
        self.config.load()

        # Build components
        self.pipeline = self._build_pipeline()
        self.ms_sender = MiniserverSender(self.config.miniservers)
        self.mqtt_client = MqttClient(
            host=self.config.broker_host,
            port=self.config.broker_port,
            username=self.config.broker_user,
            password=self.config.broker_pass,
            hostname=socket.gethostname(),
        )

        # Discover transformers
        self.transformer.discover()
        await self.transformer.load_skills()

        # Update state references
        self.state.do_not_forward = {
            t: "true" for t in self.config.do_not_forward
        }
        self.state.subscription_filters = [
            p.pattern for p in self.config.subscription_filters
        ]

        # Start UDP listener
        loop = asyncio.get_event_loop()
        transport, _ = await loop.create_datagram_endpoint(
            lambda: UdpListenerProtocol(
                self._udp_queue, self.transformer.known_names
            ),
            local_addr=("0.0.0.0", self.config.udp_in_port),
        )
        log.info("UDP listener on port %d", self.config.udp_in_port)

        topics = self._get_all_topics()
        log.info("Starting with %d subscriptions", len(topics))

        # Run all tasks
        async with asyncio.TaskGroup() as tg:
            tg.create_task(self.mqtt_client.connect_and_run(
                topics, self._on_mqtt_message
            ))
            tg.create_task(self._process_udp_commands())
            tg.create_task(self._config_watcher())
            tg.create_task(self._state_saver())
            tg.create_task(self._watchdog())


async def main() -> None:
    global log
    log = setup_logging(loglevel=7)
    log.log(OK, "MQTT Gateway V2 starting")

    gateway = Gateway()
    try:
        await gateway.run()
    except (KeyboardInterrupt, asyncio.CancelledError):
        log.info("Shutting down...")
    finally:
        if gateway.ms_sender:
            await gateway.ms_sender.close()
        if gateway.mqtt_client:
            await gateway.mqtt_client.publish(
                f"{socket.gethostname()}/mqttgateway/status",
                "Disconnected", retain=True,
            )
        log.info("MQTT Gateway V2 stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
```

- [ ] **Step 2: Verify the module structure is complete**

Run: `cd sbin && python3 -c "from mqttgateway.__main__ import Gateway; print('OK')"`
Expected: Prints "OK" (all imports resolve).

- [ ] **Step 3: Commit**

```bash
git add sbin/mqttgateway/__main__.py
git commit -m "feat(mqtt-gw): main entry point — all components wired"
```

---

### Task 13: systemd service and handler update

**Files:**
- Create: `system/daemons/system/mqttgateway.service`
- Modify: `sbin/mqtt-handler.pl` (update restartgateway action)

- [ ] **Step 1: Create systemd service file**

```ini
# system/daemons/system/mqttgateway.service
[Unit]
Description=LoxBerry MQTT Gateway V2
After=network-online.target mosquitto.service
Wants=network-online.target

[Service]
Type=simple
User=loxberry
ExecStart=/usr/bin/python3 /opt/loxberry/sbin/mqttgateway
Restart=on-failure
RestartSec=5
WatchdogSec=60
Environment=LBHOMEDIR=/opt/loxberry

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 2: Update `mqtt-handler.pl` restartgateway action**

In `sbin/mqtt-handler.pl`, find the `restartgateway` action block and update it to use systemctl instead of PID-based kill:

Current code (approx):
```perl
if ($action eq "restartgateway") {
    # ... PID-based restart logic
}
```

Change to:
```perl
if ($action eq "restartgateway") {
    system("systemctl restart mqttgateway");
}
```

- [ ] **Step 3: Update `ajax-mqtt.php` getpids to detect Python process**

In `webfrontend/htmlauth/system/ajax/ajax-mqtt.php`, line ~157, the `getpids` action greps for `mqttgateway.pl`. Update to also detect the Python daemon:

```php
$pids['mqttgateway'] = trim(`pgrep -f 'mqttgateway.pl|python.*mqttgateway'`) ;
```

- [ ] **Step 4: Commit**

```bash
git add system/daemons/system/mqttgateway.service
git add sbin/mqtt-handler.pl
git add webfrontend/htmlauth/system/ajax/ajax-mqtt.php
git commit -m "feat(mqtt-gw): systemd service + handler migration"
```

---

### Task 14: Integration smoke test

**Files:**
- Create: `sbin/mqttgateway/tests/test_integration.py`

A test that wires the real components (except MQTT and HTTP) to verify end-to-end flow with test fixtures.

- [ ] **Step 1: Write integration test**

```python
# sbin/mqttgateway/tests/test_integration.py
"""Integration test — verifies the pipeline with real config fixtures."""
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

        cfg = GatewayConfig(gen_path, gw_path)
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

        state = StateManager(
            datafile=os.path.join(tmpdir, "topics.json")
        )

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
            # battery not configured — should not appear
            assert "zigbee2mqtt_livingroom_battery" not in topics
            # humidity routes to [1, 2] and is noncached
            hum = topics["zigbee2mqtt_livingroom_humidity"]
            assert hum.toms == [1, 2]
            assert hum.noncached is True

    def test_nested_json_expansion(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg, pipeline, state = self._setup(tmpdir)
            payload = json.dumps({
                "sys": {"available_updates": {"stable": {"version": "2.0.0"}}}
            })
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
                state.record_http(
                    item.topic_underlined, item.value,
                    item.original_topic, ms_nr=1, code=200,
                )
            state.save()
            data = json.load(open(os.path.join(tmpdir, "topics.json")))
            assert "tasmota_sensor_temperature" in data["http"]
```

- [ ] **Step 2: Run integration tests**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/test_integration.py -v`
Expected: All 10 tests PASS.

- [ ] **Step 3: Run full test suite**

Run: `cd sbin && python3 -m pytest mqttgateway/tests/ -v`
Expected: All tests PASS across all test files.

- [ ] **Step 4: Commit**

```bash
git add sbin/mqttgateway/tests/test_integration.py
git commit -m "test(mqtt-gw): integration smoke tests"
```

---

### Task 15: Disable old Perl daemon startup

**Files:**
- Modify: `system/daemons/system/50-mqttgateway`

The old startup script must not start the Perl daemon when the Python daemon is active. Add a guard that checks if the systemd service is enabled.

- [ ] **Step 1: Update the old startup script**

```bash
#!/bin/bash
# Legacy MQTT Gateway startup — skips if systemd service is active
if systemctl is-enabled mqttgateway.service &>/dev/null; then
    echo "MQTT Gateway runs as systemd service — skipping legacy startup"
    exit 0
fi

# Fallback: start Perl daemon (for systems not yet migrated)
su loxberry -c "$LBHOMEDIR/sbin/mqttgateway.pl > /dev/null 2>&1 &"
```

- [ ] **Step 2: Commit**

```bash
git add system/daemons/system/50-mqttgateway
git commit -m "feat(mqtt-gw): guard old startup script for systemd migration"
```

---

## Spec Coverage Checklist

| Spec Section | Task(s) |
|---|---|
| Project structure | Task 1 |
| Config loading + V2 parsing + @@-notation | Task 3 |
| Pipeline: early filter | Task 4 |
| Pipeline: debounce | Task 4 |
| Pipeline: JSON expansion | Task 5 |
| Pipeline: boolean + user conversions | Task 6 |
| Miniserver HTTP delta-send | Task 7 |
| Miniserver UDP send | Task 7 |
| Reset-after-send | Task 7, Task 12 |
| UDP Listener (MS -> MQTT) | Task 8 |
| Transformer async subprocess | Task 9 |
| State snapshot for WebUI | Task 10 |
| MQTT client (aiomqtt) | Task 11 |
| Main entry point (all wired) | Task 12 |
| systemd service | Task 13 |
| Logging compatibility | Task 2 |
| Config hot-reload | Task 3, Task 12 |
| systemd watchdog | Task 12 |
| Old daemon migration | Task 13, Task 15 |
