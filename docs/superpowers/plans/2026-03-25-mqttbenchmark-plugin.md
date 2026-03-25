# MQTT Benchmark Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the MQTT Gateway Benchmark tool as an installable LoxBerry plugin with Web UI for browser-based benchmark management.

**Architecture:** LoxBerry plugin with Perl CGI frontend, AJAX backend for async benchmark control, and modified orchestrator for status reporting and JSON output.

**Tech Stack:** Perl 5 (LoxBerry::Web, LoxBerry::System, LoxBerry::Log, Config::Simple, CGI, JSON), HTML::Template, Bash, JavaScript (jQuery for AJAX polling)

**Spec:** `docs/superpowers/specs/2026-03-25-mqttbenchmark-plugin-design.md`

---

## Task 1: Plugin Scaffold

**Goal:** Create the complete plugin directory structure under `plugin/mqttbenchmark/` and populate it with metadata, lifecycle hooks, default config, placeholder icons, and copies of the 3 unchanged scripts.

### Steps

- [ ] Create directory structure:
  ```
  plugin/mqttbenchmark/
  ├── plugin.cfg
  ├── postinstall.sh
  ├── postroot.sh
  ├── preupgrade.sh
  ├── postupgrade.sh
  ├── dpkg/apt
  ├── uninstall/uninstall
  ├── bin/
  ├── config/mqttbenchmark.cfg
  ├── data/dummies/.gitkeep
  ├── icons/
  ├── templates/lang/
  └── webfrontend/htmlauth/
  ```

- [ ] Create `plugin/mqttbenchmark/plugin.cfg`:

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

- [ ] Create `plugin/mqttbenchmark/dpkg/apt`:

```
gawk
```

- [ ] Create `plugin/mqttbenchmark/postinstall.sh`:

```bash
#!/bin/bash
# LoxBerry Plugin postinstall -- runs as user loxberry

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

- [ ] Create `plugin/mqttbenchmark/postroot.sh`:

```bash
#!/bin/bash
# LoxBerry Plugin postroot -- runs as root

echo "<INFO> Setting script permissions..."
chmod +x $LBPBIN/mqtt-benchmark.sh
chmod +x $LBPBIN/mqtt-loadgen.pl
chmod +x $LBPBIN/mqtt-metric-collector.pl
chmod +x $LBPBIN/mqttgateway_benchmarkable.pl
echo "<OK> Permissions set"
exit 0
```

- [ ] Create `plugin/mqttbenchmark/preupgrade.sh`:

```bash
#!/bin/bash
# Backup config before upgrade

echo "<INFO> Backing up config..."
cp -f $LBPCONFIG/mqttbenchmark.cfg /tmp/mqttbenchmark_cfg_backup 2>/dev/null
echo "<OK> Config backed up"
exit 0
```

- [ ] Create `plugin/mqttbenchmark/postupgrade.sh`:

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

- [ ] Create `plugin/mqttbenchmark/uninstall/uninstall`:

```bash
#!/bin/bash
# Cleanup -- runs as root

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

- [ ] Create `plugin/mqttbenchmark/config/mqttbenchmark.cfg`:

```ini
[BENCHMARK]
DURATION=60
LOGLEVEL=6
RUNS=realistic,stress
FIXES=1,2,3,4,5,6,7
```

- [ ] Create `plugin/mqttbenchmark/data/dummies/.gitkeep` (empty file)

- [ ] Create placeholder icons `plugin/mqttbenchmark/icons/icon_64.png`, `icon_128.png`, `icon_256.png`, `icon_512.png` -- create minimal 1x1 PNGs as placeholders with a TODO comment in the commit message

- [ ] Copy unchanged scripts from `sbin/benchmark/` to `plugin/mqttbenchmark/bin/`:
  - `sbin/benchmark/mqtt-loadgen.pl` -> `plugin/mqttbenchmark/bin/mqtt-loadgen.pl`
  - `sbin/benchmark/mqtt-metric-collector.pl` -> `plugin/mqttbenchmark/bin/mqtt-metric-collector.pl`
  - `sbin/benchmark/mqttgateway_benchmarkable.pl` -> `plugin/mqttbenchmark/bin/mqttgateway_benchmarkable.pl`

- [ ] Copy `sbin/benchmark/mqtt-benchmark.sh` -> `plugin/mqttbenchmark/bin/mqtt-benchmark.sh` (will be modified in Task 2)

- [ ] Commit: `feat(mqttbenchmark): plugin scaffold with lifecycle hooks and copied scripts`

---

## Task 2: Orchestrator Extensions

**Goal:** Modify the copied `plugin/mqttbenchmark/bin/mqtt-benchmark.sh` to add plugin-mode CLI options (`--status-file`, `--json-output`, `--runs`, `--fixes`), status file writing, summary.json generation, PID file writing, and LoxBerry plugin path variables.

### Files Modified

- `plugin/mqttbenchmark/bin/mqtt-benchmark.sh`

### Steps

- [ ] Add new CLI options to argument parsing block. Extend the `while [[ $# -gt 0 ]]` loop:

```bash
# --- New plugin-mode options ---
STATUS_FILE=""
JSON_OUTPUT=0
RUNS_FILTER=""           # e.g. "realistic,stress" or "realistic" or "stress"
FIXES_FILTER=""          # e.g. "1,2,3" -- which fixes to test

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --loglevel)
            LOGLEVEL="$2"
            shift 2
            ;;
        --status-file)
            STATUS_FILE="$2"
            shift 2
            ;;
        --json-output)
            JSON_OUTPUT=1
            shift
            ;;
        --runs)
            RUNS_FILTER="$2"
            shift 2
            ;;
        --fixes)
            FIXES_FILTER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--duration N] [--loglevel N]"
            echo "       [--status-file PATH] [--json-output]"
            echo "       [--runs realistic,stress] [--fixes 1,2,3,4,5,6,7]"
            exit 1
            ;;
    esac
done
```

- [ ] Update path configuration to use LoxBerry plugin variables with fallbacks. Replace the hardcoded path block near the top:

```bash
# Plugin-mode path resolution: use LoxBerry plugin env vars if available
if [[ -n "${LBPBIN:-}" ]]; then
    SCRIPT_DIR="$LBPBIN"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

LBHOMEDIR="${LBHOMEDIR:-/opt/loxberry}"

# Source LoxBerry env if available
if [[ -f "${LBHOMEDIR}/libs/bash/loxberry_system.sh" ]]; then
    source "${LBHOMEDIR}/libs/bash/loxberry_system.sh"
fi

# Results directory: prefer plugin data dir, fall back to log dir
if [[ -n "${LBPDATA:-}" ]]; then
    RESULTS_DIR="${LBPDATA}/results"
elif [[ -n "${LBPLOG:-}" ]]; then
    RESULTS_DIR="${LBPLOG}/results"
else
    BENCHMARK_DIR="${LBHOMEDIR}/log/plugins/benchmark"
    RESULTS_DIR="${BENCHMARK_DIR}/results"
fi

# Log directory
LOG_DIR="${LBPLOG:-${LBHOMEDIR}/log/plugins/benchmark}"

TIMESTAMP=$(date +%Y%m%d_%H%M)
```

- [ ] Add PID file writing at the start of main execution (after argument parsing, before selftest):

```bash
# Write PID file for plugin management
echo $$ > /dev/shm/mqttbenchmark_pid
log_info "PID $$ written to /dev/shm/mqttbenchmark_pid"
```

- [ ] Add PID file cleanup in the `cleanup()` function:

```bash
cleanup() {
    log_info "Cleaning up..."
    [[ -n "$COLLECTOR_PID" ]] && kill "$COLLECTOR_PID" 2>/dev/null || true
    [[ -n "$LOADGEN_PID" ]] && kill "$LOADGEN_PID" 2>/dev/null || true
    if [[ "$ORIGINAL_GW_RESTORED" -eq 0 ]]; then
        stop_gateway
    else
        rm -f /dev/shm/bench_* 2>/dev/null || true
        GW_PID=""
    fi
    # Remove PID file
    rm -f /dev/shm/mqttbenchmark_pid 2>/dev/null || true
    # Write final status
    if [[ -n "$STATUS_FILE" ]]; then
        write_status_file false
    fi
    log_info "Cleanup complete."
}
```

- [ ] Add `write_status_file()` function that writes the progress JSON:

```bash
write_status_file() {
    local is_running="$1"
    [[ -z "$STATUS_FILE" ]] && return

    local completed_json="["
    local first=1
    for name in "${COMPLETED_RUN_NAMES[@]}"; do
        if [[ $first -eq 0 ]]; then
            completed_json+=","
        fi
        completed_json+="\"${name}\""
        first=0
    done
    completed_json+="]"

    local now
    now=$(date +%s)

    if [[ "$is_running" == "true" ]]; then
        cat > "${STATUS_FILE}.tmp" << STATUSEOF
{
  "running": true,
  "pid": $$,
  "run_id": ${CURRENT_RUN_ID:-0},
  "run_name": "${CURRENT_RUN_NAME:-}",
  "total_runs": ${ACTUAL_TOTAL_RUNS:-0},
  "started_at": ${BENCHMARK_START_TIME:-$now},
  "current_run_start": ${CURRENT_RUN_START:-$now},
  "completed_runs": ${completed_json}
}
STATUSEOF
    else
        cat > "${STATUS_FILE}.tmp" << STATUSEOF
{
  "running": false,
  "pid": $$,
  "total_runs": ${ACTUAL_TOTAL_RUNS:-0},
  "started_at": ${BENCHMARK_START_TIME:-$now},
  "finished_at": $now,
  "completed_runs": ${completed_json}
}
STATUSEOF
    fi

    mv -f "${STATUS_FILE}.tmp" "$STATUS_FILE" 2>/dev/null || true
}
```

