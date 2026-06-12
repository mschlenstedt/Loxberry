#!/usr/bin/perl

# ─────────────────────────────────────────────────────────────────────────────
# MQTT Finder Watchdog
#
# Runs every minute via system/cron/cron.01min/mqttfinderwatchdog (user loxberry).
#
# Problem it solves:
#   The MQTT Finder (sbin/mqttfinder.pl) can keep running while having silently
#   lost its connection to the MQTT broker. When that happens the Finder UI
#   (mqtt-finder.cgi and the gateway subscriptions page) stops updating although
#   the data is present in the broker. The process looks alive, so nothing
#   restarts it.
#
# Detection:
#   The MQTT Gateway publishes a *retained* keepalive epoch every 60 s to
#       <short-hostname>/mqttgateway/keepaliveepoch
#   (the prefix is socket.gethostname() without the domain part — it is NOT the
#   literal "loxberry"; see _gw_topic_base() in sbin/mqtt_gateway.py).
#
#   This watchdog fetches that value fresh from the broker via
#   LoxBerry::IO::mqtt_get and compares it with the value the Finder last stored
#   in /dev/shm/mqttfinder.json. If the Finder lags the broker by more than
#   $THRESHOLD_SECS, the Finder is stuck → it gets killed and restarted.
#
# Why compare the epoch *values* (and not strict equality):
#   * In healthy operation the Finder's stored value routinely lags the broker by
#     exactly one 60 s cycle (sampling is not atomic), so strict equality would
#     cause near-constant false restarts. Only a real lag (> threshold) acts.
#   * If the *Gateway* itself stops, the retained broker value freezes too, so
#     broker == finder → no restart. Correct: restarting the Finder would not
#     help when the Gateway is the one that is down.
# ─────────────────────────────────────────────────────────────────────────────

use strict;
use warnings;
use Sys::Hostname;
use Time::HiRes qw(sleep);
use LoxBerry::System;
use LoxBerry::IO;
use LoxBerry::JSON;
use LoxBerry::Log;

# ---- Configuration ----------------------------------------------------------
my $THRESHOLD_SECS     = 150;   # max allowed lag of Finder behind broker (2.5 keepalive cycles)
my $RESTART_GRACE_SECS = 180;   # do not restart again within this window after a restart
my $datafile           = "/dev/shm/mqttfinder.json";
my $stampfile          = "/dev/shm/mqttfinderwatchdog.laststart";
my $finderscript       = "$lbhomedir/sbin/mqttfinder.pl";
my $perllib            = "$lbhomedir/libs/perllib";

# Keepalive topic — built exactly like the gateway's _gw_topic_base():
#   socket.gethostname().split(".")[0] + "/mqttgateway/keepaliveepoch"
my $host_short = hostname();
$host_short =~ s/\..*$//;
my $keepalive_topic = "$host_short/mqttgateway/keepaliveepoch";

# ---- Helpers ----------------------------------------------------------------

# Return PIDs of the running Finder.
#
# The first letter of the basename is wrapped in a regex class ([m]qttfinder.pl)
# — the classic "grep [p]attern" trick. This stops pgrep -f from matching its
# own command line / the shell wrapper that literally contains the pattern
# (which would otherwise make a dead Finder look alive). It also keeps this
# watchdog (mqttfinderwatchdog.pl) out of the result.
sub finder_pids {
	my $patt = "$lbhomedir/sbin/[m]qttfinder.pl";
	my @out  = `pgrep -f -- '$patt'`;
	chomp @out;
	return grep { /^\d+$/ } @out;
}

# Read the stamp time of the last restart performed by this watchdog.
sub last_restart_time {
	return 0 unless -f $stampfile;
	open( my $fh, '<', $stampfile ) or return 0;
	my $t = <$fh>;
	close($fh);
	$t //= 0;
	chomp $t;
	return ( $t =~ /^\d+$/ ) ? $t : 0;
}

sub write_stamp {
	open( my $fh, '>', $stampfile ) or return;
	print $fh time();
	close($fh);
}

