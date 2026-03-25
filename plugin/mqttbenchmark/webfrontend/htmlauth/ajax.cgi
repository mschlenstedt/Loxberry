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
} elsif ($action eq 'dryrun') {
    handle_dryrun();
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
# Action: dryrun
##########################################################################

sub handle_dryrun {
    my $duration = ($q->{duration} && $q->{duration} =~ /^(30|60|120)$/) ? $1 : 60;
    my $runs     = ($q->{runs}     && $q->{runs}     =~ /^([a-z,]+)$/)  ? $1 : "realistic,stress";
    my $fixes    = ($q->{fixes}    && $q->{fixes}    =~ /^([\d,]+)$/)   ? $1 : "1,2,3,4,5,6,7";

    my $cmd = "$lbpbindir/mqtt-benchmark.sh"
        . " --dry-run"
        . " --duration $duration"
        . " --runs $runs"
        . " --fixes $fixes"
        . " 2>&1";

    my $output = `$cmd`;
    send_json({ error => 0, output => $output });
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