- [ ] Add tracking variables after argument parsing:

```bash
declare -a COMPLETED_RUN_NAMES=()
CURRENT_RUN_ID=0
CURRENT_RUN_NAME=""
CURRENT_RUN_START=0
BENCHMARK_START_TIME=$(date +%s)
ACTUAL_TOTAL_RUNS=0
```

- [ ] Inject status file writes into `run_benchmark()` -- add at the beginning of the function, right after the `mkdir -p`:

```bash
    # Update status tracking
    CURRENT_RUN_ID="$run_id"
    CURRENT_RUN_NAME="$run_name"
    CURRENT_RUN_START=$(date +%s)
    write_status_file true
```

And at the end of `run_benchmark()`, before `log_info "Run $run_id complete."`:

```bash
    COMPLETED_RUN_NAMES+=("$run_name")
    write_status_file true
```

- [ ] Add `--fixes` filtering logic. Create a helper function `should_run_fix()`:

```bash
# --fixes filter: determine if a specific fix run should execute
# Baseline runs 0, 1, and 9 always run. Runs 2-8 are filtered by --fixes.
# Fix mapping: run 2 = fix 1, run 3 = fix 2, ..., run 8 = fix 7
should_run_fix() {
    local run_id="$1"

    # Baseline runs always execute
    if [[ "$run_id" -le 1 ]] || [[ "$run_id" -eq 9 ]]; then
        return 0  # true
    fi

    # If no filter set, run everything
    if [[ -z "$FIXES_FILTER" ]]; then
        return 0
    fi

    # Map run_id to fix_id: run 2 -> fix 1, run 3 -> fix 2, etc.
    local fix_id=$((run_id - 1))

    # Check if fix_id is in the comma-separated FIXES_FILTER
    if echo ",$FIXES_FILTER," | grep -q ",$fix_id,"; then
        return 0  # true
    fi

    return 1  # false, skip this run
}
```

- [ ] Add `--runs` filtering logic. Wrap the realistic runs block with a check:

```bash
# Determine which run groups to execute
RUN_REALISTIC=1
RUN_STRESS=1

if [[ -n "$RUNS_FILTER" ]]; then
    RUN_REALISTIC=0
    RUN_STRESS=0
    if echo "$RUNS_FILTER" | grep -q "realistic"; then
        RUN_REALISTIC=1
    fi
    if echo "$RUNS_FILTER" | grep -q "stress"; then
        RUN_STRESS=1
    fi
fi
```

Then wrap the execution blocks:

```bash
if [[ "$RUN_REALISTIC" -eq 1 ]]; then
    # Run 0: Original gateway, realistic load
    run_benchmark 0 "Original Gateway" "$ORIGINAL_GW" "realistic" "0"

    # Run 1: Benchmarkable gateway, all flags OFF, realistic load
    run_benchmark 1 "Benchmarkable (no flags)" "$BENCH_GW" "realistic" "0"

    # Runs 2-8: Benchmarkable, one flag at a time (filtered by --fixes)
    for i in "${!FLAG_NAMES[@]}"; do
        rid=$((i + 2))
        if should_run_fix "$rid"; then
            run_benchmark "$rid" "${FLAG_NAMES[$i]}" "$BENCH_GW" "realistic" "0" "${FLAG_VALUES[$i]}"
        else
            log_info "Skipping run $rid (${FLAG_NAMES[$i]}) -- not in --fixes filter"
        fi
    done

    # Run 9: Benchmarkable, all flags ON, realistic load
    run_benchmark 9 "All Optimizations" "$BENCH_GW" "realistic" "0" $ALL_FLAGS
fi

if [[ "$RUN_STRESS" -eq 1 ]]; then
    stress_id=10
    for rate in "${STRESS_RATES[@]}"; do
        if [[ $(perl -e "print $rate > $MAX_RATE ? 1 : 0") -eq 1 ]]; then
            log_warn "Skipping stress rate ${rate} msg/s (exceeds max loadgen rate ${MAX_RATE})"
            continue
        fi
        run_benchmark "$stress_id" "Stress ${rate}msg/s (original)" "$ORIGINAL_GW" "stress" "$rate"
        STRESS_RUN_IDS+=("$stress_id")
        run_benchmark "$((stress_id + 1))" "Stress ${rate}msg/s (optimized)" "$BENCH_GW" "stress" "$rate" $ALL_FLAGS
        STRESS_RUN_IDS+=("$((stress_id + 1))")
        stress_id=$((stress_id + 2))
    done
fi
```

- [ ] Calculate `ACTUAL_TOTAL_RUNS` after filtering is determined (before execution starts):

```bash
# Calculate actual number of runs based on filters
ACTUAL_TOTAL_RUNS=0
if [[ "$RUN_REALISTIC" -eq 1 ]]; then
    ACTUAL_TOTAL_RUNS=2  # runs 0 and 1 always
    for i in "${!FLAG_NAMES[@]}"; do
        rid=$((i + 2))
        if should_run_fix "$rid"; then
            ACTUAL_TOTAL_RUNS=$((ACTUAL_TOTAL_RUNS + 1))
        fi
    done
    ACTUAL_TOTAL_RUNS=$((ACTUAL_TOTAL_RUNS + 1))  # run 9
fi
if [[ "$RUN_STRESS" -eq 1 ]]; then
    ACTUAL_TOTAL_RUNS=$((ACTUAL_TOTAL_RUNS + ${#STRESS_RATES[@]} * 2))
fi
```

- [ ] Add `generate_summary_json()` function that writes `summary.json` when `--json-output` is set. Add this after `generate_report()`:

```bash
generate_summary_json() {
    [[ "$JSON_OUTPUT" -eq 0 ]] && return

    local json_file="${RESULTS_DIR}/${TIMESTAMP}/summary.json"
    log_info "Generating summary.json..."

    local base_cpu="${RUN_RESULTS[0_cpu]:-0}"
    local base_rss="${RUN_RESULTS[0_rss]:-0}"
    local base_tp="${RUN_RESULTS[0_http_rate]:-0}"
    local base_p50="${RUN_RESULTS[0_p50]:-0}"
    local base_p95="${RUN_RESULTS[0_p95]:-0}"
    local base_loss="${RUN_RESULTS[0_loss_pct]:-0}"

    local opt_cpu="${RUN_RESULTS[9_cpu]:-0}"
    local opt_rss="${RUN_RESULTS[9_rss]:-0}"
    local opt_tp="${RUN_RESULTS[9_http_rate]:-0}"
    local opt_p50="${RUN_RESULTS[9_p50]:-0}"
    local opt_p95="${RUN_RESULTS[9_p95]:-0}"
    local opt_loss="${RUN_RESULTS[9_loss_pct]:-0}"

    local overall_score
    overall_score=$(calc_score "$base_cpu" "$opt_cpu" "$base_tp" "$opt_tp" "$base_p95" "$opt_p95" "$base_loss" "$opt_loss")

    # Collect system info fields
    local hw_model os_name lb_version perl_version mosquitto_version ms_count plugin_count
    hw_model=$( [[ -r /proc/device-tree/model ]] && tr -d '\0' < /proc/device-tree/model || echo "unknown" )
    os_name=$( [[ -r /etc/os-release ]] && (. /etc/os-release && echo "$PRETTY_NAME") || echo "unknown" )
    lb_version=$(perl -e 'use LoxBerry::System; print LoxBerry::System::lbversion();' 2>/dev/null || echo "unknown")
    perl_version=$(perl -e 'print $^V;' 2>/dev/null || echo "unknown")
    mosquitto_version=$(mosquitto -h 2>&1 | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
    ms_count=$(perl -e 'use LoxBerry::System; my %ms = LoxBerry::System::get_miniservers(); print scalar keys %ms;' 2>/dev/null || echo "0")
    plugin_count=$(perl -e 'use LoxBerry::System; my @p = LoxBerry::System::get_plugins(); print scalar @p;' 2>/dev/null || echo "0")
    local mem_total
    mem_total=$( [[ -r /proc/meminfo ]] && awk '/MemTotal/{printf "%.0f MB", $2/1024}' /proc/meminfo || echo "unknown" )

    # Build fixes array JSON
    local fixes_json="["
    local fixes_first=1
    local ind_base_cpu="${RUN_RESULTS[1_cpu]:-$base_cpu}"
    local ind_base_tp="${RUN_RESULTS[1_http_rate]:-$base_tp}"
    local ind_base_p95="${RUN_RESULTS[1_p95]:-$base_p95}"
    local ind_base_loss="${RUN_RESULTS[1_loss_pct]:-$base_loss}"

    for i in "${!FLAG_NAMES[@]}"; do
        local rid=$((i + 2))
        local fix_id=$((i + 1))
        # Only include if this run was executed
        [[ -z "${RUN_RESULTS[${rid}_name]:-}" ]] && continue

        local r_cpu="${RUN_RESULTS[${rid}_cpu]:-0}"
        local r_tp="${RUN_RESULTS[${rid}_http_rate]:-0}"
        local r_p50="${RUN_RESULTS[${rid}_p50]:-0}"
        local r_p95="${RUN_RESULTS[${rid}_p95]:-0}"
        local r_loss="${RUN_RESULTS[${rid}_loss_pct]:-0}"

        local r_score
        r_score=$(calc_score "$ind_base_cpu" "$r_cpu" "$ind_base_tp" "$r_tp" "$ind_base_p95" "$r_p95" "$ind_base_loss" "$r_loss")

        local r_stars_num
        r_stars_num=$(perl -e '
            my $s = $ARGV[0];
            if    ($s >= 140) { print 5 }
            elsif ($s >= 125) { print 4 }
            elsif ($s >= 115) { print 3 }
            elsif ($s >= 108) { print 2 }
            else              { print 1 }
        ' "$r_score")

        if [[ $fixes_first -eq 0 ]]; then
            fixes_json+=","
        fi
        fixes_json+="{\"id\":${fix_id},\"name\":\"${FLAG_NAMES[$i]}\",\"flag\":\"${FLAG_VALUES[$i]%%=*}\",\"cpu\":${r_cpu},\"http_rate\":${r_tp},\"latency_avg\":${r_p50},\"score\":${r_score},\"stars\":${r_stars_num}}"
        fixes_first=0
    done
    fixes_json+="]"

    # Build stress JSON
    local stress_json="{}"
    if [[ ${#STRESS_RUN_IDS[@]} -gt 0 ]]; then
        # Find max rates for original (even IDs) and optimized (odd IDs)
        local orig_max=0
        local opt_max=0
        local rates_json="["
        local rates_first=1

        # Process stress pairs
        local prev_sid=""
        for sid in "${STRESS_RUN_IDS[@]}"; do
            local s_tp="${RUN_RESULTS[${sid}_http_rate]:-0}"
            local s_loss="${RUN_RESULTS[${sid}_loss_pct]:-0}"
            local s_name="${RUN_RESULTS[${sid}_name]:-}"

            if echo "$s_name" | grep -q "(original)"; then
                local s_rate
                s_rate=$(echo "$s_name" | grep -oP '\d+(?=msg/s)' || echo "0")
                orig_max=$(perl -e "print $s_tp > $orig_max ? $s_tp : $orig_max")
                prev_sid="$sid"
            elif echo "$s_name" | grep -q "(optimized)" && [[ -n "$prev_sid" ]]; then
                local orig_loss="${RUN_RESULTS[${prev_sid}_loss_pct]:-0}"
                s_rate=$(echo "$s_name" | grep -oP '\d+(?=msg/s)' || echo "0")
                opt_max=$(perl -e "print $s_tp > $opt_max ? $s_tp : $opt_max")

                if [[ $rates_first -eq 0 ]]; then
                    rates_json+=","
                fi
                rates_json+="{\"rate\":${s_rate},\"original_loss\":${orig_loss},\"optimized_loss\":${s_loss}}"
                rates_first=0
                prev_sid=""
            fi
        done
        rates_json+="]"

        stress_json="{\"original_max\":${orig_max},\"optimized_max\":${opt_max},\"rates\":${rates_json}}"
    fi

    # Write the JSON file
    cat > "${json_file}.tmp" << JSONEOF
{
  "timestamp": "${TIMESTAMP}",
  "duration": ${DURATION},
  "system_info": {
    "hardware": "${hw_model}",
    "os": "${os_name}",
    "loxberry": "${lb_version}",
    "perl": "${perl_version}",
    "mosquitto": "${mosquitto_version}",
    "miniservers": ${ms_count},
    "plugins": ${plugin_count}
  },
  "baseline": {
    "cpu": ${base_cpu}, "rss_mb": ${base_rss}, "http_rate": ${base_tp},
    "latency_avg": ${base_p50}, "latency_p95": ${base_p95}, "loss_pct": ${base_loss}
  },
  "optimized": {
    "cpu": ${opt_cpu}, "rss_mb": ${opt_rss}, "http_rate": ${opt_tp},
    "latency_avg": ${opt_p50}, "latency_p95": ${opt_p95}, "loss_pct": ${opt_loss}
  },
  "score": ${overall_score},
  "fixes": ${fixes_json},
  "stress": ${stress_json}
}
JSONEOF
    mv -f "${json_file}.tmp" "$json_file" 2>/dev/null || true
    log_info "summary.json written to $json_file"
}
```

- [ ] Call `generate_summary_json` after `generate_report` in main execution:

```bash
generate_report
generate_summary_json
```

- [ ] Also rename `summary_${TIMESTAMP}.csv` to just `summary.csv` in `generate_report()` so the plugin can find it at a predictable path:

```bash
local csv_file="${RESULTS_DIR}/${TIMESTAMP}/summary.csv"
```

- [ ] Add `report.txt` alias -- rename `benchmark_report.txt` to `report.txt`:

```bash
local report_file="${RESULTS_DIR}/${TIMESTAMP}/report.txt"
```

- [ ] Remove the dual-write to `DATA_DIR` at the end of `generate_report()`. The plugin orchestrator writes directly to `$LBPDATA/results/`, so no copy is needed. Delete these lines:

```bash
# DELETE: Copy results to DATA_DIR for persistence
# mkdir -p "$DATA_DIR"
# cp -r "${RESULTS_DIR}/${TIMESTAMP}" "$DATA_DIR/" 2>/dev/null || true
# log_info "Results copied to $DATA_DIR/${TIMESTAMP}/"
```

- [ ] Commit: `feat(mqttbenchmark): orchestrator extensions for plugin mode`

---

## Task 3: Language Files

**Goal:** Create `language_de.ini` and `language_en.ini` with all translation keys needed by the Web UI.

### Files Created

- `plugin/mqttbenchmark/templates/lang/language_de.ini`
- `plugin/mqttbenchmark/templates/lang/language_en.ini`

### Steps

- [ ] Create `plugin/mqttbenchmark/templates/lang/language_de.ini`:

```ini
[COMMON]
TAB_BENCHMARK="Benchmark"
TAB_RESULTS="Ergebnisse"
TAB_COMPARE="Vergleich"
TAB_LOGS="Logfiles"
PLUGIN_TITLE="MQTT Gateway Benchmark"

[BENCHMARK]
LABEL_DURATION="Testdauer"
LABEL_LOGLEVEL="Log-Level"
LABEL_RUNS="Testreihen"
LABEL_FIXES="Optimierungen"
CB_REALISTIC="Realistische Last (Runs 0-9)"
CB_STRESS="Stresstest (Runs 10+)"
CB_SELECTFIXES="Nur bestimmte Fixes"
FIX_1="Early Filter"
FIX_2="Connection Pool"
FIX_3="Miniserver Cache"
FIX_4="Precompiled Regex"
FIX_5="Own Topic Filter"
FIX_6="Flatten Singleton"
FIX_7="JSON::XS"
BTN_START="Benchmark starten"
BTN_DRYRUN="Dry Run"
BTN_CANCEL="Abbrechen"
BTN_SAVE="Einstellungen speichern"
PROGRESS_RUN="Run {0}/{1}: {2}"
PROGRESS_ETA="Geschaetzte Restzeit: {0}"
STATUS_RUNNING="Benchmark laeuft..."
STATUS_IDLE="Bereit"
ERR_ALREADY_RUNNING="Benchmark laeuft bereits"
OK_SETTINGS_SAVED="Einstellungen gespeichert"
DURATION_30="30 Sekunden"
DURATION_60="60 Sekunden"
DURATION_120="120 Sekunden"
LOGLEVEL_3="3 - Nur Fehler"
LOGLEVEL_6="6 - Info"
LOGLEVEL_7="7 - Debug"

[RESULTS]
LABEL_SELECT="Benchmark-Lauf auswaehlen"
LABEL_NODATA="Keine Ergebnisse vorhanden. Starten Sie zuerst einen Benchmark."
TH_METRIC="Metrik"
TH_ORIGINAL="Original"
TH_OPTIMIZED="Optimiert"
TH_CHANGE="Veraenderung"
TH_FIX="Optimierung"
TH_CPU="CPU-Delta"
TH_HTTPRATE="HTTP-Rate"
TH_STARS="Bewertung"
TH_SCORE="Score"
LABEL_SYSINFO="Systemkonfiguration"
BTN_CSV="CSV herunterladen"
LABEL_STRESS="Stresstest-Ergebnis"
LABEL_OVERVIEW="Gesamtvergleich: Original vs. Optimiert"
LABEL_INDIVIDUAL="Einzelne Optimierungen"
ROW_CPU="CPU-Auslastung"
ROW_HTTPRATE="HTTP-Durchsatz"
ROW_LATENCY="Latenz (p95)"
ROW_LOSS="Nachrichtenverlust"
ROW_SCORE="Gesamtscore"

[COMPARE]
LABEL_RUN_A="Lauf A"
LABEL_RUN_B="Lauf B"
BTN_COMPARE="Vergleichen"
BETTER="besser"
WORSE="schlechter"
LABEL_NOSELECTION="Bitte waehlen Sie zwei Laeufe zum Vergleichen aus."

[ERRORS]
ERR_NO_BENCHMARK="Kein Benchmark laeuft"
ERR_NOT_FOUND="Ergebnis nicht gefunden"
ERR_INVALID_ACTION="Unbekannte Aktion"
ERR_START_FAILED="Benchmark konnte nicht gestartet werden"
```

