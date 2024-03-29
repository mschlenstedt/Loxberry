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

LOGINF "Repairing broken PHP Installation";
unlink ("/etc/php/7.4/cli/conf.d/20-loxberry-cli.ini");
execute( command => "ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.4/cli/conf.d/20-loxberry-cli.ini", log => $log );

LOGINF "Repairing broken Symlink for USB mount";
#unlink ("$lbhomedir/system/storage/usb");
execute( command => "rm -r $lbhomedir/system/storage/usb", log => $log );
execute( command => "ln -vsfn /media/usb $lbhomedir/system/storage/usb", log => $log );
execute( command => "chown -h loxberry:loxberry $lbhomedir/system/storage/usb", log => $log );

LOGINF "Removing dhcpcd5";
apt_remove("dhcpcd5");

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
