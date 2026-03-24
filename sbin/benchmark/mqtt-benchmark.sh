#!/bin/bash
set -euo pipefail

# mqtt-benchmark.sh
# Benchmark orchestrator for LoxBerry MQTT Gateway optimization measurement.
#
# Manages the full test matrix: gateway lifecycle, feature flags,
# metric collection, load generation, report generation, and scoring.
#
# Usage:
#   mqtt-benchmark.sh [--dry-run] [--duration N] [--loglevel N]

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LBHOMEDIR="${LBHOMEDIR:-/opt/loxberry}"
BENCHMARK_DIR="${LBHOMEDIR}/log/plugins/benchmark"
RESULTS_DIR="${BENCHMARK_DIR}/results"
DATA_DIR="${LBHOMEDIR}/data/plugins/benchmark/results"
TIMESTAMP=$(date +%Y%m%d_%H%M)
DURATION=60
DRY_RUN=0
LOGLEVEL=6

ORIGINAL_GW="${LBHOMEDIR}/sbin/mqttgateway.pl"
BENCH_GW="${SCRIPT_DIR}/mqttgateway_benchmarkable.pl"

GW_PID=""
COLLECTOR_PID=""
LOADGEN_PID=""

declare -A RUN_RESULTS
declare -a RUN_ORDER=()
declare -a STRESS_RUN_IDS=()

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

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
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--duration N] [--loglevel N]"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Feature flag definitions
# ---------------------------------------------------------------------------

FLAGS_EARLY_FILTER="BENCH_EARLY_FILTER=1"
FLAGS_CONNECTION_POOL="BENCH_CONNECTION_POOL=1"
FLAGS_MS_CACHE="BENCH_MS_CACHE=1"
FLAGS_PRECOMPILED_REGEX="BENCH_PRECOMPILED_REGEX=1"
FLAGS_OWN_TOPIC_FILTER="BENCH_OWN_TOPIC_FILTER=1"
FLAGS_FLATTEN_SINGLETON="BENCH_FLATTEN_SINGLETON=1"
FLAGS_JSON_XS="BENCH_JSON_XS=1"

ALL_FLAGS="$FLAGS_EARLY_FILTER $FLAGS_CONNECTION_POOL $FLAGS_MS_CACHE $FLAGS_PRECOMPILED_REGEX $FLAGS_OWN_TOPIC_FILTER $FLAGS_FLATTEN_SINGLETON $FLAGS_JSON_XS"

FLAG_NAMES=(
    "Early Filter"
    "Connection Pool"
    "Miniserver Cache"
    "Precompiled Regex"
    "Own Topic Filter"
    "Flatten Singleton"
    "JSON::XS"
)

FLAG_VALUES=(
    "$FLAGS_EARLY_FILTER"
    "$FLAGS_CONNECTION_POOL"
    "$FLAGS_MS_CACHE"
    "$FLAGS_PRECOMPILED_REGEX"
    "$FLAGS_OWN_TOPIC_FILTER"
    "$FLAGS_FLATTEN_SINGLETON"
    "$FLAGS_JSON_XS"
)

# ---------------------------------------------------------------------------
# Utility: logging
# ---------------------------------------------------------------------------

log_info()  { echo "[$(date '+%H:%M:%S')] INFO  $*"; }
log_warn()  { echo "[$(date '+%H:%M:%S')] WARN  $*" >&2; }
log_error() { echo "[$(date '+%H:%M:%S')] ERROR $*" >&2; }
log_debug() { [[ "$LOGLEVEL" -ge 7 ]] && echo "[$(date '+%H:%M:%S')] DEBUG $*" || true; }

# ---------------------------------------------------------------------------
# System info collection
# ---------------------------------------------------------------------------

