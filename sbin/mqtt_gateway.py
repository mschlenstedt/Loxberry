#!/usr/bin/env python3
"""MQTT Gateway V2.0 — Loxone Miniserver Bridge"""

import asyncio
import json
import logging
import os
import re
import sys
import base64
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

import aiomqtt
import aiohttp

# ─── Global state ────────────────────────────────────────────────────────────
_loglevel: int = 3
_miniservers: dict = {}
_subscriptions: list = []
_cache: dict = {}
_vi_locks: dict = {}   # vi_name -> asyncio.Lock; ensures one active send per VI

_LBSCONFIG    = Path(os.environ["LBSCONFIG"])
CONFIG_GENERAL = _LBSCONFIG / "general.json"
CONFIG_SUBS    = _LBSCONFIG / "subscriptions.json"
STATUS_FILE    = Path("/dev/shm/mqttgatwayv2_status.json")
PID_FILE       = Path("/dev/shm/mqtt_gateway.pid")

# ─── Logging ─────────────────────────────────────────────────────────────────
class _LiveStdoutHandler(logging.StreamHandler):
    """Always writes to the current sys.stdout (compatible with pytest capsys)."""
    @property
    def stream(self):
        return sys.stdout
    @stream.setter
    def stream(self, _):
        pass

_logger = logging.getLogger("mqtt_gateway")
_logger.propagate = False
_logger.setLevel(logging.DEBUG)
_log_handler = _LiveStdoutHandler()
_log_handler.setFormatter(logging.Formatter(
    '%(asctime)s.%(msecs)03d <%(levelname)s> %(message)s',
    datefmt='%H:%M:%S'
))
_logger.addHandler(_log_handler)

def _log(level: int, levelname: str, msg: str) -> None:
    if level <= _loglevel:
        record = logging.LogRecord(
            name=_logger.name, level=logging.DEBUG,
            pathname='', lineno=0, msg=msg, args=(), exc_info=None,
        )
        record.levelname = levelname
        _log_handler.emit(record)

def LOGSTART(msg: str)  -> None: _log(5, "OK",     msg)
def LOGEMERGE(msg: str) -> None: _log(0, "EMERGE", msg)
def LOGALERT(msg: str)  -> None: _log(1, "ALERT",  msg)
def LOGCRIT(msg: str)   -> None: _log(2, "CRIT",   msg)
def LOGERR(msg: str)    -> None: _log(3, "ERR",    msg)
def LOGWARN(msg: str)   -> None: _log(4, "WARN",   msg)
def LOGOK(msg: str)     -> None: _log(5, "OK",     msg)
def LOGINF(msg: str)    -> None: _log(6, "INFO",   msg)
def LOGDEB(msg: str)    -> None: _log(7, "DEBUG",  msg)

# ─── Config loading ───────────────────────────────────────────────────────────
def get_loglevel(general_data: dict) -> int:
    try:
        return int(general_data["Mqtt"]["Loglevel"])
    except (KeyError, TypeError, ValueError):
        pass
    try:
        return int(general_data["Base"]["Systemloglevel"])
    except (KeyError, TypeError, ValueError):
        return 3

def parse_miniservers(general_data: dict) -> dict:
    result = {}
    for ms_id, ms_data in general_data.get("Miniserver", {}).items():
        result[str(ms_id)] = {
            "fulluri": ms_data.get("Fulluri", ""),
        }
    return result

def parse_subscriptions(subs_data: dict) -> list:
    result = []
    for sub in subs_data.get("Subscriptions", []):
        json_fields = []
        for field in sub.get("Json", []):
            json_fields.append({
                "id":             field["Id"],
                "toms":           [str(t) for t in field.get("Toms", [])],
                "noncached":      bool(field.get("Noncached", False)),
                "resetaftersend": bool(field.get("resetaftersend", False)),
            })
        result.append({
            "id":             sub["Id"],
            "toms":           [str(t) for t in sub.get("Toms", [])],
            "noncached":      bool(sub.get("Noncached", False)),
            "resetaftersend": bool(sub.get("resetaftersend", False)),
            "jsonexpand":     bool(sub.get("Jsonexpand", False)),
            "json":           json_fields,
        })
    return result

