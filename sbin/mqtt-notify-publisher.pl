#!/usr/bin/perl
# mqtt-notify-publisher.pl
# Reads LoxBerry notification DB and publishes stats to MQTT broker.
# Called non-blocking from notify_ext() in LoxBerry::Log.

use strict;
use warnings;
use utf8;
use JSON;
use DBI;
use lib '/opt/loxberry/libs/perllib';
use LoxBerry::System;
use LoxBerry::IO;

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
    GROUP BY n.notifykey
    ORDER BY n.notifykey ASC
}, { Slice => {} });
$dbh->disconnect;
exit 0 unless $rows && @$rows;

# --- Aggregate stats ---
my (%plugin, %system);
my ($total_count, $total_errors, $total_infos) = (0, 0, 0);

for my $r (@$rows) {
    my $pkg     = $r->{PACKAGE} || 'unknown';
    my $sev     = $r->{SEVERITY} || 0;
    my $is_err  = ($sev <= 3) ? 1 : 0;
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

# Helper: publish retained topic via LoxBerry::IO
sub pub { LoxBerry::IO::mqtt_retain($_[0], $_[1]) }

pub('loxberry/notifies/count',  $total_count);
pub('loxberry/notifies/errors', $total_errors);
pub('loxberry/notifies/infos',  $total_infos);

for my $pkg (sort keys %plugin) {
    my $d    = $plugin{$pkg};
    my $base = "loxberry/notifies/plugins/$pkg";
    pub("$base/count",        $d->{count}  || 0);
    pub("$base/errors",       $d->{errors} || 0);
    pub("$base/infos",        $d->{infos}  || 0);
    pub("$base/last_message", encode_json($d->{last})) if $d->{last};
}

for my $pkg (sort keys %system) {
    my $d    = $system{$pkg};
    my $base = "loxberry/notifies/system/$pkg";
    pub("$base/count",        $d->{count}  || 0);
    pub("$base/errors",       $d->{errors} || 0);
    pub("$base/infos",        $d->{infos}  || 0);
    pub("$base/last_message", encode_json($d->{last})) if $d->{last};
}

exit 0;