- [ ] Create `plugin/mqttbenchmark/templates/lang/language_en.ini`:

```ini
[COMMON]
TAB_BENCHMARK="Benchmark"
TAB_RESULTS="Results"
TAB_COMPARE="Compare"
TAB_LOGS="Logfiles"
PLUGIN_TITLE="MQTT Gateway Benchmark"

[BENCHMARK]
LABEL_DURATION="Test Duration"
LABEL_LOGLEVEL="Log Level"
LABEL_RUNS="Test Runs"
LABEL_FIXES="Optimizations"
CB_REALISTIC="Realistic Load (Runs 0-9)"
CB_STRESS="Stress Test (Runs 10+)"
CB_SELECTFIXES="Only specific fixes"
FIX_1="Early Filter"
FIX_2="Connection Pool"
FIX_3="Miniserver Cache"
FIX_4="Precompiled Regex"
FIX_5="Own Topic Filter"
FIX_6="Flatten Singleton"
FIX_7="JSON::XS"
BTN_START="Start Benchmark"
BTN_DRYRUN="Dry Run"
BTN_CANCEL="Cancel"
BTN_SAVE="Save Settings"
PROGRESS_RUN="Run {0}/{1}: {2}"
PROGRESS_ETA="Estimated time: {0}"
STATUS_RUNNING="Benchmark running..."
STATUS_IDLE="Ready"
ERR_ALREADY_RUNNING="Benchmark already running"
OK_SETTINGS_SAVED="Settings saved"
DURATION_30="30 seconds"
DURATION_60="60 seconds"
DURATION_120="120 seconds"
LOGLEVEL_3="3 - Errors only"
LOGLEVEL_6="6 - Info"
LOGLEVEL_7="7 - Debug"

[RESULTS]
LABEL_SELECT="Select benchmark run"
LABEL_NODATA="No results available. Run a benchmark first."
TH_METRIC="Metric"
TH_ORIGINAL="Original"
TH_OPTIMIZED="Optimized"
TH_CHANGE="Change"
TH_FIX="Optimization"
TH_CPU="CPU Delta"
TH_HTTPRATE="HTTP Rate"
TH_STARS="Rating"
TH_SCORE="Score"
LABEL_SYSINFO="System Configuration"
BTN_CSV="Download CSV"
LABEL_STRESS="Stress Test Result"
LABEL_OVERVIEW="Overall Comparison: Original vs. Optimized"
LABEL_INDIVIDUAL="Individual Optimizations"
ROW_CPU="CPU Usage"
ROW_HTTPRATE="HTTP Throughput"
ROW_LATENCY="Latency (p95)"
ROW_LOSS="Message Loss"
ROW_SCORE="Overall Score"

[COMPARE]
LABEL_RUN_A="Run A"
LABEL_RUN_B="Run B"
BTN_COMPARE="Compare"
BETTER="better"
WORSE="worse"
LABEL_NOSELECTION="Please select two runs to compare."

[ERRORS]
ERR_NO_BENCHMARK="No benchmark running"
ERR_NOT_FOUND="Result not found"
ERR_INVALID_ACTION="Unknown action"
ERR_START_FAILED="Failed to start benchmark"
```

- [ ] Commit: `feat(mqttbenchmark): language files (DE/EN)`

---

## Task 4: CGI Handler (index.cgi)

**Goal:** Create the Perl CGI handler following LoxBerry::Web boilerplate patterns. Handles 4-tab navbar, config loading/saving, template rendering.

### Files Created

- `plugin/mqttbenchmark/webfrontend/htmlauth/index.cgi`

### Steps

- [ ] Create `plugin/mqttbenchmark/webfrontend/htmlauth/index.cgi`:

```perl
#!/usr/bin/perl

use strict;
use warnings;
use Config::Simple '-strict';
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use JSON qw(decode_json encode_json);
use LoxBerry::System;
use LoxBerry::Web;

##########################################################################
# Variables
##########################################################################

my $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Read Settings
##########################################################################

my $version = LoxBerry::System::pluginversion();
my $cfg = new Config::Simple("$lbpconfigdir/mqttbenchmark.cfg");

##########################################################################
# Form Processing: Save settings
##########################################################################

if ($R::saveformdata) {
    # Validate and save duration
    my $duration = ($R::duration && $R::duration =~ /^(30|60|120)$/) ? $1 : 60;
    $cfg->param("BENCHMARK.DURATION", $duration);

    # Validate and save loglevel
    my $loglevel = ($R::loglevel && $R::loglevel =~ /^(3|6|7)$/) ? $1 : 6;
    $cfg->param("BENCHMARK.LOGLEVEL", $loglevel);

    # Validate and save runs
    my $runs = "";
    $runs .= "realistic," if $R::run_realistic;
    $runs .= "stress,"    if $R::run_stress;
    $runs =~ s/,$//;
    $runs = "realistic,stress" unless $runs;
    $cfg->param("BENCHMARK.RUNS", $runs);

    # Validate and save fixes
    my @fixes;
    for my $i (1..7) {
        my $param = "fix_$i";
        push @fixes, $i if $R::{$param};
    }
    my $fixes_str = @fixes ? join(",", @fixes) : "1,2,3,4,5,6,7";
    $cfg->param("BENCHMARK.FIXES", $fixes_str);

    $cfg->save();
}

##########################################################################
# Template
##########################################################################

my $template = HTML::Template->new(
    filename        => "$lbptemplatedir/settings.html",
    global_vars     => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
    associate       => $cfg,
);

# Load language file
my %L = LoxBerry::System::readlanguage($template, "language.ini");

##########################################################################
# Fill template variables from config
##########################################################################

my $duration = $cfg->param("BENCHMARK.DURATION") || 60;
my $loglevel = $cfg->param("BENCHMARK.LOGLEVEL") || 6;
my $runs     = $cfg->param("BENCHMARK.RUNS") || "realistic,stress";
my $fixes    = $cfg->param("BENCHMARK.FIXES") || "1,2,3,4,5,6,7";

# Duration dropdown selected states
$template->param("DURATION_30_SEL",  ($duration == 30)  ? "selected" : "");
$template->param("DURATION_60_SEL",  ($duration == 60)  ? "selected" : "");
$template->param("DURATION_120_SEL", ($duration == 120) ? "selected" : "");

# Loglevel dropdown selected states
$template->param("LOGLEVEL_3_SEL", ($loglevel == 3) ? "selected" : "");
$template->param("LOGLEVEL_6_SEL", ($loglevel == 6) ? "selected" : "");
$template->param("LOGLEVEL_7_SEL", ($loglevel == 7) ? "selected" : "");

# Runs checkboxes
$template->param("RUN_REALISTIC_CHK", ($runs =~ /realistic/) ? "checked" : "");
$template->param("RUN_STRESS_CHK",    ($runs =~ /stress/)    ? "checked" : "");

# Fixes checkboxes
for my $i (1..7) {
    $template->param("FIX_${i}_CHK", ($fixes =~ /\b$i\b/) ? "checked" : "");
}

##########################################################################
# Navbar
##########################################################################

our %navbar;
$navbar{1}{Name}  = "$L{'COMMON.TAB_BENCHMARK'}";
$navbar{1}{URL}   = 'index.cgi?form=1';

$navbar{2}{Name}  = "$L{'COMMON.TAB_RESULTS'}";
$navbar{2}{URL}   = 'index.cgi?form=2';

$navbar{3}{Name}  = "$L{'COMMON.TAB_COMPARE'}";
$navbar{3}{URL}   = 'index.cgi?form=3';

$navbar{99}{Name} = "$L{'COMMON.TAB_LOGS'}";
$navbar{99}{URL}  = 'index.cgi?form=99';

# Active tab
if (!$R::form || $R::form eq "1") {
    $navbar{1}{active} = 1;
    $template->param("FORM1", 1);
} elsif ($R::form eq "2") {
    $navbar{2}{active} = 1;
    $template->param("FORM2", 1);
} elsif ($R::form eq "3") {
    $navbar{3}{active} = 1;
    $template->param("FORM3", 1);
} elsif ($R::form eq "99") {
    $navbar{99}{active} = 1;
    $template->param("FORM99", 1);
    $template->param("LOGLIST_HTML", LoxBerry::Web::loglist_html());
}

# Save confirmation
if ($R::saveformdata) {
    $template->param("SAVE_OK", 1);
}

##########################################################################
# Output
##########################################################################

LoxBerry::Web::lbheader(
    "$L{'COMMON.PLUGIN_TITLE'} V$version",
    "https://wiki.loxberry.de/plugins/mqttbenchmark/start",
    "help.html"
);
print $template->output();
LoxBerry::Web::lbfooter();

exit;
```

- [ ] Commit: `feat(mqttbenchmark): CGI handler (index.cgi)`

---

## Task 5: HTML Templates (settings.html + help.html)

