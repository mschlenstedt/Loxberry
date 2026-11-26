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
