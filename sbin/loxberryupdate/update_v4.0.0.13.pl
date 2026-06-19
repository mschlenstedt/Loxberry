#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Install the updated sudoers defaults.
#
# network-interfaces-write.pl writes /etc/network/interfaces and must run as root
# (called via "sudo" from network.cgi). The required NOPASSWD entry was added to
# system/sudoers/lbdefaults. Because system/ is excluded from the update rsync
# (update-exclude.system), the file must be copied explicitly via copy_to_loxberry.
LOGINF "Installing updated sudoers defaults (network-interfaces-write.pl entry)...";
copy_to_loxberry("/system/sudoers/lbdefaults");

LOGOK  "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
