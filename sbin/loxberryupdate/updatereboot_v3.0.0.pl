#!/usr/bin/perl

# This script will be executed on next reboot
# from update_v3.0.0.pl

use LoxBerry::System;
use LoxBerry::Update;
use LoxBerry::Log;
use LoxBerry::JSON;
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
	LOGINF "Re-Enabling Unattended Upgrades...";
	my $output = qx { systemctl enable unattended-upgrades };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error occurred while re-enabling Unattended Upgrades - Error $exitcode";
		$errors++;
	} else {
		LOGOK "Unattended Upgrades enabled successfully.";
	}
	if (-e "/etc/init.d/rpimonitor") {
		LOGINF "Re-Enabling RPI Monitor Service...";
		my $output = qx { systemctl enable rpimonitor };
		my $exitcode = $? >> 8;
		if ($exitcode != 0) {
			LOGERR "Error occurred while re-enabling RPI Monitor. Ignoring this error... - Error $exitcode";
		} else {
			LOGOK "RPI Monitor enabled successfully.";
		}
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
my $hostname = 'loxberry.de';
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

LOGINF "Stopping unattended-upgrades...";
my $output = qx { systemctl stop unattended-upgrades };
LOGINF "Stopping rpimonitor...";
my $output = qx { systemctl stop rpimonitor };

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
# Fix rights of /tmp
#
LOGINF "Change permissions of /tmp to 1777...";
qx { chmod 1777 /tmp };

LOGINF "(Re-)Set current date/time to make sure communication with apt-servers will be ok - seems to be a problem on VMs sometimes...";
my $output = qx { su loxberry -c "$lbhomedir/sbin/setdatetime.pl" };

#
# Fix broken /boot filesystem from previous Image
#
LOGINF "Checking Boot Partition...";
my %folderinfo = LoxBerry::System::diskspaceinfo('/boot');
my $repairerror;;
my $findmnt;
my $bootfound;
if (-e "$lbsconfigdir/is_raspberry.cfg") {
	my ($rc, $output) = execute( command => "findmnt /boot -b -J", log => $log );
	eval {
		$findmnt = decode_json( $output );
	};
	if( $rc != 0 or ! $findmnt ) {
		LOGERR "Could not read mountlist (findmnt /boot)";
	} else {
		if ($findmnt->{filesystems}[0]->{"source"} eq "/dev/mmcblk0p1" || $findmnt->{filesystems}[0]->{"fstype"} eq "vfat") {
			$bootfound = 1;
		}
	}
} else {
	LOGINF "Seems this is not a Raspberry - fine, everything should be fine.";
}
if ($folderinfo{size} eq "6657428" && -e "$lbsconfigdir/is_raspberry.cfg" && $bootfound eq "1") {
	LOGINF "The filesystem of your boot partition seems to be broken. We will repair it now.";
	execute( command => "rm -rf /boot.repair", log => $log );
	execute( command => "mkdir -p /boot.repair", log => $log );
	$exitcode  = $? >> 8;
	if ( $? >> 8 > 0) {
		LOGERR "Could not create temporary folder /boot.repair. Repairing of /boot failed.";
		$repairerror++;
	}
	if ($repairerror < 1) {
		execute( command => "cd /boot && tar cSp --numeric-owner --warning='no-file-ignored' -f - . | (cd /boot.repair && tar xSpvf - )", log => $log );
		if ( $? >> 8 > 0) {
			LOGERR "Could not backup /boot into /boot.repair. Repairing of /boot failed.";
			execute( command => "rm -rf /boot.repair", log => $log );
			$repairerror++;
		}
	}
	if ($repairerror < 1) {
		my ($rc, $output) = execute( command => "findmnt /boot -b -J", log => $log );
		eval {
			$findmnt = decode_json( $output );
		};
		if( $rc != 0 or ! $findmnt ) {
			LOGERR "Could not read mountlist (findmnt /boot)";
			$repairerror++;
		}
	}
	if ($repairerror < 1 ) {
		if ($findmnt->{filesystems}[0]->{"source"} ne "/dev/mmcblk0p1" || $findmnt->{filesystems}[0]->{"fstype"} ne "vfat") {
			LOGERR "Cannot find a valid boot partition at /boot. Repairing of /boot failed.";
			$repairerror++;
		} else {
			execute( command => "umount /boot", log => $log );
			execute( command => "mkfs.vfat /dev/mmcblk0p1", log => $log );
			if ( $? >> 8 > 0) {
				LOGERR "Could not create new Filesystem on /dev/mmcblk0p1. Repairing of /boot failed.";
				$repairerror++;
			}
		}
	}
	if ($repairerror < 1 ) {
		execute( command => "mount /boot", log => $log );
		if ( $? >> 8 > 0) {
			LOGERR "Could not remount /boot. Repairing of /boot failed.";
			$repairerror++;
		}
	}
	if ($repairerror < 1) {
		my ($rc, $output) = execute( command => "findmnt /boot -b -J", log => $log );
		eval {
			$findmnt = decode_json( $output );
		};
		if( $rc != 0 or ! $findmnt ) {
			LOGERR "Could not read mountlist (findmnt /boot)";
			$repairerror++;
		}
	}
	if ($repairerror < 1 ) {
		if ($findmnt->{filesystems}[0]->{"source"} ne "/dev/mmcblk0p1" || $findmnt->{filesystems}[0]->{"fstype"} ne "vfat") {
			LOGERR "Cannot find a valid boot partition at /boot. Repairing of /boot failed.";
			$repairerror++;
		}
	}
	if ($repairerror < 1) {
		execute( command => "cd /boot.repair && tar cSp --numeric-owner --warning='no-file-ignored' -f - . | (cd /boot && tar xSpvf - )", log => $log );
		if ( $? >> 8 > 0) {
			LOGERR "Could not restore backup from /boot.repair to /boot. Repairing of /boot failed.";
			$repairerror++;
		}
	}
	if ($repairerror < 1) {
		LOGOK "Repairing of /boot seems to be successfull. Good!";
		execute( command => "sync", log => $log );
		execute( command => "rm -rf /boot.repair", log => $log );
	} else {
		$errors++;
	}
}

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
      my $output = qx { sed -i --follow-symlinks 's/frontend=pager/frontend=none/' /etc/apt/listchanges.conf };
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
my $output = qx { find /etc/apt -name "*.list" | xargs sed -i --follow-symlinks '/^deb/s/buster/bullseye/g' >> $logfilename 2>&1 };
# Repair broken security mirror on VMs
my $output = qx { sed -i 's#^deb http://security.debian.org/debian-security bullseye/updates.*\$#deb http://security.debian.org/debian-security bullseye-security main contrib non-free#' /etc/apt/sources.list };
my $output = qx { sed -i 's#^deb-src http://security.debian.org/debian-security bullseye/updates.*\$#deb-src http://security.debian.org/debian-security bullseye-security main contrib non-free#' /etc/apt/sources.list };
$log->open;

LOGINF "Cleaning up and updating apt databases...";
apt_update();

LOGINF "Executing upgrade...";
apt_upgrade();

LOGINF "Installing packages 'gcc-8-base' and 'libgcc-8-dev'...";
apt_install("libgcc-8-dev gcc-8-base");

LOGINF "Cleaning up and updating apt databases...";
apt_update();

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

#
# Node.js V18
#
LOGINF "Installing Node.js V18...";
LOGINF "Adding Node.js repository key to LoxBerry keyring...";
my $output = qx { curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
		LOGERR "Error adding Node.js repo key to LoxBerry - Error $exitcode";
		LOGDEB $output;
	        $errors++;
	} else {
        	LOGOK "Node.js repo key added successfully.";
	}

LOGINF "Adding/Updating Node.js V18.x repository to LoxBerry...";
qx { echo 'deb https://deb.nodesource.com/node_18.x bullseye main' > /etc/apt/sources.list.d/nodesource.list };
qx { echo 'deb-src https://deb.nodesource.com/node_18.x bullseye main' >> /etc/apt/sources.list.d/nodesource.list };

if ( ! -e '/etc/apt/sources.list.d/nodesource.list' ) {
	LOGERR "Error adding Node.js repo to LoxBerry - Repo file missing";
        $errors++;
} else {
	LOGOK "Node.js repo added successfully.";
}
LOGINF "Update apt database";
apt_update();

LOGINF "Installing/updating Node.js V18...";
apt_install("nodejs");

LOGINF "Testing Node.js...";
LOGDEB `node -e "console.log('Hello LoxBerry users, this is Node.js '+process.version);"`;

#
# PHP
#
LOGINF "Activating PHP7.4...";
apt_remove("php7.0-common php7.1-common php7.2-common php7.3-common");
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

LOGINF "Configuring PHP7.4...";
$log->close;
if ( -e "/etc/php/7.4" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.4/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.4/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.4/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
};
$log->open;

LOGINF "Configuring logrotate...";
$log->close;
if ( -e "/etc/logrotate.conf.dpkg-new" ) {
	my $output = qx { mv -v /etc/logrotate.conf.dpkg-new /etc/logrotate.conf >> $logfilename 2>&1 };
}
if ( -e "/etc/logrotate.conf.dpkg-dist" ) {
	my $output = qx { mv -v /etc/logrotate.conf.dpkg-dist /etc/logrotate.conf >> $logfilename 2>&1 };
}
my $output = qx { sed -i --follow-symlinks 's/^#compress/compress/g' /etc/logrotate.conf >> $logfilename 2>&1 };
$log->open;

#
# Update Kernel and Firmware on Raspberry
# GIT Firmware Hash:   224cd2fe45becbb44fea386399254a1f84227218
#
LOGINF "Upgrading Linux Kernel if we are running on a Raspberry...";
rpi_update("224cd2fe45becbb44fea386399254a1f84227218");

#
# Firmware Files are not updated automatically by apt-get (why? *really* don't no!)
#
LOGINF "Installing newest firmware files from Debian Buillseye...";
system("curl -L https://github.com/RPi-Distro/firmware-nonfree/archive/refs/heads/bullseye.zip -o /lib/master.zip");
system("cd /lib && yes | unzip -o /lib/master.zip");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error extracting new firmware. This is a problem for PI ZeroW2 only. Wifi may not work on the Zero2 - Error $exitcode";
		system ("rm -r /lib/master.zip");
} else {
        LOGOK "Extracting of new firmware files successfully. Installing...";
		system ("rm -r /lib/master.zip");
		system("cp -vr /lib/firmware-nonfree-bullseye/debian/config/* /lib/firmware");
}
system ("rm -r /lib/firmware-nonfree-bullseye");
	
