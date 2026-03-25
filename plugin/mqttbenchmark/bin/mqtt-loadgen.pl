#!/usr/bin/perl

# mqtt-loadgen.pl
# MQTT load generator for benchmarking the LoxBerry MQTT Gateway.
#
# Usage:
#   mqtt-loadgen.pl --mode realistic|stress|selftest --output DIR
#                   [--rate N] [--topics N] [--duration N] [--loglevel N]
#
# Modes:
#   realistic  — 7 simulated device profiles at natural intervals (~15-20 msg/s)
#   stress     — N topics at a fixed rate (requires --rate)
#   selftest   — sweep rates 10..1000 msg/s; write selftest.json + max_rate.txt
#
# All published payloads carry a _bench_ts field for latency measurement.
# Output stats are written atomically to --output DIR.

use strict;
use warnings;

use LoxBerry::Log;
use LoxBerry::IO;
use Time::HiRes qw(time sleep gettimeofday);
use JSON;
use File::Copy qw(move);
use Getopt::Long qw(:config no_ignore_case);

# ---------------------------------------------------------------------------
# Command-line arguments
# ---------------------------------------------------------------------------

my $mode       = 'realistic';
my $rate;
my $topics     = 7;
my $duration   = 60;
my $output_dir;
my $loglevel   = 6;

GetOptions(
    'mode=s'     => \$mode,
    'rate=f'     => \$rate,
    'topics=i'   => \$topics,
    'duration=f' => \$duration,
    'output=s'   => \$output_dir,
    'loglevel=i' => \$loglevel,
) or die "Usage: $0 --mode realistic|stress|selftest --output DIR "
       . "[--rate N] [--topics N] [--duration N] [--loglevel N]\n";

die "--output is required\n" unless defined $output_dir;

unless ($mode =~ /^(realistic|stress|selftest)$/) {
    die "--mode must be realistic, stress, or selftest\n";
}

