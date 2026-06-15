#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Deploy the MQTT Finder Watchdog cron job.
#
# system/cron/ is excluded from the update rsync (update-exclude.system), so the
# cron file must be copied explicitly via copy_to_loxberry. The watchdog itself
# (sbin/mqttfinderwatchdog.pl) lives outside system/ and is installed by the
# normal rsync — here we only make sure it is executable.
LOGINF "Installing MQTT Finder Watchdog cron job (cron.01min)...";
copy_to_loxberry('/system/cron/cron.01min/mqttfinderwatchdog');
execute( command => "chmod +x $lbhomedir/system/cron/cron.01min/mqttfinderwatchdog", log => $log );
execute( command => "dos2unix $lbhomedir/system/cron/cron.01min/mqttfinderwatchdog", log => $log, ignoreerrors => 1 );

LOGINF "Ensuring MQTT Finder Watchdog script is executable...";
execute( command => "chmod +x $lbhomedir/sbin/mqttfinderwatchdog.pl", log => $log );
execute( command => "dos2unix $lbhomedir/sbin/mqttfinderwatchdog.pl",  log => $log, ignoreerrors => 1 );

# Restore the Debian-default network layout.
#
# On old LoxBerry installations /etc/network/interfaces was a symlink pointing to
# /opt/loxberry/system/network/interfaces. We restore the original Debian state:
# /etc/network/interfaces must be a regular file. From now on the WebUI reads and
# network-interfaces-write.pl writes /etc/network/interfaces directly.
my $etc_ifaces = "/etc/network/interfaces";
my $lb_ifaces  = "$lbhomedir/system/network/interfaces";

LOGINF "Checking if $etc_ifaces is a symlink (old LoxBerry layout)...";
my $is_symlink = system("[ -L '$etc_ifaces' ]");

if ($is_symlink == 0) {
    LOGINF "$etc_ifaces is a symlink — removing it and restoring the Debian default.";

    # Remove the symlink, then copy the real config file into place.
    execute( command => "rm -f '$etc_ifaces'", log => $log );
    if ( -e $lb_ifaces ) {
        execute( command => "cp '$lb_ifaces' '$etc_ifaces'", log => $log );
    } else {
        LOGERR "$lb_ifaces does not exist — cannot restore $etc_ifaces!";
    }
    execute( command => "chown root:root '$etc_ifaces'", log => $log );
    execute( command => "chmod 644 '$etc_ifaces'",       log => $log );

    LOGOK "$etc_ifaces successfully restored as a regular file." if ( $errors == 0 );
} else {
    LOGOK "$etc_ifaces is already a regular file — no migration needed.";
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
