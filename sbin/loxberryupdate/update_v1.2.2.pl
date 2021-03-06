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

LOGOK "This update adds missing envrionment variables to LoxBerry.";

### sudoers/lbdefaults
LOGINF "Updating sudoers lbdefaults file";

my $output = qx { if [ -e $updatedir/system/sudoers/lbdefaults ] ; then cp -f $updatedir/system/sudoers/lbdefaults $lbhomedir/system/sudoers/ ; fi };
my $exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error copying new lbdefaults - Error $exitcode";
	$errors++;
} else {
	LOGOK "New sudoers lbdefaults copied.";
}
qx { chown root:root $lbhomedir/system/sudoers/lbdefaults };

### sudoers/lbdefaults
LOGINF "Updating Apache site configuration";

my $output = qx { if [ -e $updatedir/system/apache2/sites-available/000-default.conf ] ; then cp -f $updatedir/system/apache2/sites-available/000-default.conf $lbhomedir/system/apache2/sites-available/ ; fi };
my $exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error copying new 000-default.conf - Error $exitcode";
	$errors++;
} else {
	LOGOK "New Apache 000-default copied.";
}
my $apacheport = lbwebserverport();
if ($apacheport ne "80") {
	LOGINF "Webserver port is not 80 - changing webserver port in Apache config to $apacheport";
	qx { sed -i -e "s/<VirtualHost.*/<VirtualHost *:$apacheport>/" $lbhomedir/system/apache2/sites-available/000-default.conf };
}
qx { chown loxberry:loxberry $lbhomedir/system/apache2/sites-available/000-default.conf };

###  system/lighttpd/conf-available/
LOGINF "Updating Lighty configuration";
my $output = qx { if [ -e $updatedir/system/lighttpd/conf-available/15-fastcgi-perl.conf ] ; then cp -f $updatedir/system/lighttpd/conf-available/15-fastcgi-perl.conf $lbhomedir/system/lighttpd/conf-available/ ; fi };
my $exitcode1  = $? >> 8;
my $output = qx { if [ -e $updatedir/system/lighttpd/conf-available/15-fastcgi-php.conf ] ; then cp -f $updatedir/system/lighttpd/conf-available/15-fastcgi-php.conf $lbhomedir/system/lighttpd/conf-available/ ; fi };
my $exitcode2  = $? >> 8;

if ($exitcode1 != 0 or $exitcode2 != 0) {
	LOGERR "Error copying lighttpd configuration";
	$errors++;
} else {
	LOGOK "New Lighty configuration copied.";
}
qx { chown loxberry:loxberry $lbhomedir/system/lighttpd/conf-available/15-fastcgi-perl.conf };
qx { chown loxberry:loxberry $lbhomedir/system/lighttpd/conf-available/15-fastcgi-php.conf };

###  setenvironment.sh
LOGINF "Running setenvironment to update further environments";
LOGWARN "Apache is forced to re-read it's configuration during this process. If LoxBerry Update stalls for more than some minutes, please refresh the browser and check the installation state.";

my $output = qx { $lbhomedir/sbin/setenvironment.sh };
my $exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error running setenvironment.sh - Error $exitcode";
	$errors++;
} else {
	LOGOK "Setenvironment successfully finished.";
}


## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);

