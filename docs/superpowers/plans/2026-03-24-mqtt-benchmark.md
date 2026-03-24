# MQTT Gateway Benchmark Tool — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a benchmark tool that measures the performance impact of 7 individual optimizations in mqttgateway.pl, producing reproducible scores and reports for the developer interview on 2026-04-08.

**Architecture:** Hybrid approach — Bash shell orchestrates test runs (start/stop gateway, set flags, collect results), Perl scripts handle MQTT load generation and metric collection. A benchmarkable variant of the optimized gateway adds environment-variable guards around each fix for isolated measurement.

**Tech Stack:** Perl 5 (Net::MQTT::Simple, LoxBerry::Log, LoxBerry::IO, LoxBerry::System, LWP::UserAgent, File::Copy), Bash, /proc filesystem, /dev/shm shared memory

**Spec:** `docs/superpowers/specs/2026-03-24-mqtt-benchmark-design.md`

**LoxBerry Dev KB:** `D:\Claude_Projekte\LoxberryPlugin_Entwicklung` (logging, MQTT, data-storage, API patterns)

---

## File Map

| File | Responsibility |
|------|----------------|
| `sbin/benchmark/mqttgateway_benchmarkable.pl` | Copy of `vorarbeit/mqttgateway_optimized.pl` with `$ENV{BENCH_*}` guards around each of 7 fixes + HTTP counter + latency logging instrumentation |
| `sbin/benchmark/mqtt-loadgen.pl` | MQTT load generator: realistic + stress modes, timestamps in payload, self-test |
| `sbin/benchmark/mqtt-metric-collector.pl` | Lightweight Perl poller: reads `/proc/[pid]/stat` every 500ms, writes CSV samples |
| `sbin/benchmark/mqtt-benchmark.sh` | Orchestrator: runs test matrix, manages gateway lifecycle, generates report + scoring |

---

## Task 1: Create benchmarkable gateway with feature flags

The largest single task. Copy `vorarbeit/mqttgateway_optimized.pl` → `sbin/benchmark/mqttgateway_benchmarkable.pl` and wrap each of the 7 fixes in `$ENV{BENCH_*}` guards so they can be individually toggled.

**Files:**
- Source: `vorarbeit/mqttgateway_optimized.pl`
- Create: `sbin/benchmark/mqttgateway_benchmarkable.pl`

**Reference lines in optimized file (all 7 fix locations):**
- FIX 1 (Early Filter): lines 577-611 in `received()` — early DoNotForward + regex before JSON expansion
- FIX 2 (Connection Pool): lines 161-173 (`init_http_ua`), 181-294 (fast HTTP functions), 862/864/870 (call sites in `received()`)
- FIX 3 (MS Cache): lines 175-178 (`refresh_ms_cache`), 346-347 (init), 1010-1012 (reload)
- FIX 4 (Precompiled Regex): lines 100-106 (vars), 712-715 + 767-775 (usage), 1089-1106 + 1158-1175 (compilation)
- FIX 5 (Own Topic Filter): lines 138-139 (var), 577-587 (check), 952-954 (regex compile)
- FIX 6 (Flatten Singleton): lines 150-159 (instantiation), 638-639 (usage)
- FIX 7 (JSON::XS): lines 48-59 (BEGIN block)

- [ ] **Step 1: Create benchmark directory and copy optimized gateway**

```bash
mkdir -p sbin/benchmark
cp vorarbeit/mqttgateway_optimized.pl sbin/benchmark/mqttgateway_benchmarkable.pl
```

- [ ] **Step 2: Add FIX 7 guard (JSON::XS) — lines 48-59**

The BEGIN block always loads JSON::XS. Add a guard so that when `BENCH_JSON_XS` is off, it forces JSON::PP:

```perl
# Around line 48-59 in the BEGIN block:
BEGIN {
    if ($ENV{BENCH_JSON_XS}) {
        eval { require JSON::XS; JSON::XS->import(); $JSON_MODULE = 'JSON::XS'; 1; }
            or do { require JSON; JSON->import(); $JSON_MODULE = 'JSON'; };
    } else {
        require JSON; JSON->import(); $JSON_MODULE = 'JSON';
    }
}
```

- [ ] **Step 3: Add FIX 6 guard (Flatten Singleton) — lines 150-159, 638-639**

Keep the singleton `$flatterer` instantiated at line 150-159, but at the flatten call site (line 639), use a new instance when flag is off (original behavior: new per call):

```perl
# Replace line 639:
#   my $flat_hash = $flatterer->flatten($contjson);
# With:
my $flat_hash;
if ($ENV{BENCH_FLATTEN_SINGLETON}) {
    $flat_hash = $flatterer->flatten($contjson);  # reuse singleton (FIX 6)
} else {
    my $f = Hash::Flatten->new({OnRefScalar => 'warn'});
    $flat_hash = $f->flatten($contjson);  # new per call (original behavior)
}
```

- [ ] **Step 4: Add FIX 5 guard (Own Topic Filter) — lines 577-587**

In `received()`, wrap the existing gateway-topic early exit block (lines 581-587). When flag is off, these topics pass through to the full pipeline (original behavior — causes 404 cascades at Miniserver):

```perl
# Replace lines 581-587:
#   if (defined $gw_topic_regex and $topic =~ $gw_topic_regex) {
#       LOGDEB "MQTT IN (gw-filtered): $topic: $message";
#       my $topic_underlined = $topic;
#       $topic_underlined =~ s/[\/%]/_/g;
#       _track_overview($topic, $topic_underlined, $message);
#       return;
#   }
# With:
if ($ENV{BENCH_OWN_TOPIC_FILTER}) {
    if (defined $gw_topic_regex and $topic =~ $gw_topic_regex) {
        LOGDEB "MQTT IN (gw-filtered): $topic: $message";
        my $topic_underlined = $topic;
        $topic_underlined =~ s/[\/%]/_/g;
        _track_overview($topic, $topic_underlined, $message);
        return;
    }
}
```

- [ ] **Step 5: Add FIX 1 guard (Early Filter) — lines 589-611**

Wrap the early DoNotForward + regex filter block. When flag is off, skip straight to JSON expansion (original behavior — filtering happens only after expansion):

```perl
# Replace lines 589-611 with a guard. The actual source code does:
#   - Line 593: $raw_topic_underlined = $topic; s/[\/%]/_/g;
#   - Line 598: check $cfg->{doNotForward}->{$raw_topic_underlined}
#   - Line 605: foreach @subscriptionfilters_compiled (bare qr// objects)
#
# Wrap it:
if ($ENV{BENCH_EARLY_FILTER}) {
    # FIX 1: Check DoNotForward on raw topic BEFORE JSON expansion
    my $raw_topic_underlined = $topic;
    $raw_topic_underlined =~ s/[\/%]/_/g;

    if (exists $cfg->{doNotForward}->{$raw_topic_underlined}) {
        LOGDEB "MQTT IN (dnf-filtered): $topic: $message";
        _track_overview($topic, $raw_topic_underlined, $message);
        return;
    }

    # FIX 1: Regex filter on raw topic
    foreach my $filter_re (@subscriptionfilters_compiled) {
        if ($raw_topic_underlined =~ $filter_re) {
            LOGDEB "MQTT IN (regex-filtered): $topic: $message";
            _track_overview($topic, $raw_topic_underlined, $message);
            return;
        }
    }
}
# JSON expansion follows (always runs if not early-filtered)
```

