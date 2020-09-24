#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

LOGINF "Deleting CloudDNS cache files to get rebuilt with https...";
unlink "$lbstmpfslogdir/clouddns_cache.json";

# Install additional apt sources e.g. if a server is down
LOGINF "Add additional servers for the apt repositories...";
open(FH, ">>", "/etc/apt/sources.list");
print FH "deb http://ftp.gwdg.de/pub/linux/debian/raspbian/raspbian/ buster main contrib non-free rpi\n";
print FH "deb http://ftp.agdsn.de/pub/mirrors/raspbian/raspbian/ buster main contrib non-free rpi\n";
close(FH);

# Update Kernel and Firmware
if (-e "$lbhomedir/config/system/is_raspberry.cfg" && !-e "$lbhomedir/config/system/is_odroidxu3xu4.cfg") {
	LOGINF "Preparing Guru Meditation...";
	LOGINF "This will take some time now. We suggest getting a coffee or a second beer :-)";
	LOGINF "Upgrading system kernel and firmware. Takes up to 10 minutes or longer! Be patient and do NOT reboot!";

	unlink "/boot/.firmware_revision";
	qx { mkdir /boot.tmp };
		$log->close;
	system (" SKIP_WARNING=1 SKIP_BACKUP=1 BRANCH=stable WANT_PI4=1 SKIP_CHECK_PARTITION=1 BOOT_PATH=/boot.tmp ROOT_PATH=/ /usr/bin/rpi-update 2d76ecb08cbf7a4656ac102df32a5fe448c930b1 >> $logfilename 2>&1 ");
	$log->open;
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
        	LOGERR "Error upgrading kernel and firmware - Error $exitcode";
        	$errors++;
	} else {
		# Delete beta 64Bit kernel (we have not enough space on /boot...)
		unlink "/boot.tmp/kernel8.img";
		# Check for complete boot partition
		my $md5 = qx { find /boot.tmp -type f -exec md5sum {} \; | sort -k 2 | cut -d" " -f1 | md5sum -z |  cut -d" " -f1 };
		if ( $md5 eq "c44a8e0e55362369513914b584aaf8bd" ) {
			unlink "/boot/kernel*.img";
			qx ( cp -r /boot.tmp/* /boot );
			qx ( rm -r /boot.tmp );
        	LOGOK "Upgrading kernel and firmware successfully.";
		} else {
			LOGERR "Error upgrading kernel and firmware (content of /boot.tmp seems to be wrong or incomplete)";
        	$errors++;
		}
	}
}

LOGINF "We are migrating general.cfg to general.json ...";
LOGINF "Create backup of your general.cfg";
my ($exitcode, $output);
my $time = time;
($exitcode, $output) = execute( {
    command => "cp $lbsconfigdir/general.cfg $lbsconfigdir/general.backup_$time.cfg",
    log => $log
} );

LOGINF "Starting migration...";
($exitcode, $output) = execute( {
    command => "$lbhomedir/sbin/migrate_generalcfg.pl",
    log => $log
} );
LOGOK "Migration complete. The primary configuration of LoxBerry now is stored in general.json.";

# Install mod_rewrite for Apache
LOGINF "Deleting CloudDNS cache files to get rebuilt with https...";
unlink "$lbstmpfslogdir/clouddns_cache.json";

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