# ─── HTTP communication ───────────────────────────────────────────────────────
async def send_http(session: aiohttp.ClientSession, ms: dict,
                    vi_name: str, value) -> tuple[bool, int | None]:
    """Send HTTP GET to Loxone Miniserver.
    Returns (True, http_status) on 2xx, (False, http_status) on HTTP error,
    (False, None) on connection error."""
    path = f"/dev/sps/io/{quote(vi_name, safe='')}/{quote(str(value), safe='')}"
    url  = ms["fulluri"] + path
    LOGDEB(f"HTTP GET {url}")
    try:
        async with session.get(
            url,
            timeout=aiohttp.ClientTimeout(total=5)
        ) as resp:
            if resp.status < 300:
                return True, resp.status
            LOGERR(f"HTTP {resp.status}: {vi_name} → MS (non-2xx response)")
            return False, resp.status
    except Exception as exc:
        LOGERR(f"HTTP failed: {vi_name} ({exc})")
        return False, None

# ─── Config watcher ───────────────────────────────────────────────────────────
async def config_watcher() -> None:
    """Async task: reload config every 5 s; re-subscribe on subscription changes."""
    global _loglevel, _miniservers, _subscriptions

    _last_general_mtime = 0.0
    _last_subs_mtime    = 0.0

    while True:
        try:
            gm = CONFIG_GENERAL.stat().st_mtime
            sm = CONFIG_SUBS.stat().st_mtime
            if gm != _last_general_mtime or sm != _last_subs_mtime:
                new_ms, new_subs, new_level = load_configs()
                _last_general_mtime = gm
                _last_subs_mtime    = sm

                old_topics = {s["id"] for s in _subscriptions}
                new_topics = {s["id"] for s in new_subs}

                _loglevel      = new_level
                _miniservers   = new_ms
                _subscriptions = new_subs

                LOGINF("Config reloaded")

                if _mqtt_client is not None:
                    for topic in old_topics - new_topics:
                        await _mqtt_client.unsubscribe(topic)
                        LOGINF(f"Unsubscribed: {topic}")
                    for topic in new_topics - old_topics:
                        await _mqtt_client.subscribe(topic)
                        LOGINF(f"Subscribed: {topic}")

        except Exception as exc:
            LOGERR(f"Config reload failed: {exc} — keeping current config")

        await asyncio.sleep(5)

# ─── MQTT Listener ────────────────────────────────────────────────────────────
_mqtt_client = None

async def mqtt_listener(queue: asyncio.Queue, mqtt_config: dict) -> None:
    """Async task: connect to MQTT broker, subscribe to all topics, feed queue."""
    global _mqtt_client
    host     = mqtt_config.get("host", "localhost")
    port     = int(mqtt_config.get("port", 1883))
    username = mqtt_config.get("username")
    password = mqtt_config.get("password")

    while True:
        try:
            client_kwargs = {"hostname": host, "port": port}
            if username and password:
                client_kwargs["username"] = username
                client_kwargs["password"] = password
            async with aiomqtt.Client(**client_kwargs) as client:
                _mqtt_client = client
                auth_info = f" (user: {username})" if username else ""
                LOGINF(f"MQTT connected to {host}:{port}{auth_info}")

                for sub in _subscriptions:
                    await client.subscribe(sub["id"])
                    LOGINF(f"Subscribed: {sub['id']}")

                loop = asyncio.get_event_loop()
                async for message in client.messages:
                    topic       = str(message.topic)
                    payload     = message.payload.decode("utf-8", errors="replace")
                    recv_mono   = loop.time()
                    recv_dt     = datetime.now()
                    recv_ts     = recv_dt.strftime("%H:%M:%S.") + f"{recv_dt.microsecond // 1000:03d}"
                    LOGDEB(f"MQTT received [{recv_ts}]: {topic} = {payload!r}")
                    await queue.put({
                        "type":        "mqtt",
                        "topic":       topic,
                        "payload":     payload,
                        "received_at": recv_mono,
                        "received_ts": recv_ts,
                    })

        except aiomqtt.MqttError as exc:
            _mqtt_client = None
            LOGERR(f"MQTT connection lost: {exc} — reconnecting in 5s")
            await asyncio.sleep(5)

# ─── HTTP worker ─────────────────────────────────────────────────────────────
async def http_worker(queue: asyncio.Queue, status_event: asyncio.Event) -> None:
    """Async task: process queue items — JSON expand, cache check, HTTP send."""
    async with aiohttp.ClientSession() as session:
        while True:
            item = await queue.get()

            if item["type"] == "reset":
                await _process_reset(session, item, status_event)
            elif item["type"] == "mqtt":
                await _process_mqtt(session, item, status_event, queue)

            await asyncio.sleep(0.01)   # 10 ms rate-limit