collect_sysinfo() {
    local hw_model="unknown"
    local mem_total="unknown"
    local os_name="unknown"
    local lb_version="unknown"
    local perl_version="unknown"
    local mosquitto_version="unknown"
    local ms_count="unknown"
    local plugin_count="unknown"
    local uptime_info
    local load_info
    local free_ram
    local swap_info
    local cpu_temp="n/a"

    if [[ -r /proc/device-tree/model ]]; then
        hw_model=$(tr -d '\0' < /proc/device-tree/model)
    elif [[ -r /proc/cpuinfo ]]; then
        hw_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    fi

    if [[ -r /proc/meminfo ]]; then
        mem_total=$(grep MemTotal /proc/meminfo | awk '{printf "%.0f MB", $2/1024}')
    fi

    if [[ -r /etc/os-release ]]; then
        os_name=$(. /etc/os-release && echo "$PRETTY_NAME")
    fi

    lb_version=$(perl -e 'use LoxBerry::System; print LoxBerry::System::lbversion();' 2>/dev/null || echo "unknown")
    perl_version=$(perl -e 'print $^V;' 2>/dev/null || echo "unknown")
    mosquitto_version=$(mosquitto -h 2>&1 | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")

    ms_count=$(perl -e 'use LoxBerry::System; my %ms = LoxBerry::System::get_miniservers(); print scalar keys %ms;' 2>/dev/null || echo "?")
    plugin_count=$(perl -e 'use LoxBerry::System; my @p = LoxBerry::System::get_plugins(); print scalar @p;' 2>/dev/null || echo "?")

    uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F',' '{print $1}')
    load_info=$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || echo "n/a")
    free_ram=$(awk '/MemAvailable/{printf "%.0f MB", $2/1024}' /proc/meminfo 2>/dev/null || echo "n/a")
    swap_info=$(awk '/SwapTotal/{total=$2} /SwapFree/{free=$2} END{printf "%.0f/%.0f MB", (total-free)/1024, total/1024}' /proc/meminfo 2>/dev/null || echo "n/a")

    if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
        local raw_temp
        raw_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        cpu_temp=$(perl -e "printf '%.1f', $raw_temp / 1000")
    fi

    SYSINFO_BLOCK=$(cat <<SYSEOF
+-------------------------------------------------------+
|  SYSTEM CONFIGURATION                                  |
+-------------------------------------------------------+
| Hardware:     $hw_model
| Memory:       $mem_total (free: $free_ram)
| OS:           $os_name
| LoxBerry:     $lb_version
| Perl:         $perl_version
| Mosquitto:    $mosquitto_version
| Miniservers:  $ms_count
| Plugins:      $plugin_count
| Uptime:       $uptime_info
| Load:         $load_info
| Swap:         $swap_info
| CPU Temp:     ${cpu_temp} C
+-------------------------------------------------------+
SYSEOF
)
    echo "$SYSINFO_BLOCK"
}

# ---------------------------------------------------------------------------
# Gateway lifecycle
# ---------------------------------------------------------------------------

