#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

# Install mod_rewrite for Apache
LOGINF "Deleting CloudDNS cache files to get rebuilt with https...";
unlink "$lbstmpfslogdir/clouddns_cache.json";

# Install additional apt sources e.g. if a server is down
LOGINF "Add additional servers for the apt repositories...";
open(FH, ">>", "/etc/apt/sources.list");
print FH "deb http://ftp.gwdg.de/pub/linux/debian/raspbian/raspbian/ buster main contrib non-free rpi\n";
print FH "deb http://ftp.agdsn.de/pub/mirrors/raspbian/raspbian/ buster main contrib non-free rpi\n";
close(FH);

#
## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
# reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
