#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Deploy the MQTT Finder Watchdog cron job.
#
# system/cron/ is excluded from the update rsync (update-exclude.system), so the
# cron file must be copied explicitly via copy_to_loxberry. The watchdog itself
# (sbin/mqttfinderwatchdog.pl) lives outside system/ and is installed by the
# normal rsync — here we only make sure it is executable.
LOGINF "Installing MQTT Finder Watchdog cron job (cron.01min)...";
copy_to_loxberry('/system/cron/cron.01min/mqttfinderwatchdog');
execute( command => "chmod +x $lbhomedir/system/cron/cron.01min/mqttfinderwatchdog", log => $log );
execute( command => "dos2unix $lbhomedir/system/cron/cron.01min/mqttfinderwatchdog", log => $log, ignoreerrors => 1 );

LOGINF "Ensuring MQTT Finder Watchdog script is executable...";
execute( command => "chmod +x $lbhomedir/sbin/mqttfinderwatchdog.pl", log => $log );
execute( command => "dos2unix $lbhomedir/sbin/mqttfinderwatchdog.pl",  log => $log, ignoreerrors => 1 );

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
