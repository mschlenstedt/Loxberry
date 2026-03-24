# MQTT Gateway Benchmark

A performance benchmarking suite for the LoxBerry MQTT Gateway. Measures CPU usage,
memory footprint, HTTP throughput and message latency for 7 individual optimization
flags and their combined effect under realistic and stress load.

---

## Usage

All commands must be run on the LoxBerry host as `root` or the `loxberry` user.

```bash
# Dry-run: verify setup without executing measurements
bash sbin/benchmark/mqtt-benchmark.sh --dry-run

# Full benchmark with default settings (60 s per run)
bash sbin/benchmark/mqtt-benchmark.sh

# Shorter runs for quick iteration
bash sbin/benchmark/mqtt-benchmark.sh --duration 30

# Enable debug logging (loglevel 7)
bash sbin/benchmark/mqtt-benchmark.sh --loglevel 7
```

---

## Output

Results are written to two locations:

| Path | Contents |
|------|----------|
| `/opt/loxberry/log/plugins/benchmark/results/<TIMESTAMP>/` | Live results (runtime) |
| `/opt/loxberry/data/plugins/benchmark/benchmark/results/<TIMESTAMP>/` | Persistent copy |

Inside each timestamped directory:

```
benchmark_report.txt        Human-readable summary printed to terminal
summary_<TIMESTAMP>.csv     Per-run aggregated metrics
run_<N>/
  samples_<PID>.csv         Raw time-series: ts, cpu_pct, rss_kb, temp_c, http_count
  loadgen_stats.json        Load generator statistics (msgs sent, rate, latency)
selftest/
  max_rate.txt              Maximum sustainable message rate detected
```

---

## How It Works

The orchestrator (`mqtt-benchmark.sh`) runs 9+ benchmark rounds:

1. **Baseline** – original `mqttgateway.pl` (if present on the system)
2. **No flags** – benchmarkable gateway with all optimizations disabled
3. **Flag 1–7** – each optimization enabled individually
4. **All flags** – all 7 optimizations active simultaneously
5. **Stress tests** – increasing message rates with all optimizations active

Each round:
- Starts the gateway under test
- Runs `mqtt-metric-collector.pl` to sample CPU/RAM/temp/HTTP rate
- Runs `mqtt-loadgen.pl` to inject MQTT messages
- Collects and stores results
- Stops the gateway

---

## Feature Flags

The benchmarkable gateway (`mqttgateway_benchmarkable.pl`) accepts these environment
variables. The orchestrator sets them automatically per run.

| Flag | Fix | Description |
|------|-----|-------------|
| `BENCH_EARLY_FILTER` | FIX 1 | Filter non-matching topics before JSON expansion |
| `BENCH_CONNECTION_POOL` | FIX 2 | Reuse LWP::UserAgent HTTP connections (keep-alive) |
| `BENCH_MS_CACHE` | FIX 3 | Cache Miniserver config instead of querying per message |
| `BENCH_PRECOMPILED_REGEX` | FIX 4 | Pre-compile subscription regexes at startup (`qr//`) |
| `BENCH_OWN_TOPIC_FILTER` | FIX 5 | Skip messages published by the gateway itself |
| `BENCH_FLATTEN_SINGLETON` | FIX 6 | Reuse `Hash::Flatten` instance instead of creating per call |
| `BENCH_JSON_XS` | FIX 7 | Use `JSON::XS` (10–50x faster) instead of `JSON::PP` |

You can also run the gateway manually with individual flags for ad-hoc testing:

```bash
BENCH_EARLY_FILTER=1 BENCH_JSON_XS=1 perl sbin/benchmark/mqttgateway_benchmarkable.pl
```

---

## Components

| File | Role |
|------|------|
| `mqtt-benchmark.sh` | Orchestrator: coordinates all runs and generates the report |
| `mqttgateway_benchmarkable.pl` | Drop-in gateway with 7 toggleable optimizations |
| `mqtt-loadgen.pl` | MQTT load generator (realistic / stress / selftest modes) |
| `mqtt-metric-collector.pl` | Samples CPU, RAM, temperature and HTTP counter during a run |

---

## Requirements

- LoxBerry 3.x with `mqttgateway.pl` installed
- Perl modules: `LoxBerry::Log`, `LoxBerry::System`, `Net::MQTT::Simple`,
  `LWP::UserAgent`, `JSON` (optionally `JSON::XS` for FIX 7)
- `bash` >= 4.0 (associative arrays used by the orchestrator)
- Must run as `root` or `loxberry` user (gateway needs access to LoxBerry config)
- MQTT broker must be reachable at `localhost:1883` (default LoxBerry setup)
