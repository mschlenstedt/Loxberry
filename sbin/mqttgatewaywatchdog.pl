#!/usr/bin/perl
# ─────────────────────────────────────────────────────────────────────────────
# MQTT Gateway V2 Watchdog
#
# Runs every minute via system/cron/cron.01min/mqttgatewaywatchdog (user loxberry).
#
# Problem it solves (#1567):
#   MQTT Gateway V2 (sbin/mqtt_gateway.py) can crash or hang. Nothing restarted
#   it - the Healthcheck only reports - so the Miniserver got no values until
#   someone restarted the gateway by hand.
#
# Checks only if all of these hold, otherwise it exits silently:
#   - Mqtt.Gatewayversion is 2
#   - Mqtt.Gatewayautostart is enabled ("Stop" in the WebUI sets it to 0 - a
#     gateway stopped on purpose stays stopped)
#   - at least one Miniserver is configured (the gateway does not start without)
#   - the system is up for more than $BOOT_GRACE_SECS: cron.01min runs before
#     loxberryinit.sh starts the daemons, so the watchdog would race the boot
#     start (same trap as the MQTT Finder in #1578)
#   - no LoxBerry update or plugin installation is running
#
# Detection:
#   1. No V2 process (PID file /dev/shm/mqtt_gateway.pid, pgrep as fallback).
#   2. The process runs, but the retained keepalive it publishes every 60 s to
#        <short-hostname>/mqttgateway/keepaliveepoch
#      is older than $KEEPALIVE_MAX_AGE_SECS: the gateway hangs or lost the
#      broker. Read fresh from the broker via LoxBerry::IO::mqtt_get. If the
#      broker does not answer, the watchdog does nothing - then the broker is
#      the problem, and V2 reconnects by itself. The keepalive is only checked
#      for a process older than $KEEPALIVE_MAX_AGE_SECS, so a gateway that is
#      still connecting after a restart is left alone.
#
# Action:
#   "mqtt-handler.pl action=bootstart" via sudo - the same path as at boot. It
#   honours Gatewayautostart, checks the Miniserver, stops leftovers and starts
#   V2 as loxberry. Logged (only when acting) to mqttgatewaywatchdog.log, plus a
#   LoxBerry notification.
#
# Restart storm protection:
#   At least $RESTART_GRACE_SECS between two restarts. After $MAX_RESTARTS
#   restarts within $MAX_RESTARTS_WINDOW the watchdog gives up for the rest of
#   that window, logs an error and sends one notification.
# ─────────────────────────────────────────────────────────────────────────────

use strict;
use warnings;
use Sys::Hostname;
use LoxBerry::System;
use LoxBerry::IO;
use LoxBerry::JSON;
use LoxBerry::Log;

# ---- Configuration ----------------------------------------------------------
my $KEEPALIVE_MAX_AGE_SECS = 180;    # 3 keepalive cycles
my $RESTART_GRACE_SECS     = 300;    # min. time between two restarts
my $MAX_RESTARTS           = 3;      # restarts allowed within the window ...
my $MAX_RESTARTS_WINDOW    = 3600;   # ... of one hour
my $BOOT_GRACE_SECS        = 300;    # leave the boot start alone

my $pidfile      = "/dev/shm/mqtt_gateway.pid";
my $statefile    = "/dev/shm/mqttgatewaywatchdog.state";
my $generaljson  = "$lbsconfigdir/general.json";
my @lockfiles    = ( "/var/lock/lbupdate.lock", "/var/lock/plugininstall.lock" );

# Keepalive topic - built exactly like _gw_topic_base() in sbin/mqtt_gateway.py:
#   socket.gethostname().split(".")[0] + "/mqttgateway/keepaliveepoch"
my $host_short = hostname();
$host_short =~ s/\..*$//;
my $keepalive_topic = "$host_short/mqttgateway/keepaliveepoch";

# ---- Helpers ----------------------------------------------------------------

# PID of the running V2 gateway, or undef. The PID file is the primary source;
# pgrep with the "[m]" trick catches an instance without PID file and keeps
# pgrep from matching its own command line.
sub gateway_pid {
	if ( open( my $fh, '<', $pidfile ) ) {
		my $pid = <$fh> // '';
		close $fh;
		$pid =~ s/\s+//g;
		return $pid if ( $pid =~ /^\d+$/ and -d "/proc/$pid" );
	}
	my @out = `pgrep -f -- '$lbhomedir/sbin/[m]qtt_gateway.py'`;
	chomp @out;
	my @pids = grep { /^\d+$/ } @out;
	return @pids ? $pids[0] : undef;
}

# Seconds since the process started
sub process_age {
	my ($pid) = @_;
	my $age = `ps -o etimes= -p $pid 2>/dev/null`;
	$age =~ s/\s+//g;
	return ( $age =~ /^\d+$/ ) ? $age : 0;
}

