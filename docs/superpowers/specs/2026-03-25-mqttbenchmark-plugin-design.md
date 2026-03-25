# MQTT Gateway Benchmark Plugin — Design Spec

**Datum:** 2026-03-25
**Plugin-Name:** `mqttbenchmark`
**Plugin-Title:** MQTT Gateway Benchmark
**Autor:** P.Lewald aka Strike
**Plattform:** LoxBerry 3.0+ auf Raspberry Pi 4

## Motivation

Das MQTT Gateway Benchmark-Tool (4 Scripts in `sbin/benchmark/`) misst den Impact von 7 Optimierungen in der mqttgateway.pl. Aktuell ist es nur per SSH/Kommandozeile nutzbar. Dieses Plugin verpackt es als installierbares LoxBerry-Plugin mit Web-UI, sodass Benchmarks direkt aus dem Browser gestartet, konfiguriert und ausgewertet werden können.

## Plugin-Struktur

```
mqttbenchmark/
├── plugin.cfg
├── postinstall.sh
├── postroot.sh
├── preupgrade.sh
├── postupgrade.sh
├── uninstall/uninstall
├── dpkg/apt                             # System-Pakete (gawk)
├── bin/
│   ├── mqtt-benchmark.sh               # Orchestrator (erweitert)
│   ├── mqtt-loadgen.pl                 # Lastgenerator (bestehend)
│   ├── mqtt-metric-collector.pl        # Metriken-Sammler (bestehend)
│   └── mqttgateway_benchmarkable.pl    # Benchmarkable Gateway (bestehend)
├── config/
│   └── mqttbenchmark.cfg               # Plugin-Einstellungen
├── data/dummies/
│   └── .gitkeep
├── icons/
│   ├── icon_64.png
│   ├── icon_128.png
│   ├── icon_256.png
│   └── icon_512.png
├── templates/
│   ├── settings.html                   # Haupttemplate (4 Tabs)
│   ├── help.html                       # Hilfe-Seite
│   └── lang/
│       ├── language_de.ini
│       └── language_en.ini
└── webfrontend/htmlauth/
    ├── index.cgi                       # Perl CGI-Handler
    └── ajax.cgi                        # AJAX-Backend
```

### dpkg/apt

```
gawk
```

## plugin.cfg

```ini
[AUTHOR]
NAME=P.Lewald aka Strike
EMAIL=placeholder@example.com

[PLUGIN]
VERSION=1.0.0
NAME=mqttbenchmark
FOLDER=mqttbenchmark
TITLE=MQTT Gateway Benchmark

[SYSTEM]
REBOOT=false
LB_MINIMUM=3.0.0
LB_MAXIMUM=false
INTERFACE=2.0
CUSTOM_LOGLEVELS=True
```

## Web-UI

### Tab 1: Benchmark (`?form=1`)

**Einstellungen:**
- Duration: Dropdown (30s / 60s / 120s), Default: 60s
- Loglevel: Dropdown (3=Errors / 6=Info / 7=Debug), Default: 6
- Checkboxen — welche Runs:
  - [x] Realistic (Runs 0-9)
  - [x] Stresstest (Runs 10+)
  - [ ] Nur bestimmte Fixes testen → expandiert zu 7 Checkboxen (Early Filter, Connection Pool, MS Cache, Precompiled Regex, Own Topic Filter, Flatten Singleton, JSON::XS)

**Aktionen:**
- Button "Benchmark starten"
- Button "Dry Run" (zeigt Testmatrix ohne auszuführen)

**Fortschrittsanzeige** (erscheint nach Start, pollt per AJAX alle 2s):
- Aktueller Run: "Run 3/12: Connection Pool"
- Fortschrittsbalken (% basierend auf run_id/total_runs)
- Geschätzte Restzeit
- Button "Abbrechen"

### Tab 2: Ergebnisse (`?form=2`)

