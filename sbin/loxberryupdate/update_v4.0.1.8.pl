#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;
use LoxBerry::JSON;

init();

# apache2ctl lives in sbin - not every caller has it in PATH
$ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

# ---------------------------------------------------------------------------
# PHP upload limits for the web interface (#1619)
#
# PHP's defaults from php.ini-production (upload_max_filesize 2M, post_max_size
# 8M) applied - larger uploads of plugins arrived empty. system/php/
# loxberry-apache.ini (linked as conf.d/20-loxberry-apache.ini, read after
# php.ini) now sets 64M / 72M. system/ is excluded from rsync, so the file is
# copied explicitly. mod_php reads its ini files only when Apache (re)loads.
# ---------------------------------------------------------------------------
LOGINF "Raising the PHP upload limits of the web interface (upload_max_filesize 64M, post_max_size 72M)...";
copy_to_loxberry('/system/php/loxberry-apache.ini');

if ( system("systemctl is-active --quiet apache2.service") != 0 ) {
	LOGINF "Apache is not running - the new limits apply with its next start.";
} else {
	my ($cexitcode) = execute( command => "apache2ctl configtest 2>&1", log => $log );
	if ( $cexitcode != 0 ) {
		LOGWARN "Apache configtest failed - Apache is not reloaded, the new limits apply after its next restart.";
	} else {
		# A graceful reload does not cut off the request of an update started from the WebUI
		execute( command => "systemctl reload apache2.service", log => $log, ignoreerrors => 1 );
		sleep(2);
		if ( system("systemctl is-active --quiet apache2.service") == 0 ) {
			LOGOK "Apache reloaded - the new PHP upload limits are active.";
		} else {
			LOGERR "Apache is not running after the reload - starting it again...";
			execute( command => "systemctl restart apache2.service", log => $log, ignoreerrors => 1 );
			$errors++;
		}
	}
}

