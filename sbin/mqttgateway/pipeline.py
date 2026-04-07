"""LoxBerry MQTT Gateway — message processing pipeline.

Five stages:
  1. Early filter  — own topics, doNotForward, regex filters
  2. Debounce      — drop duplicate payloads
  3. JSON expansion — extract fields from JSON payloads
  4. Convert        — boolean + user-defined value conversions
  5. Route          — toms already embedded in SendItems from Stage 3
"""
from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field
from typing import Any

from mqttgateway.config import Subscription, extract_by_path

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Public data classes
# ---------------------------------------------------------------------------

@dataclass
class SendItem:
    """A single value ready to be dispatched to a Miniserver."""
    topic_underlined: str
    original_topic: str
    value: str
    toms: list[int]
    noncached: bool
    reset_after_send: bool


@dataclass
class PipelineResult:
    """Result of processing one MQTT message — may contain multiple items."""
    items: list[SendItem] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _underline_topic(topic: str) -> str:
    """Replace `/` and `%` with `_` for LoxBerry's flat namespace."""
    return topic.replace("/", "_").replace("%", "_")


def _path_to_topic_suffix(path: list[str | int]) -> str:
    """Convert a parsed @@-path to a topic suffix string.

    Examples:
        ["temperature"]                              → "temperature"
        ["sys", "available_updates", "stable", "version"] → "sys/available_updates/stable/version"
        ["rollen", 0]                                → "rollen/0"
        ["rollen", 1, "name"]                        → "rollen/1/name"
    """
    return "/".join(str(seg) for seg in path)


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------