- Dropdown: Benchmark-Lauf auswählen (nach Datum sortiert, z.B. "25.03.2026 14:32")
- Gesamtvergleich-Tabelle: Original vs. Optimized (CPU, HTTP-Rate, Latenz, Score)
- Einzelne Optimierungen: Tabelle mit Fix-Name, CPU-Delta, HTTP-Rate-Delta, Sterne-Rating
- Stresstest-Ergebnis: Max msg/s Original vs. Optimized
- Systemkonfiguration: collapsible Bereich
- Button: "CSV herunterladen"

### Tab 3: Vergleich (`?form=3`)

- Zwei Dropdowns: Lauf A / Lauf B
- Side-by-Side Tabelle: CPU, HTTP-Rate, Latenz, Score für beide Läufe
- Farbliche Hervorhebung: Grün = besser, Rot = schlechter

### Tab 4: Logfiles (`?form=99`)

Standard LoxBerry Log-Viewer:

```perl
$navbar{99}{Name} = "$L{'COMMON.TAB_LOGS'}";
$navbar{99}{URL}  = 'index.cgi?form=99';

# Im Template:
<TMPL_IF form99>
<div id="logfiles"></div>
<script>loglist_html({ PACKAGE => 'mqttbenchmark' });</script>
</TMPL_IF>
```

## Backend-Architektur

### index.cgi

Standard LoxBerry CGI-Handler:

```perl
use LoxBerry::Web;
LoxBerry::Web::lbheader("MQTT Gateway Benchmark V$version", "https://wiki.loxberry.de/...", "help.html");
print $template->output();
LoxBerry::Web::lbfooter();
```

- Liest/speichert Plugin-Config (`$lbpconfigdir/mqttbenchmark.cfg`) via `Config::Simple`
- Rendert Template mit `LoxBerry::Web` (lbheader/lbfooter)
- Navbar mit 4 Tabs (form=1, form=2, form=3, form=99)
- `readlanguage($template, "language.ini")` — LoxBerry löst automatisch `$lbptemplatedir/lang/language_XX.ini` auf
- Startet Benchmark NICHT selbst — das macht ajax.cgi

### ajax.cgi

AJAX-Endpunkt, liefert JSON. Aktionen:

| Action | Methode | Beschreibung |
|--------|---------|-------------|
| `start` | POST | Startet Benchmark als Hintergrundprozess, speichert PID in `/dev/shm/mqttbenchmark_pid` |
| `stop` | POST | Stoppt laufenden Benchmark (kill PID) |
| `status` | GET | Liest `/dev/shm/mqttbenchmark_status.json`, liefert Fortschritt |
| `results` | GET | Liste aller Benchmark-Läufe aus `$lbpdatadir/results/` |
| `result` | GET | Einzelner Report als JSON (`summary.json` eines Laufs) |
| `compare` | GET | Side-by-Side Daten für zwei Läufe |
| `csv` | GET | CSV-Download mit Content-Disposition: attachment |

### Input-Validierung

Alle Parameter werden vor Verwendung validiert — keine direkte Interpolation in Shell-Commands:

```perl
# Validierung im ajax.cgi:
my $duration = $R::duration =~ /^(30|60|120)$/ ? $1 : 60;
my $loglevel = $R::loglevel =~ /^(3|6|7)$/ ? $1 : 6;
my $runs     = $R::runs =~ /^[a-z,]+$/ ? $1 : "realistic,stress";
my $fixes    = $R::fixes =~ /^[\d,]+$/ ? $1 : "1,2,3,4,5,6,7";
```

### Fehler-Responses

Standard JSON-Error-Envelope:

```json
{"error": 1, "message": "Benchmark already running"}
{"error": 1, "message": "No benchmark running"}
{"error": 1, "message": "Result not found: 20260325_1432"}
{"error": 0, "data": {...}}
```

`status` liefert `{"running": false}` wenn kein Benchmark läuft (kein Error).

### Benchmark-Start via ajax.cgi

