# Please increment version number on EVERY change
# Major.Minor represents LoxBerry version (e.g. 2.0.3.2 = LoxBerry V2.0.3 the 2nd change)

################################################################
# LoxBerry::Update 
# THIS LIBRARY IS EXCLUSIVELY USED BY LoxBerry Update AND
# SHOULD NOT BE USED IN PLUGINS
################################################################

use strict;
use LoxBerry::System;
use LoxBerry::Log;
use CGI;

our $cgi;
our $log;
our $logfilename;
our $updatedir;
our $release;
our $errors;

################################################################
package LoxBerry::Update;
our $VERSION = "2.0.0.2";
our $DEBUG;

### Exports ###
use base 'Exporter';
our @EXPORT = qw (

	init
	delete_directory
	copy_to_loxberry
	apt_install
	apt_update
	apt_remove

);

####################################################################
# Init the update script
# Reads parameter, inits the logfile
####################################################################
sub init
{

	$main::cgi = CGI->new;
	
	# Initialize logfile and parameters
	my $logfilename;
	if ($main::cgi->param('logfilename')) {
		$logfilename = $main::cgi->param('logfilename');
	}
	$main::log = LoxBerry::Log->new(
			package => 'LoxBerry Update',
			name => 'update',
			filename => $logfilename,
			logdir => "$LoxBerry::System::lbslogdir/loxberryupdate",
			loglevel => 7,
			stderr => 1,
			append => 1,
	);
	$main::logfilename = $main::log->filename;

	if ($main::cgi->param('updatedir') and -d $main::cgi->param('updatedir')) {
		$main::updatedir = $main::cgi->param('updatedir');
	}
	$main::release = $main::cgi->param('release');
	
	$main::log->OK("Update script $0 started.");

}


####################################################################
# Removes a folder (including subfolders)
# Parameter:
#	dir/folder to delete
####################################################################
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
					$main::log->ERR("     Delete folder: general error: $message");
				} else {
					$main::log->ERR("     Delete folder: problem unlinking $file: $message");
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
	
	if (!$main::updatedir) {
		$main::log->ERR("copy_to_loxberry: Updatedir not set. Not started from loxberryupdate? Skipping copy of $destparam");
		$main::errors++;
		return;
	}
	
	my $srcfile = $main::updatedir . $destparam;
	my $destfile = $LoxBerry::System::lbhomedir . $destparam;
	# Remove trailing slashes
	$srcfile =~ s/\/\z//;
	$destfile =~ s/\/\z//;
	
	if (! -e $srcfile ) {
		$main::log->INF("$srcfile does not exist - This file might have been removed in a later LoxBerry verion. No problem.");
		return;
	}
	
	# Check if source is a file or a directory
	if ( -d $srcfile ) { 
		$srcfile .= '/*';
		`mkdir --parents $destfile`;
	}
	
	if (!$destowner) {$destowner = "root"};	
	
	my $output = qx { cp -rf $srcfile $destfile 2>&1 };
	my $exitcode  = $? >> 8;

	if ($exitcode != 0) {
		$main::log->ERR("Error copying $srcfile to $destfile - Error $exitcode");
		$main::log->INF("Message: $output");
		$main::errors++;
	} else {
		$main::log->OK("$destparam installed.");
	}

	$output = qx { chown -R $destowner:$destowner $destfile 2>&1 };
	$exitcode  = $? >> 8;

	if ($exitcode != 0) {
		$main::log->ERR("Error changing owner to $destowner for $destfile - Error $exitcode");
		$main::log->INF("Message: $output");
		$main::errors++;
	} else {
		$main::log->OK("$destfile owner changed to $destowner.");
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
	my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";

	my $output = qx { $export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install $packagelist 2>&1 };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$main::log->CRIT("Error installing $packagelist - Error $exitcode");
		$main::log->DEB($output);
		$main::errors++;
	} else {
		$main::log->OK("Packages $packagelist successfully installed");
	}
}



####################################################################
# Update and clean apt databases and caches
# Parameter:
# 	update or none:	Update apt database and clean cache
# 	clean:		clean cache only
####################################################################
sub apt_update
{
	my $command = shift;
	if (!$command) { $command = "update" };

	my $bins = LoxBerry::System::get_binaries();
	my $aptbin = $bins->{APT};
	my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";

	# Repair and update
	if ( $command eq "update") {
		my $output = qx { $export /usr/bin/dpkg --configure -a };
		my $exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$main::log->ERR("Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode");
			$main::log->DEB($output);
			$main::errors++;
		} else {
			$main::log->OK("Configuring dpkg successfully.");
		}
		$main::log->INF("Clean up apt-databases and update");
		$output = qx { $export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$main::log->ERR("Error autoremoving apt packages - Error $exitcode");
			$main::log->DEB($output);
		        $main::errors++;
		} else {
       	 	$main::log->OK("Apt packages autoremoved successfully.");
		}
		$output = qx { $export $aptbin -q -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages update };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$main::log->ERR("Error updating apt database - Error $exitcode");
			$main::log->DEB($output);
		        $main::errors++;
		} else {
       	 	$main::log->OK("Apt database updated successfully.");
		}
	}

	# Clean cache
	my $output = qx { $export $aptbin -q -y clean };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$main::log->ERR("Error cleaning apt cache - Error $exitcode");
		$main::log->DEB($output);
	        $main::errors++;
	} else {
	 	$main::log->OK("Apt cache cleaned successfully.");
	}
	
}

####################################################################
# Remove one or multiple packages with apt
# Parameter:
#	List of packages
####################################################################
sub apt_remove
{
	my @packages = @_;
	my $packagelist = join(' ', @packages);

	my $bins = LoxBerry::System::get_binaries();
	my $aptbin = $bins->{APT};
	my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";

	my $output = qx { $export $aptbin -q -y --purge remove $packagelist 2>&1 };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$main::log->CRIT("Error removing $packagelist - Error $exitcode");
		$main::log->DEB($output);
		$main::errors++;
	} else {
		$main::log->OK("Packages $packagelist successfully removed");
	}
}

#####################################################
# Finally 1; ########################################
#####################################################
1;
