# MQTT Gateway Benchmark Tool — Design Spec

**Datum:** 2026-03-24
**Ziel:** Isolierte Messung der Performance-Optimierungen in mqttgateway.pl
**Plattform:** LoxBerry 3.0.1.3 auf Raspberry Pi 4 (4GB)

## Motivation

Die mqttgateway.pl verbraucht 11,3% CPU dauerhaft auf einer typischen LoxBerry-Installation. Eine optimierte Variante (`mqttgateway_optimized.pl`) existiert mit 7 Fixes. Dieses Benchmark-Tool misst den Impact jeder einzelnen Optimierung isoliert und liefert reproduzierbare Zahlen für das Interview mit den Core-Entwicklern am 08.04.2026.

## Architektur

### Ansatz: Hybrid (Shell-Orchestrierung + Perl-Lastgenerator)

Trennung von Concerns: Bash orchestriert die Testruns (leichtgewichtig), Perl erzeugt die MQTT-Last (präzises Timing).

### Dateien

```
/opt/loxberry/sbin/benchmark/
├── mqtt-benchmark.sh              # Orchestrierung: Testruns steuern, Metriken sammeln, Report erzeugen
├── mqtt-loadgen.pl                # Lastgenerator: MQTT-Messages mit konfigurierbarer Rate publishen
├── mqtt-metric-collector.pl       # Leichtgewichtiger Metriken-Sammler (Perl, nicht Bash)
├── mqttgateway_benchmarkable.pl   # Optimierte Gateway mit Feature-Flag-Conditionals
└── /tmp/mqtt-benchmark/results/   # CSV-Output pro Testlauf (beschreibbares Verzeichnis)
```

### Ablauf eines Benchmarks

1. `mqtt-benchmark.sh` stoppt die laufende Gateway
2. Setzt Feature-Flags (Environment-Variablen)
3. Startet die Gateway (Original oder Optimized)
4. Wartet auf Broker-Connection (healthcheck)
5. Startet `mqtt-loadgen.pl` im Hintergrund
6. Sammelt Metriken via `/proc/[pid]/stat` alle 500ms
7. Nach Testdauer: stoppt Loadgen, sammelt Ergebnisse
8. Wiederholt für nächste Konfiguration
9. Am Ende: Vergleichstabelle + CSV-Export

## Feature-Flag-Instrumentierung

### Vorbereitung: `mqttgateway_benchmarkable.pl`

Die existierende `mqttgateway_optimized.pl` hat alle 7 Fixes hard-coded. Für isolierte Messung wird eine Benchmark-Variante erstellt (`mqttgateway_benchmarkable.pl`), die jeden Fix in einen Environment-Variable-Guard wickelt:

```perl
# Beispiel FIX 1: Early Filter
if ($ENV{BENCH_EARLY_FILTER}) {
    # Optimierter Pfad: DoNotForward/Regex VOR JSON-Expansion
    return if $donotforward{$topic};
    return if $filter_re && $topic =~ $filter_re;
}
# Danach: JSON-Expansion (immer)
```

**Besondere Fälle:**
- **FIX 2 (Connection Pool):** Flag steuert ob `mshttp_send_mem_fast` (optimiert) oder `LoxBerry::MQTTGateway::IO::mshttp_send_mem2` (original) aufgerufen wird. Betrifft 3 Call-Sites.
- **FIX 6 (Flatten Singleton):** `Hash::Flatten` wird immer einmal instanziiert (Compile-Time), aber Flag steuert ob das Singleton oder eine Neu-Instanziierung pro Call genutzt wird.
- **FIX 7 (JSON::XS):** `BEGIN`-Block lädt immer `JSON::XS` wenn verfügbar. Flag steuert ob `decode_json` via XS oder PP aufgerufen wird.

### Feature-Flags

| Flag | Fix | Beschreibung |
|------|-----|-------------|
| `BENCH_EARLY_FILTER` | FIX 1 (HIGH) | DoNotForward/Regex VOR JSON-Expansion |
| `BENCH_CONNECTION_POOL` | FIX 2 (HIGH) | Persistente LWP::UserAgent mit Keep-Alive |
| `BENCH_MS_CACHE` | FIX 3 (HIGH) | get_miniservers() Cache statt pro Call |
| `BENCH_PRECOMPILED_REGEX` | FIX 4 (MEDIUM) | qr// statt Runtime-Kompilierung |
| `BENCH_OWN_TOPIC_FILTER` | FIX 5 (MEDIUM) | Gateway-eigene Topics früh abfangen |
| `BENCH_FLATTEN_SINGLETON` | FIX 6 (LOW) | Hash::Flatten einmal instanziieren |
| `BENCH_JSON_XS` | FIX 7 (LOW) | JSON::XS bevorzugen |

### Testruns