```perl
# POST action=start — nach Validierung:
my $cmd = "$lbpbindir/mqtt-benchmark.sh"
    . " --duration $duration"
    . " --loglevel $loglevel"
    . " --runs $runs"
    . " --fixes $fixes"
    . " --status-file /dev/shm/mqttbenchmark_status.json"
    . " --json-output"
    . " >> $lbplogdir/mqttbenchmark.log 2>&1 &";
system($cmd);
```

### Fortschritts-Tracking

Der Orchestrator schreibt nach jedem Run-Wechsel:

```json
// /dev/shm/mqttbenchmark_status.json
{
  "running": true,
  "pid": 1234,
  "run_id": 3,
  "run_name": "Connection Pool",
  "total_runs": 12,
  "started_at": 1711234567,
  "current_run_start": 1711234627,
  "completed_runs": ["Original", "Benchmarkable (flags OFF)", "Early Filter"]
}
```

Am Benchmark-Ende: `"running": false, "finished_at": ...`

Der AJAX-Handler liest diese Datei — kein Prozess-Polling nötig.

## Ergebnis-Speicherung

Einziger Speicherort: `$lbpdatadir/results/` (persistent, überlebt Reboot + Plugin-Update). Kein Dual-Write mehr — der Orchestrator schreibt direkt hierhin.

```
$lbpdatadir/results/
└── 20260325_1432/
    ├── summary.json          # Strukturierte Ergebnisse für Web-UI
    ├── summary.csv           # Rohdaten
    └── report.txt            # Terminal-Report
```

### summary.json Format

`http_rate` ist die einheitliche Metrik für Gateway-Durchsatz (HTTP-Calls/s an Miniserver, gemessen als Counter-Delta/Duration im Metric-Collector). Wird überall als `http_rate` bezeichnet — kein separates `throughput`-Feld.

```json
{
  "timestamp": "20260325_1432",
  "duration": 60,
  "system_info": {
    "hardware": "Raspberry Pi 4 Model B Rev 1.4, 4096 MB",
    "os": "Debian 11 (Bullseye)",
    "loxberry": "3.0.1.3",
    "perl": "5.32.1",
    "mosquitto": "2.0.11",
    "miniservers": 2,
    "plugins": 7
  },
  "baseline": {
    "cpu": 11.3, "rss_mb": 28, "http_rate": 42,
    "latency_avg": 124, "latency_p95": 210, "loss_pct": 8.2
  },
  "optimized": {
    "cpu": 4.2, "rss_mb": 26, "http_rate": 98,
    "latency_avg": 31, "latency_p95": 55, "loss_pct": 0.1
  },
  "score": 287,
  "fixes": [
    {"id": 1, "name": "Early Filter", "flag": "BENCH_EARLY_FILTER", "cpu": 7.0, "http_rate": 61, "latency_avg": 95, "score": 142, "stars": 5},
    {"id": 2, "name": "Connection Pool", "flag": "BENCH_CONNECTION_POOL", "cpu": 9.8, "http_rate": 48, "latency_avg": 60, "score": 128, "stars": 4}
  ],
  "stress": {
    "original_max": 38,
    "optimized_max": 195,
    "rates": [
      {"rate": 10, "original_loss": 0, "optimized_loss": 0},
      {"rate": 50, "original_loss": 5.2, "optimized_loss": 0}
    ]
  }
}
```

## Anpassungen am Orchestrator

Der bestehende `mqtt-benchmark.sh` bekommt diese neuen CLI-Optionen:

| Option | Beschreibung |
|--------|-------------|
| `--status-file PATH` | Schreibt Fortschritts-JSON nach PATH nach jedem Run-Wechsel |
| `--json-output` | Erzeugt zusätzlich `summary.json` im Ergebnis-Verzeichnis |
| `--runs realistic,stress` | Selektiert Run-Gruppen (Default: beide) |
| `--fixes 1,2,3` | Nur bestimmte Fixes testen (Default: alle 7) |

### --fixes Mapping zur Testmatrix

