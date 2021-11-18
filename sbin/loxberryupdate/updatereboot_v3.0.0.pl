#!/usr/bin/perl

# This script will be executed on next reboot
# from update_v2.0.0.pl

use LoxBerry::System;
use LoxBerry::Update;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 
my $version = "3.0.0";

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

our $log = LoxBerry::Log->new(
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

our $errors = 0;
LOGSTART "Update Reboot script $0 started.";
LOGINF "Message : Doing system upgrade (envoked from upgrade to V3.0.0)";

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
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv300 };
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
# Fix owner of /var/log
#
LOGINF "Change owner of /var/log to root:root...";
qx { chown root:root /var/log };

#
# Make dist-upgrade from Stretch to Buster
#
LOGINF "Preparing Guru Meditation...";
LOGINF "This will take some time now. We suggest getting a coffee or a beer.";
LOGINF "We are now moving the Debian Distribution from Buster to Bullseye.";

LOGINF "Cleaning up and updating apt databases...";
apt_update();

LOGINF "Removing package 'listchanges' - just in case it is still on the system...";
apt_remove("apt-listchanges");
LOGINF "Deactivating output of 'listchanges' - just in case it is still on the system...";
if (-e "/etc/apt/listchanges.conf") {
      my $output = qx { sed -i 's/frontend=pager/frontend=none/' /etc/apt/listchanges.conf };
}

LOGINF "Removing package 'libc6-dev' - we will reinstall it in V8 later on. But V6 will break the upgrade...";
apt_remove("libc6-dev");

LOGINF "Executing upgrade...";
apt_upgrade();

LOGINF "Executing dist-upgrade...";
apt_distupgrade();

LOGINF "Cleaning up and updating apt databases...";
apt_update();

LOGINF "Update apt sources from buster to bullseye...";
$log->close;
my $output = qx { find /etc/apt -name "sources.list" | xargs sed -i '/^deb/s/buster/bullseye/g' >> $logfilename 2>&1 };
$log->open;

LOGINF "Cleaning up and updating apt databases...";
apt_update();

LOGINF "Executing upgrade...";
apt_upgrade();

LOGINF "Installing packages 'gcc-8-base' and 'libgcc-8-dev'...";
apt_install("libgcc-8-dev gcc-8-base");

LOGINF "Executing dist-upgrade...";
apt_distupgrade();

LOGINF "Cleaning up and updating apt databases...";
apt_update();

LOGINF "Executing full-upgrade...";
apt_fullupgrade();

LOGINF "Cleaning up and updating apt databases...";
apt_update();

LOGINF "Removing package 'AppArmor'...";
apt_remove("apparmor");

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
if ( -e "/etc/php/7.4" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.4/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.4/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.4/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
};
$log->open;

LOGINF "Activating PHP7.4...";
apt_remove("php7.0-common php7.3-common");
apt_install("php7.4-bz2 php7.4-curl php7.4-json php7.4-mbstring php7.4-mysql php7.4-opcache php7.4-readline php7.4-soap php7.4-sqlite3 php7.4-xml php7.4-zip php7.4-cgi");
$log->close;
my $output = qx { a2enmod php7.4 >> $logfilename 2>&1 };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error occurred while activating PHP7.4 Apache Module - Error $exitcode";
	$errors++;
} else {
	LOGOK "PHP7.4 Apache module activated successfully.";
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
# GIT Firmware Hash:   d5edc6af1ef48f97b525da88ff6c510c2d4231c3
# dirtree Checksum is: 7d32024a09eac34dfe5e511ebbc01af7
rpi_update("7d32024a09eac34dfe5e511ebbc01af7", "d5edc6af1ef48f97b525da88ff6c510c2d4231c3");

#
# Firmware Files are not updated automatically by apt-get (why? *really* don't no!)
#
LOGINF "Installing newest firmware files (from Debian Buster because Bullseye sin't currently available)...";
# Use RPi-Distro Repo
system("curl -L https://github.com/RPi-Distro/firmware-nonfree/archive/refs/heads/buster.zip -o /lib/master.zip");
system("cd /lib && unzip /lib/master.zip");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error extracting new firmware. This is a problem for Zero2 only. Wifi may not work on the Zero2 - Error $exitcode";
} else {
        LOGOK "Extracting of new firmware files successfully. Installing...";
	system ("rm -r /lib/firmware");
	system("mv /lib/firmware-nonfree-master /lib/firmware");
}
system ("rm -r /lib/master.zip");

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
	qx { rm $lbhomedir/system/daemons/system/99-updaterebootv300 };
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

qx { chown loxberry:loxberry $logfilename };

# End of script
exit($errors);

END
{
	LOGINF "Will reboot now to restart Apache...";
	LOGEND;
	system ("/sbin/reboot");
}
