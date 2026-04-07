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
    command: str
    topic: str = ""
    message: str = ""
    transformer: str | None = None
    retain: bool = False


def parse_udp_message(raw: str, known_transformers: set[str] | None = None) -> UdpCommand:
    raw = raw.strip()

    if raw in ("save_relayed_states", "reconnect"):
        return UdpCommand(command=raw)

    m = _LOGGER_RE.match(raw)
    if m:
        device = m.group(2)
        value = m.group(3).strip()
        host_short = device.split(".")[0]
        return UdpCommand(command="retain", topic=f"logger/{host_short}/{device}", message=value)

    if raw.startswith("{"):
        try:
            data = json.loads(raw)
            is_retain = str(data.get("retain", "")).lower() in ("true", "1", "yes", "on")
            return UdpCommand(
                command="retain" if is_retain else "publish",
                topic=data.get("topic", ""),
                message=str(data.get("value", "")),
                transformer=data.get("transform") or None,
            )
        except json.JSONDecodeError:
            pass

    parts = raw.split(" ", 3)
    command = parts[0].lower()

    if command in ("publish", "retain"):
        transformers = known_transformers or set()
        if len(parts) >= 4 and parts[1] in transformers:
            return UdpCommand(command=command, topic=parts[2], message=parts[3] if len(parts) > 3 else "", transformer=parts[1])
        elif len(parts) >= 3:
            return UdpCommand(command=command, topic=parts[1], message=" ".join(parts[2:]))
        elif len(parts) == 2:
            return UdpCommand(command=command, topic=parts[1])

    legacy_parts = raw.split(" ", 1)
    return UdpCommand(command="publish", topic=legacy_parts[0], message=legacy_parts[1].strip() if len(legacy_parts) > 1 else "")


class UdpListenerProtocol(asyncio.DatagramProtocol):
    def __init__(self, queue: asyncio.Queue[UdpCommand], known_transformers: set[str] | None = None):
        self._queue = queue
        self._known_transformers = known_transformers or set()

    def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
        try:
            raw = data.decode("utf-8").strip()
        except UnicodeDecodeError:
            log.warning("UDP: Could not decode from %s", addr)
            return
        if raw != "save_relayed_states":
            log.info("UDP IN from %s: %s", addr[0], raw)
        cmd = parse_udp_message(raw, self._known_transformers)
        self._queue.put_nowait(cmd)
