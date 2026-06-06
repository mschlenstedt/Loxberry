#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Install 51-mqttfinder daemon script.
# system/daemons/system/ is excluded from rsync, so it must be copied explicitly.
LOGINF "Installing 51-mqttfinder daemon script...";

my $daemon_src = "$updatedir/system/daemons/system/51-mqttfinder";
my $daemon_dst = "$lbhomedir/system/daemons/system/51-mqttfinder";

if ( -e $daemon_src ) {
    execute( command => "cp '$daemon_src' '$daemon_dst'",     log => $log );
    execute( command => "chown root:root '$daemon_dst'",      log => $log );
    execute( command => "chmod 755 '$daemon_dst'",            log => $log );
    execute( command => "dos2unix '$daemon_dst'",             log => $log, ignoreerrors => 1 );
    LOGOK "51-mqttfinder daemon script installed successfully.";
} else {
    LOGERR "Source file $daemon_src not found - skipping.";
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
