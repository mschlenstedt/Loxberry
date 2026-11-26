#!/usr/bin/perl
# mqtt-notify-publisher.pl
# Reads LoxBerry notification DB and publishes stats to MQTT broker.
# Called non-blocking from LoxBerry::Log (notify_ext, delete_notifications,
# delete_notification_key) and from the Python library whenever notifications
# are created or deleted (#1618).
#
# Counts only what the WebUI shows: errors (SEVERITY 3) and infos (SEVERITY 6).
# Helper entries with other severities (e.g. 7) are ignored.

use strict;
use warnings;
use utf8;
use JSON;
use DBI;
use Fcntl qw(:flock);
use lib '/opt/loxberry/libs/perllib';
use LoxBerry::System;
use LoxBerry::IO;

my $lockfile  = "/dev/shm/mqtt-notify-publisher.lock";

# One run at a time: several calls can start within milliseconds. Each run
# reads the database only after it holds the lock, so the last run always
# publishes the newest state (an older, slower run cannot overwrite it).
my $lfh;
if ( open($lfh, '>>', $lockfile) ) {
	chmod 0666, $lockfile;   # created by root or loxberry - both must open it
	my $locked = 0;
	for ( 1 .. 300 ) {   # wait up to 30 s
		if ( flock($lfh, LOCK_EX | LOCK_NB) ) { $locked = 1; last; }
		select(undef, undef, undef, 0.1);
	}
	exit 0 unless $locked;
}

my $dbfile = "$LoxBerry::System::lbsdatadir/notifications_sqlite.dat";
exit 0 unless -f $dbfile;

# Connect to SQLite DB
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "", { RaiseError => 0, PrintError => 0 });
exit 0 unless $dbh;
$dbh->{sqlite_unicode} = 1;

# Join notifications with _ISPLUGIN / _ISSYSTEM attributes
my $rows = $dbh->selectall_arrayref(q{
    SELECT
        n.PACKAGE,
        n.NAME,
        n.MESSAGE,
        n.SEVERITY,
        n.timestamp,
        MAX(CASE WHEN a.attrib = '_ISPLUGIN' THEN a.value ELSE NULL END) AS isplugin,
        MAX(CASE WHEN a.attrib = '_ISSYSTEM' THEN a.value ELSE NULL END) AS issystem
    FROM notifications n
    LEFT JOIN notifications_attr a ON a.keyref = n.notifykey
    WHERE n.SEVERITY IN (3, 6)
    GROUP BY n.notifykey
    ORDER BY n.notifykey ASC
}, { Slice => {} });
$dbh->disconnect;
# An empty table is a valid state: then all counters are 0 (#1618)
exit 0 unless $rows;

# --- Aggregate stats ---
my (%plugin, %system);
my ($total_count, $total_errors, $total_infos) = (0, 0, 0);

for my $r (@$rows) {
    my $pkg     = $r->{PACKAGE} || 'unknown';
    my $sev     = $r->{SEVERITY} || 0;
    my $is_err  = ($sev == 3) ? 1 : 0;
    my $is_info = ($sev == 6) ? 1 : 0;
    my $is_plugin = ($r->{isplugin} && $r->{isplugin} eq '1') ? 1 : 0;

    $total_count++;
    $total_errors++ if $is_err;
    $total_infos++  if $is_info;

    my $bucket = $is_plugin ? \%plugin : \%system;
    $bucket->{$pkg}{count}++;
    $bucket->{$pkg}{errors}++ if $is_err;
    $bucket->{$pkg}{infos}++  if $is_info;
    # Keep last (= highest notifykey = most recent) message per package
    $bucket->{$pkg}{last} = {
        message   => $r->{MESSAGE},
        severity  => $sev,
        name      => $r->{NAME},
        timestamp => $r->{timestamp},
    };
}

# --- Connect via LoxBerry MQTT lib ---
my $mqtt = LoxBerry::IO::mqtt_connect();
exit 0 unless $mqtt;

# Topic base is the short hostname (like healthcheck), not literal "loxberry" —
# multiple LoxBerrys may share one broker (issue #1527)
my $hostname = LoxBerry::System::lbhostname();
my $dotpos = index( $hostname, '.' );
if( $dotpos > -1 ) {
    $hostname = substr( $hostname, 0, $dotpos );
}
my $topicbase = "$hostname/notifies";

# Helper: publish retained topic via LoxBerry::IO
sub pub { LoxBerry::IO::mqtt_retain($_[0], $_[1]) }

pub("$topicbase/count",  $total_count);
pub("$topicbase/errors", $total_errors);
pub("$topicbase/infos",  $total_infos);

for my $pkg (sort keys %plugin) {
    my $d    = $plugin{$pkg};
    my $base = "$topicbase/plugins/$pkg";
    pub("$base/count",        $d->{count}  || 0);
    pub("$base/errors",       $d->{errors} || 0);
    pub("$base/infos",        $d->{infos}  || 0);
    pub("$base/last_message", encode_json($d->{last})) if $d->{last};
}

for my $pkg (sort keys %system) {
    my $d    = $system{$pkg};
    my $base = "$topicbase/system/$pkg";
    pub("$base/count",        $d->{count}  || 0);
    pub("$base/errors",       $d->{errors} || 0);
    pub("$base/infos",        $d->{infos}  || 0);
    pub("$base/last_message", encode_json($d->{last})) if $d->{last};
}

# --- Packages without notifications any more: remove their retained topics ---
# Without this, the topics of a package whose last notification was deleted
# kept their old numbers forever (#1618). The packages that have topics are
# read back from the broker (retained .../count), so topics left over from
# older versions are cleaned up as well.
my %seen = ( plugins => {}, system => {} );
eval {
    $mqtt->subscribe(
        "$topicbase/plugins/+/count" => sub { $seen{plugins}{$1} = 1 if $_[0] =~ m{/plugins/([^/]+)/count$} },
        "$topicbase/system/+/count"  => sub { $seen{system}{$1}  = 1 if $_[0] =~ m{/system/([^/]+)/count$} },
    );
    my $end = time + 1;   # the broker sends the retained messages right after the subscribe
    $mqtt->tick(0.2) while ( time < $end );
    $mqtt->unsubscribe("$topicbase/plugins/+/count", "$topicbase/system/+/count");
};
for my $kind ( [ 'plugins', \%plugin ], [ 'system', \%system ] ) {
    my ($name, $current) = @$kind;
    for my $pkg ( sort keys %{ $seen{$name} } ) {
        next if exists $current->{$pkg};
        my $base = "$topicbase/$name/$pkg";
        pub("$base/$_", "") for qw(count errors infos last_message);   # empty retained = delete
    }
}

exit 0;