**Goal:** Create the main HTML::Template with 4 tab sections, all form elements, AJAX polling JavaScript, progress bar, result tables, comparison tables. Create help.html.

### Files Created

- `plugin/mqttbenchmark/templates/settings.html`
- `plugin/mqttbenchmark/templates/help.html`

### Steps

- [ ] Create `plugin/mqttbenchmark/templates/settings.html`:

```html
<!-- =====================================================================
     MQTT Gateway Benchmark Plugin - Main Template
     Tabs: Benchmark | Results | Compare | Logs
     ===================================================================== -->

<!-- =====================================================================
     TAB 1: BENCHMARK
     ===================================================================== -->
<TMPL_IF FORM1>

<!-- Settings form -->
<form method="post" data-ajax="false" name="main_form" id="main_form"
      action="./index.cgi?form=1">
    <input type="hidden" name="saveformdata" value="1">

    <TMPL_IF SAVE_OK>
    <div class="ui-body ui-body-confirm ui-corner-all">
        <p><TMPL_VAR BENCHMARK.OK_SETTINGS_SAVED></p>
    </div>
    </TMPL_IF>

    <div data-role="fieldcontain">
        <label for="duration"><TMPL_VAR BENCHMARK.LABEL_DURATION></label>
        <select name="duration" id="duration" data-mini="true">
            <option value="30" <TMPL_VAR DURATION_30_SEL>><TMPL_VAR BENCHMARK.DURATION_30></option>
            <option value="60" <TMPL_VAR DURATION_60_SEL>><TMPL_VAR BENCHMARK.DURATION_60></option>
            <option value="120" <TMPL_VAR DURATION_120_SEL>><TMPL_VAR BENCHMARK.DURATION_120></option>
        </select>
    </div>

    <div data-role="fieldcontain">
        <label for="loglevel"><TMPL_VAR BENCHMARK.LABEL_LOGLEVEL></label>
        <select name="loglevel" id="loglevel" data-mini="true">
            <option value="3" <TMPL_VAR LOGLEVEL_3_SEL>><TMPL_VAR BENCHMARK.LOGLEVEL_3></option>
            <option value="6" <TMPL_VAR LOGLEVEL_6_SEL>><TMPL_VAR BENCHMARK.LOGLEVEL_6></option>
            <option value="7" <TMPL_VAR LOGLEVEL_7_SEL>><TMPL_VAR BENCHMARK.LOGLEVEL_7></option>
        </select>
    </div>

    <div data-role="fieldcontain">
        <fieldset data-role="controlgroup">
            <legend><TMPL_VAR BENCHMARK.LABEL_RUNS></legend>
            <label for="run_realistic">
                <input type="checkbox" name="run_realistic" id="run_realistic"
                       <TMPL_VAR RUN_REALISTIC_CHK>>
                <TMPL_VAR BENCHMARK.CB_REALISTIC>
            </label>
            <label for="run_stress">
                <input type="checkbox" name="run_stress" id="run_stress"
                       <TMPL_VAR RUN_STRESS_CHK>>
                <TMPL_VAR BENCHMARK.CB_STRESS>
            </label>
        </fieldset>
    </div>

    <div data-role="fieldcontain">
        <fieldset data-role="controlgroup">
            <legend><TMPL_VAR BENCHMARK.LABEL_FIXES></legend>
            <label for="fix_1">
                <input type="checkbox" name="fix_1" id="fix_1" <TMPL_VAR FIX_1_CHK>>
                <TMPL_VAR BENCHMARK.FIX_1>
            </label>
            <label for="fix_2">
                <input type="checkbox" name="fix_2" id="fix_2" <TMPL_VAR FIX_2_CHK>>
                <TMPL_VAR BENCHMARK.FIX_2>
            </label>
            <label for="fix_3">
                <input type="checkbox" name="fix_3" id="fix_3" <TMPL_VAR FIX_3_CHK>>
                <TMPL_VAR BENCHMARK.FIX_3>
            </label>
            <label for="fix_4">
                <input type="checkbox" name="fix_4" id="fix_4" <TMPL_VAR FIX_4_CHK>>
                <TMPL_VAR BENCHMARK.FIX_4>
            </label>
            <label for="fix_5">
                <input type="checkbox" name="fix_5" id="fix_5" <TMPL_VAR FIX_5_CHK>>
                <TMPL_VAR BENCHMARK.FIX_5>
            </label>
            <label for="fix_6">
                <input type="checkbox" name="fix_6" id="fix_6" <TMPL_VAR FIX_6_CHK>>
                <TMPL_VAR BENCHMARK.FIX_6>
            </label>
            <label for="fix_7">
                <input type="checkbox" name="fix_7" id="fix_7" <TMPL_VAR FIX_7_CHK>>
                <TMPL_VAR BENCHMARK.FIX_7>
            </label>
        </fieldset>
    </div>

    <div data-role="fieldcontain">
        <a id="btn_save" data-role="button" data-inline="true" data-mini="true"
           data-icon="check" onclick="$('#main_form').submit();">
            <TMPL_VAR BENCHMARK.BTN_SAVE>
        </a>
    </div>
</form>

<hr>

<!-- Action buttons -->
<div data-role="fieldcontain">
    <a id="btn_start" data-role="button" data-inline="true" data-mini="true"
       data-icon="arrow-r" data-theme="b" href="javascript:startBenchmark();">
        <TMPL_VAR BENCHMARK.BTN_START>
    </a>
    <a id="btn_dryrun" data-role="button" data-inline="true" data-mini="true"
       data-icon="info" href="javascript:startBenchmark(true);">
        <TMPL_VAR BENCHMARK.BTN_DRYRUN>
    </a>
</div>

<!-- Progress area (hidden by default) -->
<div id="benchmark_progress" style="display:none;">
    <h3 id="progress_status"><TMPL_VAR BENCHMARK.STATUS_RUNNING></h3>
    <div id="progress_run"></div>
    <div style="background:#eee; border-radius:4px; height:20px; margin:10px 0;">
        <div id="progress_bar" style="background:#4CAF50; height:100%; border-radius:4px; width:0%; transition:width 0.5s;"></div>
    </div>
    <div id="progress_eta"></div>
    <a id="btn_cancel" data-role="button" data-inline="true" data-mini="true"
       data-icon="delete" data-theme="e" href="javascript:stopBenchmark();">
        <TMPL_VAR BENCHMARK.BTN_CANCEL>
    </a>
</div>

<script>
var pollTimer = null;

function startBenchmark(dryrun) {
    var data = {
        action: 'start',
        duration: $('#duration').val(),
        loglevel: $('#loglevel').val(),
        runs: '',
        fixes: ''
    };

    // Collect runs
    var runs = [];
    if ($('#run_realistic').is(':checked')) runs.push('realistic');
    if ($('#run_stress').is(':checked')) runs.push('stress');
    data.runs = runs.join(',') || 'realistic,stress';

    // Collect fixes
    var fixes = [];
    for (var i = 1; i <= 7; i++) {
        if ($('#fix_' + i).is(':checked')) fixes.push(i);
    }
    data.fixes = fixes.join(',') || '1,2,3,4,5,6,7';

    if (dryrun) {
        data.action = 'dryrun';
    }

    $.ajax({
        url: 'ajax.cgi',
        type: 'POST',
        data: data,
        dataType: 'json',
        success: function(resp) {
            if (resp.error) {
                alert(resp.message);
                return;
            }
            if (!dryrun) {
                $('#benchmark_progress').show();
                $('#btn_start').hide();
                $('#btn_dryrun').hide();
                pollStatus();
                pollTimer = setInterval(pollStatus, 2000);
            }
        },
        error: function(xhr, status, err) {
            alert('Error: ' + err);
        }
    });
}

function stopBenchmark() {
    $.ajax({
        url: 'ajax.cgi',
        type: 'POST',
        data: { action: 'stop' },
        dataType: 'json',
        success: function(resp) {
            clearInterval(pollTimer);
            pollTimer = null;
            $('#benchmark_progress').hide();
            $('#btn_start').show();
            $('#btn_dryrun').show();
        }
    });
}

function pollStatus() {
    $.ajax({
        url: 'ajax.cgi',
        type: 'GET',
        data: { action: 'status' },
        dataType: 'json',
        success: function(resp) {
            if (!resp.running) {
                clearInterval(pollTimer);
                pollTimer = null;
                $('#benchmark_progress').hide();
                $('#btn_start').show();
                $('#btn_dryrun').show();
                return;
            }

            var pct = 0;
            if (resp.total_runs > 0) {
                pct = Math.round((resp.completed_runs.length / resp.total_runs) * 100);
            }
            $('#progress_bar').css('width', pct + '%');
            $('#progress_run').text(
                'Run ' + (resp.completed_runs.length + 1) + '/' + resp.total_runs + ': ' + resp.run_name
            );

            // ETA calculation
            if (resp.started_at && resp.completed_runs.length > 0) {
                var elapsed = Math.floor(Date.now() / 1000) - resp.started_at;
                var perRun = elapsed / resp.completed_runs.length;
                var remaining = Math.round(perRun * (resp.total_runs - resp.completed_runs.length));
                var mins = Math.floor(remaining / 60);
                var secs = remaining % 60;
                $('#progress_eta').text('~' + mins + 'm ' + secs + 's remaining');
            }
        }
    });
}

// Check status on page load (in case benchmark is already running)
$(document).ready(function() {
    $.ajax({
        url: 'ajax.cgi',
        type: 'GET',
        data: { action: 'status' },
        dataType: 'json',
        success: function(resp) {
            if (resp.running) {
                $('#benchmark_progress').show();
                $('#btn_start').hide();
                $('#btn_dryrun').hide();
                pollStatus();
                pollTimer = setInterval(pollStatus, 2000);
            }
        }
    });
});
</script>

</TMPL_IF>

<!-- =====================================================================
     TAB 2: RESULTS
     ===================================================================== -->
<TMPL_IF FORM2>

<div id="results_container">
    <div data-role="fieldcontain">
        <label for="result_select"><TMPL_VAR RESULTS.LABEL_SELECT></label>
        <select name="result_select" id="result_select" data-mini="true">
            <option value="">--</option>
        </select>
    </div>

    <div id="results_content" style="display:none;">

        <!-- Overall comparison table -->
        <h3><TMPL_VAR RESULTS.LABEL_OVERVIEW></h3>
        <table data-role="table" class="ui-responsive" id="tbl_overview">
            <thead>
                <tr>
                    <th><TMPL_VAR RESULTS.TH_METRIC></th>
                    <th><TMPL_VAR RESULTS.TH_ORIGINAL></th>
                    <th><TMPL_VAR RESULTS.TH_OPTIMIZED></th>
                    <th><TMPL_VAR RESULTS.TH_CHANGE></th>
                </tr>
            </thead>
            <tbody id="overview_body">
            </tbody>
        </table>

        <!-- Individual optimizations table -->
        <h3><TMPL_VAR RESULTS.LABEL_INDIVIDUAL></h3>
        <table data-role="table" class="ui-responsive" id="tbl_individual">
            <thead>
                <tr>
                    <th><TMPL_VAR RESULTS.TH_FIX></th>
                    <th><TMPL_VAR RESULTS.TH_CPU></th>
                    <th><TMPL_VAR RESULTS.TH_HTTPRATE></th>
                    <th><TMPL_VAR RESULTS.TH_SCORE></th>
                    <th><TMPL_VAR RESULTS.TH_STARS></th>
                </tr>
            </thead>
            <tbody id="individual_body">
            </tbody>
        </table>

        <!-- Stress test results -->
        <div id="stress_section" style="display:none;">
            <h3><TMPL_VAR RESULTS.LABEL_STRESS></h3>
            <table data-role="table" class="ui-responsive" id="tbl_stress">
                <thead>
                    <tr>
                        <th>Rate (msg/s)</th>
                        <th>Original Loss %</th>
                        <th>Optimized Loss %</th>
                    </tr>
                </thead>
                <tbody id="stress_body">
                </tbody>
            </table>
        </div>

        <!-- System info (collapsible) -->
        <div data-role="collapsible" data-collapsed="true">
            <h3><TMPL_VAR RESULTS.LABEL_SYSINFO></h3>
            <div id="sysinfo_content"></div>
        </div>

        <!-- CSV download -->
        <a id="btn_csv" data-role="button" data-inline="true" data-mini="true"
           data-icon="arrow-d" href="javascript:downloadCSV();">
            <TMPL_VAR RESULTS.BTN_CSV>
        </a>
    </div>

    <div id="results_nodata">
        <p><TMPL_VAR RESULTS.LABEL_NODATA></p>
    </div>
</div>

<script>
// Load results list on page load
$(document).ready(function() {
    $.ajax({
        url: 'ajax.cgi',
        type: 'GET',
        data: { action: 'results' },
        dataType: 'json',
        success: function(resp) {
            if (resp.error) return;
            var runs = resp.data || [];
            if (runs.length === 0) {
                $('#results_nodata').show();
                return;
            }
            $('#results_nodata').hide();
            var sel = $('#result_select');
            for (var i = 0; i < runs.length; i++) {
                // Format timestamp: 20260325_1432 -> 25.03.2026 14:32
                var ts = runs[i];
                var label = ts.substring(6,8) + '.' + ts.substring(4,6) + '.'
                          + ts.substring(0,4) + ' ' + ts.substring(9,11) + ':'
                          + ts.substring(11,13);
                sel.append('<option value="' + ts + '">' + label + '</option>');
            }
            sel.selectmenu('refresh');
        }
    });

    $('#result_select').on('change', function() {
        var ts = $(this).val();
        if (!ts) {
            $('#results_content').hide();
            return;
        }
        loadResult(ts);
    });
});

function loadResult(timestamp) {
    $.ajax({
        url: 'ajax.cgi',
        type: 'GET',
        data: { action: 'result', timestamp: timestamp },
        dataType: 'json',
        success: function(resp) {
            if (resp.error) {
                alert(resp.message);
                return;
            }
            var d = resp.data;
            renderOverview(d);
            renderIndividual(d);
            renderStress(d);
            renderSysinfo(d);
            $('#results_content').show();
        }
    });
}

function renderOverview(d) {
    var b = d.baseline;
    var o = d.optimized;
    var rows = '';

    // CPU
    var cpuChange = b.cpu > 0 ? ((1 - o.cpu / b.cpu) * 100).toFixed(1) : 0;
    rows += '<tr><td><TMPL_VAR RESULTS.ROW_CPU></td><td>' + b.cpu + '%</td><td>'
          + o.cpu + '%</td><td style="color:green">-' + cpuChange + '%</td></tr>';

    // HTTP Rate
    var tpChange = b.http_rate > 0 ? ((o.http_rate / b.http_rate - 1) * 100).toFixed(1) : 0;
    rows += '<tr><td><TMPL_VAR RESULTS.ROW_HTTPRATE></td><td>' + b.http_rate + '/s</td><td>'
          + o.http_rate + '/s</td><td style="color:green">+' + tpChange + '%</td></tr>';

    // Latency p95
    var latChange = b.latency_p95 > 0 ? ((1 - o.latency_p95 / b.latency_p95) * 100).toFixed(1) : 0;
    rows += '<tr><td><TMPL_VAR RESULTS.ROW_LATENCY></td><td>' + b.latency_p95 + 'ms</td><td>'
          + o.latency_p95 + 'ms</td><td style="color:green">-' + latChange + '%</td></tr>';

    // Loss
    rows += '<tr><td><TMPL_VAR RESULTS.ROW_LOSS></td><td>' + b.loss_pct + '%</td><td>'
          + o.loss_pct + '%</td><td></td></tr>';

    // Score
    rows += '<tr><td><strong><TMPL_VAR RESULTS.ROW_SCORE></strong></td><td></td><td></td><td><strong>'
          + d.score + '</strong></td></tr>';

    $('#overview_body').html(rows);
}

function renderIndividual(d) {
    var rows = '';
    var fixes = d.fixes || [];
    // Sort by score descending
    fixes.sort(function(a, b) { return b.score - a.score; });

    for (var i = 0; i < fixes.length; i++) {
        var f = fixes[i];
        var stars = '';
        for (var s = 0; s < f.stars; s++) stars += '\u2605';
        for (var s = f.stars; s < 5; s++) stars += '\u2606';
        rows += '<tr><td>' + f.name + '</td><td>' + f.cpu + '%</td><td>'
              + f.http_rate + '/s</td><td>' + f.score + '</td><td>' + stars + '</td></tr>';
    }
    $('#individual_body').html(rows);
}

function renderStress(d) {
    if (!d.stress || !d.stress.rates || d.stress.rates.length === 0) {
        $('#stress_section').hide();
        return;
    }
    var rows = '';
    var rates = d.stress.rates;
    for (var i = 0; i < rates.length; i++) {
        var r = rates[i];
        rows += '<tr><td>' + r.rate + '</td><td>' + r.original_loss + '%</td><td>'
              + r.optimized_loss + '%</td></tr>';
    }
    rows += '<tr><td><strong>Max HTTP/s</strong></td><td>' + d.stress.original_max
          + '</td><td>' + d.stress.optimized_max + '</td></tr>';
    $('#stress_body').html(rows);
    $('#stress_section').show();
}

function renderSysinfo(d) {
    if (!d.system_info) return;
    var s = d.system_info;
    var html = '<table>';
    html += '<tr><td>Hardware</td><td>' + s.hardware + '</td></tr>';
    html += '<tr><td>OS</td><td>' + s.os + '</td></tr>';
    html += '<tr><td>LoxBerry</td><td>' + s.loxberry + '</td></tr>';
    html += '<tr><td>Perl</td><td>' + s.perl + '</td></tr>';
    html += '<tr><td>Mosquitto</td><td>' + s.mosquitto + '</td></tr>';
    html += '<tr><td>Miniservers</td><td>' + s.miniservers + '</td></tr>';
    html += '<tr><td>Plugins</td><td>' + s.plugins + '</td></tr>';
    html += '</table>';
    $('#sysinfo_content').html(html);
}

function downloadCSV() {
    var ts = $('#result_select').val();
    if (!ts) return;
    window.location = 'ajax.cgi?action=csv&timestamp=' + ts;
}
</script>

</TMPL_IF>

<!-- =====================================================================
     TAB 3: COMPARE
     ===================================================================== -->
<TMPL_IF FORM3>

<div id="compare_container">
    <div data-role="fieldcontain">
        <label for="compare_a"><TMPL_VAR COMPARE.LABEL_RUN_A></label>
        <select name="compare_a" id="compare_a" data-mini="true">
            <option value="">--</option>
        </select>
    </div>

    <div data-role="fieldcontain">
        <label for="compare_b"><TMPL_VAR COMPARE.LABEL_RUN_B></label>
        <select name="compare_b" id="compare_b" data-mini="true">
            <option value="">--</option>
        </select>
    </div>

    <a id="btn_compare" data-role="button" data-inline="true" data-mini="true"
       data-icon="grid" data-theme="b" href="javascript:runCompare();">
        <TMPL_VAR COMPARE.BTN_COMPARE>
    </a>

    <div id="compare_result" style="display:none;">
        <table data-role="table" class="ui-responsive" id="tbl_compare">
            <thead>
                <tr>
                    <th><TMPL_VAR RESULTS.TH_METRIC></th>
                    <th id="compare_header_a">A</th>
                    <th id="compare_header_b">B</th>
                    <th><TMPL_VAR RESULTS.TH_CHANGE></th>
                </tr>
            </thead>
            <tbody id="compare_body">
            </tbody>
        </table>
    </div>
</div>

<script>
$(document).ready(function() {
    $.ajax({
        url: 'ajax.cgi',
        type: 'GET',
        data: { action: 'results' },
        dataType: 'json',
        success: function(resp) {
            if (resp.error) return;
            var runs = resp.data || [];
            var selA = $('#compare_a');
            var selB = $('#compare_b');
            for (var i = 0; i < runs.length; i++) {
                var ts = runs[i];
                var label = ts.substring(6,8) + '.' + ts.substring(4,6) + '.'
                          + ts.substring(0,4) + ' ' + ts.substring(9,11) + ':'
                          + ts.substring(11,13);
                selA.append('<option value="' + ts + '">' + label + '</option>');
                selB.append('<option value="' + ts + '">' + label + '</option>');
            }
            selA.selectmenu('refresh');
            selB.selectmenu('refresh');
        }
    });
});

function runCompare() {
    var a = $('#compare_a').val();
    var b = $('#compare_b').val();
    if (!a || !b) {
        alert('<TMPL_VAR COMPARE.LABEL_NOSELECTION>');
        return;
    }

    $.ajax({
        url: 'ajax.cgi',
        type: 'GET',
        data: { action: 'compare', timestamp_a: a, timestamp_b: b },
        dataType: 'json',
        success: function(resp) {
            if (resp.error) {
                alert(resp.message);
                return;
            }
            var d = resp.data;
            renderCompare(d);
            $('#compare_result').show();
        }
    });
}

function renderCompare(d) {
    var a = d.a;
    var b = d.b;

    // Update headers with timestamps
    var tsA = d.timestamp_a || 'A';
    var tsB = d.timestamp_b || 'B';
    $('#compare_header_a').text(tsA.substring(6,8) + '.' + tsA.substring(4,6) + '.' + tsA.substring(0,4));
    $('#compare_header_b').text(tsB.substring(6,8) + '.' + tsB.substring(4,6) + '.' + tsB.substring(0,4));

    var rows = '';

    // CPU (lower is better)
    rows += compareRow('<TMPL_VAR RESULTS.ROW_CPU>', a.optimized.cpu, b.optimized.cpu, '%', true);

    // HTTP Rate (higher is better)
    rows += compareRow('<TMPL_VAR RESULTS.ROW_HTTPRATE>', a.optimized.http_rate, b.optimized.http_rate, '/s', false);

    // Latency (lower is better)
    rows += compareRow('<TMPL_VAR RESULTS.ROW_LATENCY>', a.optimized.latency_p95, b.optimized.latency_p95, 'ms', true);

    // Score (higher is better)
    rows += compareRow('<TMPL_VAR RESULTS.ROW_SCORE>', a.score, b.score, '', false);

    $('#compare_body').html(rows);
}

function compareRow(label, valA, valB, unit, lowerIsBetter) {
    var diff = valB - valA;
    var color = '';
    var diffText = '';

    if (diff !== 0) {
        var isBetter;
        if (lowerIsBetter) {
            isBetter = diff < 0;
        } else {
            isBetter = diff > 0;
        }
        color = isBetter ? 'color:green' : 'color:red';
        diffText = (diff > 0 ? '+' : '') + diff.toFixed(1) + unit;
        diffText += ' (' + (isBetter
            ? '<TMPL_VAR COMPARE.BETTER>'
            : '<TMPL_VAR COMPARE.WORSE>') + ')';
    }

    return '<tr><td>' + label + '</td><td>' + valA + unit + '</td><td>'
         + valB + unit + '</td><td style="' + color + '">' + diffText + '</td></tr>';
}
</script>

</TMPL_IF>

<!-- =====================================================================
     TAB 99: LOGFILES
     ===================================================================== -->
<TMPL_IF FORM99>
<TMPL_VAR LOGLIST_HTML>
</TMPL_IF>
```

