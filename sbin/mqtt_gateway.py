#!/usr/bin/env python3
"""MQTT Gateway V2.0 — Loxone Miniserver Bridge"""

import asyncio
import json
import logging
import os
import re
import shlex
import socket
import subprocess
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
_reset_delay_ms: float = 1000.0
_convert_booleans: bool = True
_conversions: dict = {}
_use_http: bool = True
_use_udp: bool = False
_udp_out_port: int = 7777
_udp_in_port: int = 11884
_udp_out_sock: socket.socket | None = None

UDP_PREFIX = "MQTT: "
UDP_MAX = 220

_LBSCONFIG    = Path(os.environ["LBSCONFIG"])
_LBSBIN       = Path(os.environ.get("LBSBIN", "/opt/loxberry/bin"))
CONFIG_GENERAL    = _LBSCONFIG / "general.json"
CONFIG_GW         = _LBSCONFIG / "mqttgateway.json"
CONFIG_SUBS       = _LBSCONFIG / "subscriptions.json"
STATUS_FILE       = Path("/dev/shm/mqttgatwayv2_status.json")
PID_FILE          = Path("/dev/shm/mqtt_gateway.pid")
TRANSFORMER_BASE  = _LBSBIN / "mqtt" / "transform"
TRANSFORMER_FILE  = Path("/dev/shm/mqttgateway_transformers.json")

_trans_udpin: dict = {}  # transformer name -> metadata

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

def get_reset_delay_ms(gw_data: dict) -> float:
    try:
        return float(gw_data["Main"]["resetaftersendms"])
    except (KeyError, TypeError, ValueError):
        return 1000.0

def get_convert_booleans(gw_data: dict) -> bool:
    try:
        val = str(gw_data["Main"]["convert_booleans"]).strip().lower()
        return val in ("1", "true", "yes", "on", "enabled")
    except (KeyError, TypeError):
        return True

def get_use_http(gw_data: dict) -> bool:
    try:
        val = str(gw_data["Main"]["use_http"]).strip().lower()
        return val in ("1", "true", "yes", "on", "enabled")
    except (KeyError, TypeError):
        return True

def get_use_udp(gw_data: dict) -> bool:
    try:
        val = str(gw_data["Main"]["use_udp"]).strip().lower()
        return val in ("1", "true", "yes", "on", "enabled")
    except (KeyError, TypeError):
        return False

def get_udp_out_port(gw_data: dict) -> int:
    try:
        return int(gw_data["Main"]["udpport"])
    except (KeyError, TypeError, ValueError):
        return 7777

def parse_conversions(gw_data: dict) -> dict:
    result = {}
    for entry in gw_data.get("conversions", []):
        entry = str(entry)
        if "=" not in entry:
            continue
        text, _, value = entry.partition("=")
        text, value = text.strip(), value.strip()
        if text and value:
            result[text] = value
    return result

_BOOL_TRUE  = {"true", "yes", "on", "enabled", "enable",
               "check", "checked", "select", "selected"}
_BOOL_FALSE = {"false", "no", "off", "disabled", "disable"}

def apply_value_transforms(value: str) -> str:
    """Boolean conversion then user-defined conversions — same order as V1."""
    if _convert_booleans and value:
        lower = value.strip().lower()
        if lower in _BOOL_TRUE:
            value = "1"
        elif lower in _BOOL_FALSE:
            value = "0"
    if _conversions:
        value = _conversions.get(value.strip(), value)
    return value

