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

LOGOK "This update migrates the notification feature from file-based to SQLite-based and introduces new notification functions. Therefore, old notifications will be deleted.";
delete_directory ("$lbsdatadir/notifications");

if (-e "$lbsdatadir/notifications_sqlite.dat" ) {
	LOGWARN "Deleting notification database from 'Latest Commit' users as time format has changed from GMT to localtime";
	unlink "$lbsdatadir/notifications_sqlite.dat";
}

 
#LOGINF "Replacing system default sudoers file";
#LOGINF "Copying new";

#my $output = qx { if [ -e $updatedir/system/sudoers/lbdefaults ] ; then cp -f $updatedir/system/sudoers/lbdefaults $lbhomedir/system/sudoers/ ; fi };
#my $exitcode  = $? >> 8;

#if ($exitcode != 0) {
#	LOGERR "Error copying new lbdefaults - Error $exitcode";
#	$errors++;
#} else {
#	LOGOK "New lbdefaults copied.";
#}
#qx { chown root:root $lbhomedir/system/sudoers/lbdefaults };

LOGINF "Installing packages usbmount and ntfs-3g";

my $output = qx { /usr/bin/dpkg --configure -a };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode";
        $errors++;
} else {
        LOGOK "Configuring dpkg successfully.";
}
$output = qx { /usr/bin/apt-get -q -y update };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error updating apt database - Error $exitcode";
        $errors++;
} else {
        LOGOK "Apt database updated successfully.";
}
$output = qx { /usr/bin/apt-get -q -y install usbmount ntfs-3g };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error installing packages usbmount ntfs-3g with apt-get - Error $exitcode";
	$errors++;
} else {
	LOGOK "Installing usbmount ntfs-3g successfully.";
}

if ( -e "/etc/usbmount/usbmount.conf" ) {
	$output = qx {awk -v s='FILESYSTEMS="vfat ntfs fuseblk ext2 ext3 ext4 hfsplus"' '/^FILESYSTEMS=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/usbmount/usbmount.conf };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
       		LOGERR "Error replacing string FILESYSTEMS= in /etc/usbmount/usbmount.conf - Error $exitcode";
      		$errors++;
	} else {
        	LOGOK "Replacing string FILESYSTEMS= successfully in /etc/usbmount/usbmount.conf.";
	}
	$output = qx {awk -v s='FS_MOUNTOPTIONS="-fstype=ntfs-3g,nls=utf8,umask=007,gid=1001 -fstype=fuseblk,nls=utf8,umask=007,gid=1001 -fstype=vfat,gid=1001,uid=1001,umask=007"' '/^FS_MOUNTOPTIONS=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/usbmount/usbmount.conf };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
       		LOGERR "Error replacing string FS_MOUNTOPTIONS= in /etc/usbmount/usbmount.conf - Error $exitcode";
      		$errors++;
	} else {
        	LOGOK "Replacing string FS_MOUNTOPTIONS= successfully in /etc/usbmount/usbmount.conf.";
	}
}
$output = qx { ln -s /var/run/usbmount/ $lbhomedir/system/storage };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error creating symlink $lbhomedir/system/storage - Error $exitcode";
	$errors++;
} else {
	LOGOK "Symlink $lbhomedir/system/storage created successfully";
}

LOGINF "Replacing system samba config file";
LOGINF "Copying new";

$output = qx { if [ -e $updatedir/system/samba/smb.conf ] ; then cp -f $updatedir/system/samba/smb.conf $lbhomedir/system/samba/ ; fi };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error copying new samba config file - Error $exitcode";
	$errors++;
} else {
	LOGOK "New samba config file copied.";
}
qx { chown loxberry:loxberry $lbhomedir/system/samba/smb.conf };

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