if ($mode eq 'stress' && !defined $rate) {
    die "--rate is required for stress mode\n";
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

my $log = LoxBerry::Log->new(
    name     => 'MQTT Loadgen',
    filename => "$output_dir/loadgen.log",
    append   => 1,
    loglevel => $loglevel,
);

LOGSTART "MQTT Loadgen — mode=$mode duration=${duration}s";
LOGINF "Output dir: $output_dir";

# ---------------------------------------------------------------------------
# MQTT connection
# ---------------------------------------------------------------------------

my $creds = LoxBerry::IO::mqtt_connectiondetails();
unless (defined $creds) {
    LOGERR "mqtt_connectiondetails() returned undef — MQTT Gateway plugin not installed?";
    LOGEND "Exiting with error";
    exit 1;
}

my $broker = "$creds->{brokerhost}:$creds->{brokerport}";
LOGINF "Connecting to broker $broker";

# Allow insecure login (plain-text credentials) if needed
$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;

require Net::MQTT::Simple;
my $mqtt = Net::MQTT::Simple->new($broker);
unless ($mqtt) {
    LOGERR "Failed to connect to MQTT broker $broker";
    LOGEND "Exiting with error";
    exit 1;
}

if ($creds->{brokeruser}) {
    LOGINF "Logging in as user '$creds->{brokeruser}'";
    $mqtt->login($creds->{brokeruser}, $creds->{brokerpass});
}

LOGOK "Connected to MQTT broker $broker";

# ---------------------------------------------------------------------------
# Signal handlers — clean shutdown
# ---------------------------------------------------------------------------

my $running = 1;
$SIG{INT}  = sub { LOGINF "Interrupted by signal"; $running = 0; };
$SIG{TERM} = sub { LOGINF "Terminated by signal";  $running = 0; };

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

if ($mode eq 'realistic') {
    run_realistic();
} elsif ($mode eq 'stress') {
    run_stress($rate, $topics, $duration);
} elsif ($mode eq 'selftest') {
    run_selftest();
}

LOGEND "MQTT Loadgen finished";
exit 0;

# ===========================================================================
# MODE: realistic
# ===========================================================================

sub run_realistic {
    LOGINF "Starting realistic mode — 7 device profiles — expected ~17.4 msg/s — duration=${duration}s";

    # --- Device profiles ---------------------------------------------------
    # Each profile: name, topic, interval (s), payload_sub
    my @profiles = (
        {
            name     => 'tasmota1',
            topic    => 'benchmark/loadgen/tasmota/sensor1/SENSOR',
            interval => 0.25,
            payload  => sub {
                return encode_json({
                    Time   => _iso_time(),
                    ENERGY => {
                        Total   => _rand_f(100, 500, 2),
                        Power   => _rand_f(0, 3000, 1),
                        Voltage => _rand_f(220, 240, 1),
                        Current => _rand_f(0, 13, 2),
                    },
                    _bench_ts => time(),
                });
            },
        },
        {
            name     => 'tasmota2',
            topic    => 'benchmark/loadgen/tasmota/sensor2/SENSOR',
            interval => 0.25,
            payload  => sub {
                return encode_json({
                    Time    => _iso_time(),
                    DS18B20 => { Temperature => _rand_f(15, 30, 1) },
                    _bench_ts => time(),
                });
            },
        },
        {
            name     => 'tasmota3',
            topic    => 'benchmark/loadgen/tasmota/sensor3/SENSOR',
            interval => 0.25,
            payload  => sub {
                return encode_json({
                    Time   => _iso_time(),
                    BME280 => {
                        Temperature => _rand_f(18, 28, 1),
                        Humidity    => _rand_f(30, 80, 1),
                        Pressure    => _rand_f(990, 1030, 1),
                    },
                    _bench_ts => time(),
                });
            },
        },
        {
            name     => 'zigbee2mqtt',
            topic    => 'benchmark/loadgen/zigbee2mqtt/lamp1',
            interval => 1.0,
            payload  => sub {
                return encode_json({
                    state       => (int(rand(2)) ? 'ON' : 'OFF'),
                    brightness  => int(rand(254)),
                    color_temp  => int(rand(350)) + 153,
                    _bench_ts   => time(),
                });
            },
        },
        {
            name     => 'venus1',
            topic    => 'benchmark/loadgen/venus/battery/Soc',
            interval => 0.5,
            payload  => sub {
                return encode_json({
                    value     => _rand_f(20, 100, 1),
                    _bench_ts => time(),
                });
            },
        },
        {
            name     => 'venus2',
            topic    => 'benchmark/loadgen/venus/system/Ac/ConsumptionOnInput/L1/Power',
            interval => 0.5,
            payload  => sub {
                return encode_json({
                    value     => _rand_f(0, 5000, 1),
                    _bench_ts => time(),
                });
            },
        },
        {
            name     => 'shelly1',
            topic    => 'benchmark/loadgen/shelly/relay1/status',
            interval => 2.5,
            payload  => sub {
                return encode_json({
                    ison   => \1,
                    power  => _rand_f(0, 2500, 1),
                    energy => _rand_f(0, 10000, 2),
                    _bench_ts => time(),
                });
            },
        },
    );

    # Initialise next_send time for each profile
    my $now = time();
    for my $p (@profiles) {
        $p->{next_send} = $now + rand($p->{interval});   # stagger initial sends
    }

    my $start     = time();
    my $end       = $start + $duration;
    my $msg_count = 0;

    while ($running && time() < $end) {
        my $t = time();

        for my $p (@profiles) {
            if ($t >= $p->{next_send}) {
                my $payload = $p->{payload}->();
                $mqtt->publish($p->{topic}, $payload);
                $msg_count++;
                $p->{next_send} += $p->{interval};
                # If we fell behind, reset to now to avoid burst catch-up
                $p->{next_send} = $t + $p->{interval}
                    if $p->{next_send} < $t;
            }
        }

        # 10 ms sleep to avoid busy-wait while still being responsive
        Time::HiRes::sleep(0.01);
    }

    my $elapsed     = time() - $start;
    my $actual_rate = ($elapsed > 0) ? sprintf("%.1f", $msg_count / $elapsed) : '0.0';

    LOGOK "Realistic mode finished: $msg_count messages in ${elapsed}s (~${actual_rate} msg/s)";

    _write_stats({
        mode        => 'realistic',
        duration    => $duration,
        msg_count   => $msg_count,
        actual_rate => $actual_rate,
    });
}

# ===========================================================================
# MODE: stress
# ===========================================================================

sub run_stress {
    my ($target_rate, $num_topics, $dur) = @_;

    LOGINF "Starting stress mode — rate=${target_rate} msg/s  topics=${num_topics}  duration=${dur}s";

    my $interval = 1.0 / $target_rate;

    # Build topic list
    my @stress_topics = map {
        "benchmark/loadgen/stress/device${_}/SENSOR"
    } (1 .. $num_topics);

    my $start     = time();
    my $end       = $start + $dur;
    my $msg_count = 0;
    my $counter   = 0;

    my $next_send = time();

    while ($running && time() < $end) {
        my $t = time();

        if ($t >= $next_send) {
            my $topic_idx = $msg_count % $num_topics;
            my $topic     = $stress_topics[$topic_idx];

            my $payload = encode_json({
                temperature => _rand_f(15, 35, 1),
                humidity    => _rand_f(30, 80, 1),
                counter     => ++$counter,
                _bench_ts   => time(),
            });

            $mqtt->publish($topic, $payload);
            $msg_count++;
            $next_send += $interval;

            # Warn if falling behind by more than 1 second, then reset
            if ($next_send < $t - 1.0) {
                LOGWARN sprintf(
                    "Stress mode falling behind: %.1fs lag after %d msgs — resetting timing",
                    $t - $next_send, $msg_count
                );
                $next_send = $t + $interval;
            }
        }

        # Sub-millisecond sleep for precise timing without burning a full CPU core
        select(undef, undef, undef, 0.0005);
    }

    my $elapsed     = time() - $start;
    my $actual_rate = ($elapsed > 0) ? sprintf("%.1f", $msg_count / $elapsed) : '0.0';

    LOGOK "Stress mode finished: $msg_count messages in ${elapsed}s (~${actual_rate} msg/s)";

    _write_stats({
        mode        => 'stress',
        target_rate => $target_rate,
        topics      => $num_topics,
        duration    => $dur,
        msg_count   => $msg_count,
        actual_rate => $actual_rate,
    });
}

# ===========================================================================
# MODE: selftest
# ===========================================================================

sub run_selftest {
    LOGINF "Starting selftest — sweeping rates: 10, 50, 100, 200, 500, 1000 msg/s";

    my @test_rates  = (10, 50, 100, 200, 500, 1000);
    my $test_dur    = 5;   # seconds per rate step
    my $topic       = 'benchmark/loadgen/selftest/SENSOR';

    my @results;
    my $max_rate = 0;

    for my $target (@test_rates) {
        last unless $running;

        LOGINF "Selftest: testing ${target} msg/s for ${test_dur}s ...";

        my $interval  = 1.0 / $target;
        my $start     = time();
        my $end       = $start + $test_dur;
        my $count     = 0;
        my $next_send = $start;

        while (time() < $end) {
            my $t = time();
            if ($t >= $next_send) {
                my $payload = encode_json({
                    counter   => $count,
                    _bench_ts => time(),
                });
                $mqtt->publish($topic, $payload);
                $count++;
                $next_send += $interval;

                # Reset if severely behind
                $next_send = $t + $interval if $next_send < $t - 0.5;
            }
            select(undef, undef, undef, 0.0005);
        }

        my $elapsed       = time() - $start;
        my $achieved_rate = ($elapsed > 0) ? ($count / $elapsed) : 0;
        my $achieved_pct  = ($target > 0) ? ($achieved_rate / $target * 100) : 0;

        my $result = {
            target_rate   => $target,
            achieved_rate => sprintf("%.1f", $achieved_rate),
            achieved_pct  => sprintf("%.1f", $achieved_pct),
            msg_count     => $count,
        };
        push @results, $result;

        LOGINF sprintf(
            "Selftest %d msg/s: achieved %.1f msg/s (%.0f%%)",
            $target, $achieved_rate, $achieved_pct
        );

        if ($achieved_pct >= 90) {
            $max_rate = $target;
            LOGOK "Rate ${target} msg/s: PASS";
        } else {
            LOGWARN sprintf(
                "Rate %d msg/s: FAIL — only achieved %.0f%% — stopping sweep",
                $target, $achieved_pct
            );
            last;
        }
    }

    LOGOK "Selftest complete — max sustainable rate: ${max_rate} msg/s";

    # Write selftest.json (atomic)
    my $selftest_tmp  = "$output_dir/selftest.json.tmp";
    my $selftest_file = "$output_dir/selftest.json";
    _atomic_write_json($selftest_tmp, $selftest_file, {
        results  => \@results,
        max_rate => $max_rate,
    });

    # Write max_rate.txt (atomic)
    my $maxrate_tmp  = "$output_dir/max_rate.txt.tmp";
    my $maxrate_file = "$output_dir/max_rate.txt";
    open(my $fh, '>', $maxrate_tmp)
        or do { LOGERR "Cannot write $maxrate_tmp: $!"; return; };
    print $fh "$max_rate\n";
    close $fh;

    if (move($maxrate_tmp, $maxrate_file)) {
        LOGINF "max_rate.txt written: $max_rate msg/s";
    } else {
        LOGERR "Failed to rename $maxrate_tmp -> $maxrate_file: $!";
    }
}

# ===========================================================================
# Helpers
# ===========================================================================

# _write_stats(\%data)
# Atomically writes $output_dir/loadgen_stats.json
sub _write_stats {
    my ($data) = @_;
    my $tmp_file  = "$output_dir/loadgen_stats.json.tmp";
    my $json_file = "$output_dir/loadgen_stats.json";
    _atomic_write_json($tmp_file, $json_file, $data);
    LOGINF "Stats written to $json_file";
}

# _atomic_write_json($tmp, $final, \%data)
sub _atomic_write_json {
    my ($tmp_file, $final_file, $data) = @_;

    open(my $fh, '>', $tmp_file)
        or do { LOGERR "Cannot write $tmp_file: $!"; return; };
    print $fh JSON->new->utf8->pretty->encode($data);
    close $fh;

    unless (move($tmp_file, $final_file)) {
        LOGERR "Failed to rename $tmp_file -> $final_file: $!";
    }
}

# _rand_f($min, $max, $decimals)
# Returns a random float in [$min, $max] with $decimals decimal places.
sub _rand_f {
    my ($min, $max, $dec) = @_;
    my $val = $min + rand($max - $min);
    return sprintf("%.${dec}f", $val) + 0;
}

# _iso_time()
# Returns current time as ISO 8601 string (matches Tasmota format).
sub _iso_time {
    my @t = localtime(time());
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
        $t[5] + 1900, $t[4] + 1, $t[3],
        $t[2], $t[1], $t[0]);
}
