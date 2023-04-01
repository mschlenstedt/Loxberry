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

LOGINF "Repairing broken Mosquitto Installation";

# Install Mosquitto and overwrite modified conf files with original configuration
execute( command => "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::='--force-confask,confnew,confmiss' install mosquitto", log => $log, ignoreerrors => 1 );
	
execute( command => "mkdir --parents /opt/backup.mqttgateway", log => $log, ignoreerrors => 1);

if ( -e "/etc/mosquitto/mosquitto.conf.dpkg-dist" ) {
	execute( command => "cp /etc/mosquitto/mosquitto.conf /opt/backup.mqttgateway/etc_mosquitto.conf", log => $log );
	unlink ("/etc/mosquitto/mosquitto.conf");
	execute( command => "mv /etc/mosquitto/mosquitto.conf.dpkg-dist /etc/mosquitto/mosquitto.conf", log => $log );
}

if ( -e "/etc/mosquitto/mosquitto.conf.dpkg-old" ) {
	execute( command => "cp /etc/mosquitto/mosquitto.conf.dpkg-old /opt/backup.mqttgateway/etc_mosquitto.conf", log => $log );
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
