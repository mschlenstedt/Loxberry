#!/usr/bin/perl

# This script will be executed on next reboot
# from update_v2.0.0.pl

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 
my $scriptversion = "2.0.0.6";

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
LOGINF "Message : Doing system upgrade (envoked from upgrade to V2.0.0)";

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
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv200 };
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

LOGINF "Removing package 'AppArmor'...";
$log->close;
my $output = qx { APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends -y --fix-broken --reinstall remove apparmor >> $logfilename 2>&1 };
$log->open;
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while removing packages - Error $exitcode";
	$errors++;
} else {
	LOGOK "Packages removed successfully.";
}

LOGINF "Configuring PHP...";
$log->close;
if ( -e "/etc/php/7.0" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.0/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.0/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.0/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.1" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.1/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.1/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.1/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.2" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.2/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.2/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.2/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
};
if ( -e "/etc/php/7.3" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.3/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.3/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.3/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
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
if ( -e "/etc/logrotate.conf.dpkg-new" ) {
	my $output = qx { mv -v /etc/logrotate.conf.dpkg-new /etc/logrotate.conf >> $logfilename 2>&1 };
}
if ( -e "/etc/logrotate.conf.dpkg-dist" ) {
	my $output = qx { mv -v /etc/logrotate.conf.dpkg-dist /etc/logrotate.conf >> $logfilename 2>&1 };
}
my $output = qx { sed -i 's/^#compress/compress/g' /etc/logrotate.conf >> $logfilename 2>&1 };
$log->open;

# Update Kernel and Firmware
if (-e "$lbhomedir/config/system/is_raspberry.cfg" && !-e "$lbhomedir/config/system/is_odroidxu3xu4.cfg") {
	LOGINF "Preparing Guru Meditation...";
	LOGINF "This will take some time now. We suggest getting a coffee or a second beer :-)";
	LOGINF "Upgrading system kernel and firmware. Takes up to 10 minutes or longer! Be patient and do NOT reboot!";

	qx { rm /boot/.firmware_revision };
	#qx { rm /boot/kernel*.img };
	$log->close;
	system (" SKIP_WARNING=1 SKIP_BACKUP=1 BRANCH=stable WANT_PI4=1 /usr/bin/rpi-update f8c5a8734cde51ab94e07c204c97563a65a68636 >> $logfilename 2>&1 ");
	$log->open;
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
        	LOGERR "Error upgrading kernel and firmware - Error $exitcode";
        	$errors++;
	} else {
        	LOGOK "Upgrading kernel and firmware successfully.";
	}
}

#
# Reinstall Python packages, because rasbian's upgrade will overwrite all of them...
#
LOGINF "Upgrade python packages...";
if (-e "$lbsdatadir/pip_list.dat") {
	$log->close;
	system("cat $lbsdatadir/pip_list.dat | cut -d = -f 1 | xargs -n1 pip install >> $logfilename 2>&1");
	system("mv $lbsdatadir/pip_list.dat $lbsdatadir/pip_list.dat.bkp");
	$log->open;
}
if (-e "$lbsdatadir/pip3_list.dat") {
	$log->close;
	system("cat $lbsdatadir/pip3_list.dat | cut -d = -f 1 | xargs -n1 pip3 install >> $logfilename 2>&1");
	system("mv $lbsdatadir/pip3_list.dat $lbsdatadir/pip3_list.dat.bkp");
	$log->open;
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
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv200 };
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

# Continue with LoxBerry Update
LOGINF "Continue with updating ...";
$syscfg = new Config::Simple("$lbsconfigdir/general.cfg") or LOGERR "Cannot read general.cfg";
my $querytype = $syscfg->param('UPDATE.RELEASETYPE');
if(!$querytype) {
	$querytype = "release";
}
#$log->close;
#system (". /etc/environment && /opt/loxberry/sbin/loxberryupdatecheck.pl querytype=$querytype update=1 nofork=1 >> $logfilename 2>&1");
#$log->open;
LOGINF "Continuing with Upgrade ON NEXT REBOOT.";
open(F,">$lbhomedir/system/daemons/system/98-updaterebootcontinue");
print F <<EOF;
#!/bin/bash
$lbhomedir/sbin/loxberryupdatecheck.pl querytype=$querytype update=1
rm $lbhomedir/system/daemons/system/98-updaterebootcontinue
EOF
close (F);
qx { chmod +x $lbhomedir/system/daemons/system/98-updaterebootcontinue };

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
