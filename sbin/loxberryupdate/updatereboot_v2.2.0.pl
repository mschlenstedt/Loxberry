#!/usr/bin/perl

# This script will be executed on next reboot
# from update_v2.0.0.pl

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 
my $scriptversion = "2.2.0.0";

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
LOGINF "Message : Doing system upgrade (envoked from upgrade to V2.2.0)";

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
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv220 };
	qx { rm /boot/rebootupdatescript };
	LOGINF "Re-Enabling Apache2...";
	my $output = qx { systemctl enable apache2.service };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error occurred while re-enabling Apache2 - Error $exitcode";
		$errors++;
	} else {
		LOGOK "Apache2 enabled successfully.";
	}
	exit 1;
} else {
	open(F,">/boot/rebootupdatescript");
	$starts++;
	print F "$starts";
	close (F);
}

# Sleep waiting network to be up after boot
use Net::Ping;
my $p = Net::Ping->new();
my $hostname = 'google.com';
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
# Stopping Apache 2
#
my $port = lbwebserverport();
LOGINF "Stopping Apache2...";
my $output = qx { systemctl stop apache2.service };
sleep (2);
my $output = qx { fuser -k $port/tcp };
sleep (2);

#
# Start simple Webserver
#
LOGINF "Starting simple update webserver...";
system ("$lbhomedir/sbin/updaterebootwebserver.pl $logfilename </dev/null >/dev/null 2>&1 &");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred - Error $exitcode";
	$errors++;
} else {
	LOGOK "Started simple webserver successfully.";
}

#
# Upgrade distribution
#
LOGINF "Preparing Guru Meditation...";
LOGINF "This will take some time now. We suggest getting a coffee or a beer.";
LOGINF "We are now moving the Debian Distribution from Stretch to Buster.";

LOGINF "Cleaning up apt databases...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y --fix-broken install >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while installing broken packages - Error $exitcode";
	$errors++;
} else {
	LOGOK "Installed broken packages successfully.";
}
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages -y autoremove >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while autoremoving packages - Error $exitcode";
	$errors++;
} else {
	LOGOK "Autoremoved packages successfully.";
}
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages -y clean >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while cleaning cache - Error $exitcode";
	$errors++;
} else {
	LOGOK "Cache cleaned successfully.";
}
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/dpkg --configure -a >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while repairing dpkg configure - Error $exitcode";
	$errors++;
} else {
	LOGOK "DPKG configure repaired successfully.";
}

LOGINF "Updating apt databases...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages -y update >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while updating - Error $exitcode";
	$errors++;
} else {
	LOGOK "Updating apt successfully.";
}

LOGINF "Executing upgrade...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --fix-broken -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" upgrade >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while upgrading - Error $exitcode";
	$errors++;
} else {
	LOGOK "Upgrading apt successfully.";
}

# If errors occurred, mark this script as failed. If ok, never start it again.
if ($errors) {
	LOGINF "Setting update script $0 as failed in general.cfg.";
	$failed_script = version->parse(vers_tag($version));
	$syscfg = new Config::Simple("$lbsconfigdir/general.cfg") or LOGERR "Cannot read general.cfg";
	$syscfg->param('UPDATE.FAILED_SCRIPT', "$failed_script");
	$syscfg->write();
	undef $syscfg;
} else {
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv220 };
	qx { rm /boot/rebootupdatescript };
	LOGINF "Re-Enabling Apache2...";
	my $output = qx { systemctl enable apache2.service };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error occurred while re-enabling Apache2 - Error $exitcode";
		$errors++;
	} else {
		LOGOK "Apache2 enabled successfully.";
	}
}

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

qx { "chown loxberry:loxberry $logfilename" };

# End of script
exit($errors);

END
{
	LOGINF "Will reboot now to restart Apache...";
	LOGEND;
	system ("/sbin/reboot");
}
