#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

LOGINF "Updating f*cking changed YARN key. What the f*ck they are doing?!...";
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -

LOGINF "Enabling Emergency Webserver...";
&copy_to_loxberry('/system/daemons/system/05-emergencywebserver');
&copy_to_loxberry('/system/cron/cron.hourly');

LOGINF "Updating LoxBerry cron folders execution behaviour...";
&copy_to_loxberry('/system/cron/cron.d/lbdefaults');


## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

LOGINF "Installing pre-requisites for LoxBerry RAMDISK File Analyzer...";
apt_update("update");
apt_install("libsys-filesystem-perl libipc-run3-perl libhash-merge-perl");


LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