- [ ] Create `plugin/mqttbenchmark/templates/help.html`:

```html
<p>The MQTT Gateway Benchmark Plugin measures the performance impact of 7 optimizations
in the LoxBerry MQTT Gateway (mqttgateway.pl).</p>

<h4>Benchmark Tab</h4>
<p>Configure test duration, log level, and which test runs to execute.
Click "Start Benchmark" to begin. The progress bar shows the current run and estimated time remaining.
A benchmark run takes approximately 20-40 minutes depending on settings.</p>

<h4>Results Tab</h4>
<p>View results from completed benchmark runs. The overview table shows the overall
improvement from Original to Optimized. The individual optimizations table shows
the impact of each fix sorted by score. Use "Download CSV" for raw data.</p>

<h4>Compare Tab</h4>
<p>Compare two benchmark runs side by side. Useful for measuring improvement
over time or comparing different configurations.</p>

<h4>Logfiles Tab</h4>
<p>Standard LoxBerry log viewer for all benchmark-related log files.</p>

<h4>Scoring</h4>
<p>The score is calculated from CPU usage (30%), HTTP throughput (30%),
latency (20%), and message loss (20%). A score of 100 = no change,
higher = better. Star ratings: 5 stars >= 140, 4 stars >= 125,
3 stars >= 115, 2 stars >= 108.</p>
```