class Pipeline:
    """Process one MQTT message at a time through a 5-stage pipeline."""

    def __init__(
        self,
        hostname: str = "loxberry",
        do_not_forward: set[str] | None = None,
        subscription_filters: list[re.Pattern] | None = None,
        convert_booleans: bool = True,
        conversions: dict[str, str] | None = None,
        subscriptions: list[Subscription] | None = None,
        default_ms: int = 1,
    ) -> None:
        self._hostname = hostname
        self._do_not_forward: set[str] = do_not_forward or set()
        self._subscription_filters: list[re.Pattern] = subscription_filters or []
        self._convert_booleans = convert_booleans
        self._conversions: dict[str, str] = conversions or {}
        self._subscriptions: list[Subscription] = subscriptions or []
        self._default_ms = default_ms

        # Debounce cache: topic → last seen payload
        self._debounce: dict[str, str] = {}

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def process(self, topic: str, payload: str) -> PipelineResult | None:
        """Run topic+payload through the pipeline.

        Returns PipelineResult or None if the message was filtered/debounced.
        """
        # Stage 1 — Early filter
        if self._early_filter(topic):
            return None

        # Stage 2 — Debounce
        if self._is_debounced(topic, payload):
            return None
        self._debounce[topic] = payload

        # Stage 3 — JSON expansion → list[SendItem] (value still raw)
        items = self._expand(topic, payload)

        # Stage 4 — Convert
        items = self._convert(items)

        return PipelineResult(items=items)

    # ------------------------------------------------------------------
    # Stage 1: Early filter
    # ------------------------------------------------------------------

    def _early_filter(self, topic: str) -> bool:
        """Return True if the message should be dropped."""
        # Own gateway topics
        if topic.startswith(f"{self._hostname}/mqttgateway/"):
            return True

        underlined = _underline_topic(topic)

        if underlined in self._do_not_forward:
            return True

        for pattern in self._subscription_filters:
            if pattern.search(underlined):
                return True

        return False

    # ------------------------------------------------------------------
    # Stage 2: Debounce
    # ------------------------------------------------------------------

    def _is_debounced(self, topic: str, payload: str) -> bool:
        return self._debounce.get(topic) == payload

    # ------------------------------------------------------------------
    # Stage 3: JSON expansion
    # ------------------------------------------------------------------

    def _expand(self, topic: str, payload: str) -> list[SendItem]:
        sub = self._find_subscription(topic)

        if sub is None or not sub.json_expand or not sub.json_fields:
            # No expansion — pass through as a single SendItem
            toms = sub.toms if sub is not None else [self._default_ms]
            noncached = sub.noncached if sub is not None else False
            reset_after_send = sub.reset_after_send if sub is not None else False
            return [SendItem(
                topic_underlined=_underline_topic(topic),
                original_topic=topic,
                value=payload,
                toms=toms,
                noncached=noncached,
                reset_after_send=reset_after_send,
            )]

        # Try to parse JSON
        try:
            data: Any = json.loads(payload)
        except (json.JSONDecodeError, ValueError):
            log.debug("json_expand enabled but payload is not valid JSON for %s", topic)
            return [SendItem(
                topic_underlined=_underline_topic(topic),
                original_topic=topic,
                value=payload,
                toms=sub.toms,
                noncached=sub.noncached,
                reset_after_send=sub.reset_after_send,
            )]

        items: list[SendItem] = []

        for jf in sub.json_fields:
            if jf.id_raw == "*":
                # Expand all top-level keys (only works on dicts)
                if isinstance(data, dict):
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
                else:
                    log.debug("Wildcard * expansion requires a dict payload for %s", topic)
            else:
                value = extract_by_path(data, jf.path)
                if value is None:
                    log.debug("Field %r not found in payload for %s", jf.id_raw, topic)
                    continue
                suffix = _path_to_topic_suffix(jf.path)
                expanded_topic = f"{topic}/{suffix}"
                items.append(SendItem(
                    topic_underlined=_underline_topic(expanded_topic),
                    original_topic=expanded_topic,
                    value=str(value),
                    toms=jf.toms,
                    noncached=jf.noncached,
                    reset_after_send=jf.reset_after_send,
                ))

        return items

    # ------------------------------------------------------------------
    # Stage 4: Convert
    # ------------------------------------------------------------------

    _BOOL_TRUE = {"true", "yes", "on"}
    _BOOL_FALSE = {"false", "no", "off"}

    def _convert_value(self, value: str) -> str:
        # Boolean conversion first
        if self._convert_booleans:
            lower = value.strip().lower()
            if lower in self._BOOL_TRUE:
                value = "1"
            elif lower in self._BOOL_FALSE:
                value = "0"

        # User-defined conversions
        if self._conversions:
            stripped = value.strip()
            if stripped in self._conversions:
                value = self._conversions[stripped]

        return value

    def _convert(self, items: list[SendItem]) -> list[SendItem]:
        for item in items:
            item.value = self._convert_value(item.value)
        return items

    # ------------------------------------------------------------------
    # Subscription matching
    # ------------------------------------------------------------------

    def _find_subscription(self, topic: str) -> Subscription | None:
        """Return the first subscription whose pattern matches topic, or None."""
        for sub in self._subscriptions:
            if self._topic_matches(sub.topic, topic):
                return sub
        return None

    @staticmethod
    def _topic_matches(pattern: str, topic: str) -> bool:
        """MQTT wildcard matching.

        Rules:
          - `#` alone matches everything
          - `prefix/#` matches anything starting with prefix/
          - `+` matches exactly one non-empty topic level
          - All other characters are literal
        """
        if pattern == "#":
            return True

        pattern_parts = pattern.split("/")
        topic_parts = topic.split("/")

        pi = 0  # pattern index
        ti = 0  # topic index

        while pi < len(pattern_parts) and ti < len(topic_parts):
            pp = pattern_parts[pi]
            if pp == "#":
                # Matches the rest — success
                return True
            elif pp == "+":
                # Matches exactly this level — advance both
                pi += 1
                ti += 1
            else:
                if pp != topic_parts[ti]:
                    return False
                pi += 1
                ti += 1

        # If pattern ended with a # we already returned True above.
        # Both must be exhausted for a match.
        return pi == len(pattern_parts) and ti == len(topic_parts)
