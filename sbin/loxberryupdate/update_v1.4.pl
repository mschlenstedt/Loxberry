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
########################################################################

my $errors = 0;
LOGOK "Update script $0 started.";


## Commented, possibly re-use in 1.4? (from 1.2.5 updatescript)
LOGINF "Clean up apt databases and update";
my $output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -y --fix-broken install };
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -y autoremove };
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -y clean };
$output = qx { rm -r /var/cache/apt/archives/* };

$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/dpkg --configure -a };
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

LOGINF "Installing jq (json parser for shell)...";

$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --no-install-recommends -q -y --fix-broken --reinstall install jq };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error installing jq - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "jq package successfully installed";
}

LOGINF "Installing openvpn (for Remote Support Widget)...";

$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --no-install-recommends -q -y --fix-broken --reinstall install openvpn };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error installing openvpn - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "openvpn package successfully installed";
}

LOGINF "Installing watchdog...";
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --no-install-recommends -q -y --fix-broken --reinstall install watchdog };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error installing watchdog - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "watchdog package successfully installed";
}

# Diable it by default: watchdog
$output = qx { systemctl disable watchdog.service };
$output = qx { systemctl stop watchdog.service };

# Installing default config: watchdog
copy_to_loxberry("/system/watchdog", "root");
copy_to_loxberry("/system/watchdog/watchdog.conf", "loxberry");
$output = qx { mv /etc/watchdog.conf /etc/watchdog.bkp };
$output = qx { ln -f -s $lbhomedir/system/watchdog/watchdog.conf /etc/watchdog.conf };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink $lbhomedir/system/watchdog/watchdog.conf - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Symlink $lbhomedir/system/watchdog/watchdog.conf created successfully";
}
system("/bin/sed -i 's:REPLACELBHOMEDIR:$lbhomedir:g' $lbhomedir/system/watchdog/rsyslog.conf");
$output = qx ( cat /etc/default/watchdog | grep -q -e "watchdog_options" );
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	qx (echo 'watchdog_options=""' >> /etc/default/watchdog);
}
system("/bin/sed -i 's:watchdog_options=\"\\(.*\\)\":watchdog_options=\"\\1 -v\":g' /etc/default/watchdog");
$output = qx { ln -f -s $lbhomedir/system/watchdog/rsyslog.conf /etc/rsyslog.d/10-watchdog.conf };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink $lbhomedir/system/watchdog/rsyslog.conf - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Symlink $lbhomedir/system/watchdog/rsyslog.conf created successfully";
}
system("systemctl restart rsyslog.service");

LOGINF "Converting mail.cfg to mail.json";
$oldmailfile = $lbsconfigdir . "/mail.cfg";
$newmailfile = $lbsconfigdir . "/mail.json";

if (! -e $oldmailfile) {
	LOGWARN "No mail configuration found to migrate - skipping migration";
} else { 
	
	unlink $newmailfile;
	
	require LoxBerry::JSON;
	
	LOGDEB "Loading mail.cfg";
	Config::Simple->import_from($oldmailfile, \%oldmcfg);
	LOGDEB "Creating mail.json";
	my $newmailobj = LoxBerry::JSON->new();
	my $newmcfg = $newmailobj->open(filename => $newmailfile);
	
	LOGDEB "Migrating settings...";
	
	foreach my $key (sort keys %oldmcfg) {
		my ($section, $param) = split('\.', $key, 2);
		#LOGDEB "ref $param is " . ref($oldmcfg{$key});
		if(ref($oldmcfg{$key}) eq 'ARRAY') {
			LOGWARN "Parameter $param had commas in it's field. Migration has tried to";
			LOGWARN "restore the value, but you should check the Mailserver widget settings and";
			LOGWARN "save it's settings again.";
			my $tmpfield = join(',', @{$oldmcfg{$key}});
			$oldmcfg{$key} = $tmpfield;
		}
		# LOGDEB "$section $param = " . $oldmcfg{$key};
		$newmcfg->{$section}->{$param} = %oldmcfg{$key};
		my $logline = index(lc($key), 'pass') != -1 ? "Migrated $section.$param = *****" : "Migrated $section.$param = $oldmcfg{$key}";
		LOGINF $logline;
	}
	
	if ( $newmcfg->{SMTP}->{EMAIL} and $newmcfg->{SMTP}->{SMTPSERVER} and $newmcfg->{SMTP}->{PORT} ) {
		# Enable mail by default if settings are made
		$newmcfg->{SMTP}->{ACTIVATE_MAIL} = "1";
	}
	
	$newmailobj->write();
	`chown loxberry:loxberry $newmailfile`;
	`chmod 0600 $newmailfile`;
	LOGINF "Deleting old mail settings file...";
	unlink $oldmailfile;
	LOGOK "Migrated your mail settings. Check your settings in the Mailserver widget.";
	
}

# Some new files from ~/system
LOGINF "Installing some new system configs...";
copy_to_loxberry("/system/sudoers/lbdefaults", "root");
copy_to_loxberry("/system/supportvpn", "loxberry");
copy_to_loxberry("/system/daemons/system/04-remotesupport", "root");
copy_to_loxberry("/system/network/interfaces.eth_dhcp", "loxberry");
copy_to_loxberry("/system/network/interfaces.eth_static", "loxberry");
copy_to_loxberry("/system/network/interfaces.wlan_dhcp", "loxberry");
copy_to_loxberry("/system/network/interfaces.wlan_static", "loxberry");

LOGINF "Installing daily cronjob for plugin update checks...";
$output = qx { rm -f $lbhomedir/system/cron/cron.weekly/pluginsupdate.pl };
$output = qx { ln -f -s $lbhomedir/sbin/pluginsupdate.pl $lbhomedir/system/cron/cron.daily/02-pluginsupdate.pl };

# Upgrade Raspbian on next reboot
LOGINF "Upgrading system to latest Raspbian release ON NEXT REBOOT.";
my $logfilename_wo_ext = $logfilename;
$logfilename_wo_ext =~ s{\.[^.]+$}{};
open(F,">$lbhomedir/system/daemons/system/99-updaterebootv140");
print F <<EOF;
#!/bin/bash
perl $lbhomedir/sbin/loxberryupdate/updatereboot_v1.4.0.pl logfilename=$logfilename_wo_ext-reboot 2>&1
EOF
close (F);
qx { chmod +x $lbhomedir/system/daemons/system/99-updaterebootv140 };

# Update Kernel and Firmware
if (-e "$lbhomedir/config/system/is_raspberry.cfg" && !-e "$lbhomedir/config/system/is_odroidxu3xu4.cfg") {
	LOGINF "Preparing Guru Meditation...";
	LOGINF "This will take some time now. We suggest getting a coffee or a second beer :-)";
	LOGINF "Upgrading system kernel and firmware. Takes up to 10 minutes or longer! Be patient and do NOT reboot!";

	my $output = qx { SKIP_WARNING=1 SKIP_BACKUP=1 BRANCH=stable /usr/bin/rpi-update 3678d3dba62d8d4ad9cce5ceeab3b377e0ee059d };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
        	LOGERR "Error upgrading kernel and firmware - Error $exitcode";
        	LOGDEB $output;
                $errors++;
	} else {
        	LOGOK "Upgrading kernel and firmware successfully.";
	}
}

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);


sub delete_directory
{
	
	require File::Path;
	my $delfolder = shift;
	
	if (-d $delfolder) {   
		File::Path::rmtree($delfolder, {error => \my $err});
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					LOGERR "     Delete folder: general error: $message";
				} else {
					LOGERR "     Delete folder: problem unlinking $file: $message";
				}
			}
		return undef;
		}
	}
	return 1;
}


####################################################################
# Copy a file or dir from updatedir to lbhomedir including error handling
# Parameter:
#	file/dir starting from ~ 
#   (without /opt/loxberry, with leading /)
#       owner
####################################################################
sub copy_to_loxberry
{
	my ($destparam, $destowner) = @_;
		
	my $destfile = $lbhomedir . $destparam;
	my $srcfile = $updatedir . $destparam;
	if (!$destowner) {$destowner = "root"};	

	if (! -e $srcfile) {
		LOGINF "$srcfile does not exist - This file might have been removed in a later LoxBerry verion. No problem.";
		return;
	}
	
	my $output = qx { cp -rf $srcfile $destfile 2>&1 };
	my $exitcode  = $? >> 8;

	if ($exitcode != 0) {
		LOGERR "Error copying $destparam - Error $exitcode";
		LOGINF "Message: $output";
		$errors++;
	} else {
		LOGOK "$destparam installed.";
	}

	$output = qx { chown -R $destowner:$destowner $destfile 2>&1 };
	$exitcode  = $? >> 8;

	if ($exitcode != 0) {
		LOGERR "Error changing owner to $destowner for $destfile - Error $exitcode";
		LOGINF "Message: $output";
		$errors++;
	} else {
		LOGOK "$destfile owner changedi to $destowner.";
	}

}