| Run | Beschreibung |
|-----|-------------|
| 0 | Original `mqttgateway.pl` (Baseline) |
| 1 | Benchmarkable, alle Flags AUS (Infrastruktur-Overhead der Benchmark-Variante — erwartet: <5% Abweichung zu Run 0) |
| 2-8 | Benchmarkable, jeweils nur EIN Flag AN (isolierte Messung) |
| 9 | Benchmarkable, alle Flags AN (Gesamtverbesserung) |
| 10 | Original `mqttgateway.pl` + Stresstest (Stufen 10-500 msg/s) |
| 11 | Benchmarkable, alle Flags AN + Stresstest (Stufen 10-500 msg/s) |

12 Runs. Realistic Runs (0-9): 60s + 20s Cooldown = ~13 Minuten. Stresstest Runs (10-11): je ~5 Minuten (Stufen à 60s). **Gesamt: ~23 Minuten.**

### Cooldown zwischen Runs

- 20 Sekunden Pause zwischen jedem Run
- CPU-Temperatur wird via `/sys/class/thermal/thermal_zone0/temp` geprüft
- Falls >75°C: warten bis <70°C bevor nächster Run startet
- Mosquitto-Broker wird zwischen Runs nicht neugestartet (retained Messages bleiben, realistischer)

## Lastgenerator (`mqtt-loadgen.pl`)

### Realistisches Szenario

- 7 simulierte Clients (Tasmota x3, Zigbee2MQTT, Venus, etc.)
- Typische Topic-Strukturen: `tasmota/sensor1/SENSOR`, `zigbee2mqtt/lamp1`, `venus/battery/Soc`
- Realistische Payloads (JSON mit nested Objects — triggert Hash::Flatten)
- Realistische Raten: ~2msg/s pro Tasmota, ~1msg/s Venus, periodische Bursts von Zigbee2MQTT
- Gesamt: ca. 15-20 msg/s

### Stresstest

- Konfigurierbar via Kommandozeile: `--rate 50 --topics 20 --duration 60`
- Stufen: 10, 50, 100, 200, 500 msg/s
- Gleiche Payload-Struktur wie realistisch, nur mehr davon
- Erkennt automatisch ab wann Messages verloren gehen

### Selbsttest des Loadgen

Vor dem eigentlichen Benchmark führt der Loadgen einen Selbsttest durch: maximale sustainable Publish-Rate ohne Gateway, nur Broker. Das Ergebnis wird im Report als "Loadgen-Obergrenze" dokumentiert. Stresstest-Stufen die über diesem Wert liegen werden übersprungen.

### Messung

- Published direkt an lokalen Mosquitto-Broker (`localhost:1883`)
- Nutzt `Net::MQTT::Simple` (bereits auf LoxBerry vorhanden)
- Jede Message bekommt Timestamp im Payload für Latenz-Messung

## Metriken

### Metriken-Sammler (`mqtt-metric-collector.pl`)

Ein leichtgewichtiger Perl-Prozess (nicht Bash-Subshells!) der alle 500ms `/proc/[pid]/stat` direkt liest. Erwarteter Overhead: <0,5% CPU auf dem RPi 4. Schreibt Samples in eine temporäre CSV.

### Prozess-Metriken (alle 500ms)

- **CPU-Auslastung:** user + system CPU-Zeit aus `/proc/[pid]/stat` → CPU%
- **RAM-Verbrauch:** RSS (Resident Set Size)
- **CPU-Temperatur:** `/sys/class/thermal/thermal_zone0/temp` (Thermal-Throttling-Erkennung)

### Durchsatz-Metriken (vom Loadgen)

- **Messages gesendet:** Loadgen zählt mit
- **Messages verarbeitet:** Änderungsrate in `/dev/shm/mshttp_mem_*.json` (Delta-Cache der Gateway)
- **Verlustrate:** 1 - (verarbeitet/gesendet)
- **HTTP-Calls/s:** Gezählt via Instrumentierung in der benchmarkable Gateway — ein atomarer Counter der bei jedem `mshttp_send` inkrementiert und vom Metric-Collector gelesen wird (über Shared-Memory-File `/dev/shm/bench_http_counter`)

### Latenz-Messung

Die Gateway-Pipeline endet mit einem HTTP-Call an den Miniserver, nicht mit einem MQTT-Publish. Ein MQTT-Probe-Subscriber kann daher die End-to-End-Latenz nicht messen.

**Lösung:** Die benchmarkable Gateway wird mit einem Timestamp-Log instrumentiert:
- Loadgen schreibt Timestamp in den MQTT-Payload: `{"_bench_ts": 1711234567.123, "temperature": 22.5, ...}`
- Gateway loggt beim HTTP-Send: `bench_ts, send_ts` in `/dev/shm/bench_latency.log`
- Metric-Collector liest das Log am Ende des Runs und berechnet: min/avg/max/p95 Latenz

Das misst die tatsächliche MQTT-receive → HTTP-send Latenz innerhalb der Gateway.

## Report & Scoring

### Terminal-Output

