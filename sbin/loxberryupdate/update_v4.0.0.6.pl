#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Remove old MQTT Gateway V2 venv from sbin/ — it has been moved to
# system/python_venv/mqttgateway/ and will be recreated there on next start.

my $old_venv = "$lbhomedir/sbin/mqttgateway_venv";

LOGINF "Checking for old MQTT Gateway venv at $old_venv...";

if ( -d $old_venv ) {
    execute( command => "rm -rf '$old_venv'", log => $log );
    LOGOK "Old venv removed: $old_venv" if ($errors == 0);
} else {
    LOGOK "Old venv not present — nothing to do.";
}

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

exit($errors);
