#!/usr/bin/perl

# This script will be executed on next reboot
# from update_v1.5.0.pl

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 
my $version = "1.5.0";

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
LOGINF "Message : Doing system upgrade (envoked from upgrade to V1.5.0)";

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
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv150 };
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
# Stopping Apache 2
#
LOGINF "Stopping Apache2...";
my $output = qx { systemctl stop apache2.service };
sleep (2);
my $output = qx { fuser -k 80/tcp };
sleep (2);

#
# Start simple Webserver
#
LOGINF "Starting simple update webserver...";
system ("$lbhomedir/sbin/loxberryupdate/updaterebootwebserver.pl $logfilename </dev/null >/dev/null 2>&1 &");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred - Error $exitcode";
	$errors++;
} else {
	LOGOK "Started simple webserver successfully.";
}

#
# Make dist-upgrade from Stretch to Buster
#
LOGINF "Preparing Guru Meditation...";
LOGINF "This will take some time now. We suggest getting a coffee or a beer.";
LOGINF "We are now moving the Debian Distribution from Stretch to Buster.";

LOGINF "Update apt sources from stretch to buster...";
$log->close;
my $output = qx { find /etc/apt -name "*.list" | xargs sed -i '/^deb/s/stretch/buster/g' >> $logfilename 2>&1 };
$log->open;

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
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y autoremove >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while autoremoving packages - Error $exitcode";
	$errors++;
} else {
	LOGOK "Autoremoved packages successfully.";
}
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y clean >> $logfilename 2>&1 };
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

LOGINF "Removing package 'listchanges' and 'lighttpd'...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends -y --fix-broken --reinstall remove apt-listchanges lighttpd >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while removing packages - Error $exitcode";
	$errors++;
} else {
	LOGOK "Packages removed successfully.";
}

LOGINF "Updating apt databases...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y update >> $logfilename 2>&1 };
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
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --fix-broken -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" upgrade >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while upgrading - Error $exitcode";
	$errors++;
} else {
	LOGOK "Upgrading apt successfully.";
}

LOGINF "Executing dist-upgrade...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --fix-broken -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" dist-upgrade >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while dist-upgrade - Error $exitcode";
	$errors++;
} else {
	LOGOK "Dist-Upgrade successfully.";
}

LOGINF "Configuring PHP7.3...";
$log->close;
if ( -e "/etc/php/7.0" && !-e "/etc/php/7.0/apache2/conf.d/20-loxberry.ini" ) {
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.0/apache2/conf.d/20-loxberry.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.0/cgi/conf.d/20-loxberry.ini >> $logfilename 2>&1};
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.0/cli/conf.d/20-loxberry.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.1" && !-e "/etc/php/7.1/apache2/conf.d/20-loxberry.ini" ) {
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.1/apache2/conf.d/20-loxberry.ini >> $logfilename 2>&1};
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.1/cgi/conf.d/20-loxberry.ini >> $logfilename 2>&1};
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.1/cli/conf.d/20-loxberry.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.2"  && !-e "/etc/php/7.2/apache2/conf.d/20-loxberry.ini" ) {
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.2/apache2/conf.d/20-loxberry.ini>> $logfilename 2>&1 };
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.2/cgi/conf.d/20-loxberry.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.2/cli/conf.d/20-loxberry.ini >> $logfilename 2>&1 };
};
if ( -e "/etc/php/7.3" && !-e "/etc/php/7.3/apache2/conf.d/20-loxberry.ini" ) {
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.3/apache2/conf.d/20-loxberry.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.3/cgi/conf.d/20-loxberry.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vs $LBHOME/system/php/20-loxberry.ini /etc/php/7.3/cli/conf.d/20-loxberry.ini >> $logfilename 2>&1 };
};
$log->open;

LOGINF "Activating PHP7.3...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends -y --fix-broken --reinstall remove php7.0-common >> $logfilename 2>&1 };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Error occurred while removing PHP 7.0 - Error $exitcode";
} else {
	LOGOK "PHP7.0 removed successfully.";
}
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends -y --fix-broken --reinstall install php7.3-bz2 php7.3-curl php7.3-json php7.3-mbstring php7.3-mysql php7.3-opcache php7.3-readline php7.3-soap php7.3-sqlite3 php7.3-xml php7.3-zip php7.3-cgi >> $logfilename 2>&1 };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while installing PHP 7.3 modules - Error $exitcode";
	$errors++;
} else {
	LOGOK "PHP7.3 modules installed successfully.";
}
my $output = qx { a2enmod php7.3 >> $logfilename 2>&1 };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while activating PHP7.3 Apache Module - Error $exitcode";
	$errors++;
} else {
	LOGOK "PHP7.3 Apache module activated successfully.";
}
$log->open;

LOGINF "Configuring logrotate...";
$log->close;
my $output = qx { mv -v /etc/logrotate.conf.dpkg-new /etc/logrotate.conf >> $logfilename 2>&1 };
my $output = qx { sed -i 's/^#compress/compress/g' /etc/logrotate.conf >> $logfilename 2>&1 };
$log->open;





# If errors occurred, mark this script as failed. If ok, never start it again.
if ($errors) {
	LOGINF "Setting update script $0 as failed in general.cfg.";
	$failed_script = version->parse(vers_tag($version));
	$syscfg = new Config::Simple("$lbsconfigdir/general.cfg") or LOGERR "Cannot read general.cfg";
	$syscfg->param('UPDATE.FAILED_SCRIPT', "$failed_script");
	$syscfg->write();
	undef $syscfg;
} else {
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv150 };
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

qx { chown loxberry:loxberry $logfilename };

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);

END
{
	my $reboot;
	# Kill simple webserver - try several times...
	LOGINF "Killing simple update webserver...";
	my $output = qx { pkill -f updaterebootwebserver };
	my $output = qx { fuser -k 80/tcp };
	sleep (2);
	LOGINF "Restart Apache2...";
	my $output = qx { systemctl start apache2.service };
	$exitcode = $? >> 8;
	if ($exitcode != 0) {
		LOGINF "Could not start Apache webserver - Error $exitcode";
		LOGINF "Will reboot now to restart Apache...";
		$reboot = 1;
	} else {
		LOGOK "Apache2 webserver started successfully.";
	}
	LOGEND;

	if ( $reboot ) {
		system ("reboot");
	}
}
