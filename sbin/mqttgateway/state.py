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
    def __init__(self, datafile: str = "/dev/shm/mqttgateway_topics.json"):
        self._datafile = datafile
        self._http_topics: dict[str, dict[str, Any]] = {}
        self._udp_topics: dict[str, dict[str, Any]] = {}
        self.health_state: dict[str, Any] = {}
        self.subscription_filters: list[str] = []
        self.do_not_forward: dict[str, str] = {}
        self.noncached: dict[str, str] = {}
        self.reset_after_send: dict[str, int] = {}

    def record_http(self, topic_underlined: str, value: str, original_topic: str, ms_nr: int | None = None, code: int | None = None) -> None:
        entry = self._http_topics.setdefault(topic_underlined, {})
        entry["timestamp"] = time.time()
        entry["message"] = value
        entry["originaltopic"] = original_topic
        if ms_nr is not None and code is not None:
            toms = entry.setdefault("toMS", {})
            toms[str(ms_nr)] = {"code": code, "lastsent": time.time()}

    def record_udp(self, topic: str, value: str, original_topic: str) -> None:
        entry = self._udp_topics.setdefault(topic, {})
        entry["timestamp"] = time.time()
        entry["message"] = value
        entry["originaltopic"] = original_topic

    def _cleanup(self) -> None:
        cutoff = time.time() - _24H
        for store in (self._http_topics, self._udp_topics):
            to_delete = [k for k, v in store.items() if v.get("timestamp", 0) < cutoff or not v.get("message")]
            for k in to_delete:
                del store[k]

    def save(self) -> None:
        self._cleanup()
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
            "http": self._http_topics, "udp": self._udp_topics,
            "Noncached": self.noncached, "resetAfterSend": self.reset_after_send,
            "doNotForward": self.do_not_forward, "health_state": self.health_state,
            "subscriptionfilters": self.subscription_filters,
        }
        try:
            tmp = self._datafile + ".tmp"
            with open(tmp, "w") as f:
                json.dump(data, f)
            os.replace(tmp, self._datafile)
        except OSError as e:
            log.error("Failed to write state: %s", e)
