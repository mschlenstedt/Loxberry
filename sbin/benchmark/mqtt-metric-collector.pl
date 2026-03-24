#!/usr/bin/perl

# mqtt-metric-collector.pl
# Lightweight process metrics sampler for MQTT Gateway benchmarks.
#
# Usage:
#   mqtt-metric-collector.pl --pid PID --output DIR [--interval 0.5] [--duration 60] [--loglevel 6]
#
# Reads /proc/[pid]/stat every --interval seconds, computes CPU% and RSS,
# reads CPU temperature and HTTP counter, writes samples to CSV.
# Exits early if the monitored process dies.

use strict;
use warnings;

use LoxBerry::Log;
use Time::HiRes qw(time sleep);
use File::Copy qw(move);
use Getopt::Long qw(:config no_ignore_case);

# ---------------------------------------------------------------------------
# Command-line arguments
# ---------------------------------------------------------------------------

my $pid;
my $output_dir;
my $interval  = 0.5;
my $duration  = 60;
my $loglevel  = 6;

GetOptions(
    'pid=i'      => \$pid,
    'output=s'   => \$output_dir,
    'interval=f' => \$interval,
    'duration=f' => \$duration,
    'loglevel=i' => \$loglevel,
) or die "Usage: $0 --pid PID --output DIR [--interval 0.5] [--duration 60] [--loglevel 6]\n";

die "--pid is required\n"    unless defined $pid;
die "--output is required\n" unless defined $output_dir;

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

my $log = LoxBerry::Log->new(
    name      => 'MQTT Benchmark Metrics',
    filename  => "$output_dir/metric-collector.log",
    append    => 1,
    loglevel  => $loglevel,
);

LOGSTART "Metric collector for PID $pid";
LOGINF "Output dir: $output_dir  interval: ${interval}s  duration: ${duration}s";

# ---------------------------------------------------------------------------
# Validate PID early
# ---------------------------------------------------------------------------

unless (-r "/proc/$pid/stat") {
    LOGERR "Cannot read /proc/$pid/stat — PID $pid not found or not readable";
    LOGEND "Exiting with error";
    exit 1;
}

# ---------------------------------------------------------------------------
# Determine CLK_TCK (timer ticks per second, usually 100)
# ---------------------------------------------------------------------------

my $clk_tck = get_clk_tck();
LOGDEB "CLK_TCK = $clk_tck";

# ---------------------------------------------------------------------------
# Output file paths
# ---------------------------------------------------------------------------

my $csv_file = "$output_dir/samples_${pid}.csv";
my $tmp_file = "$output_dir/samples_${pid}.csv.tmp";

# Open the .tmp file for incremental writing during the run
open(my $fh, '>', $tmp_file)
    or do { LOGERR "Cannot open $tmp_file: $!"; LOGEND "Exiting"; exit 1; };

# Write CSV header
print $fh "timestamp,elapsed_s,cpu_pct,rss_mb,cpu_temp_c,http_calls\n";

# ---------------------------------------------------------------------------
# Sampling loop
# ---------------------------------------------------------------------------

my $start_wall  = time();
my $end_wall    = $start_wall + $duration;

# Bootstrap: read first stat sample so we can compute delta on next iteration
my ($prev_cpu_ticks, $prev_wall) = read_cpu_ticks($pid);
unless (defined $prev_cpu_ticks) {
    LOGERR "Failed to read initial /proc/$pid/stat";
    close $fh;
    LOGEND "Exiting with error";
    exit 1;
}

my $samples = 0;

while (time() < $end_wall) {
    sleep($interval);

    my $now = time();

    # --- Check process still alive ---
    unless (kill(0, $pid)) {
        LOGINF "PID $pid no longer running — stopping collection after $samples samples";
        last;
    }

    # --- Read /proc/[pid]/stat ---
    my ($curr_cpu_ticks, $curr_wall, $rss_mb) = read_proc_stat($pid);
    unless (defined $curr_cpu_ticks) {
        LOGWARN "Failed to read /proc/$pid/stat at sample $samples — skipping";
        next;
    }

    # --- CPU% ---
    my $wall_delta = $curr_wall - $prev_wall;
    my $tick_delta = $curr_cpu_ticks - $prev_cpu_ticks;
    my $cpu_pct    = ($wall_delta > 0)
        ? ($tick_delta / $clk_tck / $wall_delta * 100)
        : 0;

    $prev_cpu_ticks = $curr_cpu_ticks;
    $prev_wall      = $curr_wall;

    # --- CPU temperature ---
    my $cpu_temp = read_cpu_temp();

    # --- HTTP counter ---
    my $http_calls = read_http_counter();

    # --- Elapsed ---
    my $elapsed = $now - $start_wall;

    # --- Write CSV row ---
    printf $fh "%.3f,%.3f,%.2f,%.2f,%.1f,%d\n",
        $now, $elapsed, $cpu_pct, $rss_mb, $cpu_temp, $http_calls;

    $samples++;

    LOGDEB sprintf("sample %d: elapsed=%.1fs cpu=%.1f%% rss=%.1fMB temp=%.1f°C http=%d",
        $samples, $elapsed, $cpu_pct, $rss_mb, $cpu_temp, $http_calls)
        if ($samples % 10 == 0 || $samples <= 3);
}