async def _process_reset(session, item: dict, status_event: asyncio.Event) -> None:
    vi_name = item["virtual_input"]
    ms_id   = item["miniserver"]
    ms = _miniservers.get(ms_id)
    if ms is None:
        LOGWARN(f"Reset: miniserver {ms_id} not found")
        return
    lock = _vi_locks.setdefault(vi_name, asyncio.Lock())
    if lock.locked():
        LOGDEB(f"Waiting for VI lock (reset): {vi_name}")
    async with lock:
        ok, http_status = await send_http(session, ms, vi_name, "0")
        entry = make_cache_entry("0", "sent_ok" if ok else "send_failed",
                                 ms_id, None, http_status)
        _cache[vi_name] = entry
        status_event.set()
        if ok:
            LOGOK(f"Reset sent: {vi_name} = 0 → MS{ms_id}")
        LOGDEB(f"Cache: {vi_name} | status={entry['status']} | http_status={http_status} | epoch={entry['last_updated_epoch']}")


async def _process_mqtt(session, item: dict,
                        status_event: asyncio.Event,
                        queue: asyncio.Queue) -> None:
    topic       = item["topic"]
    payload     = item["payload"]
    received_at = item["received_at"]
    received_ts = item.get("received_ts", "?")

    LOGDEB(f"Queue item: {topic} = {payload!r}")

    sub = next((s for s in _subscriptions if s["id"] == topic), None)
    if sub is None:
        LOGWARN(f"No subscription for topic: {topic}")
        return

    sends: list[tuple] = []

    if sub["jsonexpand"]:
        try:
            data = json.loads(payload)
        except json.JSONDecodeError as exc:
            LOGERR(f"JSON parse error ({topic}): {exc}")
            return
        for field in sub["json"]:
            try:
                value   = extract_json_value(data, field["id"])
                vi_name = build_vi_name(topic, field["id"])
                ms_ids  = get_miniserver_ids(field["toms"] or sub["toms"])
                sends.append((vi_name, value, ms_ids,
                               field["noncached"], field["resetaftersend"]))
            except (KeyError, IndexError, TypeError) as exc:
                LOGWARN(f"JSON extract failed for {field['id']!r}: {exc}")
    else:
        vi_name = build_vi_name(topic)
        sends.append((vi_name, payload, get_miniserver_ids(sub["toms"]),
                      sub["noncached"], sub["resetaftersend"]))

    loop = asyncio.get_event_loop()
    for vi_name, value, ms_ids, noncached, resetaftersend in sends:
        lock = _vi_locks.setdefault(vi_name, asyncio.Lock())
        if lock.locked():
            LOGDEB(f"Waiting for VI lock: {vi_name} (new value={value!r})")
        async with lock:
            for ms_id in ms_ids:
                if not should_send(vi_name, value, noncached, _cache):
                    LOGDEB(f"Cache hit (skip): {vi_name} = {value}")
                    continue
                ms = _miniservers.get(ms_id)
                if ms is None:
                    LOGWARN(f"Miniserver {ms_id} not in config")
                    continue

                elapsed_ms  = (loop.time() - received_at) * 1000
                send_dt     = datetime.now()
                send_ts     = send_dt.strftime("%H:%M:%S.") + f"{send_dt.microsecond // 1000:03d}"
                ok, http_status = await send_http(session, ms, vi_name, value)

                if ok:
                    entry = make_cache_entry(value, "sent_ok",
                                             ms_id, round(elapsed_ms, 1), http_status)
                    _cache[vi_name] = entry
                    status_event.set()
                    LOGOK(f"HTTP sent: {vi_name} = {value} → MS{ms_id}")
                    LOGDEB(f"recv={received_ts} → sent={send_ts} | total={elapsed_ms:.1f}ms | "
                           f"http_status={http_status} | epoch={entry['last_updated_epoch']}")
                else:
                    entry = _cache.get(vi_name, make_cache_entry(
                        value, "send_failed", ms_id, round(elapsed_ms, 1), http_status))
                    entry["status"]             = "send_failed"
                    entry["http_status"]        = http_status
                    entry["last_processing_ms"] = round(elapsed_ms, 1)
                    now = datetime.now()
                    entry["last_updated"]       = now.isoformat(timespec="seconds")
                    entry["last_updated_epoch"] = int(now.timestamp())
                    _cache[vi_name] = entry
                    status_event.set()
                    LOGDEB(f"Send failed: {vi_name} | http_status={http_status} | "
                           f"total={elapsed_ms:.1f}ms | epoch={entry['last_updated_epoch']}")

                if ok and resetaftersend:
                    async def _enqueue_reset(q=queue, vi=vi_name, ms=ms_id):
                        await asyncio.sleep(1)
                        await q.put({"type": "reset", "virtual_input": vi,
                                     "miniserver": ms, "noncached": True,
                                     "resetaftersend": False})
                    asyncio.create_task(_enqueue_reset())

