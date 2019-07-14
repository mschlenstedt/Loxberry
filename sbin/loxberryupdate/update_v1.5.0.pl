#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

#
# Switching to rwth-aachen.de for the Rasbian Repo due to lot of connection errors with original rpo
#
LOGINF "Replacing archive.raspbian.org with ftp.halifax.rwth-aachen.de/raspbian/raspbian/ in /etc/apt/sources.list.";
system ("/bin/sed -i 's:mirrordirector.raspbian.org:ftp.halifax.rwth-aachen.de/raspbian/raspbian:g' /etc/apt/sources.list");
system ("/bin/sed -i 's:archive.raspbian.org:ftp.halifax.rwth-aachen.de/raspbian/raspbian:g' /etc/apt/sources.list");
unlink ("/etc/apt/sources.list.d/raspi.list");

LOGINF "Getting signature for ftp.halifax.rwth-aachen.de/raspbian/raspbian.";
$output = qx ( wget http://ftp.halifax.rwth-aachen.de/raspbian/raspbian.public.key -O - | apt-key add - );
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error getting signature for ftp.halifax.rwth-aachen.de/raspbian - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
     	LOGOK "Got signature for ftp.halifax.rwth-aachen.de/raspbian successfully.";
}

#
# Installing new network templates
#
LOGINF "Installing new network templates for IPv6...";
unlink "$lbhomedir/system/network/interfaces.eth_dhcp";
unlink "$lbhomedir/system/network/interfaces.eth_static";
unlink "$lbhomedir/system/network/interfaces.wlan_dhcp";
unlink "$lbhomedir/system/network/interfaces.wlan_static";
copy_to_loxberry("/system/network/interfaces.loopback");
copy_to_loxberry("/system/network/interfaces.ipv4");
copy_to_loxberry("/system/network/interfaces.ipv6");

LOGINF "Installing additional Perl modules...";
apt_update("update");
apt_install("libdata-validate-ip-perl");

#
# Upgrade Raspbian on next reboot
#
LOGINF "Upgrading system to latest Raspbian release ON NEXT REBOOT.";
my $logfilename_wo_ext = $logfilename;
$logfilename_wo_ext =~ s{\.[^.]+$}{};
open(F,">$lbhomedir/system/daemons/system/99-updaterebootv150");
print F <<EOF;
#!/bin/bash
perl $lbhomedir/sbin/loxberryupdate/updatereboot_v1.5.0.pl logfilename=$logfilename_wo_ext-reboot 2>&1
EOF
close (F);
qx { chmod +x $lbhomedir/system/daemons/system/99-updaterebootv150 };

#
# Diable Apache2 for next reboot
#
LOGINF "Disabling Apache2 Service for next reboot...";
my $output = qx { systemctl disable apache2.service };
LOGINF "$output";
$exitcode = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Could not disable Apache webserver - Error $exitcode";
} else {
	LOGOK "OK.";
}

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

apt_update("clean");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
