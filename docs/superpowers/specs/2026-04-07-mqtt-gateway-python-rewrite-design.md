# MQTT Gateway Python Rewrite — Design Spec

**Datum:** 2026-04-07
**Branch:** feature/mqtt-gateway-python
**Status:** Approved

## Zusammenfassung

Rewrite des MQTT Gateway Daemons (`mqttgateway.pl`) von Perl nach Python mit asyncio. Nur V2-Modus (Opt-In). WebUI, PHP-AJAX-Backend, mqttfinder.pl und mqtt-handler.pl bleiben unverändert. Der neue Daemon liest/schreibt die gleichen JSON-Config-Dateien und produziert die gleichen Shared-Memory-Dateien für die WebUI.

## Entscheidungen

| Entscheidung | Wahl |
|---|---|
| Scope | Nur Daemon (mqttgateway.pl -> Python) |
| V1/V2 | Nur V2 (Opt-In), kein V1-Fallback |
| Hilfs-Daemons | mqttfinder.pl, mqtt-handler.pl bleiben Perl |
| Architektur | Monolithischer async Daemon (Ansatz A) |
| Async-Stack | asyncio + aiomqtt + httpx |
| Transformer | Bestehende PHP/Perl via async Subprocess |
| Deployment | systemd Service |
| Performance | Alle bekannten Optimierungen, kein festes Ziel |
| Logging | Gleicher Pfad/Format fuer WebUI-Kompatibilitaet |

## Projektstruktur

```
sbin/
  mqttgateway/
    __main__.py          # Entry Point: python3 -m mqttgateway
    config.py            # Config laden, V2-Format parsen, File-Watcher
    mqtt_client.py       # aiomqtt Subscription-Management
    pipeline.py          # Message-Pipeline: Filter -> Expand -> Convert -> Debounce -> Route
    miniserver.py        # HTTP (httpx) + UDP Sender, Delta-Cache, Connection Pooling
    udp_listener.py      # MS -> MQTT Reverse-Kanal (UDP In-Port)
    transformer.py       # Async Subprocess-Aufrufe fuer PHP/Perl Transformer
    logging_compat.py    # LoxBerry-kompatibles Logging nach /dev/shm/
    state.py             # Shared State: Topic-Snapshot fuer WebUI
```

Package-Aufruf: `python3 /opt/loxberry/sbin/mqttgateway` (erkennt `__main__.py`).

## Config-Management (config.py)

### Quellen

- `general.json` -> Broker-Host/Port/Credentials, UDP-Ports, Miniserver-Liste
- `mqttgateway.json` -> V2 Subscriptions, Conversions, Miniserver-Routing

### Verhalten

- **Startup:** Config komplett laden, Subscriptions parsen, Regex-Filter vorkompilieren (`re.compile()`)
- **File-Watcher:** asyncio + `os.stat()` Polling alle 5 Sekunden auf mtime-Aenderung (kein externes Dependency)
- **Hot-Reload:** Bei Config-Aenderung ohne Restart: Subscriptions neu aufbauen, MQTT Re-Subscribe, Caches invalidieren
- **Plugin-Configs:** Weiterhin aus `/config/plugins/<plugin>/mqtt_subscriptions.cfg` etc. lesen
- **Plugin-State:** Aenderungen ueber `/dev/shm/plugins_state.json` erkennen

### V2 Config-Parsing

Michaels @@-Pfadnotation wird beim Laden in Lookup-Struktur konvertiert:

```python
# Config: "rollen@@[3]@@rolle"
# Parsed: ["rollen", 3, "rolle"]
# Runtime: json_payload["rollen"][3]["rolle"]
```

- `Toms`-Array pro Subscription und pro JSON-Feld ergibt Routing-Map Topic->Miniserver
- Praesenz in Config = abonniert (kein enabled-Flag)

## Message-Pipeline (pipeline.py)

Ersetzt die Perl `received()` Funktion. Stufen:

### Stufe 1: Early Filter

- Gateway-eigene Topics verwerfen (`hostname/mqttgateway/*`)
- DoNotForward-Topics per Hash-Lookup (O(1))
- Subscription-Filter per vorkompilierter Regex

Groesster Einzelgewinn: ~38% CPU-Reduktion laut Benchmark.

### Stufe 2: Topic-Debounce

- Gleicher Topic + gleicher Payload wie letztes Mal -> Skip
- Default: reiner Wert-Vergleich (0ms Zeitfenster)
- Adressiert Tasmota-Spam (identische Payloads alle 500ms)

### Stufe 3: JSON Expansion

- Nur wenn `Subscription.Jsonexpand = true`
- @@-Pfadnotation: gezielt konfigurierte Felder extrahieren statt alles flatten
- Rekursiv, Arrays mit Index-Modus (0-basiert in Config, 1-basiert Richtung MS)
- Wildcard `Json: ["*"]` fuer "alle Felder expandieren"

### Stufe 4: Convert

- Boolean: `true/false` -> `1/0`
- User-Conversions (Lookup-Dict)
- Plugin-Conversions

### Stufe 5: Route & Send

- Toms-Array bestimmt Ziel-Miniserver
- Pro MS: Noncached -> UDP sofort, Cached -> HTTP Delta-Send
- ResetAfterSend -> 0 nachsenden nach konfigurierbarem Delay (async)
- Transformer -> subprocess falls noetig

## Miniserver-Kommunikation (miniserver.py)

### HTTP (Cached Delta-Send)

