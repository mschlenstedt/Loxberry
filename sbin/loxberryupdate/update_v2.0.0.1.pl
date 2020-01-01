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
# Use apt Repo
#apt_update("update");
#apt_remove("firmware-atheros bluez-firmware firmware-brcm80211 firmware-libertas firmware-misc-nonfree firmware-realtek");
#apt_install("firmware-atheros bluez-firmware firmware-brcm80211 firmware-libertas firmware-misc-nonfree firmware-realtek");
# Use Kernel.org
#system("rm -r /lib/firmware/*");
#system("curl -L https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot/linux-firmware-20190923.tar.gz -o /lib/firmware/linux-firmware-20190923.tar.gz");
#system("tar xvfz linux-firmware-20190923.tar.gz -C /lib/firmware/");
#system("mv /lib/firmware/linux-firmware-20190923/* /lib/firmware/");
#system("rm -r /lib/firmware/linux-firmware-20190923*");
# Use RPi-Distro Repo
system("curl -L https://github.com/RPi-Distro/firmware-nonfree/archive/master.zip -o /lib/master.zip");
system("cd /lib && unzip /lib/master.zip");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error extracting new firmware. This is a problem for PI4 only. Wifi may not work on the Pi4 - Error $exitcode";
} else {
        LOGOK "Extracting of new firmware files successfully. Installing...";
	system ("rm -r /lib/firmware");
	system("mv /lib/firmware-nonfree-master /lib/firmware");
}
system ("rm -r /lib/master.zip");

#
# Install missing rfkill
#
LOGINF "Installing rfkill...";
apt_update("update");
apt_install("rfkill");

#
# Install Python (including suggested packages)
#
LOGINF "Install Python/pip as a standard...";
apt_install("python-pip python3-pip");

#
# Upgrade any older packages (in case this LoxBerry was upgraded and python plugins were installed before)
#
LOGINF "Upgrade python packages...";
system ("pip install pip --upgrade");
system("pip list --outdated --format=freeze | cut -d = -f 1 | xargs -n1 pip install -U");
system ("pip3 install pip --upgrade");
system("pip3 list --outdated --format=freeze | cut -d = -f 1 | xargs -n1 pip3 install -U");

# Clean apt
apt_update("clean");

#
# Repair broken msmtp permissions from 2.0.0.0
#
LOGINF "Repair broken msmtp permissions from previous upgrade...";
if (-e "$lbhomedir/system/msmtp/msmtprc $lbhomedir/.msmtprc") {
	system( "ln -s $lbhomedir/system/msmtp/msmtprc /etc/msmtprc" );
	#system( "chown -h loxberry:loxberry $lbhomedir/.msmtprc" );
	unlink ( "$lbhomedir/.msmtprc" );
}
copy_to_loxberry("/system/sudoers/lbdefaults");

## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
