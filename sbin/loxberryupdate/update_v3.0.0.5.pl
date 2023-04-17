#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::JSON;
use LoxBerry::System;

init();

if ( -e "/boot/dietpi/.hw_model" ) {
	LOGINF "Repairing broken Cron Service on DietPis prior to 8.16...";
	execute( command => "systemctl unmask cron.service", log => $log, ignoreerrors => 1 );
	execute( command => "systemctl enable cron.service", log => $log, ignoreerrors => 1 );
	execute( command => "systemctl start cron.service", log => $log, ignoreerrors => 1 );
	execute( command => "systemctl status cron.service", log => $log, ignoreerrors => 1 );
}

LOGOK "Done.";

## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
# reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End Skript for reboot
# Just to remeber for the next Major update: Exit this script with 250 or 250 will popup a "reboot.force" messages,
# because update process will continue after reboot the loxberry

exit($errors);