# ─── Status file writer ───────────────────────────────────────────────────────
async def status_writer(status_event: asyncio.Event, cache: dict,
                        path: Path = STATUS_FILE) -> None:
    """Async task: write cache dict to status JSON file on every status_event."""
    while True:
        await status_event.wait()
        status_event.clear()
        try:
            path.write_text(json.dumps(cache, indent=2), encoding="utf-8")
            LOGDEB(f"Status file written: {path}")
        except Exception as exc:
            LOGERR(f"Status file write failed: {exc}")

# ─── VI name builder ──────────────────────────────────────────────────────────
def build_vi_name(topic: str, json_path: str | None = None) -> str:
    """Build Loxone Virtual Input name from MQTT topic and optional JSON path.

    Rules: '/' -> '_', '@@' -> '_', '[n]' -> 'n'
    """
    topic_part = topic.replace("/", "_")
    if json_path is None:
        return topic_part
    json_part = re.sub(r'\[(\d+)\]', r'\1', json_path)
    json_part = json_part.replace("@@", "_")
    return f"{topic_part}_{json_part}"

# ─── JSON path extractor ──────────────────────────────────────────────────────
def extract_json_value(data: dict | list, path_str: str):
    """Extract a value from nested dict/list using @@-separated path.

    Array indices are written as [n], e.g. 'rollen@@[3]@@rolle'.
    Raises KeyError or IndexError if path does not exist.
    """
    current = data
    for part in path_str.split("@@"):
        m = re.fullmatch(r'\[(\d+)\]', part)
        if m:
            current = current[int(m.group(1))]
        else:
            current = current[part]
    return current

def load_configs() -> tuple[dict, list, int]:
    """Load and parse both config files. Returns (miniservers, subscriptions, loglevel).
    Raises on file/JSON error — caller must handle."""
    general_data = json.loads(CONFIG_GENERAL.read_text(encoding="utf-8"))
    subs_data    = json.loads(CONFIG_SUBS.read_text(encoding="utf-8"))
    return (
        parse_miniservers(general_data),
        parse_subscriptions(subs_data),
        get_loglevel(general_data),
    )

# ─── Cache helpers ────────────────────────────────────────────────────────────
def should_send(vi_name: str, value, noncached: bool, cache: dict) -> bool:
    """Return True if value should be forwarded via HTTP."""
    if noncached:
        return True
    entry = cache.get(vi_name)
    if entry is None:
        return True
    return str(entry["value"]) != str(value)

def get_miniserver_ids(toms: list) -> list[str]:
    """Return miniserver IDs to send to. Empty list means Miniserver 1."""
    return ["1"] if not toms else [str(t) for t in toms]

def make_cache_entry(value, status: str, ms_id: str,
                     processing_ms: float | None = None,
                     http_status: int | None = None) -> dict:
    now = datetime.now()
    return {
        "value":              str(value),
        "status":             status,
        "http_status":        http_status,
        "miniserver":         ms_id,
        "last_updated":       now.isoformat(timespec="seconds"),
        "last_updated_epoch": int(now.timestamp()),
        "last_processing_ms": processing_ms,
    }

# ─── Main ─────────────────────────────────────────────────────────────────────
async def main() -> None:
    global _loglevel, _miniservers, _subscriptions

    try:
        _miniservers, _subscriptions, _loglevel = load_configs()
    except Exception as exc:
        print(f" CRIT: Cannot load config: {exc}", flush=True)
        return

    LOGSTART("MQTT Gateway V2.0 starting")
    LOGINF(f"Loglevel: {_loglevel}")
    LOGINF(f"Miniservers: {list(_miniservers.keys())}")
    LOGINF(f"Subscriptions: {[s['id'] for s in _subscriptions]}")

    queue        = asyncio.Queue()
    status_event = asyncio.Event()

    try:
        raw = json.loads(CONFIG_GENERAL.read_text(encoding="utf-8"))
        user   = raw["Mqtt"].get("Brokeruser", "")
        passwd = raw["Mqtt"].get("Brokerpass", "")
        mqtt_cfg = {
            "host":     raw["Mqtt"].get("Brokerhost", "localhost"),
            "port":     int(raw["Mqtt"].get("Brokerport", 1883)),
            "username": user   if (user and passwd) else None,
            "password": passwd if (user and passwd) else None,
        }
    except Exception as exc:
        LOGERR(f"Cannot read MQTT broker config: {exc}")
        return

    await asyncio.gather(
        mqtt_listener(queue, mqtt_cfg),
        http_worker(queue, status_event),
        config_watcher(),
        status_writer(status_event, _cache),
    )


if __name__ == "__main__":
    PID_FILE.write_text(str(os.getpid()))
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print(" OK: Gateway stopped by user", flush=True)
    finally:
        PID_FILE.unlink(missing_ok=True)