- [ ] **Step 6: Add FIX 4 guard (Precompiled Regex) — lines 712-715, 767-775**

Two sites need guards. Both `@subscriptionfilters_compiled` and `@subscriptions_compiled` contain bare `qr//` objects. When flag is off, fall back to runtime compilation from the string arrays `@subscriptionfilters` and `@subscriptions`:

```perl
# Around line 712-734 (filter matching in the per-topic loop):
# Replace:
#   foreach my $filter_re (@subscriptionfilters_compiled) {
#       if( $sendtopic_underlined =~ $filter_re ) {
# With:
if ($ENV{BENCH_PRECOMPILED_REGEX}) {
    foreach my $filter_re (@subscriptionfilters_compiled) {
        $regexcounter++;
        if( $sendtopic_underlined =~ $filter_re ) {
            # ... existing match handling (lines 716-733) ...
            $regexmatch = 1;
            last;
        }
    }
} else {
    # Original: compile regex at runtime from string
    foreach my $filter_str (@subscriptionfilters) {
        $regexcounter++;
        my $match = eval { $sendtopic_underlined =~ /$filter_str/ };
        if( $match ) {
            # ... same match handling ...
            $regexmatch = 1;
            last;
        }
    }
}

# Around line 767-775 (subscription matching for toMS):
# Replace:
#   foreach my $sub_re (@subscriptions_compiled) {
#       if( $topic =~ $sub_re ) {
# With:
if ($ENV{BENCH_PRECOMPILED_REGEX}) {
    foreach my $sub_re (@subscriptions_compiled) {
        if( $topic =~ $sub_re ) {
            @toMS = @{$subscriptions_toms[$idx]};
            last;
        }
        $idx++;
    }
} else {
    # Original: compile subscription regex at runtime
    foreach my $sub_str (@subscriptions) {
        my $regex = $sub_str;
        $regex =~ s/\+/[^\/]+/g;
        $regex =~ s/\\//g;
        if( $regex eq '#' ) { $regex = ".+"; }
        elsif ( substr($regex, -1) eq '#' ) { $regex = substr($regex, 0, -2) . '.*'; }
        if( $topic =~ /$regex/ ) {
            @toMS = @{$subscriptions_toms[$idx]};
            last;
        }
        $idx++;
    }
}
```

- [ ] **Step 7: Add FIX 3 guard (MS Cache) — lines 175-178, call sites**

When flag is off, call `get_miniservers()` fresh each time (original behavior):

```perl
# In the HTTP send functions (lines 181-294):
sub get_ms_config {
    my ($msnr) = @_;
    if ($ENV{BENCH_MS_CACHE}) {
        return $ms_cache{$msnr};  # cached at reload
    } else {
        my %ms = LoxBerry::System::get_miniservers();
        return $ms{$msnr};  # fresh every call
    }
}
```

- [ ] **Step 8: Add FIX 2 guard (Connection Pool) — lines 862, 864, 870**

At the 3 HTTP call sites in `received()`, switch between the fast pooled functions (defined in the optimized file at lines 211-294) and the original `LoxBerry::MQTTGateway::IO` module calls (verified from original gateway at lines 710/712/718):

```perl
# Line 862 — noncached send:
if ($ENV{BENCH_CONNECTION_POOL}) {
    $httpresp = mshttp_send_fast($_,  %sendhash_noncached);
} else {
    $httpresp = LoxBerry::MQTTGateway::IO::mshttp_send2($_,  %sendhash_noncached);
}

# Line 864 — cached send:
if ($ENV{BENCH_CONNECTION_POOL}) {
    $httpresp = mshttp_send_mem_fast($_,  %sendhash_cached);
} else {
    $httpresp = LoxBerry::MQTTGateway::IO::mshttp_send_mem2($_,  %sendhash_cached);
}

# Line 870 — reset-after-send:
if ($ENV{BENCH_CONNECTION_POOL}) {
    $httpresp = mshttp_send_fast($_, %sendhash_resetaftersend);
} else {
    $httpresp = LoxBerry::MQTTGateway::IO::mshttp_send2($_, %sendhash_resetaftersend);
}
```

- [ ] **Step 9: Add benchmark instrumentation — HTTP counter + latency log**

Add atomic counter for HTTP calls and latency logging:

```perl
# Near top of file, after use statements:
my $bench_http_counter_file = '/dev/shm/bench_http_counter';
my $bench_latency_log = '/dev/shm/bench_latency.log';

# In the HTTP send path (inside mshttp_send_fast and mshttp_send_mem_fast):
sub bench_count_http {
    # Atomic counter: read current value, increment, write back
    use Fcntl qw(:flock);
    if (sysopen(my $fh, $bench_http_counter_file, O_RDWR|O_CREAT)) {
        flock($fh, LOCK_EX);
        my $count = <$fh> || 0;
        chomp $count;
        seek($fh, 0, 0);
        truncate($fh, 0);
        print $fh ($count + 1);
        close $fh;
    }
}

# In received(), after HTTP send, log latency if _bench_ts present:
sub bench_log_latency {
    my ($payload_ref) = @_;
    if (exists $payload_ref->{'_bench_ts'}) {
        my $now = Time::HiRes::time();
        if (open(my $fh, '>>', $bench_latency_log)) {
            print $fh "$payload_ref->{'_bench_ts'},$now\n";
            close $fh;
        }
    }
}
```

- [ ] **Step 10: Verify the file is syntactically valid**

```bash
cd sbin/benchmark
perl -c mqttgateway_benchmarkable.pl 2>&1 | head -5
# Expected: "mqttgateway_benchmarkable.pl syntax OK" or known missing module warnings
# (LoxBerry modules won't be available on dev machine, but syntax should be clean)
```

- [ ] **Step 11: Commit**

```bash
git add sbin/benchmark/mqttgateway_benchmarkable.pl
git commit -m "feat(benchmark): create benchmarkable gateway with 7 feature flags

Copied from mqttgateway_optimized.pl with ENV guards around each fix:
BENCH_EARLY_FILTER, BENCH_CONNECTION_POOL, BENCH_MS_CACHE,
BENCH_PRECOMPILED_REGEX, BENCH_OWN_TOPIC_FILTER, BENCH_FLATTEN_SINGLETON,
BENCH_JSON_XS. Added HTTP counter and latency logging instrumentation."
```

---

## Task 2: Create the metric collector

Lightweight Perl process that reads `/proc/[pid]/stat` every 500ms and writes CSV samples. Runs alongside the gateway during each benchmark run.

**Files:**
- Create: `sbin/benchmark/mqtt-metric-collector.pl`

**Reference:** LoxBerry logging patterns from `D:\Claude_Projekte\LoxberryPlugin_Entwicklung\docs\patterns\logging.md`

- [ ] **Step 1: Create mqtt-metric-collector.pl with argument parsing**

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(time sleep);
use File::Copy qw(move);
use POSIX qw(strftime);

# LoxBerry modules (available on target system)
use LoxBerry::Log;

my $pid;
my $output_dir;
my $interval = 0.5;  # 500ms
my $duration = 60;
my $loglevel = 6;

GetOptions(
    'pid=i'        => \$pid,
    'output=s'     => \$output_dir,
    'interval=f'   => \$interval,
    'duration=i'   => \$duration,
    'loglevel=i'   => \$loglevel,
) or die "Usage: $0 --pid PID --output DIR [--interval 0.5] [--duration 60]\n";