close $fh;

# Atomic rename .tmp → final CSV
if (move($tmp_file, $csv_file)) {
    LOGINF "CSV written to $csv_file ($samples samples)";
} else {
    LOGERR "Failed to rename $tmp_file to $csv_file: $!";
    LOGEND "Exiting with error";
    exit 1;
}

LOGEND "Metric collector finished — $samples samples collected";
exit 0;

# ---------------------------------------------------------------------------
# Subroutines
# ---------------------------------------------------------------------------

# read_proc_stat($pid)
# Returns ($total_cpu_ticks, $wall_time, $rss_mb) or undef on error.
#
# /proc/[pid]/stat layout: after the comm field (which may contain spaces and
# parens), all remaining fields are space-separated.  We find the LAST ')'
# in the line and split everything after it.
#
#   Fields after comm (0-indexed):
#     0  = state
#     ...
#     11 = utime   (CPU ticks in user mode)
#     12 = stime   (CPU ticks in kernel mode)
#     ...
#     21 = rss     (Resident Set Size, in pages of 4096 bytes)
sub read_proc_stat {
    my ($pid) = @_;
    my $stat_file = "/proc/$pid/stat";

    open(my $sfh, '<', $stat_file) or return (undef, undef, undef);
    my $line = <$sfh>;
    close $sfh;

    return (undef, undef, undef) unless defined $line;
    chomp $line;

    # Find the LAST ')' to handle process names containing '(' or ')'
    my $last_paren = rindex($line, ')');
    return (undef, undef, undef) if $last_paren < 0;

    my $after_comm = substr($line, $last_paren + 1);
    $after_comm =~ s/^\s+//;
    my @fields = split(/\s+/, $after_comm);

    # utime=index 11, stime=index 12, rss=index 21
    return (undef, undef, undef) unless @fields >= 22;

    my $utime = $fields[11];
    my $stime = $fields[12];
    my $rss   = $fields[21];    # pages

    my $total_ticks = $utime + $stime;
    my $rss_mb      = ($rss * 4096) / (1024 * 1024);
    my $wall        = time();

    return ($total_ticks, $wall, $rss_mb);
}

# read_cpu_ticks($pid)
# Thin wrapper used for the bootstrap read (no rss needed).
sub read_cpu_ticks {
    my ($pid) = @_;
    my ($ticks, $wall, undef) = read_proc_stat($pid);
    return ($ticks, $wall);
}

# read_cpu_temp()
# Reads /sys/class/thermal/thermal_zone0/temp (millidegrees → degrees).
# Returns 0 if not available (e.g. non-RPi hardware).
sub read_cpu_temp {
    my $temp_file = '/sys/class/thermal/thermal_zone0/temp';
    open(my $tfh, '<', $temp_file) or return 0;
    my $raw = <$tfh>;
    close $tfh;
    chomp $raw if defined $raw;
    return (defined $raw && $raw =~ /^\d+$/) ? ($raw / 1000) : 0;
}

# read_http_counter()
# Reads /dev/shm/bench_http_counter — a single numeric value written
# atomically by the benchmarkable gateway for each HTTP request made.
# Returns 0 if the file does not exist yet.
sub read_http_counter {
    my $counter_file = '/dev/shm/bench_http_counter';
    open(my $cfh, '<', $counter_file) or return 0;
    my $val = <$cfh>;
    close $cfh;
    chomp $val if defined $val;
    return (defined $val && $val =~ /^\d+$/) ? int($val) : 0;
}

# get_clk_tck()
# Retrieves the system clock tick rate via `getconf CLK_TCK`.
# Falls back to 100 (the standard Linux default) on any error.
sub get_clk_tck {
    my $tck = qx{getconf CLK_TCK 2>/dev/null};
    chomp $tck if defined $tck;
    return ($tck && $tck =~ /^\d+$/) ? int($tck) : 100;
}