stop_gateway() {
    log_info "Stopping any running gateway..."
    local pids
    pids=$(pgrep -f 'mqttgateway.*\.pl' 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        for p in $pids; do
            log_debug "Sending TERM to PID $p"
            kill "$p" 2>/dev/null || true
        done
        sleep 2
        # Force kill if still alive
        pids=$(pgrep -f 'mqttgateway.*\.pl' 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            for p in $pids; do
                log_warn "Force-killing PID $p"
                kill -9 "$p" 2>/dev/null || true
            done
            sleep 1
        fi
    fi
    # Clean shared memory benchmark files
    rm -f /dev/shm/bench_* 2>/dev/null || true
    GW_PID=""
    log_info "Gateway stopped."
}

start_gateway() {
    local gw_script="$1"
    shift
    local flags=("$@")

    log_info "Starting gateway: $(basename "$gw_script")"

    # Export BENCH_ flags as environment variables
    for flag in "${flags[@]}"; do
        if [[ -n "$flag" ]]; then
            local varname="${flag%%=*}"
            local varval="${flag#*=}"
            export "$varname"="$varval"
            log_debug "  Set $varname=$varval"
        fi
    done

    perl "$gw_script" &
    GW_PID=$!
    log_info "Gateway started with PID $GW_PID"

    # Wait for startup (check /proc/PID exists)
    local waited=0
    while [[ $waited -lt 10 ]]; do
        if [[ -d "/proc/$GW_PID" ]]; then
            sleep 1
            waited=$((waited + 1))
        else
            log_error "Gateway died during startup (PID $GW_PID)"
            GW_PID=""
            return 1
        fi
    done

    # Unset flags after startup to avoid leaking into other processes
    for flag in "${flags[@]}"; do
        if [[ -n "$flag" ]]; then
            local varname="${flag%%=*}"
            unset "$varname" 2>/dev/null || true
        fi
    done

    log_info "Gateway ready (PID $GW_PID, waited ${waited}s)"
    return 0
}

# ---------------------------------------------------------------------------
# Thermal check
# ---------------------------------------------------------------------------

wait_for_cooldown() {
    local max_temp=75000  # 75 C in millidegrees

    if [[ ! -r /sys/class/thermal/thermal_zone0/temp ]]; then
        log_debug "No thermal sensor available, skipping thermal wait."
        return
    fi

    local temp
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    if [[ "$temp" -gt "$max_temp" ]]; then
        log_warn "CPU temp $(perl -e "printf '%.1f', $temp / 1000") C > 75 C, waiting for cooldown..."
        while [[ "$temp" -gt "$max_temp" ]]; do
            sleep 5
            temp=$(cat /sys/class/thermal/thermal_zone0/temp)
            log_debug "  Temp: $(perl -e "printf '%.1f', $temp / 1000") C"
        done
        log_info "CPU cooled to $(perl -e "printf '%.1f', $temp / 1000") C"
    fi
}

# ---------------------------------------------------------------------------
# Run execution
# ---------------------------------------------------------------------------

run_benchmark() {
    local run_id="$1"
    local run_name="$2"
    local gw_script="$3"
    local loadgen_mode="$4"
    local loadgen_rate="$5"
    shift 5
    local flags=("$@")

    local run_dir="${RESULTS_DIR}/${TIMESTAMP}/run_${run_id}"
    mkdir -p "$run_dir"

    log_info "================================================================"
    log_info "RUN $run_id: $run_name"
    log_info "  Gateway:  $(basename "$gw_script")"
    log_info "  Mode:     $loadgen_mode  Rate: ${loadgen_rate:-auto}"
    log_info "  Duration: ${DURATION}s"
    if [[ ${#flags[@]} -gt 0 ]]; then
        log_info "  Flags:    ${flags[*]}"
    fi
    log_info "================================================================"

    # Step 1: Stop gateway
    stop_gateway

    # Step 2: Cooldown (skip for first run)
    if [[ "$run_id" -gt 0 ]]; then
        log_info "Cooldown 20s..."
        sleep 20
        wait_for_cooldown
    else
        log_info "First run — minimal cooldown (5s)..."
        sleep 5
    fi

    # Step 3: Start gateway with flags
    if ! start_gateway "$gw_script" "${flags[@]}"; then
        log_error "Failed to start gateway for run $run_id"
        return 1
    fi

    # Step 4: Start metric collector in background
    log_info "Starting metric collector..."
    perl "${SCRIPT_DIR}/mqtt-metric-collector.pl" \
        --pid "$GW_PID" \
        --output "$run_dir" \
        --duration "$DURATION" \
        --loglevel "$LOGLEVEL" &
    COLLECTOR_PID=$!

    # Step 5: Start loadgen in background
    log_info "Starting load generator..."
    local loadgen_args=(
        --mode "$loadgen_mode"
        --output "$run_dir"
        --duration "$DURATION"
        --loglevel "$LOGLEVEL"
    )
    if [[ -n "$loadgen_rate" && "$loadgen_rate" != "0" ]]; then
        loadgen_args+=(--rate "$loadgen_rate")
    fi
    perl "${SCRIPT_DIR}/mqtt-loadgen.pl" "${loadgen_args[@]}" &
    LOADGEN_PID=$!

    # Step 6: Wait for loadgen + collector to finish
    log_info "Waiting for loadgen (PID $LOADGEN_PID) and collector (PID $COLLECTOR_PID)..."
    wait "$LOADGEN_PID" 2>/dev/null || log_warn "Loadgen exited with non-zero status"
    wait "$COLLECTOR_PID" 2>/dev/null || log_warn "Collector exited with non-zero status"

    # Step 7: Collect results BEFORE stopping gateway (need GW_PID for CSV filename)
    collect_run_results "$run_id" "$run_name" "$run_dir" "$GW_PID"

    # Step 8: Stop gateway
    stop_gateway

    RUN_ORDER+=("$run_id")
    log_info "Run $run_id complete."
}

# ---------------------------------------------------------------------------
# Result collection
# ---------------------------------------------------------------------------

collect_run_results() {
    local run_id="$1"
    local run_name="$2"
    local run_dir="$3"
    local gw_pid="$4"

    log_info "Collecting results for run $run_id..."

    local csv_file="${run_dir}/samples_${gw_pid}.csv"
    local stats_file="${run_dir}/loadgen_stats.json"
    local latency_file="${run_dir}/latency.log"

    # Defaults
    local avg_cpu="0"
    local avg_rss="0"
    local avg_temp="0"
    local http_rate="0"
    local msg_sent="0"
    local msg_lost="0"
    local loss_pct="0"
    local p50_lat="0"
    local p95_lat="0"
    local p99_lat="0"

    # Parse metric CSV: columns are ts,cpu_pct,rss_kb,temp_c,http_count
    if [[ -f "$csv_file" ]]; then
        # Calculate averages for CPU, RSS, temp
        # Calculate HTTP rate as delta (last - first) / duration
        read -r avg_cpu avg_rss avg_temp http_rate < <(
            gawk -F',' '
            NR == 1 { next }  # skip header
            {
                cpu_sum += $2; rss_sum += $3; temp_sum += $4
                if (first_http == "") first_http = $5
                last_http = $5
                count++
            }
            END {
                if (count > 0) {
                    printf "%.2f %.1f %.1f ", cpu_sum/count, rss_sum/count, temp_sum/count
                } else {
                    printf "0 0 0 "
                }
                duration = '"$DURATION"'
                if (duration > 0 && last_http != "" && first_http != "") {
                    printf "%.2f", (last_http - first_http) / duration
                } else {
                    printf "0"
                }
            }' "$csv_file" 2>/dev/null || echo "0 0 0 0"
        )
        log_debug "  CSV parsed: cpu=$avg_cpu rss=$avg_rss temp=$avg_temp http_rate=$http_rate"
    else
        log_warn "  Metric CSV not found: $csv_file"
    fi

    # Parse loadgen stats JSON
    if [[ -f "$stats_file" ]]; then
        read -r msg_sent msg_lost loss_pct < <(
            perl -MJSON -e '
                open my $fh, "<", "'"$stats_file"'" or die $!;
                local $/; my $json = <$fh>; close $fh;
                my $d = decode_json($json);
                printf "%d %d %.4f",
                    $d->{messages_sent} // 0,
                    $d->{messages_lost} // 0,
                    $d->{loss_percent} // 0;
            ' 2>/dev/null || echo "0 0 0"
        )
        log_debug "  Loadgen stats: sent=$msg_sent lost=$msg_lost loss=$loss_pct%"
    else
        log_warn "  Loadgen stats not found: $stats_file"
    fi

    # Parse latency log (tab-separated: timestamp latency_ms)
    if [[ -f "$latency_file" ]]; then
        read -r p50_lat p95_lat p99_lat < <(
            gawk '
            {
                latencies[NR] = $2
            }
            END {
                n = asort(latencies)
                if (n == 0) { printf "0 0 0"; exit }
                p50 = latencies[int(n * 0.50) + 1]
                p95 = latencies[int(n * 0.95) + 1]
                p99 = latencies[int(n * 0.99) + 1]
                printf "%.2f %.2f %.2f", p50, p95, p99
            }' "$latency_file" 2>/dev/null || echo "0 0 0"
        )
        log_debug "  Latency: p50=$p50_lat p95=$p95_lat p99=$p99_lat"
    else
        log_debug "  No latency log found (optional)"
    fi

    # Store results in associative array
    RUN_RESULTS["${run_id}_name"]="$run_name"
    RUN_RESULTS["${run_id}_cpu"]="$avg_cpu"
    RUN_RESULTS["${run_id}_rss"]="$avg_rss"
    RUN_RESULTS["${run_id}_temp"]="$avg_temp"
    RUN_RESULTS["${run_id}_http_rate"]="$http_rate"
    RUN_RESULTS["${run_id}_msg_sent"]="$msg_sent"
    RUN_RESULTS["${run_id}_msg_lost"]="$msg_lost"
    RUN_RESULTS["${run_id}_loss_pct"]="$loss_pct"
    RUN_RESULTS["${run_id}_p50"]="$p50_lat"
    RUN_RESULTS["${run_id}_p95"]="$p95_lat"
    RUN_RESULTS["${run_id}_p99"]="$p99_lat"
}

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

calc_score() {
    local baseline_cpu="$1"
    local measured_cpu="$2"
    local baseline_throughput="$3"
    local measured_throughput="$4"
    local baseline_latency="$5"
    local measured_latency="$6"
    local baseline_loss="$7"
    local measured_loss="$8"

    perl -e '
        my ($b_cpu, $m_cpu, $b_tp, $m_tp, $b_lat, $m_lat, $b_loss, $m_loss) = @ARGV;

        # Avoid division by zero
        $m_cpu    = 0.01 if $m_cpu    <= 0;
        $b_tp     = 0.01 if $b_tp     <= 0;
        $m_lat    = 0.01 if $m_lat    <= 0;

        # Clamp loss to [0, 1)
        $b_loss = $b_loss / 100 if $b_loss > 1;
        $m_loss = $m_loss / 100 if $m_loss > 1;
        $b_loss = 0.999 if $b_loss >= 1;
        $m_loss = 0.999 if $m_loss >= 1;

        my $score_cpu        = ($b_cpu / $m_cpu)         * 100 * 0.30;
        my $score_throughput = ($m_tp  / $b_tp)          * 100 * 0.30;
        my $score_latency    = ($b_lat / $m_lat)         * 100 * 0.20;
        my $score_loss       = ((1 - $m_loss) / (1 - $b_loss)) * 100 * 0.20;

        my $total = $score_cpu + $score_throughput + $score_latency + $score_loss;

        printf "%.1f", $total;
    ' "$baseline_cpu" "$measured_cpu" "$baseline_throughput" "$measured_throughput" \
      "$baseline_latency" "$measured_latency" "$baseline_loss" "$measured_loss"
}

score_to_stars() {
    local score="$1"
    perl -e '
        my $s = $ARGV[0];
        if    ($s >= 140) { print "★★★★★" }
        elsif ($s >= 125) { print "★★★★☆" }
        elsif ($s >= 115) { print "★★★☆☆" }
        elsif ($s >= 108) { print "★★☆☆☆" }
        else              { print "★☆☆☆☆" }
    ' "$score"
}

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

generate_report() {
    local report_file="${RESULTS_DIR}/${TIMESTAMP}/benchmark_report.txt"
    local csv_file="${RESULTS_DIR}/${TIMESTAMP}/summary_${TIMESTAMP}.csv"
    local git_hash
    git_hash=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

    log_info "Generating report..."

    # Collect system info
    local sysinfo
    sysinfo=$(collect_sysinfo)

    # Get baseline values (run 0 = original)
    local base_cpu="${RUN_RESULTS[0_cpu]:-0}"
    local base_tp="${RUN_RESULTS[0_http_rate]:-0}"
    local base_p95="${RUN_RESULTS[0_p95]:-0}"
    local base_loss="${RUN_RESULTS[0_loss_pct]:-0}"

    # Get optimized values (run 9 = all flags)
    local opt_cpu="${RUN_RESULTS[9_cpu]:-0}"
    local opt_tp="${RUN_RESULTS[9_http_rate]:-0}"
    local opt_p95="${RUN_RESULTS[9_p95]:-0}"
    local opt_loss="${RUN_RESULTS[9_loss_pct]:-0}"

    local overall_score
    overall_score=$(calc_score "$base_cpu" "$opt_cpu" "$base_tp" "$opt_tp" "$base_p95" "$opt_p95" "$base_loss" "$opt_loss")
    local overall_stars
    overall_stars=$(score_to_stars "$overall_score")

    {
        echo "============================================================"
        echo "  MQTT GATEWAY BENCHMARK REPORT"
        echo "  $(date '+%Y-%m-%d %H:%M:%S')  |  Git: $git_hash"
        echo "  Duration: ${DURATION}s per run"
        echo "============================================================"
        echo ""
        echo "$sysinfo"
        echo ""
        echo "┌──────────────────────────────────────────────────────────┐"
        echo "│  OVERALL COMPARISON: Original vs. All Optimizations      │"
        echo "├──────────────────────────────────────────────────────────┤"
        printf "│  %-20s %12s %12s %10s │\n" "Metric" "Original" "Optimized" "Change"
        echo "├──────────────────────────────────────────────────────────┤"

        # CPU comparison
        local cpu_change
        cpu_change=$(perl -e "printf '%.1f', (1 - $opt_cpu / ($base_cpu > 0 ? $base_cpu : 0.01)) * 100")
        printf "│  %-20s %11s%% %11s%% %9s%% │\n" "CPU Usage" "$base_cpu" "$opt_cpu" "-${cpu_change}"

        # Throughput comparison
        local tp_change
        tp_change=$(perl -e "printf '%.1f', ($opt_tp / ($base_tp > 0 ? $base_tp : 0.01) - 1) * 100")
        printf "│  %-20s %10s/s %10s/s %9s%% │\n" "HTTP Throughput" "$base_tp" "$opt_tp" "+${tp_change}"

        # Latency comparison
        local lat_change
        lat_change=$(perl -e "printf '%.1f', (1 - $opt_p95 / ($base_p95 > 0 ? $base_p95 : 0.01)) * 100")
        printf "│  %-20s %10sms %10sms %9s%% │\n" "Latency (p95)" "$base_p95" "$opt_p95" "-${lat_change}"

        # Loss comparison
        printf "│  %-20s %11s%% %11s%% %10s │\n" "Message Loss" "$base_loss" "$opt_loss" ""

        echo "├──────────────────────────────────────────────────────────┤"
        printf "│  GESAMTSCORE: %-6s  %s %27s│\n" "$overall_score" "$overall_stars" ""
        echo "└──────────────────────────────────────────────────────────┘"
        echo ""

        # Individual optimizations (runs 2-8)
        echo "┌──────────────────────────────────────────────────────────┐"
        echo "│  INDIVIDUAL OPTIMIZATIONS (sorted by impact)             │"
        echo "├──────────────────────────────────────────────────────────┤"
        printf "│  %-3s %-22s %7s %7s %7s %5s │\n" "Run" "Optimization" "CPU%" "HTTP/s" "Score" "Stars"
        echo "├──────────────────────────────────────────────────────────┤"

        # Collect scores for runs 2-8, then sort by score descending
        local scores_list=""
        for rid in 2 3 4 5 6 7 8; do
            local r_name="${RUN_RESULTS[${rid}_name]:-Run $rid}"
            local r_cpu="${RUN_RESULTS[${rid}_cpu]:-0}"
            local r_tp="${RUN_RESULTS[${rid}_http_rate]:-0}"
            local r_p95="${RUN_RESULTS[${rid}_p95]:-0}"
            local r_loss="${RUN_RESULTS[${rid}_loss_pct]:-0}"

            # Use run 1 (benchmarkable, no flags) as baseline for individual scoring
            local ind_base_cpu="${RUN_RESULTS[1_cpu]:-$base_cpu}"
            local ind_base_tp="${RUN_RESULTS[1_http_rate]:-$base_tp}"
            local ind_base_p95="${RUN_RESULTS[1_p95]:-$base_p95}"
            local ind_base_loss="${RUN_RESULTS[1_loss_pct]:-$base_loss}"

            local r_score
            r_score=$(calc_score "$ind_base_cpu" "$r_cpu" "$ind_base_tp" "$r_tp" "$ind_base_p95" "$r_p95" "$ind_base_loss" "$r_loss")

            scores_list+="${r_score}|${rid}|${r_name}|${r_cpu}|${r_tp}|${r_score}\n"
        done

        # Sort by score descending and print
        echo -e "$scores_list" | sort -t'|' -k1 -rn | while IFS='|' read -r sort_key rid r_name r_cpu r_tp r_score; do
            [[ -z "$rid" ]] && continue
            local r_stars
            r_stars=$(score_to_stars "$r_score")
            printf "│  %-3s %-22s %6s %7s %6s %s │\n" "$rid" "$r_name" "$r_cpu" "$r_tp" "$r_score" "$r_stars"
        done

        echo "└──────────────────────────────────────────────────────────┘"
        echo ""

        # Stresstest results
        if [[ ${#STRESS_RUN_IDS[@]} -gt 0 ]]; then
            echo "┌──────────────────────────────────────────────────────────┐"
            echo "│  STRESSTEST RESULTS                                      │"
            echo "├──────────────────────────────────────────────────────────┤"
            printf "│  %-3s %-22s %5s %7s %6s %6s │\n" "Run" "Name" "Rate" "CPU%" "Loss%" "HTTP/s"
            echo "├──────────────────────────────────────────────────────────┤"

            for sid in "${STRESS_RUN_IDS[@]}"; do
                local s_name="${RUN_RESULTS[${sid}_name]:-Run $sid}"
                local s_cpu="${RUN_RESULTS[${sid}_cpu]:-0}"
                local s_tp="${RUN_RESULTS[${sid}_http_rate]:-0}"
                local s_loss="${RUN_RESULTS[${sid}_loss_pct]:-0}"
                local s_rate
                s_rate=$(echo "$s_name" | grep -oP '\d+msg/s' || echo "?")
                printf "│  %-3s %-22s %5s %6s %6s %6s │\n" "$sid" "$s_name" "$s_rate" "$s_cpu" "$s_loss" "$s_tp"
            done

            echo "└──────────────────────────────────────────────────────────┘"
        fi

        echo ""
        echo "Results directory: ${RESULTS_DIR}/${TIMESTAMP}/"
        echo "============================================================"

    } | tee "$report_file"

    # Write summary CSV
    {
        echo "# MQTT Gateway Benchmark Summary"
        echo "# Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Git: $git_hash"
        echo "# Duration: ${DURATION}s per run"
        if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
            local final_temp
            final_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
            echo "# Final CPU Temp: $(perl -e "printf '%.1f', $final_temp / 1000") C"
        fi
        echo "run_id,run_name,cpu_pct,rss_kb,temp_c,http_rate,msg_sent,msg_lost,loss_pct,p50_ms,p95_ms,p99_ms"

        for rid in "${RUN_ORDER[@]}"; do
            printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
                "$rid" \
                "${RUN_RESULTS[${rid}_name]:-}" \
                "${RUN_RESULTS[${rid}_cpu]:-0}" \
                "${RUN_RESULTS[${rid}_rss]:-0}" \
                "${RUN_RESULTS[${rid}_temp]:-0}" \
                "${RUN_RESULTS[${rid}_http_rate]:-0}" \
                "${RUN_RESULTS[${rid}_msg_sent]:-0}" \
                "${RUN_RESULTS[${rid}_msg_lost]:-0}" \
                "${RUN_RESULTS[${rid}_loss_pct]:-0}" \
                "${RUN_RESULTS[${rid}_p50]:-0}" \
                "${RUN_RESULTS[${rid}_p95]:-0}" \
                "${RUN_RESULTS[${rid}_p99]:-0}"
        done
    } > "$csv_file"

    log_info "Summary CSV: $csv_file"

    # Copy results to DATA_DIR for persistence
    mkdir -p "$DATA_DIR"
    cp -r "${RESULTS_DIR}/${TIMESTAMP}" "$DATA_DIR/" 2>/dev/null || true
    log_info "Results copied to $DATA_DIR/${TIMESTAMP}/"
}

# ---------------------------------------------------------------------------
# Cleanup on exit
# ---------------------------------------------------------------------------

cleanup() {
    log_info "Cleaning up..."
    # Kill background processes if still running
    [[ -n "$COLLECTOR_PID" ]] && kill "$COLLECTOR_PID" 2>/dev/null || true
    [[ -n "$LOADGEN_PID" ]] && kill "$LOADGEN_PID" 2>/dev/null || true
    stop_gateway
    log_info "Cleanup complete."
}

trap cleanup EXIT

# ===========================================================================
# MAIN EXECUTION
# ===========================================================================

log_info "MQTT Gateway Benchmark Orchestrator"
log_info "Duration: ${DURATION}s per run | Loglevel: $LOGLEVEL"

# Verify prerequisites
if [[ ! -f "$BENCH_GW" ]]; then
    log_error "Benchmarkable gateway not found: $BENCH_GW"
    exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/mqtt-metric-collector.pl" ]]; then
    log_error "Metric collector not found: ${SCRIPT_DIR}/mqtt-metric-collector.pl"
    exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/mqtt-loadgen.pl" ]]; then
    log_error "Load generator not found: ${SCRIPT_DIR}/mqtt-loadgen.pl"
    exit 1
fi

# Create output directories
mkdir -p "${RESULTS_DIR}/${TIMESTAMP}"
mkdir -p "$DATA_DIR"

# ---------------------------------------------------------------------------
# Define the test matrix
# ---------------------------------------------------------------------------

# Estimated time per run: duration + 30s overhead (cooldown + startup + collection)
EST_PER_RUN=$((DURATION + 30))

# Stress test rates
STRESS_RATES=(50 100 200 500)

# Total runs: 0 + 1 + 7 individual + 1 all-opt + stress pairs
TOTAL_REALISTIC_RUNS=10  # runs 0-9
TOTAL_STRESS_PAIRS=$(( ${#STRESS_RATES[@]} * 2 ))
TOTAL_RUNS=$(( TOTAL_REALISTIC_RUNS + TOTAL_STRESS_PAIRS ))
EST_TOTAL_TIME=$(( TOTAL_RUNS * EST_PER_RUN / 60 ))

log_info "Test matrix: $TOTAL_RUNS runs, estimated ${EST_TOTAL_TIME} minutes"

# ---------------------------------------------------------------------------
# Dry-run mode: print matrix and exit
# ---------------------------------------------------------------------------

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    echo "=== DRY-RUN: Test Matrix ==="
    echo ""
    printf "  %-5s %-30s %-15s %-12s %s\n" "Run" "Name" "Gateway" "Mode" "Flags"
    echo "  -----------------------------------------------------------------------"
    printf "  %-5s %-30s %-15s %-12s %s\n" "0"  "Original Gateway"       "original"     "realistic"  "(none)"
    printf "  %-5s %-30s %-15s %-12s %s\n" "1"  "Benchmarkable (no flags)" "benchmarkable" "realistic" "(none)"
    for i in "${!FLAG_NAMES[@]}"; do
        local rid=$((i + 2))
        printf "  %-5s %-30s %-15s %-12s %s\n" "$rid" "${FLAG_NAMES[$i]}" "benchmarkable" "realistic" "${FLAG_VALUES[$i]}"
    done
    printf "  %-5s %-30s %-15s %-12s %s\n" "9"  "All Optimizations"      "benchmarkable" "realistic" "ALL_FLAGS"
    echo ""

    local stress_id=10
    for rate in "${STRESS_RATES[@]}"; do
        printf "  %-5s %-30s %-15s %-12s %s\n" "$stress_id" "Stress ${rate}msg/s (orig)" "original" "stress @${rate}" "(none)"
        printf "  %-5s %-30s %-15s %-12s %s\n" "$((stress_id + 1))" "Stress ${rate}msg/s (opt)" "benchmarkable" "stress @${rate}" "ALL_FLAGS"
        stress_id=$((stress_id + 2))
    done

    echo ""
    echo "  Total runs: $TOTAL_RUNS"
    echo "  Estimated time: ~${EST_TOTAL_TIME} minutes"
    echo ""
    echo "  (Use without --dry-run to execute)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Pre-flight: loadgen selftest
# ---------------------------------------------------------------------------

log_info "Running loadgen selftest to determine max sustainable rate..."

SELFTEST_DIR="${RESULTS_DIR}/${TIMESTAMP}/selftest"
mkdir -p "$SELFTEST_DIR"

# Need a running gateway for selftest
if [[ -f "$ORIGINAL_GW" ]]; then
    start_gateway "$ORIGINAL_GW" || true
else
    start_gateway "$BENCH_GW" || true
fi

perl "${SCRIPT_DIR}/mqtt-loadgen.pl" \
    --mode selftest \
    --output "$SELFTEST_DIR" \
    --loglevel "$LOGLEVEL" || true

stop_gateway

MAX_RATE=0
if [[ -f "${SELFTEST_DIR}/max_rate.txt" ]]; then
    MAX_RATE=$(cat "${SELFTEST_DIR}/max_rate.txt" | tr -d '[:space:]')
    log_info "Loadgen max sustainable rate: ${MAX_RATE} msg/s"
else
    log_warn "Selftest did not produce max_rate.txt, stress tests may fail"
    MAX_RATE=9999
fi

# ---------------------------------------------------------------------------
# Execute test matrix
# ---------------------------------------------------------------------------

# Run 0: Original gateway, realistic load
run_benchmark 0 "Original Gateway" "$ORIGINAL_GW" "realistic" "0"

# Run 1: Benchmarkable gateway, all flags OFF, realistic load
run_benchmark 1 "Benchmarkable (no flags)" "$BENCH_GW" "realistic" "0"

# Runs 2-8: Benchmarkable, one flag at a time
for i in "${!FLAG_NAMES[@]}"; do
    rid=$((i + 2))
    run_benchmark "$rid" "${FLAG_NAMES[$i]}" "$BENCH_GW" "realistic" "0" "${FLAG_VALUES[$i]}"
done

# Run 9: Benchmarkable, all flags ON, realistic load
run_benchmark 9 "All Optimizations" "$BENCH_GW" "realistic" "0" $ALL_FLAGS

# Stress tests: pairs of (original, optimized) at increasing rates
stress_id=10
for rate in "${STRESS_RATES[@]}"; do
    # Skip rates beyond loadgen capability
    if [[ $(perl -e "print $rate > $MAX_RATE ? 1 : 0") -eq 1 ]]; then
        log_warn "Skipping stress rate ${rate} msg/s (exceeds max loadgen rate ${MAX_RATE})"
        continue
    fi

    # Original at stress rate
    run_benchmark "$stress_id" "Stress ${rate}msg/s (original)" "$ORIGINAL_GW" "stress" "$rate"
    STRESS_RUN_IDS+=("$stress_id")

    # Optimized at stress rate
    run_benchmark "$((stress_id + 1))" "Stress ${rate}msg/s (optimized)" "$BENCH_GW" "stress" "$rate" $ALL_FLAGS
    STRESS_RUN_IDS+=("$((stress_id + 1))")

    stress_id=$((stress_id + 2))
done

# ---------------------------------------------------------------------------
# Generate report
# ---------------------------------------------------------------------------

generate_report

log_info "Benchmark complete. Results: ${RESULTS_DIR}/${TIMESTAMP}/"
