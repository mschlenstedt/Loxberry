#!/usr/bin/perl

# This script will be executed on next reboot
# It is invoked from cron (@reboot) by
# update_v1.4.0.pl

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 
my $version = "1.4.0";

# Initialize logfile and parameters
my $logfilename;
my $ext;
if ($cgi->param('logfilename')) {
	$logfilename = $cgi->param('logfilename');
	my $n = 0;
	$ext = "";
	while ( -e "$logfilename$ext.log" ) {
		$n++;
		$ext = "-$n";
	}
} 

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
LOGSTART "Update Reboot script $0 started.";
LOGINF "Message : Doing system upgrade (envoked from upgrade to V1.4.0)";

# Check how often we have tried to start. Abort if > 10 times.
my $starts;
if (!-e "/boot/rebootupdatescript") {
	$starts = 0;
} else {
	open(F,"</boot/rebootupdatescript");
	$starts = <F>;
	chomp ($starts);
	close (F);
}
LOGINF "This script already started $starts times.";
if ($starts >=10) {
	LOGCRIT "We tried 10 times without success. This is the last try.";
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv140 };
	qx { rm /boot/rebootupdatescript };
} else {
	open(F,">/boot/rebootupdatescript");
	$starts++;
	print F "$starts";
	close (F);
}

# Sleep waiting network to be up after boot
use Net::Ping;
my $p = Net::Ping->new();
my $hostname = 'download.loxberry.de';
my $success = 0;
foreach my $c (1 .. 5) {
	LOGINF "Try to reach $hostname";
	my ($ret, $duration, $ip) = $p->ping($hostname);
	if ($ret) {
		LOGOK "$hostname is reachable, so network seems to be up.";
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

#
# Repair broken update attempts 
#
LOGINF "Repair broken apt database from maybe broken updates";

$log->close;
my $output = qx { /usr/bin/apt-get -q -y --fix-broken install >> $logfilename 2>&1 };
$log->open;
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error repairing apt database - Error $exitcode";
        LOGDEB $output;
                $errors++;
} else {
        LOGOK "Repairing broken apt database successfully.";
}

#
# Upgrade Raspbian
#
LOGINF "Preparing Guru Meditation...";
LOGINF "This will take some time now. We suggest getting a coffee or a beer.";
LOGINF "Upgrading system to latest Raspbian release.";

$log->close;
my $output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/dpkg --configure -a >> $logfilename 2>&1 };
$log->open;
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode";
        LOGDEB $output;
                $errors++;
} else {
        LOGOK "Configuring dpkg successfully.";
}
$log->close;
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y update >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error updating apt database - Error $exitcode";
                LOGDEB $output;
        $errors++;
} else {
        LOGOK "Apt database updated successfully.";
}
LOGINF "Now upgrading all packages... Takes up to 10 minutes or longer! Be patient and do NOT reboot!";
$log->close;
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y upgrade >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error upgrading system - Error $exitcode";
                LOGDEB $output;
        $errors++;
} else {
        LOGOK "System upgrade successfully.";
}
qx { rm /var/cache/apt/archives/* };

# If errors occurred, mark this script as failed. If ok, never start it again.
if ($errors) {
	LOGINF "Setting update script $0 as failed in general.cfg.";
	$failed_script = version->parse(vers_tag($version));
	$syscfg = new Config::Simple("$lbsconfigdir/general.cfg") or LOGERR "Cannot read general.cfg";
	$syscfg->param('UPDATE.FAILED_SCRIPT', "$failed_script");
	$syscfg->write();
	undef $syscfg;
} else {
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv140 };
	qx { rm /boot/rebootupdatescript };
}

qx { "chown loxberry:loxberry $logfilename" };

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);

END
{
	LOGEND;
}
