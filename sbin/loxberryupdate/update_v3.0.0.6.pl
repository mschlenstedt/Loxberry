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
	LOGINF "Recreating User 'dietpi' if not exist...";
	execute( command => "adduser --no-create-home --home /home/dietpi --disabled-password --gecos '' dietpi", log => $log, ignoreerrors => 1 );
	execute( command => "echo \"dietpi:\$(echo \$random | md5sum | head -c 20; echo)\" | /usr/sbin/chpasswd -c SHA512", log => $log, ignoreerrors => 1 );
}

LOGINF "Copying new autofs config for netshares...";
copy_to_loxberry("/system/autofs/auto.smb", "loxberry");

if ( -e "$lbhomedir/system/storage/smb/.dummy" ) {
	LOGINF "Cleaning dummy file from $lbhomedir/system/storage/smb...";
	unlink ( "$lbhomedir/system/storage/smb/.dummy" );
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
