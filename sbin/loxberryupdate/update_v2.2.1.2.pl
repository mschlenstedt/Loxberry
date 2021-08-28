#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

LOGINF "Repairing apt sources - one of the rasbian mirrors are not active anymore...";
system("sed -i -e '/^deb http:\\/\\/raspbian.raspberrypi.org\\/raspbian\\/ buster/s/^/#/g' /etc/apt/sources.list");
system("sed -i -e '/^deb http:\\/\\/ftp.gwdg.de\\/pub\\/linux\\/debian\\/raspbian\\/raspbian\\/ buster/s/^/#/g' /etc/apt/sources.list");
system("sed -i -e '/^deb http:\\/\\/ftp.agdsn.de\\/pub\\/mirrors\\/raspbian\\/raspbian\\ buster/s/^/#/g' /etc/apt/sources.list");
system("sed -i -e '/^deb http:\\/\\/ftp.halifax.rwth-aachen.de\\/raspbian\\/raspbian\\/ buster/s/^/#/g' /etc/apt/sources.list");
mkdir("$lbhomedir/system/apt");
&copy_to_loxberry('/system/apt/loxberry.list');
system("chown root:root $lbhomedir/system/apt/loxberry.list");
system("ln -s $lbhomedir/system/apt/loxberry.list /etc/apt/sources.list.d/loxberry.list");
system ("rm /etc/apt/sources.list.d/pilight.list");
apt_update("update");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