# Kill any running Finder, start a fresh one detached, and log the action.
#
# IMPORTANT: logging must NEVER block the restart. LoxBerry::Log->new dies in a
# non-plugin system script unless 'package' and 'filename' are given — and even
# then we wrap every log call in eval so a logging failure can never stop the
# Finder from being restarted (the restart is this watchdog's only real job).
sub restart_finder {
	my ($reason) = @_;

	my $log = eval {
		LoxBerry::Log->new(
			package  => 'MQTT',
			name     => 'mqttfinderwatchdog',
			filename => "$lbstmpfslogdir/mqttfinderwatchdog.log",
			addtime  => 1,
		);
	};
	eval { LOGSTART "MQTT Finder Watchdog: restarting Finder"; LOGWARN $reason; } if $log;

	my @pids = finder_pids();
	if (@pids) {
		eval { LOGINF "Stopping Finder PID(s): @pids"; } if $log;
		kill 'TERM', @pids;
		# Wait up to 5 s for a clean exit (Finder has a SIGTERM handler).
		for ( 1 .. 10 ) {
			sleep 0.5;
			@pids = finder_pids();
			last unless @pids;
		}
		if (@pids) {
			eval { LOGWARN "Finder still running after TERM, sending KILL: @pids"; } if $log;
			kill 'KILL', @pids;
			sleep 0.5;
		}
	}
	else {
		eval { LOGINF "No running Finder process found — starting a fresh one."; } if $log;
	}

	# Start detached so it survives this cron process exiting. Mirrors the daemon
	# (system/daemons/system/51-mqttfinder) but without su (cron already runs as
	# loxberry). 'env … exec' via setsid leaves no lingering shell wrapper.
	system("setsid env PERL5LIB='$perllib' '$finderscript' >/dev/null 2>&1 &");
	write_stamp();

	eval { LOGOK "Finder (re)started."; LOGEND "Watchdog finished."; } if $log;
}

# ---- Main -------------------------------------------------------------------

# Grace: never restart twice within the grace window. A freshly restarted Finder
# needs up to 60 s to reconnect and receive the first keepalive — without this
# guard the next minute's run would kill it again (restart storm).
if ( ( time() - last_restart_time() ) < $RESTART_GRACE_SECS ) {
	exit 0;
}

# 1) Finder process gone entirely → start it (covers crash / failed boot start).
unless ( finder_pids() ) {
	restart_finder("Finder process is not running.");
	exit 0;
}

# 2) Fetch the broker's keepalive (fresh, retained). 2 s timeout — cron is not
#    time critical. If we cannot get a reliable value (Gateway down / V1 / no
#    retained message), we must NOT restart — there is nothing to compare to.
my $broker = LoxBerry::IO::mqtt_get( $keepalive_topic, 2000 );
unless ( defined $broker && $broker =~ /^\d+$/ ) {
	exit 0;
}

# 3) Read the value the Finder last stored.
my $finder_val;
if ( -f $datafile ) {
	my $jsonobj = LoxBerry::JSON->new();
	my $data = eval { $jsonobj->open( filename => $datafile, readonly => 1 ); };
	if ( $data && ref $data->{incoming} eq 'HASH' ) {
		$finder_val = $data->{incoming}->{$keepalive_topic}->{p};
	}
}

# 4a) Broker has a keepalive but the Finder never recorded it (and we are past
#     the grace window) → the Finder is connected to nothing useful → restart.
unless ( defined $finder_val && $finder_val =~ /^\d+$/ ) {
	restart_finder(
		"Finder has no keepalive value although broker reports $broker — Finder likely disconnected." );
	exit 0;
}

# 4b) Compare. Only a lag larger than the threshold triggers a restart.
my $delta = $broker - $finder_val;
if ( $delta > $THRESHOLD_SECS ) {
	restart_finder(
		"Finder lags broker by ${delta}s (broker=$broker, finder=$finder_val, threshold=${THRESHOLD_SECS}s)." );
	exit 0;
}

# Healthy — stay silent (do not spam the tmpfs log every minute).
exit 0;
