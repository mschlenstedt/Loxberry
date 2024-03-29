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
# Stop the update if the boot partition is too small
#
use LoxBerry::System;
my %folderinfo = LoxBerry::System::diskspaceinfo('/boot');
if ($folderinfo{size} < 200000) {
	LOGCRIT "You boot partition is too small for LoxBerry 3.0 (needed: 256 MB). Current size is: " . LoxBerry::System::bytes_humanreadable($folderinfo{size}, "K") . " Create a backup with the new LoxBerry Backup Widget. The backups will include a bigger boot partition, which is sufficient for LB3.0";
	exit (1);
}

#
# we are now in the 3.0 Branch. Increase LoxBerry's max_version for LBUpdate
#
LOGINF "Welcome 3.0 Branch :-) Increasing LoxBerry's Max_Version to 3.99.99.";
my $generaljson = $lbsconfigdir . "/general.json";
my $gcfgobj = LoxBerry::JSON->new();
my $gcfg = $gcfgobj->open(filename => $generaljson);
$gcfg->{Update}->{max_version} = "v3.99.99";
$gcfg->{Update}->{Installtype} = "install";
$gcfg->{Update}->{Interval} = "7";
$gcfg->{Update}->{Releasetype} = "release";
$gcfgobj->write();
execute("chown loxberry:loxberry $lbhomedir/config/system/general.*");

#
# Add Raspbian Mirrors to general.json
# -> done be ~/bin/createconfig.pl
#LOGINF "Adding Apt Servers to general.json";
#if (!$gcfg->{'Apt'}->{'Servers'}) {
#	my @servers = ( "http://ftp.agdsn.de/pub/mirrors/raspbian/raspbian/",
#			"http://packages.hs-regensburg.de/raspbian/",
#			"http://ftp.halifax.rwth-aachen.de/raspbian/raspbian/",
#			"http://ftp.gwdg.de/pub/linux/debian/raspbian/raspbian/",
#			"https://dist-mirror.fem.tu-ilmenau.de/raspbian/raspbian/"
#	);
#	$gcfg->{'Apt'}->{'Servers'} = \@servers;
#	$gcfgobj->write();
#	LOGOK "Apt Servers added to general.json successfully.";
#} else {
#	LOGOK "Apt Servers already in general.json -> skipping.";
#}

#
# Repair apt sources
# 
LOGINF "Repairing apt sources...";
&copy_to_loxberry('/system/apt/loxberry.list');
unlink ("/etc/apt/sources.list.d/loxberry.list");
system("chown root:root $lbhomedir/system/apt/loxberry.list");
if (-e "$LoxBerry::System::lbhomedir/config/system/is_raspberry.cfg" && !-e "$LoxBerry::System::lbhomedir/config/system/is_odroidxu3xu4.cfg") {
	system("ln -s $lbhomedir/system/apt/loxberry.list /etc/apt/sources.list.d/loxberry.list");
}
system("sed -i \"s/^\\([^#]*raspbian\\/raspbian.*\\)/#\\1/\" /etc/apt/sources.list");

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
my $exitcode = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Could not disable Apache webserver - Error $exitcode";
	LOGWARN "Maybe your LoxBerry does not respond during system upgrade after reboot. Please be patient when rebooting!";
} else {
	LOGOK "Apache Service disabled successfully.";
}

#
# Disable unattended-upgrades for next reboot
#
LOGINF "Disabling Unattended Upgrades Service for next reboot...";
my $output = qx { systemctl disable unattended-upgrades };
my $exitcode = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Could not disable Unattended Upgrades - Error $exitcode";
} else {
	LOGOK "Unattended Upgrades Service disabled successfully.";
}

#
# Disable rpimonitor for next reboot - if installed (plugin)
#
if (-e "/etc/init.d/rpimonitor") {
	LOGINF "Disabling RPI Monitor Service for next reboot...";
	my $output = qx { systemctl disable rpimonitor };
	my $exitcode = $? >> 8;
	if ($exitcode != 0) {
		LOGWARN "Could not disable RPI Monitor - Error $exitcode";
	} else {
		LOGOK "RPI Monitor Service disabled successfully.";
	}
}

