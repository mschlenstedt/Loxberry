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

# ---------------------------------------------------------------------------
# Watchdog logging setting also controls the watchdog daemon's verbosity.
#
# Historical installations start the Debian watchdog daemon with -v
# (/etc/default/watchdog), independent of the GUI setting Watchdog.Logging.
# Apply the persisted setting once; the GUI keeps it in sync from now on.
# sbin/serviceshelper is already updated by the rsync.
# ---------------------------------------------------------------------------
LOGINF "Applying the Watchdog logging setting to daemon verbosity...";
my $watchdogjson = LoxBerry::JSON->new();
my $watchdogcfg = $watchdogjson->open(filename => "$lbsconfigdir/general.json", readonly => 1);
my $watchdoglogging = is_enabled($watchdogcfg->{Watchdog}->{Logging}) ? 1 : 0;
my ($wdexitcode) = execute(
	command => "$lbhomedir/sbin/serviceshelper watchdog_logging $watchdoglogging",
	log => $log,
);
if ( $wdexitcode == 0 ) {
	my ($wdrestartcode) = execute(
		command => "systemctl try-restart watchdog.service",
		log => $log,
		ignoreerrors => 1,
	);
	if ( $wdrestartcode != 0 ) {
		# Debian's OnFailure keepalive job can cancel the restart's start job.
		LOGWARN "Watchdog restart failed; trying an explicit start to restore monitoring...";
		execute( command => "systemctl start watchdog.service", log => $log );
	}
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
