#!/usr/bin/perl

# This script will be executed on next reboot
# It is invoked from cron (@reboot) by
# update_v1.2.0.pl

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 

# Initialize logfile and parameters
my $logfilename;
if ($cgi->param('logfilename')) {
	$logfilename = $cgi->param('logfilename');
	my $n = 0;
	my $ext = "";
	while ( -e "$lbslogdir/loxberryupdate/$logfilename$ext" ) {
		$n++;
		$ext = "-$n";
	}
}

# Debug
print "Logfile is: $lbslogdir/loxberryupdate/$logfilename$ext.log\n";

my $log = LoxBerry::Log->new(
		package => 'LoxBerry Update',
		name => 'update',
		filename => "$logfilename$ext.log",
		logdir => "$lbslogdir/loxberryupdate",
		loglevel => 7,
		stderr => 1,
		append => 1,
);
$logfilename = $log->filename;

if ($cgi->param('updatedir')) {
	$updatedir = $cgi->param('updatedir');
}

# Finished initializing
# Start program here
########################################################################

my $errors = 0;
LOGOK "Update Reboot script $0 started.";

# Sleep waiting network to be up after boot
use Net::Ping;
my $p = Net::Ping->new();
my $hostname = 'download.loxberry.de';
my $success = 0;
foreach my $c (1 .. 5) {
	LOGINF "Try to reach $hostname";
	my ($ret, $duration, $ip) = $p->ping($hostname);
	if ($ret) {
		LOGOK "$hostname is reachable, so network seems to be up";
		$success = 1;
		last;
	} else {
		sleep 5;
	}
}
if (!$success) {
	LOGCRIT "Network seems to be down. Giving up and will try again on next reboot.";
	exit 1;
}

# Debug
exit 0;

#
# Upgrade Raspbian
#
LOGINF "Preparing Guru Meditation...";
LOGINF "This will take some time now. We suggest getting a coffee or a beer.";
LOGINF "Upgrading system to latest Raspbian release.";

my $output = qx { /usr/bin/dpkg --configure -a };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode";
        LOGDEB $output;
                $errors++;
} else {
        LOGOK "Configuring dpkg successfully.";
}
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y update };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error updating apt database - Error $exitcode";
                LOGDEB $output;
        $errors++;
} else {
        LOGOK "Apt database updated successfully.";
}
LOGINF "Now upgrading all packages... Takes up to 10 minutes or longer! Be patient and do NOT reboot!";
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y upgrade };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error upgrading system - Error $exitcode";
                LOGDEB $output;
        $errors++;
} else {
        LOGOK "System upgrade successfully.";
}
qx { rm /var/cache/apt/archives/* };

# If no errors occurred, never start this script again
if (!$errors) {
	qx { rm /etc/cron.d/lbupdate_reboot_v1.2.0 };
}

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