- [ ] Commit: `feat(mqttbenchmark): HTML templates (settings.html + help.html)`

---

## Task 6: AJAX Backend (ajax.cgi)

**Goal:** Create the AJAX handler with all 7 actions (start, stop, status, results, result, compare, csv). Input validation, error envelope, JSON responses.

### Files Created

- `plugin/mqttbenchmark/webfrontend/htmlauth/ajax.cgi`

### Steps

- [ ] Create `plugin/mqttbenchmark/webfrontend/htmlauth/ajax.cgi`:

```perl
#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use JSON qw(decode_json encode_json);
use LoxBerry::System;
use File::Basename;

##########################################################################
# CGI Setup
##########################################################################

my $cgi = CGI->new;
my $q = $cgi->Vars;

my $action = $q->{action} || '';

##########################################################################
# Status file and PID file paths
##########################################################################

my $STATUS_FILE = '/dev/shm/mqttbenchmark_status.json';
my $PID_FILE    = '/dev/shm/mqttbenchmark_pid';

##########################################################################
# Dispatch
##########################################################################

if ($action eq 'start') {
    handle_start();
} elsif ($action eq 'stop') {
    handle_stop();
} elsif ($action eq 'status') {
    handle_status();
} elsif ($action eq 'results') {
    handle_results();
} elsif ($action eq 'result') {
    handle_result();
} elsif ($action eq 'compare') {
    handle_compare();
} elsif ($action eq 'csv') {
    handle_csv();
} else {
    send_json({ error => 1, message => "Unknown action: $action" });
}

exit;

##########################################################################
# Action: start
##########################################################################

sub handle_start {
    # Check if already running
    if (is_running()) {
        send_json({ error => 1, message => "Benchmark already running" });
        return;
    }

    # Validate inputs
    my $duration = ($q->{duration} && $q->{duration} =~ /^(30|60|120)$/) ? $1 : 60;
    my $loglevel = ($q->{loglevel} && $q->{loglevel} =~ /^(3|6|7)$/)    ? $1 : 6;
    my $runs     = ($q->{runs}     && $q->{runs}     =~ /^([a-z,]+)$/)  ? $1 : "realistic,stress";
    my $fixes    = ($q->{fixes}    && $q->{fixes}    =~ /^([\d,]+)$/)   ? $1 : "1,2,3,4,5,6,7";

    # Build command
    my $cmd = "$lbpbindir/mqtt-benchmark.sh"
        . " --duration $duration"
        . " --loglevel $loglevel"
        . " --runs $runs"
        . " --fixes $fixes"
        . " --status-file $STATUS_FILE"
        . " --json-output"
        . " >> $lbplogdir/mqttbenchmark.log 2>&1 &";

    system($cmd);

    # Wait briefly and verify it started
    sleep(1);
    if (is_running()) {
        send_json({ error => 0, message => "Benchmark started" });
    } else {
        send_json({ error => 1, message => "Failed to start benchmark" });
    }
}

##########################################################################
# Action: stop
##########################################################################

sub handle_stop {
    unless (is_running()) {
        send_json({ error => 1, message => "No benchmark running" });
        return;
    }

    my $pid = read_pid();
    if ($pid && $pid =~ /^\d+$/) {
        # Kill process group to stop orchestrator and children
        kill('TERM', -$pid) or kill('TERM', $pid);
        sleep(1);
        # Force kill if still alive
        if (kill(0, $pid)) {
            kill('KILL', $pid);
        }
    }

    # Cleanup files
    unlink $PID_FILE;
    unlink $STATUS_FILE;

    send_json({ error => 0, message => "Benchmark stopped" });
}

##########################################################################
# Action: status
##########################################################################

sub handle_status {
    if (-f $STATUS_FILE) {
        my $json = read_file($STATUS_FILE);
        if ($json) {
            my $data = eval { decode_json($json) };
            if ($data) {
                # Verify the PID is actually alive
                if ($data->{running} && $data->{pid}) {
                    unless (kill(0, $data->{pid})) {
                        $data->{running} = JSON::false;
                    }
                }
                # Convert running to proper JSON boolean
                if ($data->{running}) {
                    $data->{running} = JSON::true;
                } else {
                    $data->{running} = JSON::false;
                }
                print $cgi->header(-type => 'application/json', -charset => 'utf-8');
                print encode_json($data);
                return;
            }
        }
    }

    # No status file or error reading it
    print $cgi->header(-type => 'application/json', -charset => 'utf-8');
    print encode_json({ running => JSON::false });
}

##########################################################################
# Action: results (list all benchmark runs)
##########################################################################

sub handle_results {
    my $results_dir = "$lbpdatadir/results";

    unless (-d $results_dir) {
        send_json({ error => 0, data => [] });
        return;
    }

    opendir(my $dh, $results_dir) or do {
        send_json({ error => 1, message => "Cannot read results directory" });
        return;
    };

    my @runs;
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\./;
        next unless -d "$results_dir/$entry";
        next unless $entry =~ /^\d{8}_\d{4}$/;  # Validate format: YYYYMMDD_HHMM
        # Only include runs that have a summary.json
        next unless -f "$results_dir/$entry/summary.json";
        push @runs, $entry;
    }
    closedir($dh);

    # Sort descending (newest first)
    @runs = sort { $b cmp $a } @runs;

    send_json({ error => 0, data => \@runs });
}

##########################################################################
# Action: result (single run details)
##########################################################################

sub handle_result {
    my $timestamp = $q->{timestamp} || '';

    # Validate timestamp format
    unless ($timestamp =~ /^\d{8}_\d{4}$/) {
        send_json({ error => 1, message => "Invalid timestamp format" });
        return;
    }

    my $json_file = "$lbpdatadir/results/$timestamp/summary.json";
    unless (-f $json_file) {
        send_json({ error => 1, message => "Result not found: $timestamp" });
        return;
    }

    my $json = read_file($json_file);
    my $data = eval { decode_json($json) };
    unless ($data) {
        send_json({ error => 1, message => "Failed to parse result JSON" });
        return;
    }

    send_json({ error => 0, data => $data });
}

##########################################################################
# Action: compare (two runs side by side)
##########################################################################

sub handle_compare {
    my $ts_a = $q->{timestamp_a} || '';
    my $ts_b = $q->{timestamp_b} || '';

    # Validate
    unless ($ts_a =~ /^\d{8}_\d{4}$/ && $ts_b =~ /^\d{8}_\d{4}$/) {
        send_json({ error => 1, message => "Invalid timestamp format" });
        return;
    }

    my $file_a = "$lbpdatadir/results/$ts_a/summary.json";
    my $file_b = "$lbpdatadir/results/$ts_b/summary.json";

    unless (-f $file_a) {
        send_json({ error => 1, message => "Result not found: $ts_a" });
        return;
    }
    unless (-f $file_b) {
        send_json({ error => 1, message => "Result not found: $ts_b" });
        return;
    }

    my $data_a = eval { decode_json(read_file($file_a)) };
    my $data_b = eval { decode_json(read_file($file_b)) };

    unless ($data_a && $data_b) {
        send_json({ error => 1, message => "Failed to parse result JSON" });
        return;
    }

    send_json({
        error => 0,
        data  => {
            timestamp_a => $ts_a,
            timestamp_b => $ts_b,
            a           => $data_a,
            b           => $data_b,
        }
    });
}

##########################################################################
# Action: csv (download)
##########################################################################

sub handle_csv {
    my $timestamp = $q->{timestamp} || '';

    unless ($timestamp =~ /^\d{8}_\d{4}$/) {
        send_json({ error => 1, message => "Invalid timestamp format" });
        return;
    }

    my $csv_file = "$lbpdatadir/results/$timestamp/summary.csv";
    unless (-f $csv_file) {
        send_json({ error => 1, message => "CSV not found: $timestamp" });
        return;
    }

    my $csv_data = read_file($csv_file);

    print $cgi->header(
        -type                => 'text/csv',
        -charset             => 'utf-8',
        -Content_Disposition => "attachment; filename=benchmark_${timestamp}.csv",
    );
    print $csv_data;
}

##########################################################################
# Helpers
##########################################################################

sub send_json {
    my ($data) = @_;
    print $cgi->header(
        -type    => 'application/json',
        -charset => 'utf-8',
    );
    print encode_json($data);
}

sub is_running {
    return 0 unless -f $PID_FILE;
    my $pid = read_pid();
    return 0 unless $pid && $pid =~ /^\d+$/;
    return kill(0, $pid) ? 1 : 0;
}

sub read_pid {
    return undef unless -f $PID_FILE;
    open(my $fh, '<', $PID_FILE) or return undef;
    my $pid = <$fh>;
    close $fh;
    chomp $pid if defined $pid;
    return $pid;
}

sub read_file {
    my ($path) = @_;
    open(my $fh, '<', $path) or return undef;
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}
```

