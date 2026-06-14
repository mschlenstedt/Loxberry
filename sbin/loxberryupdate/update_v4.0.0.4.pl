#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Migrate /opt/loxberry/system/network/interfaces from symlink to regular file.
#
# On old LoxBerry installations /etc/network/interfaces was a symlink pointing to
# /opt/loxberry/system/network/interfaces. In some setups that file itself is also
# a symlink. The network write script (network-interfaces-write.pl) writes directly
# to /opt/loxberry/system/network/interfaces and requires it to be a regular file.

my $ifaces     = "$lbhomedir/system/network/interfaces";
my $ifaces_new = "${ifaces}.new";

LOGINF "Checking if $ifaces is a symlink...";

my $is_symlink = system("[ -L '$ifaces' ]");

if ($is_symlink == 0) {
    LOGINF "$ifaces is a symlink — migrating to regular file.";

    execute( command => "cp --dereference '$ifaces' '$ifaces_new'", log => $log );
    execute( command => "rm '$ifaces'",                              log => $log );
    execute( command => "cp '$ifaces_new' '$ifaces'",               log => $log );
    execute( command => "rm '$ifaces_new'",                         log => $log );
    execute( command => "chown root:root '$ifaces'",                 log => $log );
    execute( command => "chmod 644 '$ifaces'",                       log => $log );

    LOGOK "$ifaces successfully migrated to regular file." if ($errors == 0);
} else {
    LOGOK "$ifaces is already a regular file — no migration needed.";
}

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

exit($errors);
