#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
#use LoxBerry::JSON;

init();

#
# Firmware Files are not updated automatically by apt-get (why? *really* don't no!)
#
LOGINF "Installing newest firmware files from Debian Buster...";
apt_update("update");
apt_remove("firmware-atheros bluez-firmware firmware-brcm80211 firmware-libertas firmware-misc-nonfree firmware-realtek");
apt_install("firmware-atheros bluez-firmware firmware-brcm80211 firmware-libertas firmware-misc-nonfree firmware-realtek");

#
# Install missing rfkill
#
LOGINF "Installing rfkill...";
apt_install("rfkill");

#
# Install Python (including suggested packages)
#
LOGINF "Install Python/pip as a standard...";
apt_install("python-pip python3-pip");

#
# Upgrade any older packages (in case this LoxBerry was upgraded and python plugins were installed before)
#
#LOGINF "Upgrade any manually installed python packages...";
#system ("pip install pip --upgrade");
#system("pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U");
#system ("pip3 install pip3 --upgrade");
#system("pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U");

# Clean apt
apt_update("clean");

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