Wenn `--fixes` gesetzt ist, werden nur die spezifizierten Fix-Runs ausgeführt. Baseline-Runs laufen immer:

| Run | Beschreibung | Wann |
|-----|-------------|------|
| 0 | Original (Baseline) | **Immer** |
| 1 | Benchmarkable alle Flags OFF | **Immer** |
| 2 | Early Filter | Nur wenn `1` in `--fixes` |
| 3 | Connection Pool | Nur wenn `2` in `--fixes` |
| 4 | MS Cache | Nur wenn `3` in `--fixes` |
| 5 | Precompiled Regex | Nur wenn `4` in `--fixes` |
| 6 | Own Topic Filter | Nur wenn `5` in `--fixes` |
| 7 | Flatten Singleton | Nur wenn `6` in `--fixes` |
| 8 | JSON::XS | Nur wenn `7` in `--fixes` |
| 9 | Alle Flags AN | **Immer** (wenn mindestens 1 Fix ausgewählt) |
| 10+ | Stresstest | Nur wenn `stress` in `--runs` |

### Pfade

Bash-Variablen (via `loxberry_system.sh`):

| Variable | Pfad |
|----------|------|
| `$LBPBIN` | `/opt/loxberry/bin/plugins/mqttbenchmark` |
| `$LBPLOG` | `/opt/loxberry/log/plugins/mqttbenchmark` |
| `$LBPDATA` | `/opt/loxberry/data/plugins/mqttbenchmark` |
| `$LBPCONFIG` | `/opt/loxberry/config/plugins/mqttbenchmark` |

Perl-Variablen (via `LoxBerry::System`):

| Variable | Pfad |
|----------|------|
| `$lbpbindir` | `/opt/loxberry/bin/plugins/mqttbenchmark` |
| `$lbplogdir` | `/opt/loxberry/log/plugins/mqttbenchmark` |
| `$lbpdatadir` | `/opt/loxberry/data/plugins/mqttbenchmark` |
| `$lbpconfigdir` | `/opt/loxberry/config/plugins/mqttbenchmark` |

Der Orchestrator schreibt seine PID nach `/dev/shm/mqttbenchmark_pid` beim Start.

Die 3 anderen Scripts (loadgen, metric-collector, benchmarkable gateway) bleiben unverändert.

## Lifecycle-Hooks

### postinstall.sh

```bash
#!/bin/bash
# LoxBerry Plugin postinstall — runs as user loxberry

echo "<INFO> Creating directories..."
mkdir -p $LBPDATA/results
mkdir -p $LBPLOG

echo "<INFO> Creating default config..."
if [ ! -f $LBPCONFIG/mqttbenchmark.cfg ]; then
    cat > $LBPCONFIG/mqttbenchmark.cfg << 'EOF'
[BENCHMARK]
DURATION=60
LOGLEVEL=6
RUNS=realistic,stress
FIXES=1,2,3,4,5,6,7
EOF
    echo "<OK> Default config created"
else
    echo "<OK> Config already exists, keeping it"
fi

echo "<OK> Installation complete"
exit 0
```

### postroot.sh

```bash
#!/bin/bash
# LoxBerry Plugin postroot — runs as root

echo "<INFO> Setting script permissions..."
chmod +x $LBPBIN/mqtt-benchmark.sh
chmod +x $LBPBIN/mqtt-loadgen.pl
chmod +x $LBPBIN/mqtt-metric-collector.pl
chmod +x $LBPBIN/mqttgateway_benchmarkable.pl
echo "<OK> Permissions set"
exit 0
```

### preupgrade.sh

```bash
#!/bin/bash
# Backup config before upgrade
echo "<INFO> Backing up config..."
cp -f $LBPCONFIG/mqttbenchmark.cfg /tmp/mqttbenchmark_cfg_backup 2>/dev/null
echo "<OK> Config backed up"
exit 0
```

### postupgrade.sh