die "Missing --pid\n" unless $pid;
die "Missing --output\n" unless $output_dir;
die "Process $pid not found\n" unless -d "/proc/$pid";
```

- [ ] **Step 2: Add /proc/[pid]/stat reader**

```perl
sub read_proc_stat {
    my ($target_pid) = @_;
    open(my $fh, '<', "/proc/$target_pid/stat") or return undef;
    my $line = <$fh>;
    close $fh;

    # Fields: pid (comm) state utime stime ... rss ...
    # See man proc(5) — fields 14=utime, 15=stime, 24=rss
    my @fields = split(/\s+/, $line);
    # Handle comm field which may contain spaces/parens
    my $comm_end = rindex($line, ')');
    my $after_comm = substr($line, $comm_end + 2);
    @fields = split(/\s+/, $after_comm);

    return {
        utime  => $fields[11],   # field 14 (0-indexed after comm: 11)
        stime  => $fields[12],   # field 15
        rss    => $fields[21] * 4096,  # field 24, in pages → bytes
    };
}

sub read_cpu_temp {
    open(my $fh, '<', '/sys/class/thermal/thermal_zone0/temp') or return 0;
    my $temp = <$fh>;
    close $fh;
    chomp $temp;
    return $temp / 1000.0;  # millidegrees → degrees
}

sub read_http_counter {
    my $file = '/dev/shm/bench_http_counter';
    return 0 unless -f $file;
    open(my $fh, '<', $file) or return 0;
    my $count = <$fh> || 0;
    close $fh;
    chomp $count;
    return int($count);
}
```

- [ ] **Step 3: Add main sampling loop with CSV output**

```perl
# Initialize logging
my $log = LoxBerry::Log->new(
    name     => 'MQTT Benchmark Metrics',
    filename => "$output_dir/metric-collector.log",
    append   => 1,
    loglevel => $loglevel,
);
LOGSTART "Metric collector for PID $pid";

# CSV header
my $csv_file = "$output_dir/samples_$pid.csv";
my $csv_tmp  = "$csv_file.tmp";
open(my $csv, '>', $csv_tmp) or die "Cannot write $csv_tmp: $!\n";
print $csv "timestamp,elapsed_s,cpu_pct,rss_mb,cpu_temp_c,http_calls\n";

my $clk_tck = `getconf CLK_TCK`; chomp $clk_tck; $clk_tck ||= 100;
my $start_time = time();
my $prev_stat = read_proc_stat($pid);
my $prev_time = $start_time;

LOGINF "Sampling every ${interval}s for ${duration}s";

while ((time() - $start_time) < $duration) {
    sleep($interval);

    my $now = time();
    my $stat = read_proc_stat($pid);
    last unless $stat;  # process died

    # CPU% = delta(utime+stime) / delta(wall) / CLK_TCK * 100
    my $cpu_delta = ($stat->{utime} + $stat->{stime})
                  - ($prev_stat->{utime} + $prev_stat->{stime});
    my $wall_delta = $now - $prev_time;
    my $cpu_pct = ($cpu_delta / $clk_tck) / $wall_delta * 100;

    my $rss_mb = $stat->{rss} / (1024 * 1024);
    my $temp = read_cpu_temp();
    my $http = read_http_counter();
    my $elapsed = $now - $start_time;

    printf $csv "%.3f,%.1f,%.1f,%.1f,%.1f,%d\n",
        $now, $elapsed, $cpu_pct, $rss_mb, $temp, $http;

    $prev_stat = $stat;
    $prev_time = $now;
}

close $csv;
move($csv_tmp, $csv_file);

LOGOK "Collected " . int(($duration / $interval)) . " samples to $csv_file";
LOGEND;
```

- [ ] **Step 4: Commit**

```bash
git add sbin/benchmark/mqtt-metric-collector.pl
git commit -m "feat(benchmark): add metric collector for CPU/RAM/temp sampling

Perl-based lightweight poller that reads /proc/[pid]/stat every 500ms.
Outputs CSV with cpu_pct, rss_mb, cpu_temp, http_calls. Uses LoxBerry::Log
and atomic writes."
```

---

## Task 3: Create the MQTT load generator

Perl script that publishes MQTT messages in realistic and stress-test modes. Includes self-test capability and timestamp injection for latency measurement.

**Files:**
- Create: `sbin/benchmark/mqtt-loadgen.pl`

**Reference:** MQTT patterns from `D:\Claude_Projekte\LoxberryPlugin_Entwicklung\docs\patterns\mqtt.md`, existing test `libs/perllib/LoxBerry/testing/mqtt_rapidpublish.pl`

- [ ] **Step 1: Create mqtt-loadgen.pl with argument parsing and MQTT connection**

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(time sleep gettimeofday);
use JSON;
use File::Copy qw(move);

use LoxBerry::Log;
use LoxBerry::IO;

my $mode = 'realistic';  # realistic | stress | selftest
my $rate = 0;             # msg/s (0 = auto for realistic)
my $topics = 7;
my $duration = 60;
my $output_dir;
my $loglevel = 6;

GetOptions(
    'mode=s'     => \$mode,
    'rate=i'     => \$rate,
    'topics=i'   => \$topics,
    'duration=i' => \$duration,
    'output=s'   => \$output_dir,
    'loglevel=i' => \$loglevel,
) or die "Usage: $0 --mode realistic|stress|selftest --output DIR [--rate N] [--duration 60]\n";

die "Missing --output\n" unless $output_dir;

my $log = LoxBerry::Log->new(
    name     => 'MQTT Benchmark Loadgen',
    filename => "$output_dir/loadgen.log",
    append   => 1,
    loglevel => $loglevel,
);
LOGSTART "Loadgen mode=$mode rate=$rate duration=$duration";

# Connect to MQTT broker using LoxBerry API
my $creds = LoxBerry::IO::mqtt_connectiondetails();
my $broker = "$creds->{brokerhost}:$creds->{brokerport}";
LOGINF "Connecting to broker $broker";

use Net::MQTT::Simple;
my $mqtt;
if ($creds->{brokeruser}) {
    $ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
    $mqtt = Net::MQTT::Simple->new($broker);
    $mqtt->login($creds->{brokeruser}, $creds->{brokerpass});
} else {
    $mqtt = Net::MQTT::Simple->new($broker);
}
```

- [ ] **Step 2: Add realistic payload definitions**

