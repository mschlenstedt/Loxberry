#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# ---------------------------------------------------------------------------
# Make the new Python libraries (libs/pythonlib) importable system-wide.
#
# libs/ is rsync'd normally, so libs/pythonlib/install_pth.py is already in
# place here. install_pth.py writes a loxberry.pth into the dist-packages of
# the running python3, so any Python program can do "from loxberry import
# system". The .pth lives OUTSIDE the rsync tree and is per-python-version,
# which is exactly why it must be (re)written by this versioned update script
# (also after a distro upgrade that ships a new python3).
# ---------------------------------------------------------------------------

my $pylib = "$lbhomedir/libs/pythonlib";

if ( -e "$pylib/install_pth.py" ) {
	LOGINF "Installing loxberry.pth for the system python3...";
	execute(
		command => "python3 $pylib/install_pth.py --libdir $pylib",
		log     => $log,
	);
} else {
	LOGWARN "$pylib/install_pth.py not found - skipping Python .pth install.";
}

# ---------------------------------------------------------------------------
# The Python loxberry.io library uses paho-mqtt for MQTT. Install the Debian
# package so "import paho.mqtt.client" works on all supported distributions.
# ---------------------------------------------------------------------------
LOGINF "Installing python3-paho-mqtt for the Python MQTT library...";
apt_install("python3-paho-mqtt");

# ---------------------------------------------------------------------------
# 51-mqttfinder no longer starts a second MQTT Finder at boot (#1578, #1579):
# cron.01min (mqttfinderwatchdog.pl) may already have started one before
# loxberryinit.sh reaches the system daemons.
# system/ is excluded from rsync (update-exclude.system), so the daemon script
# must be copied explicitly.
# ---------------------------------------------------------------------------
LOGINF "Installing 51-mqttfinder daemon script...";
copy_to_loxberry('/system/daemons/system/51-mqttfinder');
execute( command => "chmod +x $lbhomedir/system/daemons/system/51-mqttfinder", log => $log );

# ---------------------------------------------------------------------------
# DietPi keeps the system time in sync now (#1581). sbin/settimeserver.sh hands
# LoxBerry's time settings to DietPi and replaces sbin/setdatetime.pl.
# system/ is excluded from rsync (update-exclude.system), so the sudoers
# defaults (settimeserver.sh instead of ntpdate) are copied and the hourly cron
# job of setdatetime.pl is removed here.
# ---------------------------------------------------------------------------
LOGINF "Installing updated sudoers defaults (settimeserver.sh entry)...";
copy_to_loxberry("/system/sudoers/lbdefaults");

if ( -e "$lbhomedir/system/cron/cron.hourly/01-setdatetime" ) {
	LOGINF "Removing the hourly cron job of setdatetime.pl...";
	unlink "$lbhomedir/system/cron/cron.hourly/01-setdatetime" or LOGWARN "Could not remove 01-setdatetime: $!";
}

# The NTP server set in LoxBerry never reached DietPi so far, although the
# window showed it as active. Hand it over once. A failed sync is not an update
# error - settimeserver.sh then keeps the server DietPi had.
LOGINF "Handing the time server settings to DietPi...";
my ($tsexitcode) = execute( command => "$lbhomedir/sbin/settimeserver.sh", log => $log, ignoreerrors => 1 );
if ( $tsexitcode == 0 ) {
	LOGOK "Time server settings handed to DietPi.";
} else {
	LOGWARN "Time server settings could not be applied (exit code $tsexitcode) - see $lbhomedir/log/system_tmpfs/settimeserver.log";
}

# ---------------------------------------------------------------------------
# Watchdog for MQTT Gateway V2 (#1567): restarts the gateway if it is not
# running or no longer publishes its keepalive, unless it was stopped on
# purpose. The cron wrapper lives in system/ (excluded from rsync), the logic
# (sbin/mqttgatewaywatchdog.pl) comes with the rsync.
# ---------------------------------------------------------------------------
LOGINF "Installing MQTT Gateway V2 watchdog cron job...";
copy_to_loxberry('/system/cron/cron.01min/mqttgatewaywatchdog');
execute( command => "chmod +x $lbhomedir/system/cron/cron.01min/mqttgatewaywatchdog", log => $log );
execute( command => "dos2unix $lbhomedir/system/cron/cron.01min/mqttgatewaywatchdog", log => $log, ignoreerrors => 1 );
execute( command => "chmod +x $lbhomedir/sbin/mqttgatewaywatchdog.pl", log => $log );

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
