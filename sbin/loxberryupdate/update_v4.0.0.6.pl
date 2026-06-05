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
# system/python_venv/mqttgateway/.

my $old_venv = "$lbhomedir/sbin/mqttgateway_venv";
my $venv_dir  = "$lbhomedir/system/python_venv/mqttgateway";
my $req       = "$lbhomedir/system/python_venv/requirements_mqttgateway.txt";

LOGINF "Checking for old MQTT Gateway venv at $old_venv...";
if ( -d $old_venv ) {
    execute( command => "rm -rf '$old_venv'", log => $log );
    LOGOK "Old venv removed: $old_venv" if ($errors == 0);
} else {
    LOGOK "Old venv not present — nothing to do.";
}

# Create new venv at system/python_venv/mqttgateway/ so the first gateway
# start after the update does not stall on venv installation.
LOGINF "Creating MQTT Gateway venv at $venv_dir...";
execute( command => "python3 -m venv '$venv_dir'", log => $log );
if ( -f $req ) {
    execute( command => "'$venv_dir/bin/pip' install -q -r '$req'", log => $log );
} else {
    execute( command => "'$venv_dir/bin/pip' install -q aiomqtt aiohttp", log => $log );
}
execute( command => "chown -R loxberry:loxberry '$venv_dir'", log => $log );
LOGOK "MQTT Gateway venv created." if ($errors == 0);

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

exit($errors);