```perl
# Realistic device profiles matching actual LoxBerry installation
my @realistic_profiles = (
    {
        name     => 'tasmota1',
        topic    => 'benchmark/loadgen/tasmota/sensor1/SENSOR',
        interval => 0.5,  # 2 msg/s
        payload  => sub {
            my $ts = time();
            return encode_json({
                _bench_ts   => $ts,
                Time        => scalar localtime($ts),
                ENERGY      => {
                    TotalStartTime => "2024-01-01T00:00:00",
                    Total    => 1234.567 + rand(0.1),
                    Power    => int(50 + rand(200)),
                    Voltage  => 230 + rand(5),
                    Current  => 0.2 + rand(1),
                },
            });
        },
    },
    {
        name     => 'tasmota2',
        topic    => 'benchmark/loadgen/tasmota/sensor2/SENSOR',
        interval => 0.5,
        payload  => sub {
            return encode_json({
                _bench_ts   => time(),
                DS18B20     => { Temperature => 20 + rand(5) },
                TempUnit    => "C",
            });
        },
    },
    {
        name     => 'tasmota3',
        topic    => 'benchmark/loadgen/tasmota/sensor3/SENSOR',
        interval => 0.5,
        payload  => sub {
            return encode_json({
                _bench_ts    => time(),
                BME280       => {
                    Temperature => 21 + rand(3),
                    Humidity    => 40 + rand(20),
                    Pressure    => 1013 + rand(10),
                },
            });
        },
    },
    {
        name     => 'zigbee2mqtt',
        topic    => 'benchmark/loadgen/zigbee2mqtt/lamp1',
        interval => 2.0,  # 0.5 msg/s, periodic
        payload  => sub {
            return encode_json({
                _bench_ts   => time(),
                state       => (rand() > 0.5 ? "ON" : "OFF"),
                brightness  => int(rand(255)),
                color_temp  => int(150 + rand(350)),
            });
        },
    },
    {
        name     => 'venus1',
        topic    => 'benchmark/loadgen/venus/battery/Soc',
        interval => 1.0,  # 1 msg/s
        payload  => sub {
            return encode_json({
                _bench_ts => time(),
                value     => 50 + rand(50),
            });
        },
    },
    {
        name     => 'venus2',
        topic    => 'benchmark/loadgen/venus/system/Ac/ConsumptionOnInput/L1/Power',
        interval => 1.0,
        payload  => sub {
            return encode_json({
                _bench_ts => time(),
                value     => 200 + rand(2000),
            });
        },
    },
    {
        name     => 'shelly1',
        topic    => 'benchmark/loadgen/shelly/relay1/status',
        interval => 5.0,  # 0.2 msg/s
        payload  => sub {
            return encode_json({
                _bench_ts  => time(),
                ison       => (rand() > 0.5 ? JSON::true : JSON::false),
                has_timer  => JSON::false,
                power      => 0 + rand(100),
                energy     => int(rand(10000)),
            });
        },
    },
);
```

- [ ] **Step 3: Add realistic mode publish loop**

```perl
sub run_realistic {
    LOGINF "Starting realistic mode: " . scalar(@realistic_profiles) . " clients, ~15-20 msg/s";

    my $start = time();
    my $msg_count = 0;
    my %next_send;

    # Initialize next send time for each profile
    for my $p (@realistic_profiles) {
        $next_send{$p->{name}} = $start + rand($p->{interval});
    }

    while ((time() - $start) < $duration) {
        my $now = time();
        my $did_work = 0;

        for my $p (@realistic_profiles) {
            if ($now >= $next_send{$p->{name}}) {
                my $payload = $p->{payload}->();
                $mqtt->publish($p->{topic}, $payload);
                $msg_count++;
                $next_send{$p->{name}} = $now + $p->{interval};
                $did_work = 1;
            }
        }

        # Brief sleep if nothing to do, avoid busy-wait
        sleep(0.01) unless $did_work;
    }

    return $msg_count;
}
```

- [ ] **Step 4: Add stress mode publish loop**

```perl
sub run_stress {
    my ($target_rate) = @_;
    LOGINF "Starting stress mode: $target_rate msg/s, $topics topics";

    my $start = time();
    my $msg_count = 0;
    my $interval = 1.0 / $target_rate;

    # Generate topic list
    my @stress_topics;
    for my $i (1..$topics) {
        push @stress_topics, "benchmark/loadgen/stress/device$i/SENSOR";
    }

    my $next_send = $start;

    while ((time() - $start) < $duration) {
        my $now = time();
        if ($now >= $next_send) {
            my $topic = $stress_topics[$msg_count % scalar(@stress_topics)];
            my $payload = encode_json({
                _bench_ts   => $now,
                temperature => 20 + rand(10),
                humidity    => 40 + rand(30),
                counter     => $msg_count,
            });
            $mqtt->publish($topic, $payload);
            $msg_count++;
            $next_send += $interval;

            # If we've fallen behind, reset to avoid burst
            if (time() > $next_send + 1.0) {
                LOGWARN "Loadgen falling behind at $target_rate msg/s after $msg_count messages";
                $next_send = time();
            }
        } else {
            # Busy-wait with micro-sleep for sub-ms accuracy
            select(undef, undef, undef, 0.0005);
        }
    }

    return $msg_count;
}
```

- [ ] **Step 5: Add self-test mode**

```perl
sub run_selftest {
    LOGINF "Running loadgen self-test (max sustainable rate without gateway)";

    my @test_rates = (10, 50, 100, 200, 500, 1000);
    my %results;

    for my $target (@test_rates) {
        my $test_duration = 5;  # short bursts
        my $start = time();
        my $count = 0;
        my $interval = 1.0 / $target;
        my $next = $start;

        while ((time() - $start) < $test_duration) {
            my $now = time();
            if ($now >= $next) {
                $mqtt->publish(
                    "benchmark/loadgen/selftest/probe",
                    encode_json({ _bench_ts => $now, n => $count })
                );
                $count++;
                $next += $interval;
                if ($now > $next + 0.5) {
                    last;  # can't keep up
                }
            } else {
                select(undef, undef, undef, 0.0005);
            }
        }

        my $actual_rate = $count / (time() - $start);
        my $achieved_pct = ($actual_rate / $target) * 100;
        $results{$target} = { actual => $actual_rate, pct => $achieved_pct };
        LOGINF sprintf("Target %d msg/s → actual %.0f msg/s (%.0f%%)", $target, $actual_rate, $achieved_pct);

        last if $achieved_pct < 90;  # stop when we can't keep up
    }

    # Write results
    my $result_file = "$output_dir/selftest.json";
    open(my $fh, '>', "$result_file.tmp") or die "Cannot write selftest: $!\n";
    print $fh encode_json(\%results);
    close $fh;
    move("$result_file.tmp", $result_file);

    # Find max sustainable rate
    my $max_rate = 0;
    for my $r (sort { $a <=> $b } keys %results) {
        $max_rate = $r if $results{$r}{pct} >= 90;
    }
    LOGOK "Max sustainable loadgen rate: $max_rate msg/s";
    return $max_rate;
}
```

- [ ] **Step 6: Add main dispatch and stats output**

```perl
# Main dispatch
my $msg_count = 0;
if ($mode eq 'selftest') {
    my $max = run_selftest();
    # Write max rate for orchestrator
    open(my $fh, '>', "$output_dir/max_rate.txt") or die;
    print $fh "$max\n";
    close $fh;
} elsif ($mode eq 'realistic') {
    $msg_count = run_realistic();
} elsif ($mode eq 'stress') {
    die "Missing --rate for stress mode\n" unless $rate > 0;
    $msg_count = run_stress($rate);
} else {
    die "Unknown mode: $mode\n";
}

# Write stats
if ($msg_count > 0) {
    my $stats_file = "$output_dir/loadgen_stats.json";
    my $actual_rate = $msg_count / $duration;
    open(my $fh, '>', "$stats_file.tmp") or die;
    print $fh encode_json({
        mode       => $mode,
        duration   => $duration,
        msg_count  => $msg_count,
        actual_rate => sprintf("%.1f", $actual_rate),
    });
    close $fh;
    move("$stats_file.tmp", $stats_file);
    LOGOK "Sent $msg_count messages in ${duration}s (${\ sprintf('%.1f', $actual_rate)} msg/s)";
}

LOGEND;
```