```bash
#!/bin/bash
# Restore config after upgrade
echo "<INFO> Restoring config..."
if [ -f /tmp/mqttbenchmark_cfg_backup ]; then
    cp -f /tmp/mqttbenchmark_cfg_backup $LBPCONFIG/mqttbenchmark.cfg
    rm -f /tmp/mqttbenchmark_cfg_backup
    echo "<OK> Config restored"
fi
exit 0
```

### uninstall/uninstall

```bash
#!/bin/bash
# Cleanup — runs as root

echo "<INFO> Stopping benchmark if running..."
if [ -f /dev/shm/mqttbenchmark_pid ]; then
    PID=$(cat /dev/shm/mqttbenchmark_pid)
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        echo "<OK> Benchmark process stopped"
    fi
fi

echo "<INFO> Cleaning shared memory..."
rm -f /dev/shm/mqttbenchmark_*

echo "<OK> Uninstall complete"
exit 0
```

## Sprach-Dateien

### Wichtige Translation-Keys

```ini
# language_de.ini / language_en.ini

[COMMON]
TAB_BENCHMARK=Benchmark / Benchmark
TAB_RESULTS=Ergebnisse / Results
TAB_COMPARE=Vergleich / Compare
TAB_LOGS=Logfiles / Logfiles

[BENCHMARK]
LABEL_DURATION=Testdauer / Test Duration
LABEL_LOGLEVEL=Log-Level / Log Level
LABEL_RUNS=Testreihen / Test Runs
LABEL_FIXES=Optimierungen / Optimizations
CB_REALISTIC=Realistische Last (Runs 0-9) / Realistic Load (Runs 0-9)
CB_STRESS=Stresstest (Runs 10+) / Stress Test (Runs 10+)
CB_SELECTFIXES=Nur bestimmte Fixes / Only specific fixes
BTN_START=Benchmark starten / Start Benchmark
BTN_DRYRUN=Dry Run / Dry Run
BTN_CANCEL=Abbrechen / Cancel
PROGRESS_RUN=Run {0}/{1}: {2} / Run {0}/{1}: {2}
PROGRESS_ETA=Geschätzte Restzeit: {0} / Estimated time: {0}
STATUS_RUNNING=Benchmark läuft... / Benchmark running...
STATUS_IDLE=Bereit / Ready
ERR_ALREADY_RUNNING=Benchmark läuft bereits / Benchmark already running

[RESULTS]
LABEL_SELECT=Benchmark-Lauf auswählen / Select benchmark run
TH_METRIC=Metrik / Metric
TH_ORIGINAL=Original / Original
TH_OPTIMIZED=Optimiert / Optimized
TH_CHANGE=Veränderung / Change
TH_FIX=Optimierung / Optimization
TH_CPU=CPU-Delta / CPU Delta
TH_HTTPRATE=HTTP-Rate / HTTP Rate
TH_STARS=Bewertung / Rating
TH_SCORE=Score / Score
LABEL_SYSINFO=Systemkonfiguration / System Configuration
BTN_CSV=CSV herunterladen / Download CSV
LABEL_STRESS=Stresstest-Ergebnis / Stress Test Result

[COMPARE]
LABEL_RUN_A=Lauf A / Run A
LABEL_RUN_B=Lauf B / Run B
BETTER=besser / better
WORSE=schlechter / worse
```

## Voraussetzungen

- LoxBerry 3.0+
- Perl mit `Net::MQTT::Simple`, `LoxBerry::System`, `LoxBerry::Log`, `LoxBerry::IO`, `LoxBerry::Web`
- Mosquitto-Broker lokal laufend
- `gawk` für Latenz-Berechnung (wird via `dpkg/apt` automatisch installiert)

## Nicht im Scope

- Live-Grafiken (Charts) — Terminal-Report + Tabellen reichen
- Daemon-Betrieb — Benchmark wird on-demand gestartet
- MQTT-Filter-Verbesserungen — separates Thema
- Auto-Update / Release-Config — wird später ergänzt
