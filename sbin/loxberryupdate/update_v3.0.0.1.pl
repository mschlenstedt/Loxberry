#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::JSON;

init();

# MQTT Gateway migration

LOGINF "The next steps will prepare the Mosquitto MQTT server and MQTT Gateway.";

copy_to_loxberry('/system/sudoers/lbdefaults');
copy_to_loxberry('/system/cron.reboot/02-mqttfinder');
copy_to_loxberry('/system/cron.reboot/04-mqttgateway');



LOGINF "Starting MQTT Gateway migration";

execute( command => "$lbhomedir/sbin/loxberryupdate/mqtt_migration.pl", log => $log, ignoreerrors => 1 );

## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End Skript for reboot
if ($errors) {
	exit(251); 
} else {
	exit(250);
}
