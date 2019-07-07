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

LOGINF "Installing daily healthcheck cronjob...";
copy_to_loxberry("/system/cron/cron.daily/03-healthcheck", "loxberry");

LOGINF "Updating PHP 7.0 configuration";
LOGINF "Deleting ~/system/php...";
delete_directory("$lbhomedir/system/php");
LOGINF "Re-creating directory ~/system/php...";
mkdir "$lbhomedir/system/php" or do { LOGERR "Could not create dir $lbhomedir/system/php"; $errors++; };
LOGINF "Copying LoxBerry PHP config...";
copy_to_loxberry("/system/php/20-loxberry.ini");
LOGINF "Deleting old LoxBerry PHP config...";
my @phpfiles = ( 
	'/etc/php/7.0/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.0/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.0/cli/conf.d/20-loxberry.ini', 
);
foreach (@phpfiles) {
	if (-e "$_") { 
		unlink "$_" or do { LOGERR "Could not delete $_"; $errors++; }; 
		}
	symlink "$lbhomedir/system/php/20-loxberry.ini", "$_" or do { LOGERR "Could not create symlink from $_ to $lbhomedir/system/php/20-loxberry.ini"; $errors++; };
}

LOGOK "The changes of PHP settings require to restart your LoxBerry.";

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
		LOGOK "$destfile owner changed to $destowner.";
	}

}

####################################################################
# Install one or multiple packages with apt
# Parameter:
#	List of packages
####################################################################
sub apt_install
{
	my @packages = @_;
	my $packagelist = join(' ', @packages);

	my $bins = LoxBerry::System::get_binaries();
	my $aptbin = $bins->{APT};

	my $output = qx { /usr/bin/dpkg --configure -a };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode";
		LOGDEB $output;
		$errors++;
	} else {
		LOGOK "Configuring dpkg successfully.";
	}
	LOGINF "Clean up apt-databases and update";
	$output = qx { DEBIAN_FRONTEND=noninteractive $aptbin -y autoremove };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error autoremoving apt packages - Error $exitcode";
		LOGDEB $output;
	        $errors++;
	} else {
        	LOGOK "Apt packages autoremoved successfully.";
	}
	$output = qx { DEBIAN_FRONTEND=noninteractive $aptbin -y clean };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error cleaning apt database - Error $exitcode";
		LOGDEB $output;
	        $errors++;
	} else {
        	LOGOK "Apt database cleaned successfully.";
	}
	$output = qx { rm -r /var/cache/apt/archives/* };
	
	$output = qx { $aptbin -q -y update };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGERR "Error updating apt database - Error $exitcode";
		LOGDEB $output;
	        $errors++;
	} else {
        	LOGOK "Apt database updated successfully.";
	}

	LOGINF "Installing with apt: " . join(', ', @packages);
	
	my $output = `DEBIAN_FRONTEND=noninteractive $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall install $packagelist 2>&1`;
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
		LOGCRIT "Error installing $packagelist - Error $exitcode";
		LOGDEB $output;
		$errors++;
	} else {
		LOGOK "Packages $packagelist successfully installed";
	}
}
