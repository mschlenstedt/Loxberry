#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 

# Initialize logfile and parameters
	my $logfilename;
	if ($cgi->param('logfilename')) {
		$logfilename = $cgi->param('logfilename');
	}
	my $log = LoxBerry::Log->new(
			package => 'LoxBerry Update',
			name => 'update',
			filename => $logfilename,
			logdir => "$lbslogdir/loxberryupdate",
			loglevel => 7,
			stderr => 1,
			append => 1,
	);
	$logfilename = $log->filename;

	if ($cgi->param('updatedir')) {
		$updatedir = $cgi->param('updatedir');
	}
	my $release = $cgi->param('release');

# Finished initializing
# Start program here
my $errors = 0;
LOGOK "Update script $0 started.";


LOGINF "Replacing old setloxberryid cronjob with new job:";
LOGINF "Copying new job";

my $output = qx { if [ -e $updatedir/system/cron/cron.d/setloxberryid ] ; then cp -f $updatedir/system/cron/cron.d/setloxberryid $lbhomedir/system/cron/cron.d/ ; fi };
my $exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error copying new setloxberryid cron job - Error $exitcode";
	$errors++;
} else {
	LOGOK "New setloxberryid cronjob copied.";
}

qx { chown root:root $lbhomedir/system/cron/cron.d/setloxberryid };

LOGINF "Installing missing package php-soap";

my $bins = LoxBerry::System::get_binaries();
my $aptbin = $bins->{APT};
$output = qx { $aptbin -q -y install php-soap };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error installing php-soap - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "php-soap successfully installed.";
}

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);

