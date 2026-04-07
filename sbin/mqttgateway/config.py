"""LoxBerry MQTT Gateway — config loading with V2 subscription parsing."""
from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, field
from typing import Any


# ---------------------------------------------------------------------------
# @@-path notation
# ---------------------------------------------------------------------------

def parse_aa_path(path_str: str) -> list[str | int]:
    """Parse Michael's @@-notation into a list of path segments.

    Examples:
        "temperature"                           → ["temperature"]
        "settings@@led_indication"              → ["settings", "led_indication"]
        "rollen@@[3]@@rolle"                    → ["rollen", 3, "rolle"]
        "@@[0]@@id"                             → [0, "id"]
        "sys@@available_updates@@stable@@version" → ["sys", "available_updates", "stable", "version"]
    """
    parts = path_str.split("@@")
    result: list[str | int] = []
    for part in parts:
        if part == "":
            # Leading @@ or consecutive @@ — skip empty strings
            continue
        m = re.fullmatch(r"\[(\d+)\]", part)
        if m:
            result.append(int(m.group(1)))
        else:
            result.append(part)
    return result


def extract_by_path(data: Any, path: list[str | int]) -> Any:
    """Navigate into nested dicts/lists using a parsed @@-path.

    Returns None if any key/index is missing.
    """
    current = data
    try:
        for segment in path:
            if isinstance(segment, int):
                current = current[segment]
            else:
                current = current[segment]
    except (KeyError, IndexError, TypeError):
        return None
    return current


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class JsonField:
    """A single JSON field extraction rule inside a V2 subscription."""
    id_raw: str
    path: list[str | int]
    toms: list[int]
    noncached: bool
    reset_after_send: bool


@dataclass
class Subscription:
    """A parsed V2 MQTT subscription."""
    topic: str
    toms: list[int]
    noncached: bool
    reset_after_send: bool
    json_expand: bool
    json_fields: list[JsonField] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _is_enabled(value: Any) -> bool:
    """Match LoxBerry's is_enabled() semantics.

    "true", "yes", "on", "1", "enabled" (case-insensitive) → True,
    everything else → False.
    """
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value == 1
    if isinstance(value, str):
        return value.strip().lower() in {"true", "yes", "on", "1", "enabled"}
    return False


def _resolve_toms(toms: list[int], default_ms: int) -> list[int]:
    """Replace empty Toms with [default_ms]."""
    if not toms:
        return [default_ms]
    return list(toms)


def _parse_subscription(raw: dict, default_ms: int) -> Subscription:
    toms = _resolve_toms(raw.get("Toms", []), default_ms)
    json_fields = []
    for jf in raw.get("Json", []):
        id_raw = jf["Id"]
        jf_toms = _resolve_toms(jf.get("Toms", []), default_ms)
        json_fields.append(JsonField(
            id_raw=id_raw,
            path=parse_aa_path(id_raw),
            toms=jf_toms,
            noncached=bool(jf.get("Noncached", False)),
            reset_after_send=bool(jf.get("resetaftersend", False)),
        ))
    return Subscription(
        topic=raw["Id"],
        toms=toms,
        noncached=bool(raw.get("Noncached", False)),
        reset_after_send=bool(raw.get("resetaftersend", False)),
        json_expand=bool(raw.get("Jsonexpand", False)),
        json_fields=json_fields,
    )


def _parse_conversions(raw_list: list[str]) -> dict[str, str]:
    """Parse ["ON=1", "OFF=0", ...] into {"ON": "1", "OFF": "0", ...}."""
    result = {}
    for entry in raw_list:
        if "=" in entry:
            key, _, val = entry.partition("=")
            result[key] = val
    return result


def _read_cfg_lines(filepath: str) -> list[str]:
    """Read a .cfg file, return non-empty, non-comment lines."""
    lines = []
    try:
        with open(filepath, encoding="utf-8") as f:
            for line in f:
                stripped = line.strip()
                if stripped and not stripped.startswith("#"):
                    lines.append(stripped)
    except OSError:
        pass
    return lines


# ---------------------------------------------------------------------------
# GatewayConfig
# ---------------------------------------------------------------------------

