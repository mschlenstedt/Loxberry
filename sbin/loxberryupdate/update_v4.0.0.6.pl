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
    my ($rc) = execute( command => "rm -rf '$old_venv'", log => $log );
    $errors++ if $rc != 0;
    LOGOK "Old venv removed: $old_venv" if $rc == 0;
} else {
    LOGOK "Old venv not present — nothing to do.";
}

# Ensure python3-venv is installed before creating the venv.
apt_install('python3-venv');

# Create new venv at system/python_venv/mqttgateway/ so the first gateway
# start after the update does not stall on venv installation.
LOGINF "Creating MQTT Gateway venv at $venv_dir...";
my ($rc_venv) = execute( command => "python3 -m venv '$venv_dir'", log => $log );
$errors++ if $rc_venv != 0;
if ( $rc_venv == 0 ) {
    my ($rc_pip);
    if ( -f $req ) {
        ($rc_pip) = execute( command => "'$venv_dir/bin/pip' install -q -r '$req'", log => $log );
    } else {
        ($rc_pip) = execute( command => "'$venv_dir/bin/pip' install -q aiomqtt aiohttp", log => $log );
    }
    $errors++ if $rc_pip != 0;
}
execute( command => "chown -R loxberry:loxberry '$venv_dir'", log => $log );
LOGOK "MQTT Gateway venv created." if $errors == 0;

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

exit($errors);