- [ ] **Step 7: Commit**

```bash
git add sbin/benchmark/mqtt-loadgen.pl
git commit -m "feat(benchmark): add MQTT load generator with realistic + stress modes

Supports 7 simulated device profiles (Tasmota, Zigbee2MQTT, Venus, Shelly),
configurable stress rates, self-test for max throughput detection. Uses
LoxBerry::IO for broker credentials, injects _bench_ts for latency measurement."
```

---

## Task 4: Create the benchmark orchestrator

Bash script that manages the full test matrix: gateway lifecycle, feature flags, metric collection, report generation, and scoring.

**Files:**
- Create: `sbin/benchmark/mqtt-benchmark.sh`

- [ ] **Step 1: Create mqtt-benchmark.sh with argument parsing and system info collection**

```bash
#!/bin/bash
# MQTT Gateway Benchmark Orchestrator
# Usage: mqtt-benchmark.sh [--dry-run] [--duration 60] [--loglevel 6]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LBHOMEDIR="${LBHOMEDIR:-/opt/loxberry}"
BENCHMARK_DIR="${LBHOMEDIR}/log/plugins/benchmark"
RESULTS_DIR="${BENCHMARK_DIR}/results"
DATA_DIR="${LBHOMEDIR}/data/plugins/benchmark/results"
TIMESTAMP=$(date +%Y%m%d_%H%M)
DURATION=60
DRY_RUN=0
LOGLEVEL=6

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)   DRY_RUN=1; shift ;;
        --duration)  DURATION="$2"; shift 2 ;;
        --loglevel)  LOGLEVEL="$2"; shift 2 ;;
        *)           echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Ensure directories exist
mkdir -p "$RESULTS_DIR" "$BENCHMARK_DIR/metrics" "$DATA_DIR"

# System info collection
collect_sysinfo() {
    echo "══════════════════════════════════════════════════════════════"
    echo "  SYSTEMKONFIGURATION"
    echo "══════════════════════════════════════════════════════════════"

    # Hardware
    local model=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
    local mem_total=$(awk '/MemTotal/ {printf "%.0f MB", $2/1024}' /proc/meminfo)
    echo "  Hardware:     $model, $mem_total"

    # OS
    local os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Unknown")
    local kernel=$(uname -r)
    echo "  OS:           $os, Kernel $kernel"

    # LoxBerry version (parse from general.json)
    local lbversion=$(perl -e 'use LoxBerry::System; print LoxBerry::System::lbversion();' 2>/dev/null || echo "Unknown")
    echo "  LoxBerry:     $lbversion"

    # Perl + Mosquitto
    echo "  Perl:         $(perl -v | grep -oP 'v[\d.]+')"
    echo "  Mosquitto:    $(mosquitto -h 2>&1 | head -1 | grep -oP '[\d.]+' || echo 'Unknown')"

    # Miniserver info
    local ms_count=$(perl -e 'use LoxBerry::System; my %ms = LoxBerry::System::get_miniservers(); print scalar keys %ms;' 2>/dev/null || echo "?")
    echo "  Miniserver:   $ms_count"

    # Plugin count
    local plug_count=$(perl -e 'use LoxBerry::System; my @p = LoxBerry::System::get_plugins(); print scalar @p;' 2>/dev/null || echo "?")
    echo "  Plugins:      $plug_count installiert"

    # System state
    echo "  Uptime:       $(uptime -p)"
    echo ""
    echo "  CPU Load:     $(cut -d' ' -f1-3 /proc/loadavg)"
    echo "  RAM frei:     $(awk '/MemAvailable/ {printf "%.0f MB", $2/1024}' /proc/meminfo)"
    echo "  Swap:         $(awk '/SwapTotal/ {t=$2} /SwapFree/ {printf "%.0f MB used", (t-$2)/1024}' /proc/meminfo)"
    echo "  CPU Temp:     $(read_temp)°C"
    echo "══════════════════════════════════════════════════════════════"
}

read_temp() {
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    echo "scale=1; $temp / 1000" | bc
}
```

- [ ] **Step 2: Add gateway lifecycle management**

```bash
# Gateway management
ORIGINAL_GW="${LBHOMEDIR}/sbin/mqttgateway.pl"
BENCH_GW="${SCRIPT_DIR}/mqttgateway_benchmarkable.pl"
GW_PID=""

stop_gateway() {
    echo "  Stopping gateway..."
    # Find and stop the running gateway
    local pid=$(pgrep -f 'mqttgateway.*\.pl' || true)
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        sleep 2
        kill -9 "$pid" 2>/dev/null || true
    fi
    # Clean up shared memory files
    rm -f /dev/shm/bench_http_counter /dev/shm/bench_latency.log
    GW_PID=""
}

start_gateway() {
    local gw_script="$1"
    shift
    # Remaining args are env vars

    echo "  Starting gateway: $(basename $gw_script)"
    echo "  Flags: $@"

    # Export BENCH_ flags
    for flag in "$@"; do
        export "$flag"
    done

    # Clean shared memory
    rm -f /dev/shm/bench_http_counter /dev/shm/bench_latency.log

    # Start gateway in background
    perl "$gw_script" &
    GW_PID=$!
    echo "  Gateway PID: $GW_PID"

    # Wait for broker connection (up to 10s)
    local wait=0
    while [[ $wait -lt 10 ]]; do
        if kill -0 "$GW_PID" 2>/dev/null; then
            sleep 1
            wait=$((wait + 1))
        else
            echo "  ERROR: Gateway died on startup"
            return 1
        fi
    done

    # Unset BENCH_ flags
    for flag in "$@"; do
        local varname="${flag%%=*}"
        unset "$varname"
    done

    echo "  Gateway running"
}
```

- [ ] **Step 3: Add run execution function**

```bash
run_benchmark() {
    local run_id="$1"
    local run_name="$2"
    local gw_script="$3"
    local loadgen_mode="$4"
    local loadgen_rate="$5"
    shift 5
    local flags=("$@")

    echo ""
    echo "──────────────────────────────────────────────────────────────"
    echo "  Run $run_id: $run_name"
    echo "──────────────────────────────────────────────────────────────"

    local run_dir="$BENCHMARK_DIR/metrics/run_${run_id}"
    mkdir -p "$run_dir"

    # Stop any running gateway
    stop_gateway

    # Cooldown + thermal check
    cooldown

    # Start gateway with flags
    start_gateway "$gw_script" "${flags[@]}"

    # Start metric collector
    perl "${SCRIPT_DIR}/mqtt-metric-collector.pl" \
        --pid "$GW_PID" \
        --output "$run_dir" \
        --interval 0.5 \
        --duration "$DURATION" \
        --loglevel "$LOGLEVEL" &
    local COLLECTOR_PID=$!

    # Start load generator
    local loadgen_args="--mode $loadgen_mode --output $run_dir --duration $DURATION --loglevel $LOGLEVEL"
    if [[ "$loadgen_rate" -gt 0 ]]; then
        loadgen_args="$loadgen_args --rate $loadgen_rate"
    fi
    perl "${SCRIPT_DIR}/mqtt-loadgen.pl" $loadgen_args &
    local LOADGEN_PID=$!

    # Wait for loadgen + collector to finish
    wait $LOADGEN_PID 2>/dev/null || true
    wait $COLLECTOR_PID 2>/dev/null || true

    # Collect results BEFORE stopping (need GW_PID for CSV filename)
    collect_run_results "$run_id" "$run_name" "$run_dir" "$GW_PID"

    # Stop gateway
    stop_gateway

    echo "  Run $run_id complete"
}

cooldown() {
    echo "  Cooldown (20s)..."
    sleep 20
    # Thermal check
    local temp
    temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    temp=$((temp / 1000))
    while [[ $temp -gt 75 ]]; do
        echo "  CPU temp ${temp}°C > 75°C, waiting..."
        sleep 10
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
        temp=$((temp / 1000))
    done
}
```