# Updating /boot/config.txt for Debian Bullseye
LOGINF "Updating /boot/config.txt...";
# Add arm_boost mode for Pi4
system ("cat /boot/config.txt | grep 'arm_boost'");
$exitcode  = $? >> 8;
if ($exitcode) {
	system("sed -i -e 's:^\\[pi4\\]:\\[pi4\\]\\n# Run as fast as firmware / board allows\\narm_boost=1:g' /boot/config.txt");
}
# Remove dtoverlay=vc4-fkms-v3d
system("sed -i -e 's:^dtoverlay=vc4-fkms-v3d:#dtoverlay=vc4-fkms-v3d:g' /boot/config.txt");
# Add dtoverlay=vc4-kms-v3d for all
system ("cat /boot/config.txt | grep 'vc4-kms-v3d'");
$exitcode  = $? >> 8;
if ($exitcode) {
	system("sed -i -e 's:^max_framebuffers=2:#max_framebuffers=2:g' /boot/config.txt");
	system("sed -i -e 's:^\\[all\\]:\\[all\\]\\n# Enable DRM VC4 V3D driver\\ndtoverlay=vc4-kms-v3d\\nmax_framebuffers=2:g' /boot/config.txt");
}

# Update /boot/cmdline.txt for Bullseye - do not use predictable network device names
LOGINF "Updating /boot/cmdline.txt...";
system("sed -i /boot/cmdline.txt -e 's/net.ifnames=0 *//'");
system("sed -i /boot/cmdline.txt -e 's/rootwait/net.ifnames=0 rootwait/'");
system("rm -f /etc/systemd/network/99-default.link");
system("rm -f /etc/systemd/network/73-usb-net-by-mac.link");
system("ln -sf /dev/null /etc/systemd/network/99-default.link");
system("ln -sf /dev/null /etc/systemd/network/73-usb-net-by-mac.link");