def parse_miniservers(general_data: dict) -> dict:
    result = {}
    for ms_id, ms_data in general_data.get("Miniserver", {}).items():
        fulluri = ms_data.get("Fulluri", "")
        # LoxBerry wraps IPv4 addresses in brackets (e.g. [192.168.1.1]) which is
        # only valid for IPv6 literals in URLs — strip them so aiohttp can connect.
        fulluri = re.sub(r'\[(\d{1,3}(?:\.\d{1,3}){3})\]', r'\1', fulluri)
        result[str(ms_id)] = {
            "fulluri":   fulluri,
            "ipaddress": ms_data.get("Ipaddress", ""),
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

# ─── UDP OUT ──────────────────────────────────────────────────────────────────
def send_udp_bundled(host: str, port: int,
                     pairs: list[tuple[str, str]]) -> None:
    """Send vi_name=value pairs via UDP, bundled into packets up to 220 chars.

    Format per packet: 'MQTT: name1=val1 name2=val2 ' (trailing space per pair).
    A new packet is flushed whenever the next pair would exceed UDP_MAX chars.
    """
    global _udp_out_sock
    if not host or not port or not pairs:
        return
    if _udp_out_sock is None:
        _udp_out_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    packet = UDP_PREFIX
    for vi_name, value in pairs:
        pair_str = f"{vi_name}={value} "
        if packet != UDP_PREFIX and len(packet) + len(pair_str) > UDP_MAX:
            _udp_out_sock.sendto(packet.encode("utf-8"), (host, port))
            LOGDEB(f"UDP → {host}:{port}: {packet!r}")
            packet = UDP_PREFIX
        packet += pair_str

    if packet != UDP_PREFIX:
        _udp_out_sock.sendto(packet.encode("utf-8"), (host, port))
        LOGDEB(f"UDP → {host}:{port}: {packet!r}")

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
            timeout=aiohttp.ClientTimeout(total=5),
            ssl=False
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
    global _loglevel, _miniservers, _subscriptions, _reset_delay_ms, \
           _convert_booleans, _conversions, _use_http, _use_udp, _udp_out_port

    _last_general_mtime = 0.0
    _last_gw_mtime      = 0.0
    _last_subs_mtime    = 0.0

    while True:
        try:
            gm  = CONFIG_GENERAL.stat().st_mtime
            gwm = CONFIG_GW.stat().st_mtime
            sm  = CONFIG_SUBS.stat().st_mtime
            if gm != _last_general_mtime or gwm != _last_gw_mtime or sm != _last_subs_mtime:
                (new_ms, new_subs, new_level, new_reset_ms, new_conv_bool,
                 new_convs, new_use_http, new_use_udp, new_udp_out_port) = load_configs()
                _last_general_mtime = gm
                _last_gw_mtime      = gwm
                _last_subs_mtime    = sm

                old_topics = {s["id"] for s in _subscriptions}
                new_topics = {s["id"] for s in new_subs}

                _loglevel         = new_level
                _miniservers      = new_ms
                _subscriptions    = new_subs
                _reset_delay_ms   = new_reset_ms
                _convert_booleans = new_conv_bool
                _conversions      = new_convs
                _use_http         = new_use_http
                _use_udp          = new_use_udp
                _udp_out_port     = new_udp_out_port

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
    """Async task: process queue items — JSON expand, cache check, HTTP/UDP send."""
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
        now = datetime.now()
        entry = _cache.setdefault(vi_name, make_cache_entry("0", ms_id))
        entry["value"]              = "0"
        entry["miniserver"]         = ms_id
        entry["last_updated"]       = now.isoformat(timespec="seconds")
        entry["last_updated_epoch"] = int(now.timestamp())
        entry["last_processing_ms"] = None

        if _use_http:
            ok, http_status = await send_http(session, ms, vi_name, "0")
            entry["http"] = make_http_result(ok, http_status)
            status_event.set()
            if ok:
                LOGOK(f"Reset sent (HTTP): {vi_name} = 0 → MS{ms_id}")
            LOGDEB(f"Cache: {vi_name} | http_status={http_status} | epoch={entry['last_updated_epoch']}")

        if _use_udp and ms.get("ipaddress"):
            send_udp_bundled(ms["ipaddress"], _udp_out_port, [(vi_name, "0")])
            entry["udp"] = make_udp_result()
            status_event.set()
            LOGOK(f"Reset sent (UDP): {vi_name} = 0 → MS{ms_id} ({ms['ipaddress']}:{_udp_out_port})")


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
                value   = apply_value_transforms(str(extract_json_value(data, field["id"])))
                vi_name = build_vi_name(topic, field["id"])
                ms_ids  = get_miniserver_ids(field["toms"] or sub["toms"])
                sends.append((vi_name, value, ms_ids,
                               field["noncached"], field["resetaftersend"]))
            except (KeyError, IndexError, TypeError) as exc:
                LOGWARN(f"JSON extract failed for {field['id']!r}: {exc}")
    else:
        vi_name = build_vi_name(topic)
        sends.append((vi_name, apply_value_transforms(payload),
                      get_miniserver_ids(sub["toms"]),
                      sub["noncached"], sub["resetaftersend"]))

    loop = asyncio.get_event_loop()
    # Collect UDP pairs per ms_id for bundled sending after HTTP pass
    udp_pairs: dict[str, list[tuple[str, str]]] = {}

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

                elapsed_ms = (loop.time() - received_at) * 1000
                send_dt    = datetime.now()
                send_ts    = send_dt.strftime("%H:%M:%S.") + f"{send_dt.microsecond // 1000:03d}"
                ok = False

                # Create or update top-level cache entry
                entry = _cache.setdefault(vi_name, make_cache_entry(value, ms_id, round(elapsed_ms, 1)))
                entry["value"]              = str(value)
                entry["miniserver"]         = ms_id
                entry["last_updated"]       = send_dt.isoformat(timespec="seconds")
                entry["last_updated_epoch"] = int(send_dt.timestamp())
                entry["last_processing_ms"] = round(elapsed_ms, 1)

                if _use_http:
                    ok, http_status = await send_http(session, ms, vi_name, value)
                    entry["http"] = make_http_result(ok, http_status)
                    status_event.set()
                    if ok:
                        LOGOK(f"HTTP sent: {vi_name} = {value} → MS{ms_id}")
                        LOGDEB(f"recv={received_ts} → sent={send_ts} | total={elapsed_ms:.1f}ms | "
                               f"http_status={http_status} | epoch={entry['last_updated_epoch']}")
                    else:
                        LOGDEB(f"Send failed: {vi_name} | http_status={http_status} | "
                               f"total={elapsed_ms:.1f}ms | epoch={entry['last_updated_epoch']}")

                if _use_udp and ms.get("ipaddress"):
                    udp_pairs.setdefault(ms_id, []).append((vi_name, value))
                    if not _use_http:
                        ok = True

                if ok and resetaftersend:
                    async def _enqueue_reset(q=queue, vi=vi_name, ms=ms_id,
                                             delay_ms=_reset_delay_ms):
                        await asyncio.sleep(delay_ms / 1000)
                        await q.put({"type": "reset", "virtual_input": vi,
                                     "miniserver": ms, "noncached": True,
                                     "resetaftersend": False})
                    asyncio.create_task(_enqueue_reset())

    # Send bundled UDP packets and update UDP status in cache
    if _use_udp and udp_pairs:
        for ms_id, pairs in udp_pairs.items():
            ms = _miniservers.get(ms_id)
            if ms and ms.get("ipaddress"):
                send_udp_bundled(ms["ipaddress"], _udp_out_port, pairs)
                LOGOK(f"UDP sent: {len(pairs)} VI(s) → MS{ms_id} ({ms['ipaddress']}:{_udp_out_port})")
                for vi_name, _ in pairs:
                    if vi_name in _cache:
                        _cache[vi_name]["udp"] = make_udp_result()
                status_event.set()

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

# ─── Transformers ─────────────────────────────────────────────────────────────
def trans_skills(filepath: Path) -> dict:
    """Call transformer script with 'skills' and parse key=value output."""
    try:
        filepath.chmod(0o774)
        result = subprocess.run(
            [str(filepath), "skills"],
            capture_output=True, text=True, timeout=5
        )
        skills: dict = {}
        for line in result.stdout.splitlines():
            if "=" in line:
                k, _, v = line.partition("=")
                skills[k.strip()] = v.strip()
        skills["input"]  = "json" if skills.get("input")  == "json" else "text"
        skills["output"] = "json" if skills.get("output") == "json" else "text"
        return skills
    except Exception as exc:
        LOGWARN(f"trans_skills({filepath.name}): {exc}")
        return {"input": "text", "output": "text", "description": "", "link": ""}


def trans_load_directories() -> None:
    """Scan shipped/udpin and custom/udpin, populate _trans_udpin and write shm file."""
    global _trans_udpin
    _trans_udpin = {}
    for trans_type in ("shipped", "custom"):
        base = TRANSFORMER_BASE / trans_type / "udpin"
        if not base.is_dir():
            continue
        for filepath in sorted(base.rglob("*")):
            if not filepath.is_file() or filepath.stat().st_size == 0:
                continue
            name = filepath.stem.lower().replace(" ", "_")
            skills = trans_skills(filepath)
            _trans_udpin[name] = {
                "filename":    str(filepath),
                "type":        trans_type,
                "extension":   filepath.suffix.lstrip("."),
                "description": skills.get("description", ""),
                "link":        skills.get("link", ""),
                "input":       skills["input"],
                "output":      skills["output"],
            }
            LOGINF(f"Transformer loaded: {name} ({trans_type})")
    try:
        TRANSFORMER_FILE.write_text(
            json.dumps({"udpin": _trans_udpin}, indent=2), encoding="utf-8"
        )
        LOGDEB(f"Transformer data written to {TRANSFORMER_FILE}")
    except Exception as exc:
        LOGWARN(f"Could not write transformer data file: {exc}")


async def trans_process(
    transformer: str, command: str, topic: str, message: str
) -> list[tuple[str, str, str]]:
    """Execute transformer script and return list of (command, topic, message)."""
    t = _trans_udpin[transformer]
    if t["input"] == "json":
        param = shlex.quote(json.dumps({topic: message}))
    else:
        param = shlex.quote(f"{topic}#{message}")

    try:
        proc = await asyncio.create_subprocess_shell(
            f"{shlex.quote(t['filename'])} {param}",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_b, stderr_b = await asyncio.wait_for(proc.communicate(), timeout=10)
        output = stdout_b.decode("utf-8", errors="replace").strip()
        if stderr_b:
            LOGWARN(f"Transformer {transformer} stderr: {stderr_b.decode()[:200]}")
    except Exception as exc:
        LOGERR(f"Transformer {transformer} execution failed: {exc}")
        return []

    results: list[tuple[str, str, str]] = []
    if t["output"] == "json":
        try:
            parsed = json.loads(output)
            items = parsed if isinstance(parsed, list) else [parsed]
            for item in items:
                for k, v in item.items():
                    results.append((command, k, str(v)))
        except Exception as exc:
            LOGERR(f"Transformer {transformer} JSON parse error: {exc} — output: {output[:200]}")
    else:
        for line in output.splitlines():
            if "#" in line:
                t_topic, _, t_val = line.partition("#")
                results.append((command, t_topic.strip(), t_val.strip()))
    return results


# ─── UDP IN ───────────────────────────────────────────────────────────────────
class UdpInProtocol(asyncio.DatagramProtocol):
    """asyncio protocol that receives UDP packets and dispatches handle_udp_in."""

    def connection_made(self, transport) -> None:
        self._transport = transport

    def datagram_received(self, data: bytes, addr: tuple) -> None:
        try:
            msg = data.decode("utf-8", errors="replace").strip()
        except Exception:
            return
        if msg:
            asyncio.create_task(handle_udp_in(msg, addr))

    def error_received(self, exc: Exception) -> None:
        LOGERR(f"UDP IN socket error: {exc}")

    def connection_lost(self, exc) -> None:
        LOGWARN("UDP IN socket closed")


async def handle_udp_in(msg: str, addr: tuple) -> None:
    """Parse a UDP IN datagram and publish to the MQTT broker.

    Supports (in order):
      save_relayed_states            internal no-op
      reconnect                      clear send-cache
      YYYY-MM-DD HH:MM:SS;name;val   Loxone Logger → retain logger/{host}/{name}
      {"topic":...,"value":...}      JSON publish/retain
      publish topic message          explicit publish
      retain  topic message          explicit retain with retain-flag
      topic message                  legacy publish (2+ words; 1st word = topic)
    """
    LOGOK(f"UDP IN from {addr[0]}:{addr[1]}: {msg}")

    # ── 1. Internal save trigger ─────────────────────────────────────────────
    if msg == "save_relayed_states":
        return

    # ── 2. Loxone Logger  "YYYY-MM-DD HH:MM:SS;name;value" ──────────────────
    m = re.match(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2};(.*);(.*)', msg)
    if m:
        host_short = addr[0].split(".")[0]
        topic   = f"logger/{host_short}/{m.group(1)}"
        payload = m.group(2).strip()
        await _mqtt_udp_publish(topic, payload, retain=True)
        return

    # ── 3. JSON format ───────────────────────────────────────────────────────
    command = udptopic = udpmessage = transformer = None
    try:
        data = json.loads(msg)
        if isinstance(data, dict):
            udptopic    = str(data.get("topic", ""))
            udpmessage  = str(data.get("value", ""))
            retain_raw  = str(data.get("retain", "0")).strip().lower()
            command     = "retain" if retain_raw in _BOOL_TRUE else "publish"
            transformer = data.get("transform")
    except (json.JSONDecodeError, ValueError):
        pass

    # ── 4. Text format ───────────────────────────────────────────────────────
    if command is None:
        # Split into at most 4 parts — mirrors V1 split(/\ /, $udpmsg, 4)
        parts = (msg.split(" ", 3) + ["", "", "", ""])[:4]
        cmd, part2, part3, part4 = parts

        KNOWN = {"publish", "retain", "reconnect", "save_relayed_states"}
        if cmd.lower() not in KNOWN:
            # Legacy "topic [rest...]": everything after topic is the message
            command    = "publish"
            udptopic   = cmd
            udpmessage = " ".join([p for p in (part2, part3, part4) if p]).strip()
        else:
            command = cmd.lower()
            # Check if part2 is a known transformer name (mirrors V1 logic)
            if part2.lower() in _trans_udpin:
                transformer = part2.lower()
                udptopic    = part3
                udpmessage  = part4
            else:
                udptopic   = part2
                udpmessage = " ".join([p for p in (part3, part4) if p]).strip()

    # ── 5. Execute command ───────────────────────────────────────────────────
    if command == "reconnect":
        LOGOK("UDP IN: reconnect — clearing send-cache")
        _cache.clear()
        return

    if command in ("publish", "retain") and udptopic:
        if transformer and transformer in _trans_udpin:
            LOGINF(f"UDP IN: transformer '{transformer}' for topic '{udptopic}'")
            results = await trans_process(transformer, command, udptopic, udpmessage or "")
            for cmd_r, topic_r, msg_r in results:
                await _mqtt_udp_publish(topic_r, msg_r, retain=(cmd_r == "retain"))
        else:
            await _mqtt_udp_publish(udptopic, udpmessage or "",
                                    retain=(command == "retain"))
        return

    LOGERR(f"UDP IN: unrecognised command or missing topic: {msg!r}")


async def _mqtt_udp_publish(topic: str, payload: str, retain: bool = False) -> None:
    if _mqtt_client is None:
        LOGWARN(f"UDP IN: MQTT not connected — dropping: {topic} = {payload!r}")
        return
    try:
        await _mqtt_client.publish(topic, payload, retain=retain)
        flag = " (retain)" if retain else ""
        LOGDEB(f"UDP IN: published{flag} '{topic}' = '{payload}'")
    except Exception as exc:
        LOGERR(f"UDP IN: MQTT publish failed: {exc}")


async def udp_listener(port: int) -> None:
    """Async task: listen for UDP IN datagrams on *port* (always active)."""
    loop = asyncio.get_running_loop()
    while True:
        try:
            transport, _ = await loop.create_datagram_endpoint(
                UdpInProtocol,
                local_addr=("0.0.0.0", port),
            )
            LOGOK(f"UDP IN listening on port {port}")
            try:
                await asyncio.Future()  # run until cancelled
            finally:
                transport.close()
        except Exception as exc:
            LOGERR(f"UDP IN listener failed: {exc} — retrying in 5s")
            await asyncio.sleep(5)

# ─── VI name builder ──────────────────────────────────────────────────────────
def build_vi_name(topic: str, json_path: str | None = None) -> str:
    """Build Loxone Virtual Input name from MQTT topic and optional JSON path.

    Rules: '/' -> '_', ' ' -> '_', '@@' -> '_', '[n]' -> 'n'
    """
    topic_part = topic.replace("/", "_").replace(" ", "_")
    if json_path is None:
        return topic_part
    json_part = re.sub(r'\[(\d+)\]', r'\1', json_path)
    json_part = json_part.replace("@@", "_").replace(" ", "_")
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

def load_configs() -> tuple[dict, list, int, float, bool, dict, bool, bool, int]:
    """Load and parse config files.
    Returns (miniservers, subscriptions, loglevel, reset_delay_ms, convert_booleans,
             conversions, use_http, use_udp, udp_out_port).
    Raises on file/JSON error — caller must handle."""
    general_data = json.loads(CONFIG_GENERAL.read_text(encoding="utf-8"))
    gw_data      = json.loads(CONFIG_GW.read_text(encoding="utf-8"))
    subs_data    = json.loads(CONFIG_SUBS.read_text(encoding="utf-8"))
    return (
        parse_miniservers(general_data),
        parse_subscriptions(subs_data),
        get_loglevel(general_data),
        get_reset_delay_ms(gw_data),
        get_convert_booleans(gw_data),
        parse_conversions(gw_data),
        get_use_http(gw_data),
        get_use_udp(gw_data),
        get_udp_out_port(gw_data),
    )

# ─── Cache helpers ────────────────────────────────────────────────────────────
def should_send(vi_name: str, value, noncached: bool, cache: dict) -> bool:
    """Return True if value should be forwarded."""
    if noncached:
        return True
    entry = cache.get(vi_name)
    if entry is None:
        return True
    return str(entry["value"]) != str(value)

def get_miniserver_ids(toms: list) -> list[str]:
    """Return miniserver IDs to send to. Empty list means Miniserver 1."""
    return ["1"] if not toms else [str(t) for t in toms]

def make_cache_entry(value, ms_id: str,
                     processing_ms: float | None = None) -> dict:
    now = datetime.now()
    return {
        "value":              str(value),
        "miniserver":         ms_id,
        "last_updated":       now.isoformat(timespec="seconds"),
        "last_updated_epoch": int(now.timestamp()),
        "last_processing_ms": processing_ms,
        "http":               None,
        "udp":                None,
    }

def make_http_result(ok: bool, http_status: int | None) -> dict:
    now = datetime.now()
    return {
        "status":          "sent_ok" if ok else "send_failed",
        "http_status":     http_status,
        "last_sent":       now.isoformat(timespec="seconds"),
        "last_sent_epoch": int(now.timestamp()),
    }

def make_udp_result() -> dict:
    now = datetime.now()
    return {
        "status":          "sent_ok",
        "last_sent":       now.isoformat(timespec="seconds"),
        "last_sent_epoch": int(now.timestamp()),
    }

# ─── Main ─────────────────────────────────────────────────────────────────────
async def main() -> None:
    global _loglevel, _miniservers, _subscriptions, _reset_delay_ms, \
           _convert_booleans, _conversions, _use_http, _use_udp, \
           _udp_out_port, _udp_in_port

    try:
        (_miniservers, _subscriptions, _loglevel, _reset_delay_ms,
         _convert_booleans, _conversions,
         _use_http, _use_udp, _udp_out_port) = load_configs()
    except Exception as exc:
        print(f" CRIT: Cannot load config: {exc}", flush=True)
        return

    LOGSTART("MQTT Gateway V2.0 starting")
    trans_load_directories()
    LOGINF(f"Loglevel: {_loglevel}")
    LOGINF(f"Miniservers: {list(_miniservers.keys())}")
    LOGINF(f"Subscriptions: {[s['id'] for s in _subscriptions]}")
    LOGINF(f"use_http={_use_http}  use_udp={_use_udp}  udp_out_port={_udp_out_port}")

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
        _udp_in_port = int(raw["Mqtt"].get("Udpinport", 11884))
    except Exception as exc:
        LOGERR(f"Cannot read MQTT broker config: {exc}")
        return

    LOGINF(f"UDP IN port: {_udp_in_port}")

    await asyncio.gather(
        mqtt_listener(queue, mqtt_cfg),
        http_worker(queue, status_event),
        config_watcher(),
        status_writer(status_event, _cache),
        udp_listener(_udp_in_port),
    )


if __name__ == "__main__":
    PID_FILE.write_text(str(os.getpid()))
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print(" OK: Gateway stopped by user", flush=True)
    finally:
        PID_FILE.unlink(missing_ok=True)
