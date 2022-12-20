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
our $VERSION = "3.0.0.5";
our $DEBUG;

### Exports ###
use base 'Exporter';
our @EXPORT = qw (

	init
	delete_directory
	copy_to_loxberry
	apt_install
	apt_update
	apt_upgrade
	apt_distupgrade
	apt_fullupgrade
	rpi_update
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
	$main::logfilename = $logfilename;

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
# Performaing apt upgrade
# Parameter:
#	None
####################################################################
sub apt_upgrade
{
	my $bins = LoxBerry::System::get_binaries();
	my $aptbin = $bins->{APT};
	my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";
	my $logfilename = $main::logfilename;
	my $output = qx { $export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" upgrade >> $logfilename 2>&1 };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$main::log->CRIT("Error upgrading - Error $exitcode");
		$main::log->DEB($output);
		$main::errors++;
	} else {
		$main::log->OK("System upgrade successfully installed");
	}
}



####################################################################
# Performaing apt dist-upgrade
# Parameter:
#	None
####################################################################
sub apt_distupgrade
{
	my $bins = LoxBerry::System::get_binaries();
	my $aptbin = $bins->{APT};
	my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";
	my $logfilename = $main::logfilename;
	my $command = qq { $export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" dist-upgrade >> $logfilename 2>&1 };
	$main::log->DEB("Command:\n" . $command);
	my $output = qx { $command };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$main::log->CRIT("Error dist-upgrading - Error $exitcode");
		$main::log->DEB($output);
		$main::errors++;
	} else {
		$main::log->OK("System dist-upgrade successfully installed");
	}
}



####################################################################
# Performaing apt full-upgrade
# Parameter:
#	None
####################################################################
sub apt_fullupgrade
{
	my $bins = LoxBerry::System::get_binaries();
	my $aptbin = $bins->{APT};
	my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";
	my $logfilename = $main::logfilename;
	my $command = qq { $export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" full-upgrade >> $logfilename 2>&1 };
	$main::log->DEB("Command:\n" . $command);
	my $output = qx { $command };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$main::log->CRIT("Error full-upgrading - Error $exitcode");
		$main::log->DEB($output);
		$main::errors++;
	} else {
		$main::log->OK("System full-upgrade successfully installed");
	}
}



####################################################################
# rpi-update (use "~/sbin/prepare_rpi-update" to get hashes and checksums
# Parameter:
# 	Git hash or none: update to this firmware version from https://github.com/raspberrypi/rpi-firmware
####################################################################
sub rpi_update
{
	my $githash = shift;
	if (!$githash) { $githash = "" };

	if (-e "$LoxBerry::System::lbhomedir/config/system/is_raspberry.cfg" && !-e "$LoxBerry::System::lbhomedir/config/system/is_odroidxu3xu4.cfg") {
		unlink "/boot/.firmware_revision";
		if ( -d '/boot.bkp' ) {
			qx ( rm -rf /boot.bkp ); 
		}
		qx { mkdir -p /boot.bkp };
		qx ( cp -r /boot/* /boot.bkp );

		my $output = qx { SKIP_WARNING=1 SKIP_BACKUP=1 BRANCH=stable WANT_PI4=1 WANT_32BIT=1 SKIP_CHECK_PARTITION=1 BOOT_PATH=/boot.tmp ROOT_PATH=/ /usr/bin/rpi-update $githash 2>&1 };
		my $exitcode  = $? >> 8;
		$main::log->DEB($output);
		if ($exitcode != 0) {
			$main::log->ERR("Error upgrading kernel and firmware- Error $exitcode");
			$main::log->DEB($output);
			$main::errors++;
			qx ( rm -rf /boot.tmp ); 
			qx ( rm -rf /boot.bkp ); 
			return undef;
		} else {
			qx ( cp -r /boot.tmp/* /boot );
			qx ( rm -rf /boot.tmp );
			qx ( rm -rf /boot/boot.bkp );
			my $output = qx ( cp -r /boot.bkp /boot 2>&1 );
			my $exitcode  = $? >> 8;
			if ($exitcode eq "0") {
				qx ( rm -rf /boot.bkp );
			}
			$main::log->OK ("Upgrading kernel and firmware successfully.");
			#my $out_chksum = qx { $LoxBerry::System::lbsbindir/dirtree_md5.pl -path /boot.tmp/ -compare $checksum };
			#my $exitcode  = $? >> 8;
			#if ($exitcode eq "0") {
			#	qx ( rm -rf /boot.bkp ); 
			#	qx ( cp -r /boot /boot.bkp );
			#	qx ( cp -r /boot.tmp/* /boot );
			#	qx ( rm -r /boot.tmp );
			#	$main::log->OK ("Upgrading kernel and firmware successfully.");
			#} else {
				#$main::log->ERR("Error upgrading kernel and firmware - /boot.tmp seems to be broken.");
				#$main::log->DEB("Requested checksum: $checksum");
				#$main::log->DEB("Output of checksum test:");
				#$main::log->DEB($out_chksum);
				#$main::errors++;
				#qx ( rm -rf /boot.tmp ); 
				#return undef;
			#}
		}
	} else {
		$main::log->OK("This seems not to be a Raspberry. Do not upgrading Kernel and Firmware.");
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
	qx { chmod 1777 /tmp };
	if ( $command eq "update") {
		my $output = qx { $export /usr/bin/dpkg --configure -a --force-confdef};
		my $exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$main::log->ERR("Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode");
			$main::log->DEB($output);
			$main::errors++;
		} else {
			$main::log->OK("Configuring dpkg successfully.");
		}
		$main::log->INF("Clean up apt-databases and update");
		$output = qx { $export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$main::log->ERR("Error installing broken apt packages - Error $exitcode");
			$main::log->DEB($output);
		        $main::errors++;
		} else {
       	 	$main::log->OK("Eventually broken Apt packages installed successfully.");
		}
		$output = qx { $export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$main::log->ERR("Error autoremoving apt packages - Error $exitcode");
			$main::log->DEB($output);
		        $main::errors++;
		} else {
       	 	$main::log->OK("Apt packages autoremoved successfully.");
		}

		# Try apt-get update 3 times befor giving up, choose another mirror if command failed
		my $success = 0;
		for (my $i;$i<4;$i++) {
			$output = qx { $export $aptbin -q -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-releaseinfo-change update };
			$exitcode  = $? >> 8;
			if ($exitcode != 0) {
				$main::log->ERR("Error updating apt database - Error $exitcode");
				$main::log->DEB($output);
				require LoxBerry::JSON;
				my $cfgfile = $LoxBerry::System::lbsconfigdir . "/general.json";
				my $jsonobj = LoxBerry::JSON->new();
				my $cfg = $jsonobj->open(filename => $cfgfile);
				$main::log->INF("Updating YARN key...");
				system ("curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -");
				$main::log->INF("Updating NodeJS key...");
				system ("curl -sS https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -");
				if ($cfg->{'Apt'}->{'Servers'} && -e $LoxBerry::System::lbsconfigdir . "/is_raspberry.cfg" && -e "/etc/apt/sources.list.d/loxberry.list") {
					my $aptserver = $cfg->{'Apt'}->{'Servers'}{ int(rand keys %{ $cfg->{'Apt'}->{'Servers'} }) + 1 };
					$main::log->INF("Changing Rasbian mirror to $aptserver");
					qx ( sed -i --follow-symlinks "s#^\\([^#]*\\)http[^ ]*#\\1$aptserver#" /etc/apt/sources.list.d/loxberry.list );
				}
				$i++;
			} else {
	       	 		$main::log->OK("Apt database updated successfully.");
				$success++;
				last;
			}
		}
		if (!$success) {
			$main::log->ERR("Error updating apt database. All servers give an error. Internet connection available? Giving up.");
			$main::errors++;
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