- [ ] **Step 4: Add result collection and aggregation**

```bash
# Per-run result collection
declare -A RUN_RESULTS

collect_run_results() {
    local run_id="$1"
    local run_name="$2"
    local run_dir="$3"
    local gw_pid="$4"

    # Parse metric CSV for averages
    local csv="$run_dir/samples_${gw_pid}.csv"
    if [[ -f "$csv" ]]; then
        # Calculate averages using awk (skip header)
        local stats
        stats=$(awk -F, 'NR>1 {
            cpu += $3; rss += $4; temp += $5; http += $6; n++
        } END {
            if (n>0) printf "%.1f,%.1f,%.1f,%d", cpu/n, rss/n, temp/n, http
        }' "$csv")
        RUN_RESULTS[$run_id,cpu]=$(echo "$stats" | cut -d, -f1)
        RUN_RESULTS[$run_id,rss]=$(echo "$stats" | cut -d, -f2)
        RUN_RESULTS[$run_id,temp]=$(echo "$stats" | cut -d, -f3)
        RUN_RESULTS[$run_id,http]=$(echo "$stats" | cut -d, -f4)
    fi

    # Parse loadgen stats
    local lg_stats="$run_dir/loadgen_stats.json"
    if [[ -f "$lg_stats" ]]; then
        RUN_RESULTS[$run_id,msg_count]=$(perl -MJSON -e 'open F,"<","'"$lg_stats"'";local $/;<F>;print decode_json($_)->{msg_count}' 2>/dev/null || echo "0")
        RUN_RESULTS[$run_id,msg_rate]=$(perl -MJSON -e 'open F,"<","'"$lg_stats"'";local $/;<F>;print decode_json($_)->{actual_rate}' 2>/dev/null || echo "0")
    fi

    # Parse latency log
    local lat_log="/dev/shm/bench_latency.log"
    if [[ -f "$lat_log" ]] && [[ -s "$lat_log" ]]; then
        local lat_stats
        # Note: uses gawk (not mawk) for asort() support
        lat_stats=$(gawk -F, '{
            lat = ($2 - $1) * 1000;  # ms
            sum += lat; n++;
            if (n==1 || lat < min) min = lat;
            if (lat > max) max = lat;
            lats[n] = lat;
        } END {
            if (n>0) {
                # Sort for p95
                asort(lats);
                p95_idx = int(n * 0.95);
                if (p95_idx < 1) p95_idx = 1;
                printf "%.1f,%.1f,%.1f,%.1f", min, sum/n, max, lats[p95_idx]
            }
        }' "$lat_log")
        RUN_RESULTS[$run_id,lat_min]=$(echo "$lat_stats" | cut -d, -f1)
        RUN_RESULTS[$run_id,lat_avg]=$(echo "$lat_stats" | cut -d, -f2)
        RUN_RESULTS[$run_id,lat_max]=$(echo "$lat_stats" | cut -d, -f3)
        RUN_RESULTS[$run_id,lat_p95]=$(echo "$lat_stats" | cut -d, -f4)
    fi

    RUN_RESULTS[$run_id,name]="$run_name"
}
```

- [ ] **Step 5: Add scoring and report generation**

