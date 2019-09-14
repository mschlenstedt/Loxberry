#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

$LoxBerry::System::DEBUG = 1;

init();

LOGINF "Installing daily cronjob for plugin update checks...";
$output = qx { rm -f $lbhomedir/system/cron/cron.daily/02-pluginsupdate.pl };
$output = qx { ln -f -s $lbhomedir/sbin/pluginsupdate.pl $lbhomedir/system/cron/cron.daily/02-pluginsupdate };


## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);


