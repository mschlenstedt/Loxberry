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

LOGINF "Clean up apt databases and update";
my $output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -y autoremove };
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

#
# Reinstalling Timezones
#
LOGINF "Correcting timezone package of Debian...";
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --no-install-recommends -q -y --fix-broken --reinstall install tzdata };
#my $output = qx { apt-get --fix-broken --quiet --yes --reinstall install tzdata };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error reinstalling timezone package - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "Timezone package successfully reinstalled";
}

LOGINF "Re-setting your current timezone...";
my $cfg = new Config::Simple("$lbhomedir/config/system/general.cfg");
my $timezone = $cfg->param("TIMESERVER.ZONE");
if ($timezone ne '') {
	LOGINF "Your current LoxBerry timezone is $timezone";
	my $output = qx { /usr/bin/timedatectl set-timezone "$timezone" };
	my $exitcode  = $? >> 8;

	if ($exitcode != 0) {
		LOGERR "Error setting your timezone - Error $exitcode";
		LOGDEB $output;
		$errors++;
	} else {
		LOGOK "Your timezone was set to $timezone.";
	}
} else {
	LOGWARN "Could not read current timezone from your LoxBerry configuration. Please reset your timezone in the Timeserver widget.";
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
####################################################################
sub copy_to_loxberry
{
	my ($destparam) = @_;
		
	my $destfile = $lbhomedir . $destparam;
	my $srcfile = $updatedir . $destparam;
		
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
}

