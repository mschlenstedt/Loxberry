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

#
# Remove old usbautomount
#
LOGINF "Removing old usbmount";

qx { rm -f /etc/systemd/system/systemd-udevd.service };
qx { rm -rf $lbhomedir/system/storage };

my $output = qx { /usr/bin/dpkg --configure -a };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode";
        LOGDEB $output;
                $errors++;
} else {
        LOGOK "Configuring dpkg successfully.";
}
$output = qx { /usr/bin/apt-get -q -y update };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error updating apt database - Error $exitcode";
                LOGDEB $output;
        $errors++;
} else {
        LOGOK "Apt database updated successfully.";
}
$output = qx { /usr/bin/apt-get -q -y remove usbmount pmount };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error uninstalling packages usbmount pmount with apt-get - Error $exitcode";
        LOGDEB $output;
        $errors++;
} else {
        LOGOK "Uninstalling usbmount pmount successfully.";
}

#
# Install new usbautomount
#
LOGINF "Installing usb automount";
qx { mkdir -p /media/smb };
qx { mkdir -p /media/usb };
qx { mkdir -p $lbhomedir/system/storage };
qx { mkdir -p $lbhomedir/system/storage/smb };
$output = qx { ln -f -s /media/usb $lbhomedir/system/storage/usb };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink $lbhomedir/system/storage/usb - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Symlink $lbhomedir/system/storage/usb created successfully";
}
qx { chown -R loxberry:loxberry $lbhomedir/system/storage };

LOGINF "Creating /etc/systemd/system/usb-mount@.service";

if ( !-e "/etc/systemd/system/usb-mount@.service" ) {
	open(F,">/etc/systemd/system/usb-mount@.service");
	print F <<EOF;
[Unit]
Description=Mount USB Drive on %i
[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=$lbhomedir/sbin/usb-mount.sh add %i
ExecStop=$lbhomedir/sbin/usb-mount.sh remove %i
EOF
	close (F);
}

if ( !-e "/etc/udev/rules.d/99-usbmount.rules" ) {
	open(F,">/etc/udev/rules.d/99-usbmount.rules");
	print F <<EOF;
KERNEL=="sd[a-z]*[0-9]", SUBSYSTEMS=="usb", ACTION=="add", RUN+="/bin/systemctl start usb-mount@%k.service"
KERNEL=="sd[a-z]*[0-9]", SUBSYSTEMS=="usb", ACTION=="remove", RUN+="/bin/systemctl stop usb-mount@%k.service"
EOF
	close (F);
}

#
# Installing autofs for SMB automounts
#
LOGINF "Installing Autofs";

$output = qx { /usr/bin/apt-get -q -y install autofs smbclient };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error installing packages autofs smbclient with apt-get - Error $exitcode";
        LOGDEB $output;
        $errors++;
} else {
        LOGOK "Installing autofs smbclient successfully.";
}

$output = qx {awk -v s='/media/smb /etc/auto.smb --timeout=300 --ghost' '/^\\/media\\/smb/{\$0=s;f=1} {a[++n]=\$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/auto.master };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error replacing string /media/smb in /etc/auto.master - Error $exitcode";
        LOGDEB $output;
        $errors++;
} else {
        LOGOK "Replacing string /media/smb successfully in /etc/auto.master";
}

#
# Samba
#

LOGINF "Replacing system samba config file";
LOGINF "Copying new";

qx { mkdir -p $lbhomedir/system/samba/credentials };
$output = qx { if [ -e $updatedir/system/samba/smb.conf ] ; then cp -f $updatedir/system/samba/smb.conf $lbhomedir/system/samba/ ; fi };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error copying new samba config file - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "New samba config file copied.";
}

$output = qx { ln -f -s $lbhomedir/system/samba/credentials /etc/creds };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink /etc/creds - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Symlink /etc/creds created successfully";
}

qx { chown loxberry:loxberry $lbhomedir/system/samba/smb.conf };
qx { chown -R loxberry:loxberry $lbhomedir/system/samba/credentials };
qx { chmod 700 $lbhomedir/system/samba/credentials };





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
		rmtree($delfolder, {error => \my $err});
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