- [ ] Commit: `feat(mqttbenchmark): AJAX backend (ajax.cgi)`

---

## Task 7: Integration and Packaging

**Goal:** Verify all files are in place, check cross-references between CGI/template/AJAX, ensure file structure matches spec, and create a ZIP-ready structure.

### Steps

- [ ] Verify complete file tree matches spec. Expected files:

  ```
  plugin/mqttbenchmark/
  ├── plugin.cfg
  ├── postinstall.sh
  ├── postroot.sh
  ├── preupgrade.sh
  ├── postupgrade.sh
  ├── dpkg/apt
  ├── uninstall/uninstall
  ├── bin/
  │   ├── mqtt-benchmark.sh               (modified copy)
  │   ├── mqtt-loadgen.pl                 (unchanged copy)
  │   ├── mqtt-metric-collector.pl        (unchanged copy)
  │   └── mqttgateway_benchmarkable.pl    (unchanged copy)
  ├── config/mqttbenchmark.cfg
  ├── data/dummies/.gitkeep
  ├── icons/
  │   ├── icon_64.png
  │   ├── icon_128.png
  │   ├── icon_256.png
  │   └── icon_512.png
  ├── templates/
  │   ├── settings.html
  │   ├── help.html
  │   └── lang/
  │       ├── language_de.ini
  │       └── language_en.ini
  └── webfrontend/htmlauth/
      ├── index.cgi
      └── ajax.cgi
  ```

- [ ] Cross-reference check:
  - `index.cgi` references `settings.html` as template -> exists in `templates/`
  - `index.cgi` references `help.html` -> exists in `templates/`
  - `index.cgi` references `language.ini` -> resolved by LoxBerry to `templates/lang/language_XX.ini`
  - `index.cgi` references `$lbpconfigdir/mqttbenchmark.cfg` -> created by `postinstall.sh`
  - `ajax.cgi` references `$lbpbindir/mqtt-benchmark.sh` -> exists in `bin/`
  - `ajax.cgi` references `$lbpdatadir/results/` -> created by `postinstall.sh`
  - `settings.html` AJAX calls go to `ajax.cgi` -> exists in `webfrontend/htmlauth/`
  - Template vars (`FORM1`, `FORM2`, `FORM3`, `FORM99`, `LOGLIST_HTML`, config vars) all set in `index.cgi`
  - All language keys used in `settings.html` are defined in both `language_de.ini` and `language_en.ini`

- [ ] Verify all shell scripts use LF line endings (Unix), not CRLF

- [ ] Verify `sbin/benchmark/` originals are untouched (not moved, only copied)

- [ ] Final commit: `feat(mqttbenchmark): integration check and packaging readiness`

---

## Summary

| Task | Files | Estimated Effort |
|------|-------|-----------------|
| 1. Plugin scaffold | 12+ files (plugin.cfg, hooks, config, copies) | Small |
| 2. Orchestrator extensions | 1 file (mqtt-benchmark.sh) | Large |
| 3. Language files | 2 files (language_de.ini, language_en.ini) | Small |
| 4. CGI handler | 1 file (index.cgi) | Medium |
| 5. HTML templates | 2 files (settings.html, help.html) | Large |
| 6. AJAX backend | 1 file (ajax.cgi) | Medium |
| 7. Integration check | 0 new files, verification only | Small |

**Total:** ~19 files, 7 commits