```
══════════════════════════════════════════════════════════════
  SYSTEMKONFIGURATION
══════════════════════════════════════════════════════════════
  Hardware:     Raspberry Pi 4 Model B Rev 1.4, 4GB RAM
  OS:           Debian 11 (Bullseye), Kernel 6.1.x
  LoxBerry:     3.0.1.3
  Perl:         5.32.1
  Mosquitto:    2.0.x

  Miniserver:   2 (MS1: 192.168.x.x, MS2: 192.168.x.x)
  MQTT Clients: 7 (Tasmota x3, Zigbee2MQTT, Venus, ...)
  Plugins:      7 installiert
  Uptime:       19 Tage

  CPU Load vor Test:  0.46
  RAM frei vor Test:  594 MB
  Swap:               0 MB used
══════════════════════════════════════════════════════════════

  GESAMTVERGLEICH
──────────────────────────────────────────────────────────────
                        Original    Optimized    Verbesserung
  CPU (avg)              11.3%        4.2%         -63%
  RAM (RSS)              28 MB       26 MB          -7%
  Durchsatz (msg/s)        42          98         +133%
  Verlustrate             8.2%       0.1%         -99%
  Latenz (avg)           124ms       31ms          -75%
  HTTP-Calls/s              38          12         -68%
──────────────────────────────────────────────────────────────
  GESAMTSCORE             100        ★ 287        +187%
══════════════════════════════════════════════════════════════

  EINZELNE OPTIMIERUNGEN (sortiert nach Impact)
──────────────────────────────────────────────────────────────
  #1  Early Filter        CPU -38%  Durchsatz +45%  ★★★★★
  #2  Connection Pool     Latenz -52%  HTTP -61%     ★★★★☆
  #3  MS Cache            CPU -12%  Latenz -18%      ★★★☆☆
  #4  Precompiled Regex   CPU  -8%  Durchsatz +11%   ★★☆☆☆
  #5  Own Topic Filter    CPU  -5%  HTTP -15%        ★★☆☆☆
  #6  JSON::XS            CPU  -3%  Durchsatz  +6%   ★☆☆☆☆
  #7  Flatten Singleton   CPU  -1%  Durchsatz  +2%   ★☆☆☆☆
══════════════════════════════════════════════════════════════

  STRESSTEST-ERGEBNIS
──────────────────────────────────────────────────────────────
  Max msg/s ohne Verlust:  Original  38  |  Optimized  195
  Breakpoint (>5% Loss):   Original  52  |  Optimized  310
══════════════════════════════════════════════════════════════
```

### Scoring-Formel

Original = 100 (Baseline). Jede Metrik wird normalisiert und gewichtet:

```
score_cpu       = (baseline_cpu / measured_cpu)           * 100 * 0.30
score_throughput = (measured_throughput / baseline_throughput) * 100 * 0.30
score_latency   = (baseline_latency / measured_latency)       * 100 * 0.20
score_loss      = ((1-measured_loss) / (1-baseline_loss))     * 100 * 0.20

GESAMTSCORE = score_cpu + score_throughput + score_latency + score_loss
```

- Niedrigere CPU/Latenz/Verlust = besser, höherer Durchsatz = besser
- Sterne pro Fix: basierend auf relativem Beitrag zum Gesamtscore (1-5 Sterne)

### Dry-Run Modus

`mqtt-benchmark.sh --dry-run` gibt die geplante Testmatrix, geschätzte Laufzeit und Systemkonfiguration aus, ohne Tests zu starten. Nützlich zur Validierung vor dem eigentlichen Benchmark.

### System-Info Quellen

| Info | Quelle |
|------|--------|
| Hardware | `/proc/cpuinfo`, `/proc/meminfo` |
| LoxBerry-Version | `general.json` |
| Mosquitto | `mosquitto -v` |
| Miniserver-Config | `general.json` → Miniserver-Sektion |
| Plugins | `/opt/loxberry/data/system/plugindatabase.json` |
| System-Last | `uptime`, `free` |

### CSV-Export

- `/tmp/mqtt-benchmark/results/benchmark_YYYYMMDD_HHMM.csv` — Alle Rohdaten (500ms Samples pro Run)
- `/tmp/mqtt-benchmark/results/summary_YYYYMMDD_HHMM.csv` — Aggregierte Zusammenfassung aller Runs

Jede CSV enthält im Header: Git-Commit-Hash der getesteten Gateway, Kommandozeilen-Flags, CPU-Temperatur Start/Ende.

## Voraussetzungen

- Perl mit `Net::MQTT::Simple` (bereits auf LoxBerry vorhanden)
- Mosquitto-Broker lokal laufend
- Zugriff auf `/proc/[pid]/stat` (Standard auf Linux)
- Schreibzugriff auf `/tmp/mqtt-benchmark/` und `/dev/shm/`

## Implementierungsvoraussetzung

**Schritt 0:** Erstellung von `mqttgateway_benchmarkable.pl` aus `mqttgateway_optimized.pl` mit Feature-Flag-Guards um jeden der 7 Fixes. Dies ist die größte Einzelarbeit und muss vor dem eigentlichen Benchmark-Tool stehen.

## Nicht im Scope

- GUI/Web-Frontend für den Benchmark
- Automatisierte Regression-Tests (CI/CD)
- Benchmark anderer LoxBerry-Komponenten (healthcheck, Stats4Lox etc.)
- Netzwerk-Benchmarks (Broker-zu-Broker, Remote-Clients)