```bash
generate_report() {
    local report="$RESULTS_DIR/report_${TIMESTAMP}.txt"
    local summary_csv="$RESULTS_DIR/summary_${TIMESTAMP}.csv"

    # Git hash
    local git_hash=$(cd "$LBHOMEDIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    {
        collect_sysinfo
        echo ""

        # Overall comparison: Run 0 (baseline) vs Run 9 (all optimized)
        local base_cpu="${RUN_RESULTS[0,cpu]:-0}"
        local opt_cpu="${RUN_RESULTS[9,cpu]:-0}"
        local base_rate="${RUN_RESULTS[0,msg_rate]:-0}"
        local opt_rate="${RUN_RESULTS[9,msg_rate]:-0}"
        local base_lat="${RUN_RESULTS[0,lat_avg]:-0}"
        local opt_lat="${RUN_RESULTS[9,lat_avg]:-0}"
        local base_rss="${RUN_RESULTS[0,rss]:-0}"
        local opt_rss="${RUN_RESULTS[9,rss]:-0}"
        local base_http="${RUN_RESULTS[0,http]:-0}"
        local opt_http="${RUN_RESULTS[9,http]:-0}"

        echo "  GESAMTVERGLEICH"
        echo "──────────────────────────────────────────────────────────────"
        printf "  %-22s %10s %10s %12s\n" "" "Original" "Optimized" "Verbesserung"
        print_comparison "CPU (avg)" "$base_cpu%" "$opt_cpu%" "$base_cpu" "$opt_cpu" "lower"
        print_comparison "RAM (RSS)" "${base_rss} MB" "${opt_rss} MB" "$base_rss" "$opt_rss" "lower"
        print_comparison "Durchsatz (msg/s)" "$base_rate" "$opt_rate" "$base_rate" "$opt_rate" "higher"
        print_comparison "Latenz (avg)" "${base_lat}ms" "${opt_lat}ms" "$base_lat" "$opt_lat" "lower"
        print_comparison "HTTP-Calls/s" "$base_http" "$opt_http" "$base_http" "$opt_http" "lower"

        # Score
        local score=$(calc_score "$base_cpu" "$opt_cpu" "$base_rate" "$opt_rate" "$base_lat" "$opt_lat" "0" "0")
        echo "──────────────────────────────────────────────────────────────"
        printf "  %-22s %10s %10s\n" "GESAMTSCORE" "100" "★ $score"
        echo "══════════════════════════════════════════════════════════════"

        echo ""
        echo "  EINZELNE OPTIMIERUNGEN (sortiert nach Impact)"
        echo "──────────────────────────────────────────────────────────────"

        # Runs 2-8: each fix individually
        local -a fix_names=("Early Filter" "Connection Pool" "MS Cache" "Precompiled Regex" "Own Topic Filter" "Flatten Singleton" "JSON::XS")
        for i in $(seq 2 8); do
            local fix_idx=$((i - 2))
            local fix_cpu="${RUN_RESULTS[$i,cpu]:-0}"
            local fix_lat="${RUN_RESULTS[$i,lat_avg]:-0}"
            local fix_rate="${RUN_RESULTS[$i,msg_rate]:-0}"
            local fix_score=$(calc_score "$base_cpu" "$fix_cpu" "$base_rate" "$fix_rate" "$base_lat" "$fix_lat" "0" "0")
            local stars=$(score_to_stars "$fix_score")
            local cpu_diff=$(echo "scale=0; ($base_cpu - $fix_cpu) * 100 / $base_cpu" | bc 2>/dev/null || echo "0")
            printf "  #%d  %-20s CPU -%s%%  Score %s  %s\n" "$((fix_idx + 1))" "${fix_names[$fix_idx]}" "$cpu_diff" "$fix_score" "$stars"
        done

        echo "══════════════════════════════════════════════════════════════"

        # Stresstest results (runs 10-11)
        if [[ -n "${RUN_RESULTS[10,msg_rate]:-}" ]]; then
            echo ""
            echo "  STRESSTEST-ERGEBNIS"
            echo "──────────────────────────────────────────────────────────────"
            echo "  Original max:   ${RUN_RESULTS[10,msg_rate]:-?} msg/s"
            echo "  Optimized max:  ${RUN_RESULTS[11,msg_rate]:-?} msg/s"
            echo "══════════════════════════════════════════════════════════════"
        fi

    } | tee "$report"

    # Write summary CSV
    {
        echo "# MQTT Gateway Benchmark $TIMESTAMP"
        echo "# Git: $git_hash"
        echo "# CPU Temp Start/End: ${RUN_RESULTS[0,temp]:-?}/${RUN_RESULTS[9,temp]:-?}"
        echo "run_id,run_name,cpu_pct,rss_mb,msg_rate,lat_avg_ms,http_calls,score"
        for i in $(seq 0 11); do
            if [[ -n "${RUN_RESULTS[$i,name]:-}" ]]; then
                local s=$(calc_score "$base_cpu" "${RUN_RESULTS[$i,cpu]:-0}" "$base_rate" "${RUN_RESULTS[$i,msg_rate]:-0}" "$base_lat" "${RUN_RESULTS[$i,lat_avg]:-0}" "0" "0")
                echo "$i,${RUN_RESULTS[$i,name]},${RUN_RESULTS[$i,cpu]:-0},${RUN_RESULTS[$i,rss]:-0},${RUN_RESULTS[$i,msg_rate]:-0},${RUN_RESULTS[$i,lat_avg]:-0},${RUN_RESULTS[$i,http]:-0},$s"
            fi
        done
    } > "$summary_csv"

    echo ""
    echo "Report: $report"
    echo "CSV:    $summary_csv"

    # Persist to data dir
    cp "$report" "$DATA_DIR/"
    cp "$summary_csv" "$DATA_DIR/"
    echo "Archived to: $DATA_DIR/"
}

print_comparison() {
    local label="$1" val_a="$2" val_b="$3" num_a="$4" num_b="$5" direction="$6"
    local diff
    if [[ "$direction" == "lower" ]]; then
        diff=$(echo "scale=0; ($num_a - $num_b) * 100 / $num_a" | bc 2>/dev/null || echo "0")
        printf "  %-22s %10s %10s      -%s%%\n" "$label" "$val_a" "$val_b" "$diff"
    else
        diff=$(echo "scale=0; ($num_b - $num_a) * 100 / $num_a" | bc 2>/dev/null || echo "0")
        printf "  %-22s %10s %10s      +%s%%\n" "$label" "$val_a" "$val_b" "$diff"
    fi
}

calc_score() {
    local b_cpu="$1" m_cpu="$2" b_thr="$3" m_thr="$4" b_lat="$5" m_lat="$6" b_loss="$7" m_loss="$8"
    # Avoid division by zero — uses perl (no python3 dependency)
    perl -e '
        use List::Util qw(max);
        my ($b_cpu,$m_cpu,$b_thr,$m_thr,$b_lat,$m_lat,$b_loss,$m_loss) =
            map { $_ + 0 } @ARGV;
        $b_cpu = max($b_cpu, 0.1); $m_cpu = max($m_cpu, 0.1);
        $b_thr = max($b_thr, 0.1); $m_thr = max($m_thr, 0.1);
        $b_lat = max($b_lat, 0.1); $m_lat = max($m_lat, 0.1);
        my $s_cpu = ($b_cpu / $m_cpu) * 100 * 0.30;
        my $s_thr = ($m_thr / $b_thr) * 100 * 0.30;
        my $s_lat = ($b_lat / $m_lat) * 100 * 0.20;
        my $s_loss = ((1 - $m_loss) / max(1 - $b_loss, 0.01)) * 100 * 0.20;
        printf "%d", $s_cpu + $s_thr + $s_lat + $s_loss;
    ' "$b_cpu" "$m_cpu" "$b_thr" "$m_thr" "$b_lat" "$m_lat" "$b_loss" "$m_loss" 2>/dev/null || echo "100"
}

score_to_stars() {
    local score="$1"
    if   [[ $score -ge 140 ]]; then echo "★★★★★"
    elif [[ $score -ge 125 ]]; then echo "★★★★☆"
    elif [[ $score -ge 115 ]]; then echo "★★★☆☆"
    elif [[ $score -ge 108 ]]; then echo "★★☆☆☆"
    else echo "★☆☆☆☆"
    fi
}
```

- [ ] **Step 6: Add main execution — test matrix and dry-run**

