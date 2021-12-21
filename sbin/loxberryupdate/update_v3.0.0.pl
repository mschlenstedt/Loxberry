#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::JSON;

init();

#
# we are now in the 3.0 Branch. Increase LoxBerry's max_version for LBUpdate
#
LOGINF "Welcome 3.0 Branch :-) Increasing LoxBerry's Max_Version to 3.99.99.";
my $generaljson = $lbsconfigdir . "/general.json";
$gcfgobj = LoxBerry::JSON->new();
$gcfg = $gcfgobj->open(filename => $generaljson);
$gcfg->{Update}->{max_version} = "v3.99.99";
$gcfgobj->write();

# Add Raspbian Mirrors to general.json
LOGINF "Adding Apt Servers to general.json";
if (!$gcfg->{'apt'}->{'servers'}) {
	my @servers = ( "http://ftp.agdsn.de/pub/mirrors/raspbian/raspbian/",
			"http://packages.hs-regensburg.de/raspbian/",
			"http://ftp.halifax.rwth-aachen.de/raspbian/raspbian/",
			"http://ftp.gwdg.de/pub/linux/debian/raspbian/raspbian/",
			"https://dist-mirror.fem.tu-ilmenau.de/raspbian/raspbian/"
	);
	$gcfg->{'apt'}->{'servers'} = \@servers;
	$gcfgobj->write();
	LOGOK "Apt Servers added to general.json successfully.";
} else {
	LOGOK "Apt Servers already in general.json -> skipping.";
}

# Repair apt sources
LOGINF "Repairing apt sources...";
&copy_to_loxberry('/system/apt/loxberry.list');
unlink ("/etc/apt/sources.list.d/loxberry.list");
system("chown root:root $lbhomedir/system/apt/loxberry.list");
system("ln -s $lbhomedir/system/apt/loxberry.list /etc/apt/sources.list.d/loxberry.list");
system("sed \"s/^\\([^#]*raspbian\\/raspbian.*\\)/#\\1/\" /etc/apt/sources.list");

#
# Upgrade Raspbian on next reboot
#
LOGWARN "Upgrading system to latest Raspbian release ON NEXT REBOOT.";
my $logfilename_wo_ext = $logfilename;
$logfilename_wo_ext =~ s{\.[^.]+$}{};
open(F,">$lbhomedir/system/daemons/system/99-updaterebootv300");
print F <<EOF;
#!/bin/bash
perl $lbhomedir/sbin/loxberryupdate/updatereboot_v3.0.0.pl logfilename=$logfilename_wo_ext-reboot 2>&1
EOF
close (F);
qx { chmod +x $lbhomedir/system/daemons/system/99-updaterebootv300 };

#
# Disable Apache2 for next reboot
#
LOGINF "Disabling Apache2 Service for next reboot...";
my $output = qx { systemctl disable apache2.service };
$exitcode = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Could not disable Apache webserver - Error $exitcode";
	LOGWARN "Maybe your LoxBerry does not respond during system upgrade after reboot. Please be patient when rebooting!";
} else {
	LOGOK "Apache Service disabled successfully.";
}

#
# Backing up Python packages, because rasbian's upgrade will overwrite all of them...
#
LOGINF "Backing up all Python Modules - Will be overwritten by f***cking broken Rasbian upgrade...";
system ("which pip");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGINF "pip seems not to be installed.";
} else {
	LOGINF "Saving list with installed pip packages...";
	system ("pip install pip --upgrade");
	system("pip list --format=freeze > $lbsdatadir/pip_list.dat");
}
system ("which pip3");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGINF "pip3 seems not to be installed.";
} else {
	LOGINF "Saving list with installed pip3 packages...";
	system ("pip3 install pip --upgrade");
	system("pip3 list --format=freeze > $lbsdatadir/pip3_list.dat");
}


## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End Skript for reboot
if ($errors) {
	exit(251); 
} else {
	exit(250);
}
