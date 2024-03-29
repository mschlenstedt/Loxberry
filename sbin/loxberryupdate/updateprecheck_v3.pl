#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

my $errors;

#
# Check if everything is ok with apt - we definetely need it working after reboot
#
LOGINF "Cleaning up and updating apt databases...";
apt_update();

#
# Stop the update if the boot partition is too small
#
use LoxBerry::System;
my %folderinfo = LoxBerry::System::diskspaceinfo('/boot');
if ($folderinfo{size} < 120000) {
	my $message = "Your boot partition is too small for LoxBerry 3.0 (needed: 126 MB). Current size is: " . LoxBerry::System::bytes_humanreadable($folderinfo{size}, "K") . " Create a backup with the new LoxBerry Backup Widget. The backups will include a bigger boot partition, which is sufficient for LB3.0";
	LOGCRIT $message;
	notify('updates', 'update', $message, 'Error');
	$errors++;
}

my $output = qx { pgrep -f /usr/sbin/watchdog };
my $exitcode = $? >> 8;
if ($exitcode eq 0) {
	my $message = "Watchdog is running - it must be disabled before upgrading. Disable it in LoxBerry Services -> Watchdog and then reboot. After reboot, try LoxBerry Update again.";
	LOGCRIT $message;
	notify('updates', 'update', $message, 'Error');
	$errors++;
}

# Exit with 1 if errors occurrred and stop installation
if ($errors) {
	exit (1);
} else {
	exit (0);
}