sub uptime_secs {
	open( my $fh, '<', '/proc/uptime' ) or return 0;
	my ($up) = split( /\s+/, <$fh> // '0' );
	close $fh;
	return int($up);
}

# State file: one line per restart ("restart <epoch>"), plus "giveup <epoch>"
# when the watchdog stopped trying for the current window.
sub read_state {
	my %state = ( restarts => [], giveup => 0 );
	open( my $fh, '<', $statefile ) or return %state;
	while ( my $line = <$fh> ) {
		if    ( $line =~ /^restart (\d+)/ ) { push @{ $state{restarts} }, $1; }
		elsif ( $line =~ /^giveup (\d+)/ )  { $state{giveup} = $1; }
	}
	close $fh;
	return %state;
}

sub write_state {
	my (%state) = @_;
	my $now = time();
	open( my $fh, '>', $statefile ) or return;
	# Keep only restarts within the window
	print $fh "restart $_\n" for grep { $_ > $now - $MAX_RESTARTS_WINDOW } @{ $state{restarts} };
	print $fh "giveup $state{giveup}\n" if ( $state{giveup} );
	close $fh;
}

# Logging must never stop the restart - every log call is wrapped in eval
sub open_log {
	return eval {
		LoxBerry::Log->new(
			package  => 'mqtt',
			name     => 'mqttgatewaywatchdog',
			filename => "$lbstmpfslogdir/mqttgatewaywatchdog.log",
			append   => 1,	# keep earlier restarts - they are what users report
			addtime  => 1,
		);
	};
}

sub notify_user {
	my ( $severity, $message ) = @_;
	eval {
		LoxBerry::Log::notify_ext( {
			PACKAGE  => "mqtt",
			NAME     => "gatewaywatchdog",
			SEVERITY => $severity,
			MESSAGE  => $message,
		} );
	};
}

sub restart_gateway {
	my ( $reason, %state ) = @_;
	my $now = time();
	my $log = open_log();
	eval { LOGSTART "MQTT Gateway V2 Watchdog: restarting gateway"; LOGWARN $reason; } if $log;

	# Too many restarts within the window: give up until the window has passed
	my @recent = grep { $_ > $now - $MAX_RESTARTS_WINDOW } @{ $state{restarts} };
	if ( @recent >= $MAX_RESTARTS ) {
		my $msg = "MQTT Gateway V2 was restarted $MAX_RESTARTS times within " . ( $MAX_RESTARTS_WINDOW / 60 ) . " minutes and keeps failing. The watchdog stops restarting it for now - please check the MQTT Gateway log and the watchdog log.";
		eval { LOGERR $msg; LOGEND "Watchdog gave up."; } if $log;
		notify_user( 3, $msg );
		$state{giveup} = $now;
		write_state(%state);
		return;
	}

	my $output = `sudo -n $lbhomedir/sbin/mqtt-handler.pl action=bootstart 2>&1`;
	my $rc = $? >> 8;
	push @{ $state{restarts} }, $now;
	$state{giveup} = 0;
	write_state(%state);

	if ( $rc == 0 ) {
		eval { LOGOK "Gateway restart triggered (mqtt-handler.pl action=bootstart)."; LOGEND "Watchdog finished."; } if $log;
		notify_user( 6, "MQTT Gateway V2 was restarted by the watchdog: $reason" );
	} else {
		eval { LOGERR "mqtt-handler.pl action=bootstart failed (exit code $rc): $output"; LOGEND "Watchdog finished with errors."; } if $log;
		notify_user( 3, "MQTT Gateway V2 watchdog could not restart the gateway (exit code $rc). Please check the watchdog log." );
	}
}

# ---- Main -------------------------------------------------------------------

# Only V2, only if the gateway is meant to run
my $cfg = eval { LoxBerry::JSON->new()->open( filename => $generaljson, readonly => 1 ) };
exit 0 unless ( $cfg and ref $cfg->{Mqtt} eq 'HASH' );
exit 0 unless ( ( $cfg->{Mqtt}->{Gatewayversion} // 1 ) == 2 );
exit 0 unless ( is_enabled( $cfg->{Mqtt}->{Gatewayautostart} // 1 ) );

my %miniservers = LoxBerry::System::get_miniservers();
exit 0 unless (%miniservers);

exit 0 if ( uptime_secs() < $BOOT_GRACE_SECS );
exit 0 if ( grep { -e $_ } @lockfiles );

my %state = read_state();
my $now   = time();
my @own   = @{ $state{restarts} };
exit 0 if ( @own and $now - $own[-1] < $RESTART_GRACE_SECS );
exit 0 if ( $state{giveup} and $now - $state{giveup} < $MAX_RESTARTS_WINDOW );

# 1) No V2 process
my $pid = gateway_pid();
unless ($pid) {
	restart_gateway( "MQTT Gateway V2 is not running.", %state );
	exit 0;
}

# 2) Process runs - is it still publishing its keepalive?
exit 0 if ( process_age($pid) < $KEEPALIVE_MAX_AGE_SECS );

my $keepalive = eval { LoxBerry::IO::mqtt_get( $keepalive_topic, 2000 ) };
# Broker does not answer or there is no keepalive at all: nothing reliable to
# judge by - leave it to the gateway's own reconnect.
exit 0 unless ( defined $keepalive and $keepalive =~ /^\d+$/ );

my $age = $now - $keepalive;
if ( $age > $KEEPALIVE_MAX_AGE_SECS ) {
	restart_gateway( "MQTT Gateway V2 (PID $pid) runs, but its keepalive in the broker is ${age}s old (limit ${KEEPALIVE_MAX_AGE_SECS}s) - it hangs or lost the broker connection.", %state );
	exit 0;
}

# Healthy - stay silent (the log directory is a RAM disk)
exit 0;