- Ein `httpx.AsyncClient` pro Miniserver mit Connection Pooling (Keep-Alive)
- Delta-Cache im Memory (Dict): nur geaenderte Werte werden gesendet
- Endpoint: `http://<ms>/dev/sps/io/<topic>/<value>`
- Topic-Bereinigung: `/` und `%` -> `_` (Loxone-Einschraenkung)
- Periodischer Full-Refresh alle 60 Minuten
- Miniserver-Reboot-Erkennung via Heartbeat-Check, bei Reboot sofort Full-Refresh
- Credentials aus `general.json`

### UDP (Non-Cached)

- `asyncio.DatagramProtocol` fuer non-blocking UDP
- Format: `topic=value\n`
- Fuer Noncached-Topics und ResetAfterSend

### Reset-After-Send

- Nach Senden: `await asyncio.sleep(delay)` (konfigurierbar, default 13ms), dann `0` senden
- Non-blocking, parallele RAS-Tasks moeglich

### State-Snapshot fuer WebUI

- Alle ein-/ausgehenden Topics periodisch nach `/dev/shm/mqttgateway_topics.json`
- Gleiche Struktur wie bisher (Datenverkehr-Tab kompatibel)
- Schreib-Interval: alle 2 Sekunden

## UDP Listener (udp_listener.py)

- `asyncio.DatagramProtocol` auf Port 11884 (konfigurierbar)
- Parst UDP-Pakete vom Miniserver
- Format: `topic value` oder JSON `{"topic":"x","value":"y","transform":"name"}`
- Einfache Werte: direkt per aiomqtt publishen
- Mit transform-Feld: Transformer aufrufen, Ergebnis publishen
- Optional retain-Flag
- Rein event-driven, kein Polling

## Transformer (transformer.py)

### Discovery

- Beim Start und Config-Reload: `bin/mqtt/transform/` rekursiv scannen
- Jedes Script mit `skills`-Parameter aufrufen fuer Metadaten
- Cache als Dict: `{"name": {"path": "...", "input": "text|json", "output": "text|json"}}`

### Ausfuehrung

- `asyncio.create_subprocess_exec()` — non-blocking
- Timeout: 10 Sekunden, danach abbrechen + loggen
- Input via stdin, Output via stdout
- Text-Format: `topic#value` (mehrzeilig)
- JSON-Format: `{"topic": "value"}` oder `[{"topic": "value"}]`
- Ergebnis wird an MQTT Broker published

Keine Aenderung an bestehenden PHP/Perl-Transformern noetig.

## Logging (logging_compat.py)

- Python `logging`-Modul mit Custom-Formatter
- Output nach `/dev/shm/mqttgateway.log`
- Format kompatibel mit LoxBerry::Log:
  ```
  <OK> 2026-04-07 14:23:01 MQTT connected to localhost:1883
  <INFO> 2026-04-07 14:23:01 Subscribed to 12 topics
  <WARNING> 2026-04-07 14:23:05 HTTP send failed for MS_Gen2: timeout
  <ERROR> 2026-04-07 14:23:05 Transformer http2mqtt.php timed out
  ```
- Log-Level steuerbar (0=Off, 3=Errors, 4=Warning, 6=Info, 7=Debug)
- Log-Rotation: 5 MB max, 3 alte Dateien
- Zusaetzlich stdout/stderr fuer systemd Journal

## Deployment

### systemd Service

```ini
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

[Install]
WantedBy=multi-user.target
```

### Watchdog

- Daemon sendet alle 30s `sd_notify(WATCHDOG=1)` via `sdnotify` Package
- Falls Event-Loop haengt -> systemd killt und restartet

### Migration

- Altes Startup-Script `50-mqttgateway` deaktivieren/entfernen
- `mqtt-handler.pl` Action `restartgateway` auf `systemctl restart mqttgateway` umstellen

### Python Dependencies

- `aiomqtt` — async MQTT Client
- `httpx` — async HTTP mit Connection Pooling
- `sdnotify` — systemd Watchdog-Integration

Drei Packages, kein Framework.

### Python-Version

Minimum: Python 3.11 (fuer asyncio TaskGroup, shipped mit Debian Bookworm / LoxBerry 4.x).
aiomqtt erfordert mindestens Python 3.9, httpx 3.8.

## Schnittstellen zum bestehenden System

### Liest (Input)

| Datei | Zweck |
|---|---|
| `config/system/general.json` | Broker-Config, Miniserver-Liste, Gateway-Version |
| `data/system/plugindatabase.dat` | Plugin-Liste |
| `/config/plugins/<p>/mqtt_subscriptions.cfg` | Plugin-Subscriptions |
| `/config/plugins/<p>/mqtt_conversions.cfg` | Plugin-Conversions |
| `/config/plugins/<p>/mqtt_resetaftersend.cfg` | Plugin-RAS |
| `/dev/shm/plugins_state.json` | Plugin-Install/Update-Events |
| `data/system/mqttgateway.json` | V2 Subscriptions, Routing, Conversions |

### Schreibt (Output)

| Datei | Zweck |
|---|---|
| `/dev/shm/mqttgateway_topics.json` | Live Topic-Snapshot fuer WebUI |
| `/dev/shm/mqttgateway.log` | Log fuer WebUI Logs-Tab |
| `/run/shm/mshttp_mem_<msno>.json` | HTTP Delta-Cache pro Miniserver |

### Netzwerk

| Richtung | Protokoll | Port |
|---|---|---|
| Daemon -> Broker | MQTT | 1883 (konfigurierbar) |
| Daemon -> Miniserver | HTTP | 80 (pro MS konfigurierbar) |
| Daemon -> Miniserver | UDP | 11883 (konfigurierbar) |
| Miniserver -> Daemon | UDP | 11884 (konfigurierbar) |
