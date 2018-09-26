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
# Samba
#

LOGINF "Replacing system samba config file";

$output = qx { if [ -e $updatedir/system/samba/smb.conf ] ; then cp -f $updatedir/system/samba/smb.conf $lbhomedir/system/samba/ ; fi };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error copying new samba config file - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "New samba config file copied.";
}

qx { chown loxberry:loxberry $lbhomedir/system/samba/smb.conf };
qx { service smbd restart };

#
# Install exfat-fuse
#
LOGINF "Installing exfat-fuse filesystem driver.";

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
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y install exfat-fuse };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "Error installing exfat-fuse - Error $exitcode";
                LOGDEB $output;
        $errors++;
} else {
        LOGOK "Installed exfat-fuse successfully.";
}
qx { /var/cache/apt/archives/* };

#
# Add nofail to all devices in /etc/fstab for automount
#
LOGINF "Adding 'nofail' option to /etc/fstab";

qx { awk '!/^#/ && !/^ / && /^[a-zA-Z0-9]/ { if(!match(\$4,/nofail/)) \$4=\$4",nofail" } 1' /etc/fstab > /etc/fstab.new };
qx { cp /etc/fstab /etc/fstab.backup };
qx { cat /etc/fstab.new > /etc/fstab };
qx { rm /etc/fstab.new };

## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

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


####################################################################
# Copy a file or dir from updatedir to lbhomedir including error handling
# Parameter:
#	file/dir starting from ~ 
#   (without /opt/loxberry, with leading /)
####################################################################
sub copy_to_loxberry
{
	my ($destparam) = @_;
		
	my $destfile = $lbhomedir . $destparam;
	my $srcfile = $updatedir . $destparam;
		
	if (! -e $srcfile) {
		LOGERR "$srcfile does not exist";
		$errors++;
		return;
	}
	
	my $output = qx { cp -f $srcfile $destfile };
	my $exitcode  = $? >> 8;

	if ($exitcode != 0) {
		LOGERR "Error copying $destparam - Error $exitcode";
		LOGINF "Message: $output";
		$errors++;
	} else {
		LOGOK "$destparam installed.";
	}
}

