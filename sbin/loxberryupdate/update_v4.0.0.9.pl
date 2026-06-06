#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Deploy 51-mqttfinder daemon script.
# system/daemons/system/ is excluded from rsync (update-exclude.system),
# so daemon scripts must be copied explicitly via copy_to_loxberry.
LOGINF "Installing 51-mqttfinder daemon script...";
copy_to_loxberry('/system/daemons/system/51-mqttfinder');
execute( command => "chmod +x $lbhomedir/system/daemons/system/51-mqttfinder", log => $log );
execute( command => "dos2unix $lbhomedir/system/daemons/system/51-mqttfinder",  log => $log, ignoreerrors => 1 );

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