#
# Reinstall Python packages, because rasbian's upgrade will overwrite all of them...
#
LOGINF "Upgrade python packages...";
#if (-e "$lbsdatadir/pip_list.dat") {
#	$log->close;
#	system("cat $lbsdatadir/pip_list.dat | cut -d = -f 1 | xargs -n1 pip2 install >> $logfilename 2>&1");
#	system("mv $lbsdatadir/pip_list.dat $lbsdatadir/pip_list.dat.bkp");
#	$log->open;
#}
if (-e "$lbsdatadir/pip3_list.dat") {
	$log->close;
	system("cat $lbsdatadir/pip3_list.dat | cut -d = -f 1 | xargs -n1 pip3 install >> $logfilename 2>&1");
	system("mv $lbsdatadir/pip3_list.dat $lbsdatadir/pip3_list.dat.bkp");
	$log->open;
}

#
# Installing new raspi-config
#
LOGINF "Installing newest raspi-config (Release from 20221214)...";
system("rm /usr/bin/raspi-config");
system("curl -L https://raw.githubusercontent.com/RPi-Distro/raspi-config/0fc1f9552fc99332d57e3b6df20c64576466913a/raspi-config -o /usr/bin/raspi-config");
system("chmod +x /usr/bin/raspi-config");

#
# Installing new dependencies
#
LOGINF "Installing new packages for LoxBerry 3.0...";
apt_install("libcgi-simple-perl");

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
	LOGINF "Re-Enabling Unattended Upgrades...";
	my $output = qx { systemctl enable unattended-upgrades };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error occurred while re-enabling Unattended Upgrades - Error $exitcode";
		$errors++;
	} else {
		LOGOK "Unattended Upgrades enabled successfully.";
	}
	if (-e "/etc/init.d/rpimonitor") {
		LOGINF "Re-Enabling RPI Monitor Service...";
		my $output = qx { systemctl enable rpimonitor };
		my $exitcode = $? >> 8;
		if ($exitcode != 0) {
			LOGERR "Error occurred while re-enabling RPI Monitor. Ignoring this error... - Error $exitcode";
		} else {
			LOGOK "RPI Monitor enabled successfully.";
		}
	}
}

# Continue with LoxBerry Update on next reboot
$syscfg = new Config::Simple("$lbsconfigdir/general.cfg") or LOGERR "Cannot read general.cfg";
my $querytype = $syscfg->param('UPDATE.RELEASETYPE');
if(!$querytype) {
	$querytype = "release";
}
LOGINF "Continuing with Upgrade ON NEXT REBOOT.";
open(F,">$lbhomedir/system/daemons/system/98-updaterebootcontinue");
print F <<EOF;
#!/bin/bash
$lbhomedir/sbin/loxberryupdatecheck.pl querytype=$querytype update=1
rm $lbhomedir/system/daemons/system/98-updaterebootcontinue
EOF
close (F);
qx { chmod +x $lbhomedir/system/daemons/system/98-updaterebootcontinue };

#
# End
#
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