# ---------------------------------------------------------------------------
# Backup schedule "every n weeks" saved before 4.0.0.15 (#1594)
#
# Up to 4.0.0.14 ajax-backup.cgi put a shell test in front of the command in
# /etc/cron.d/lbclonesd. It never worked (an unescaped % ends a crontab
# command, bash syntax under dash), and the fix for #1543 only applies when
# the schedule is saved again - old schedules kept never running. Remove the
# test from the line and take its anchor date (--date=YYYYMMDD) as
# Schedule.Since, so the schedule keeps its rhythm instead of running weekly.
# ---------------------------------------------------------------------------
LOGINF "Checking the backup schedule for the old 'every n weeks' crontab line...";
{
	my $cronfile = '/etc/cron.d/lbclonesd';
	my @lines;
	if ( open( my $in, '<', $cronfile ) ) {
		@lines = <$in>;
		close($in);
	}
	my $anchor;
	my $changed = 0;
	foreach (@lines) {
		next if ( !/clone_sd_cron\.pl/ or !/\[\[/ );
		($anchor) = /--date=(\d{8})/ if ( !$anchor );
		$changed++ if ( s/\bloxberry\s+\[\[.*?\]\]\s*&&\s*/loxberry / );
	}
	if ( !$changed ) {
		LOGOK "No old backup schedule found - nothing to do.";
	} elsif ( open( my $out, '>', $cronfile ) ) {
		print $out @lines;
		close($out);
		LOGOK "Old shell test removed from $cronfile - the scheduled backup runs again.";
		if ($anchor) {
			my $since = substr( $anchor, 0, 4 ) . '-' . substr( $anchor, 4, 2 ) . '-' . substr( $anchor, 6, 2 );
			my $sobj = LoxBerry::JSON->new();
			my $scfg = $sobj->open( filename => "$lbsconfigdir/general.json", lockexclusive => 1 );
			if ( $scfg and !$scfg->{Backup}->{Schedule}->{Since} ) {
				$scfg->{Backup}->{Schedule}->{Since} = $since;
				$sobj->write();
				LOGOK "Backup schedule anchor date set to $since.";
			}
			undef $sobj;
		}
	} else {
		LOGERR "Could not write $cronfile: $! - please save the backup schedule again in the web interface.";
		$errors++;
	}
}

# ---------------------------------------------------------------------------
# Keep the /dev/shm files of user loxberry (#1608)
#
# loxberry is a normal user for logind (uid >= 1000). With RemoveIPC=yes
# (systemd default) logind deletes all files of loxberry in /dev/shm when its
# last login session ends. During boot that happens when the short su session
# for createconfig.pl has ended and the daemons have not started yet - files
# that cron.reboot scripts of plugins had created by then were lost. The
# setting matters at boot, so logind is not restarted now: it applies from the
# next boot on. The installers write the same file.
# ---------------------------------------------------------------------------
LOGINF "Setting RemoveIPC=no for systemd-logind, so files of user loxberry in /dev/shm are kept...";
{
	my $dropindir = '/etc/systemd/logind.conf.d';
	my $dropin    = "$dropindir/50-loxberry.conf";
	my $content   = "# Installed by LoxBerry - keep /dev/shm files of user loxberry (#1608)\n[Login]\nRemoveIPC=no\n";
	mkdir $dropindir if ( !-d $dropindir );
	my $fh;
	if ( open( $fh, '>', $dropin ) ) {
		print $fh $content;
		close($fh);
		chmod 0644, $dropin;
		LOGOK "$dropin written - active after the next reboot.";
	} else {
		LOGWARN "Could not write $dropin: $! - files of user loxberry in /dev/shm may still be removed during boot.";
	}
}

# ---------------------------------------------------------------------------
# Watchdog: the Logging setting also controls the daemon's verbosity (#1596)
#
# The installers and update_v1.4 always started the watchdog daemon with -v
# (/etc/default/watchdog). It writes status lines every few seconds to
# log/system/watchdog.log on the SD card, whatever the Logging setting says.
# services_watchdog.cgi now switches -v with the setting; apply the stored
# setting once. sbin/serviceshelper is already updated by the rsync.
# ---------------------------------------------------------------------------
if ( -e "/etc/default/watchdog" ) {
	LOGINF "Applying the Watchdog logging setting to the verbosity of the watchdog daemon...";
	my $wdcfg = LoxBerry::JSON->new()->open( filename => "$lbsconfigdir/general.json", readonly => 1 );
	my $wdlogging = ( $wdcfg && $wdcfg->{Watchdog} && is_enabled( $wdcfg->{Watchdog}->{Logging} ) ) ? 1 : 0;
	my ($wdexitcode) = execute( command => "$lbhomedir/sbin/serviceshelper watchdog_logging $wdlogging", log => $log, ignoreerrors => 1 );
	if ( $wdexitcode != 0 ) {
		LOGWARN "Could not change /etc/default/watchdog (exit code $wdexitcode) - saving the Watchdog settings in the web interface does it again.";
	} elsif ( system("systemctl is-active --quiet watchdog.service") != 0 ) {
		LOGOK "Watchdog verbosity set (" . ( $wdlogging ? "on" : "off" ) . ") - the watchdog is not running, it applies with its next start.";
	} else {
		my ($wdrestartcode) = execute( command => "systemctl restart watchdog.service", log => $log, ignoreerrors => 1 );
		if ( $wdrestartcode != 0 or system("systemctl is-active --quiet watchdog.service") != 0 ) {
			# Debian's OnFailure=wd_keepalive can cancel the start job of a restart
			LOGWARN "Watchdog restart failed - starting it explicitly...";
			execute( command => "systemctl start watchdog.service", log => $log, ignoreerrors => 1 );
		}
		LOGOK "Watchdog verbosity set (" . ( $wdlogging ? "on" : "off" ) . ") and watchdog restarted.";
	}
} else {
	LOGINF "No /etc/default/watchdog - watchdog not installed, nothing to do.";
}

# ---------------------------------------------------------------------------
# Restart MQTT Gateway V2
#
# rsync replaced sbin/mqtt_gateway.py, but the running gateway keeps the old
# code until it is restarted - since 4.0.1.7 that is the firewall guard
# (d14cc1cd) and the V1 send behaviour (#1620, #1622). bootstart is the same
# way as at boot: it starts only with Gatewayautostart, so a gateway stopped
# on purpose stays stopped. Gateway V1 is not touched.
# ---------------------------------------------------------------------------
my $cfg = LoxBerry::JSON->new()->open( filename => "$lbsconfigdir/general.json", readonly => 1 );
my $gwversion = ( $cfg && $cfg->{Mqtt} ) ? ( $cfg->{Mqtt}->{Gatewayversion} // 1 ) : 1;
my $autostart = ( $cfg && $cfg->{Mqtt} ) ? ( $cfg->{Mqtt}->{Gatewayautostart} // 1 ) : 1;

if ( $gwversion ne '2' ) {
	LOGINF "MQTT Gateway V1 is active - nothing to restart.";
} elsif ( !is_enabled($autostart) ) {
	LOGINF "MQTT Gateway V2 was stopped on purpose - it stays stopped.";
} else {
	LOGINF "Restarting MQTT Gateway V2, so it runs the updated code...";
	my ($gexitcode) = execute( command => "$lbhomedir/sbin/mqtt-handler.pl action=bootstart", log => $log );
	if ( $gexitcode == 0 ) {
		LOGOK "MQTT Gateway V2 restarted.";
	} else {
		LOGWARN "Restarting MQTT Gateway V2 failed (exit code $gexitcode) - the gateway watchdog or the next reboot starts it.";
	}
}

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
