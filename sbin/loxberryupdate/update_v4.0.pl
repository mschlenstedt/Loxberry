#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Install thin daemon wrapper so future updates to 50-mqttgateway-boot.sh
# (in sbin/, covered by rsync) take effect without manual steps.
LOGINF "Installing thin daemon wrapper for 50-mqttgateway...";

my $daemon_src = "$updatedir/system/daemons/system/50-mqttgateway";
my $daemon_dst = "$lbhomedir/system/daemons/system/50-mqttgateway";

if ( -e $daemon_src ) {
    execute( command => "cp '$daemon_src' '$daemon_dst'",     log => $log );
    execute( command => "chown root:root '$daemon_dst'",      log => $log );
    execute( command => "chmod 755 '$daemon_dst'",            log => $log );
    execute( command => "dos2unix '$daemon_dst'",             log => $log, ignoreerrors => 1 );
    LOGOK "50-mqttgateway daemon wrapper installed successfully.";
} else {
    LOGERR "Source file $daemon_src not found - skipping daemon wrapper installation.";
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
