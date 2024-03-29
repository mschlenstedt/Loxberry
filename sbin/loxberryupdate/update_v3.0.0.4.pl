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

LOGINF "Moving MQTT scripts to $lbhomedir/webfrontend/html/system/tools/mqtt...";
if ( -d "$lbhomedir/webfrontend/html/mqtt") {
	execute( command => "mv $lbhomedir/webfrontend/html/mqtt $lbhomedir/webfrontend/html/system/tools/mqtt", log => $log, ignoreerrors => 1 );
	execute( command => "chown -R loxberry:loxberry $lbhomedir/webfrontend/html/system/tools/mqtt", log => $log, ignoreerrors => 1 );
}

# Symlinks for compatibility
unlink ("$lbhomedir/webfrontend/html/plugins/mqttgateway/receive.php");
unlink ("$lbhomedir/webfrontend/html/plugins/mqttgateway/receive_pub.php");
unlink ("$lbhomedir/webfrontend/htmlauth/plugins/mqttgateway/mqtt.php");
execute( command => "ln -f -s $lbhomedir/webfrontend/html/system/tools/mqtt/receive.php $lbhomedir/webfrontend/html/plugins/mqttgateway/receive.php", log => $log, ignoreerorrs => 1 );
execute( command => "ln -f -s $lbhomedir/webfrontend/html/system/tools/mqtt/receive_pub.php $lbhomedir/webfrontend/html/plugins/mqttgateway/receive_pub.php", log => $log, ignoreerorrs => 1 );
execute( command => "ln -f -s $lbhomedir/webfrontend/htmlauth/system/tools/mqtt.php $lbhomedir/webfrontend/htmlauth/plugins/mqttgateway/mqtt.php", log => $log, ignoreerorrs => 1 );

# Reset permissions
execute( command => "chown -R loxberry:loxberry $lbhomedir/webfrontend/htmlauth/plugins/mqttgateway", log => $log, ignoreerrors => 1 );
execute( command => "chown -R loxberry:loxberry $lbhomedir/webfrontend/html/plugins/mqttgateway", log => $log, ignoreerrors => 1 );
execute( command => "chown -R loxberry:loxberry $lbhomedir/webfrontend/html/system/tools/mqtt", log => $log, ignoreerrors => 1 );

LOGINF "Restarting MQTT Gateway (Exitcode 255 is fine here)...";
execute( command => "sudo $lbhomedir/sbin/mqtt-handler.pl action=restartgateway", log => $log, ignoreerrors => 1 );

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
