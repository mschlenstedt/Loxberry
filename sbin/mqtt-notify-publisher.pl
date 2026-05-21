#!/usr/bin/perl
# mqtt-notify-publisher.pl
# Reads LoxBerry notification DB and publishes stats to MQTT broker.
# Called non-blocking from notify_ext() in LoxBerry::Log.

use strict;
use warnings;
use JSON;
use DBI;

my $lbhomedir = $ENV{LBHOMEDIR} || '/opt/loxberry';
my $dbfile     = "$lbhomedir/data/system/notifications_sqlite.dat";
my $cfgfile    = "$lbhomedir/config/system/general.json";

exit 0 unless -f $dbfile;
exit 0 unless -f $cfgfile;

# Read MQTT broker config from general.json
my $json_text = do { local $/; open my $fh, '<', $cfgfile or exit 0; <$fh> };
my $cfg = eval { decode_json($json_text) } or exit 0;

my $mqtt_cfg   = $cfg->{Mqtt} or exit 0;
my $broker     = $mqtt_cfg->{Brokerhost} || 'localhost';
my $port       = $mqtt_cfg->{Brokerport} || 1883;
my $user       = $mqtt_cfg->{Brokeruser} || '';
my $pass       = $mqtt_cfg->{Brokerpass} || '';

# Connect to SQLite DB
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "", { RaiseError => 0, PrintError => 0 });
exit 0 unless $dbh;
$dbh->{sqlite_unicode} = 1;

# Join notifications with _ISPLUGIN / _ISSYSTEM attributes
my $sql = <<'SQL';
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
SQL

my $rows = $dbh->selectall_arrayref($sql, { Slice => {} });
$dbh->disconnect;
exit 0 unless $rows && @$rows;

# --- Aggregate stats ---
my (%plugin, %system);
my ($total_count, $total_errors, $total_infos) = (0, 0, 0);

for my $r (@$rows) {
    my $pkg      = $r->{PACKAGE} || 'unknown';
    my $sev      = $r->{SEVERITY} || 0;
    my $is_err   = ($sev <= 3) ? 1 : 0;
    my $is_info  = ($sev == 6) ? 1 : 0;
    my $is_plugin = ($r->{isplugin} && $r->{isplugin} eq '1') ? 1 : 0;
    my $is_system = ($r->{issystem} && $r->{issystem} eq '1') ? 1 : 0;

    $total_count++;
    $total_errors++ if $is_err;
    $total_infos++  if $is_info;

    my $bucket = $is_plugin ? \%plugin : \%system;
    $bucket->{$pkg}{count}++;
    $bucket->{$pkg}{errors}++ if $is_err;
    $bucket->{$pkg}{infos}++  if $is_info;
    # Keep the last (highest notifykey = last inserted) message for each package
    $bucket->{$pkg}{last} = {
        message   => $r->{MESSAGE},
        severity  => $sev,
        name      => $r->{NAME},
        timestamp => $r->{timestamp},
    };
}

# --- Build publish list ---
my @msgs; # [ topic, payload ]

push @msgs, [ 'loxberry/notifies/count',  $total_count  ];
push @msgs, [ 'loxberry/notifies/errors', $total_errors ];
push @msgs, [ 'loxberry/notifies/infos',  $total_infos  ];

for my $pkg (sort keys %plugin) {
    my $d = $plugin{$pkg};
    my $base = "loxberry/notifies/plugins/$pkg";
    push @msgs, [ "$base/count",        $d->{count}  || 0 ];
    push @msgs, [ "$base/errors",       $d->{errors} || 0 ];
    push @msgs, [ "$base/infos",        $d->{infos}  || 0 ];
    push @msgs, [ "$base/last_message", encode_json($d->{last}) ] if $d->{last};
}

for my $pkg (sort keys %system) {
    my $d = $system{$pkg};
    my $base = "loxberry/notifies/system/$pkg";
    push @msgs, [ "$base/count",        $d->{count}  || 0 ];
    push @msgs, [ "$base/errors",       $d->{errors} || 0 ];
    push @msgs, [ "$base/infos",        $d->{infos}  || 0 ];
    push @msgs, [ "$base/last_message", encode_json($d->{last}) ] if $d->{last};
}

# --- Publish via Net::MQTT::Simple ---
eval { require Net::MQTT::Simple };
if ($@) {
    # Fallback: mosquitto_pub CLI
    for my $m (@msgs) {
        my @cmd = ('mosquitto_pub', '-h', $broker, '-p', $port,
                   '-t', $m->[0], '-m', $m->[1], '-r');
        push @cmd, ('-u', $user, '-P', $pass) if $user;
        system(@cmd);
    }
    exit 0;
}

# Net::MQTT::Simple path
my $mqtt_host = $port != 1883 ? "$broker:$port" : $broker;
my $mqtt;
eval {
    $mqtt = Net::MQTT::Simple->new($mqtt_host);
    $mqtt->login($user, $pass) if $user;
};
exit 0 if $@ || !$mqtt;

for my $m (@msgs) {
    eval { $mqtt->retain($m->[0], $m->[1]) };
}

exit 0;