class GatewayConfig:
    """Loads and holds the full gateway configuration.

    Parameters
    ----------
    general_path:
        Path to ``general.json`` (broker, Miniserver list, UDP ports).
    gateway_path:
        Path to ``mqttgateway.json`` (subscriptions, conversions, filters).
    plugins_cfg_root:
        Root directory that contains ``<plugin>/cfg/mqtt_*.cfg`` files.
        Defaults to ``/opt/loxberry/config/plugins``.
    """

    def __init__(
        self,
        general_path: str,
        gateway_path: str,
        plugins_cfg_root: str = "/opt/loxberry/config/plugins",
    ) -> None:
        self._general_path = general_path
        self._gateway_path = gateway_path
        self._plugins_cfg_root = plugins_cfg_root
        self._mtimes: dict[str, float] = {}

        # Public attributes — populated by load()
        self.broker_host: str = "localhost"
        self.broker_port: int = 1883
        self.broker_user: str = ""
        self.broker_pass: str = ""
        self.udp_in_port: int = 11884
        self.websocket_port: int = 9001
        self.gateway_version: int = 2
        self.default_ms: int = 1
        self.miniservers: dict[int, dict] = {}

        self.subscriptions: list[Subscription] = []
        self.conversions: dict[str, str] = {}
        self.subscription_filters: list[re.Pattern] = []
        self.do_not_forward: dict[str, Any] = {}

        # Plugin data
        self.plugin_subscriptions: list[str] = []
        self.plugin_conversions: dict[str, str] = {}
        self.plugin_reset_after_send: list[str] = []

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def load(self) -> None:
        """(Re-)read all config files and update public attributes."""
        self._load_general()
        self._load_gateway()
        self._load_plugins()
        self._record_mtimes()

    def has_changed(self) -> bool:
        """Return True if any config file has been modified since last load()."""
        for path, recorded_mtime in self._mtimes.items():
            try:
                if os.path.getmtime(path) != recorded_mtime:
                    return True
            except OSError:
                return True
        return False

    # ------------------------------------------------------------------
    # Private loaders
    # ------------------------------------------------------------------

    def _load_general(self) -> None:
        with open(self._general_path, encoding="utf-8") as f:
            data = json.load(f)

        mqtt = data.get("Mqtt", {})
        self.broker_host = mqtt.get("Brokerhost", "localhost")
        self.broker_port = int(mqtt.get("Brokerport", 1883))
        self.broker_user = mqtt.get("Brokeruser", "")
        self.broker_pass = mqtt.get("Brokerpass", "")
        self.udp_in_port = int(mqtt.get("Udpinport", 11884))
        self.websocket_port = int(mqtt.get("Websocketport", 9001))
        self.gateway_version = int(mqtt.get("GatewayVersion", 2))

        raw_ms = data.get("Miniserver", {})
        self.miniservers = {int(k): v for k, v in raw_ms.items()}

    def _load_gateway(self) -> None:
        with open(self._gateway_path, encoding="utf-8") as f:
            data = json.load(f)

        main = data.get("Main", {})
        self.default_ms = int(main.get("msno", 1))

        raw_subs = data.get("subscriptions_v2", [])
        self.subscriptions = [
            _parse_subscription(raw, self.default_ms) for raw in raw_subs
        ]

        raw_conv = data.get("conversions", [])
        self.conversions = _parse_conversions(raw_conv)

        raw_filters = data.get("subscriptionfilters", [])
        self.subscription_filters = [re.compile(pat) for pat in raw_filters]

        self.do_not_forward = data.get("doNotForward", {})

    def _load_plugins(self) -> None:
        self.plugin_subscriptions = []
        self.plugin_conversions = {}
        self.plugin_reset_after_send = []

        root = self._plugins_cfg_root
        if not os.path.isdir(root):
            return

        for plugin_name in sorted(os.listdir(root)):
            cfg_dir = os.path.join(root, plugin_name, "cfg")
            if not os.path.isdir(cfg_dir):
                continue

            # mqtt_subscriptions.cfg
            sub_file = os.path.join(cfg_dir, "mqtt_subscriptions.cfg")
            self.plugin_subscriptions.extend(_read_cfg_lines(sub_file))

            # mqtt_conversions.cfg
            conv_file = os.path.join(cfg_dir, "mqtt_conversions.cfg")
            self.plugin_conversions.update(
                _parse_conversions(_read_cfg_lines(conv_file))
            )

            # mqtt_resetaftersend.cfg
            ras_file = os.path.join(cfg_dir, "mqtt_resetaftersend.cfg")
            self.plugin_reset_after_send.extend(_read_cfg_lines(ras_file))

    def _record_mtimes(self) -> None:
        self._mtimes = {}
        for path in (self._general_path, self._gateway_path):
            try:
                self._mtimes[path] = os.path.getmtime(path)
            except OSError:
                pass