#
# Disable watchdog for next reboot
#
if ( is_enabled($gcfg->{'Watchdog'}->{'Enable'}) ) {
	LOGINF "Disabling Watchdog Service for next reboot...";
	my $output = qx { systemctl disable watchdog };
	my $exitcode = $? >> 8;
	if ($exitcode != 0) {
		LOGWARN "Could not disable Watchdog - Error $exitcode";
	} else {
		LOGOK "Watchdog Service disabled successfully.";
	}
}

#
# Backing up Python packages, because Rasbian's upgrade will overwrite all of them...
#
LOGINF "Backing up all Python Modules - Will be overwritten by f***cking broken Rasbian upgrade...";
system ("which pip2");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGINF "pip2 seems not to be installed.";
} else {
	LOGINF "Saving list with installed pip2 packages...";
	system("$lbssbindir/pythonmoduleupgrade.sh python2 backup $lbsdatadir/pip2_list.dat");
}
system ("which pip3");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGINF "pip3 seems not to be installed.";
} else {
	LOGINF "Saving list with installed pip3 packages...";
	system("$lbssbindir/pythonmoduleupgrade.sh python3 backup $lbsdatadir/pip3_list.dat");
}

#
# MQTT Gateway migration
#
LOGINF "The next steps will prepare the Mosquitto MQTT server and MQTT Gateway.";

copy_to_loxberry('/system/sudoers/lbdefaults');
copy_to_loxberry('/system/daemons/system/50-mqttgateway');
copy_to_loxberry('/system/daemons/system/51-mqttfinder');
execute("chmod +x $lbhomedir/system/daemons/system/50-mqttgateway");
execute("chmod +x $lbhomedir/system/daemons/system/51-mqttfinder");
# Delete Alpha files in cron.reboot
unlink "$lbhomedir/system/cron/cron.reboot/02-mqttfinder", "$lbhomedir/system/cron/cron.reboot/04-mqttgateway";

LOGINF "Starting MQTT Gateway migration";

execute( command => "$lbhomedir/sbin/loxberryupdate/mqtt_migration.pl logfilename=$logfilename", log => $log, ignoreerrors => 1 );

#
# Upgrading usb-mount
#
LOGINF "Upgrading usb-mount";

if ( -e "/etc/udev/rules.d/99-usbmount.rules" ) {
	qx {rm -f /etc/udev/rules.d/99-usbmount.rules };
}
open(F,">/etc/udev/rules.d/99-usbmount.rules");
print F <<EOF;
KERNEL=="sd[a-z]*[0-9]", SUBSYSTEMS=="usb", ACTION=="add", RUN+="/opt/loxberry/sbin/usb-mount.sh chkadd %k"
KERNEL=="sd[a-z]*[0-9]", SUBSYSTEMS=="usb", ACTION=="remove", RUN+="/bin/systemctl stop usb-mount@%k.service"
EOF
close(F);

#
# Repair missing environments in Apache
#
LOGINF "Add missing Environments in Apache Config";
system ("cat $lbhomedir/system/apache2/sites-available/000-default.conf | grep 'LBPHTMLAUTH'");
$exitcode  = $? >> 8;
if ($exitcode) {
	system("sed -i -e 's:PassEnv LBPHTML:PassEnv LBPHTML\\n\\tPassEnv LBPHTMLAUTH:g' $lbhomedir/system/apache2/sites-available/000-default.conf");
}
system ("cat $lbhomedir/system/apache2/sites-available/000-default.conf | grep 'LBSHTMLAUTH'");
$exitcode  = $? >> 8;
if ($exitcode) {
	system("sed -i -e 's:PassEnv LBSHTML:PassEnv LBSHTML\\n\\tPassEnv LBSHTMLAUTH:g' $lbhomedir/system/apache2/sites-available/000-default.conf");
}