```bash
# Feature flag definitions
FLAGS_EARLY_FILTER="BENCH_EARLY_FILTER=1"
FLAGS_CONNECTION_POOL="BENCH_CONNECTION_POOL=1"
FLAGS_MS_CACHE="BENCH_MS_CACHE=1"
FLAGS_PRECOMPILED_REGEX="BENCH_PRECOMPILED_REGEX=1"
FLAGS_OWN_TOPIC_FILTER="BENCH_OWN_TOPIC_FILTER=1"
FLAGS_FLATTEN_SINGLETON="BENCH_FLATTEN_SINGLETON=1"
FLAGS_JSON_XS="BENCH_JSON_XS=1"

ALL_FLAGS="$FLAGS_EARLY_FILTER $FLAGS_CONNECTION_POOL $FLAGS_MS_CACHE $FLAGS_PRECOMPILED_REGEX $FLAGS_OWN_TOPIC_FILTER $FLAGS_FLATTEN_SINGLETON $FLAGS_JSON_XS"

echo "══════════════════════════════════════════════════════════════"
echo "  MQTT Gateway Benchmark — $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════════════════════"

if [[ $DRY_RUN -eq 1 ]]; then
    collect_sysinfo
    echo ""
    echo "  TEST MATRIX (--dry-run)"
    echo "──────────────────────────────────────────────────────────────"
    echo "  Run  0: Original (Baseline)                [realistic ${DURATION}s]"
    echo "  Run  1: Benchmarkable, all flags OFF       [realistic ${DURATION}s]"
    echo "  Run  2: + Early Filter                     [realistic ${DURATION}s]"
    echo "  Run  3: + Connection Pool                  [realistic ${DURATION}s]"
    echo "  Run  4: + MS Cache                         [realistic ${DURATION}s]"
    echo "  Run  5: + Precompiled Regex                [realistic ${DURATION}s]"
    echo "  Run  6: + Own Topic Filter                 [realistic ${DURATION}s]"
    echo "  Run  7: + Flatten Singleton                [realistic ${DURATION}s]"
    echo "  Run  8: + JSON::XS                         [realistic ${DURATION}s]"
    echo "  Run  9: All flags ON                       [realistic ${DURATION}s]"
    echo "  Run 10: Original + Stresstest              [stress 5x${DURATION}s]"
    echo "  Run 11: Optimized + Stresstest             [stress 5x${DURATION}s]"
    echo ""
    echo "  Estimated time: ~$((DURATION * 10 / 60 + DURATION * 10 / 60 + 10)) minutes"
    echo "══════════════════════════════════════════════════════════════"
    exit 0
fi

# Run loadgen self-test first
echo ""
echo "  LOADGEN SELF-TEST"
echo "──────────────────────────────────────────────────────────────"
mkdir -p "$BENCHMARK_DIR/metrics/selftest"
perl "${SCRIPT_DIR}/mqtt-loadgen.pl" --mode selftest --output "$BENCHMARK_DIR/metrics/selftest" --loglevel "$LOGLEVEL"
MAX_RATE=$(cat "$BENCHMARK_DIR/metrics/selftest/max_rate.txt" 2>/dev/null || echo "500")
echo "  Max loadgen rate: $MAX_RATE msg/s"

# ── Realistic Runs (0-9) ──
run_benchmark 0  "Original (Baseline)"       "$ORIGINAL_GW" "realistic" 0
run_benchmark 1  "Benchmarkable (flags OFF)" "$BENCH_GW"    "realistic" 0
run_benchmark 2  "Early Filter"              "$BENCH_GW"    "realistic" 0 "$FLAGS_EARLY_FILTER"
run_benchmark 3  "Connection Pool"           "$BENCH_GW"    "realistic" 0 "$FLAGS_CONNECTION_POOL"
run_benchmark 4  "MS Cache"                  "$BENCH_GW"    "realistic" 0 "$FLAGS_MS_CACHE"
run_benchmark 5  "Precompiled Regex"         "$BENCH_GW"    "realistic" 0 "$FLAGS_PRECOMPILED_REGEX"
run_benchmark 6  "Own Topic Filter"          "$BENCH_GW"    "realistic" 0 "$FLAGS_OWN_TOPIC_FILTER"
run_benchmark 7  "Flatten Singleton"         "$BENCH_GW"    "realistic" 0 "$FLAGS_FLATTEN_SINGLETON"
run_benchmark 8  "JSON::XS"                  "$BENCH_GW"    "realistic" 0 "$FLAGS_JSON_XS"
run_benchmark 9  "All Optimizations"         "$BENCH_GW"    "realistic" 0 $ALL_FLAGS

# ── Stresstest Runs (unique IDs per rate) ──
STRESS_RATES=(10 50 100 200 500)
STRESS_RUN_ID=10
for rate in "${STRESS_RATES[@]}"; do
    if [[ $rate -gt $MAX_RATE ]]; then
        echo "  Skipping stress rate $rate (exceeds loadgen max $MAX_RATE)"
        continue
    fi
    run_benchmark "${STRESS_RUN_ID}"     "Original Stress ${rate}msg/s"  "$ORIGINAL_GW" "stress" "$rate"
    run_benchmark "$((STRESS_RUN_ID+1))" "Optimized Stress ${rate}msg/s" "$BENCH_GW"    "stress" "$rate" $ALL_FLAGS
    STRESS_RUN_ID=$((STRESS_RUN_ID + 2))
done

# Restore original gateway
echo ""
echo "  Restoring original gateway..."
perl "$ORIGINAL_GW" &
echo "  Original gateway restarted (PID $!)"

# Generate final report
generate_report

echo ""
echo "  Benchmark complete!"
```

- [ ] **Step 7: Make scripts executable**

```bash
chmod +x sbin/benchmark/mqtt-benchmark.sh
chmod +x sbin/benchmark/mqtt-loadgen.pl
chmod +x sbin/benchmark/mqtt-metric-collector.pl
chmod +x sbin/benchmark/mqttgateway_benchmarkable.pl
```

- [ ] **Step 8: Commit**

```bash
git add sbin/benchmark/mqtt-benchmark.sh
git commit -m "feat(benchmark): add orchestrator with test matrix, scoring, and reporting

Manages 12-run test matrix (baseline, 7 isolated fixes, combined, 2 stress),
collects system info via LoxBerry API, generates terminal report with scoring
and CSV export. Includes dry-run mode, thermal throttle protection, cooldown."
```

---

## Task 5: Integration test and final polish

Verify all 4 files work together, fix any issues, prepare for deployment to LoxBerry.

**Files:**
- Verify: all files in `sbin/benchmark/`
- Modify: LoxBerry MQTT gateway config (subscriptions for benchmark topics)

- [ ] **Step 0: Ensure gateway subscribes to benchmark topics**

The gateway only processes topics it's subscribed to. The benchmark loadgen publishes to `benchmark/loadgen/#`. The orchestrator must ensure this subscription exists before running.

Add to `mqtt-benchmark.sh` (before the first `run_benchmark` call):

```bash
# Ensure benchmark topic subscription exists in mqttgateway config
# The gateway subscribes to topics listed in its config.
# For the benchmark, we add a temporary subscription to benchmark/loadgen/#
# This is handled by the benchmarkable gateway itself: it subscribes to benchmark/# on startup
```

Add to `mqttgateway_benchmarkable.pl` in the subscription setup (around line 1083):

```perl
# Benchmark: always subscribe to benchmark topics
push @subscriptions, "benchmark/#";
LOGINF "Benchmark mode: subscribed to benchmark/#";
```

- [ ] **Step 1: Verify Perl syntax on all scripts**

```bash
cd sbin/benchmark
for f in *.pl; do
    echo "=== $f ==="
    perl -c "$f" 2>&1 || true
done
```

Expected: Syntax OK for each file (may show warnings about missing LoxBerry modules on dev machine — that's fine, they exist on the target).

- [ ] **Step 2: Verify Bash syntax**

```bash
bash -n sbin/benchmark/mqtt-benchmark.sh
echo $?
# Expected: 0 (no syntax errors)
```

- [ ] **Step 3: Verify file listing and permissions**

```bash
ls -la sbin/benchmark/
# All .pl and .sh files should be executable
```

- [ ] **Step 4: Create a README with usage instructions**

```bash
cat > sbin/benchmark/README.md << 'READMEEOF'
# MQTT Gateway Benchmark

Measures the performance impact of 7 optimizations in mqttgateway.pl.

## Usage

```bash
# Dry run — show test matrix without executing
./mqtt-benchmark.sh --dry-run

# Full benchmark (default: 60s per run, ~23 minutes total)
./mqtt-benchmark.sh

# Custom duration
./mqtt-benchmark.sh --duration 30

# With debug logging
./mqtt-benchmark.sh --loglevel 7
```

## Output

- Terminal report with scoring
- CSV: `$LBPLOG/benchmark/results/summary_YYYYMMDD_HHMM.csv`
- Archived to: `$LBPDATA/benchmark/results/`

## Feature Flags

Set individually to test each optimization:
- `BENCH_EARLY_FILTER` — DoNotForward/Regex before JSON expansion
- `BENCH_CONNECTION_POOL` — Persistent HTTP connections
- `BENCH_MS_CACHE` — Cached miniserver config
- `BENCH_PRECOMPILED_REGEX` — Pre-compiled subscription regexes
- `BENCH_OWN_TOPIC_FILTER` — Early gateway topic filtering
- `BENCH_FLATTEN_SINGLETON` — Reuse Hash::Flatten instance
- `BENCH_JSON_XS` — Prefer JSON::XS over JSON::PP
READMEEOF
```

- [ ] **Step 5: Final commit**

```bash
git add sbin/benchmark/
git commit -m "feat(benchmark): complete MQTT benchmark tool with README

All components: benchmarkable gateway, load generator, metric collector,
orchestrator. Ready for deployment to LoxBerry RPi 4."
```