#
# Install new sudoers
#
# Done during MQTT migration
#LOGINF "Installing new sudoers file...";
#copy_to_loxberry("/system/sudoers/lbdefaults", "root");

LOGINF "Update service files";
copy_to_loxberry('/system/systemd/createtmpfs.service');
copy_to_loxberry('/system/systemd/loxberry.service');
copy_to_loxberry('/system/systemd/ssdpd.service');
copy_to_loxberry('/system/systemd/usb-mount@.service');
if ( -e "$lbhomedir/system/daemons/system/01-ssdpd" ) {
	unlink ("$lbhomedir/system/daemons/system/01-ssdpd");
}
if ( -e "$lbhomedir/system/daemons/system/04-remotesupport" ) {
	unlink ("$lbhomedir/system/daemons/system/04-remotesupport");
}
if ( -e "$lbhomedir/system/daemons/system/05-emergencywebserver" ) {
	unlink ("$lbhomedir/system/daemons/system/05-emergencywebserver");
}

LOGINF "Update mosquitto service...";
copy_to_loxberry('/system/systemd/mosquitto.service');
if ( -e "/etc/systemd/system/mosquitto.service" ) {
	unlink ("/etc/systemd/system/mosquitto.service");
}
unlink ("$lbhomedir/data/system/mosquitto.service");
system ("ln -s $lbhomedir/system/systemd/mosquitto.service /etc/systemd/system/mosquitto.service");
system ("/bin/systemctl daemon-reload");

if ( -e "/etc/logrotate.conf" ) {
	LOGINF "Disable gzipping of Logs...";
	my $output = qx { sed -i 's/^compress/#compress/g' /etc/logrotate.conf };
}

#
# Install new 03-loxberryupdate Daemon
#
LOGINF "Installing new 03-loxberryupdate file...";
copy_to_loxberry("/system/daemons/system/03-loxberryupdate", "root");

#
# Install shellinabox and disable shellinabox daemon
#
LOGINF "Installing Shell-In-A-Box...";
apt_install("shellinabox");
my $output = qx { sed -i 's#^SHELLINABOX_DAEMON_START.*\$#SHELLINABOX_DAEMON_START=0#' /etc/default/shellinabox };
copy_to_loxberry('/system/daemons/system/06-shellinabox');
copy_to_loxberry('/system/apache2/conf-available/shellinabox.conf');
execute( command => "a2enmod proxy proxy_http", log => $log );
execute( command => "a2enconf shellinabox", log => $log );

#
# Add loxberry to i2c group
#
LOGINF "Adding user loxberry to group i2c...";
execute( command => "usermod -a -G i2c loxberry", log => $log );

#
# Apache SSL
#
LOGINF "Installing new SSL / HTTPS Option for Apache2 Webserver.";

apt_install("dnsutils");
copy_to_loxberry('/system/apache2/sites-available/001-default-ssl.conf');
copy_to_loxberry('/system/cron/cron.daily/04-checkcerts');
#copy_to_loxberry('/system/apache2/sites-enabled/001-default-ssl.conf');
#execute( command => "a2ensite 001-default-ssl", log => $log );
execute( command => "a2enmod ssl", log => $log );

#LOGINF "Creating certificates if not already exist.";
#execute( command => "$lbhomedir/sbin/checkcerts.sh", log => $log );

#LOGINF "Checking new Apapche2 configuration.";
#($exitcode) = execute( command => "apachectl -t", log => $log );
#if ($exitcode != 0) {
#	LOGERR "There's a problem with the Apache Configuration. Disabling SSL option.";
#	execute( command => "a2dissite 001-default-ssl", log => $log );
#	$errors++;
#} else {
#	LOGOK "Apache Configuration seems to be OK.";
#}

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End Skript for reboot
# Just to remeber for the next Major update: Exit this script with 250 or 250 will popup a "reboot.force" messages,
# because update process will continue after reboot the loxberry
if ($errors) {
	exit(251); 
} else {
	exit(250);
}
