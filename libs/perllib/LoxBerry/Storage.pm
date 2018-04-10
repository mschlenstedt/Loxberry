# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
use LoxBerry::System;

package LoxBerry::Storage;
our $VERSION = "1.2.0.2";
our $DEBUG;

#use base 'Exporter';

# Every exported sub or variable is accessable directly in the main namespace
# Not exported subs and global (our) variables can be accessed by specifying the 
# namespace, e.g. 
# $text = LoxBerry::System::is_enabled($text);
# my $variable = LoxBerry::System::$systemvariable;

#our @EXPORT = qw (
#);

##################################################################
# This code is executed on every use
##################################################################

# Variables only valid in this module
my @netshares;
my $netshares_delcache;
my @usbstorages;

# Finished everytime code execution
##################################################################



##################################################################################
# Get Netshares
# Returns all netshares in a hash
# Parameter: 	1. If defined (=1), returns only netshares with read/write access
# 		2. If defined (=1), forces to reload all netshares
##################################################################################
sub get_netshares
{
	my ($readwriteonly, $forcereload) = @_;
	
	if (@netshares && !$forcereload && !$netshares_delcache) {
		print STDERR "get_netshares: Returning cached version of netshares\n" if ($DEBUG);
		return @netshares;
	} else {
		print STDERR "get_netshares: Re-reading netshares\n" if ($DEBUG);
	}
	my $openerr = 0;
	opendir(my $fh1, "$LoxBerry::System::lbhomedir/system/storage") or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening storage folder $LoxBerry::System::lbhomedir/system/storage";
		return undef;
	}
	my @sharetypes = readdir($fh1);
	closedir($fh1);

	@netshares = ();
	my $netsharecount = 0;
	
	foreach (@sharetypes){
		s/[\n\r]//g;
		if($_ eq "." || $_ eq ".." || $_ eq "usb") {
			next;
		}
		my $type = $_;	
		opendir(my $fh2, "$LoxBerry::System::lbhomedir/system/storage/$type") or ($openerr = 1);
		if ($openerr) {
			$openerr = 0;
			next;
		}
  		my @serverfolders = readdir($fh2);
		closedir($fh2);

		foreach(@serverfolders) {
			s/[\n\r]//g;
			if($_ eq "." || $_ eq "..") {
				next;
			}
			my $server = $_;	
			opendir(my $fh3, "$LoxBerry::System::lbhomedir/system/storage/$type/$server") or ($openerr = 1);
			if ($openerr) {
				$openerr = 0;
				next;
			}
  			my @sharefolders = readdir($fh3);
			closedir($fh3);

			foreach (@sharefolders) {
				s/[\n\r]//g;
				if($_ eq "." || $_ eq "..") {
					next;
				}
				my $share = $_;
				my %netshare;
				my $state = "";
				# Check read/write state
				qx(ls \"$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share\");
				if ($? eq 0) {
					$state = "Readonly";
				}
				qx(touch \"$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share/check_loxberry_rw_state.tmp\");
				if ($? eq 0) {
					$state = "Writable";
				}
				qx(rm \"$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share/check_loxberry_rw_state.tmp\");
				if ( ($readwriteonly && $state ne "Writable") || !$state ) {
					next;
				}
				$netsharecount++;
				$netshare{NETSHARE_NO} = $netsharecount;
				$netshare{NETSHARE_SERVER} = $server;
				$netshare{NETSHARE_TYPE} = $type;
				$netshare{NETSHARE_SERVERPATH} = "$LoxBerry::System::lbhomedir/system/storage/$type/$server";
				$netshare{NETSHARE_SHAREPATH} = "$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share";
				$netshare{NETSHARE_SHARENAME} = "$share";
				$netshare{NETSHARE_STATE} = "$state";
				push(@netshares, \%netshare);
			}
		}
	}

	return @netshares;

}


##################################################################################
# Get Netservers
# Returns all netshare servers in a hash
##################################################################################
sub get_netservers
{
	my $openerr = 0;
	opendir(my $fh1, "$LoxBerry::System::lbhomedir/system/storage") or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening storage folder $LoxBerry::System::lbhomedir/system/storage";
		return undef;
	}
	my @sharetypes = readdir($fh1);
	closedir($fh1);

	my @netservers = ();
	my $netservercount = 0;
	
	foreach (@sharetypes){
		s/[\n\r]//g;
		if($_ eq "." || $_ eq ".." || $_ eq "usb") {
			next;
		}
		my $type = $_;	
		opendir(my $fh2, "$LoxBerry::System::lbhomedir/system/storage/$type") or ($openerr = 1);
		if ($openerr) {
			$openerr = 0;
			next;
		}
  		my @serverfolders = readdir($fh2);
		closedir($fh2);

		foreach(@serverfolders) {
			s/[\n\r]//g;
			if($_ eq "." || $_ eq "..") {
				next;
			}
			my $server = $_;	
			my %netserver;
			$netservercount++;
			$netserver{NETSERVER_NO} = $netservercount;
			$netserver{NETSERVER_SERVER} = $server;
			$netserver{NETSERVER_TYPE} = $type;
			$netserver{NETSERVER_SERVERPATH} = "$LoxBerry::System::lbhomedir/system/storage/$type/$server";
			push(@netservers, \%netserver);
		}
	}

	return @netservers;

}


##################################################################################
# Get USB Storage
# Returns all usb storage devices in a hash
# Parameter: 	1. Defines Filesize. Allowed values: MB, GB. If empty, kB is used.
#            	2. If defined (=1), returns only devices with read/write access
##################################################################################
sub get_usbstorages
{
	my ($size, $readwriteonly) = @_;

	my $openerr = 0;
	opendir(my $fh1, "$LoxBerry::System::lbhomedir/system/storage/usb") or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening storage folder $LoxBerry::System::lbhomedir/system/storage/usb";
		return undef;
	}
	my @usbdevices = readdir($fh1);
	closedir($fh1);

	my @usbstorages = ();
	my $usbstoragecount = 0;
	my $device;
	my $output;
	my @df;
	my $used;
	my $type;
	my $available;
	my $opt;
	foreach (@usbdevices){
		s/[\n\r]//g;
		if($_ eq "." || $_ eq "..") {
			next;
		}
		my $device = $_;	
		my %usbstorage;
		if ( $size eq "H" | $size eq "h" ) {
			$opt = "-h";
		}
		$output = qx { df -P -l -T $opt | grep /media/usb/$device | sed 's/[[:space:]]\\+/|/g' };
		@df = split(/\|/,$output);	
		if ($size eq "MB" || $size eq "mb" ) {
			$used = sprintf "%.1f",$df[3] / 1000;
			$available = sprintf "%.1f",$df[4] / 1000;
		} elsif ($size eq "GB" || $size eq "gb" ) {
			$used = sprintf "%.1f",$df[3] / 1000 / 1000;
			$available = sprintf "%.1f",$df[4] / 1000 / 1000;
		} else {
			$used = $df[3];
			$available = $df[4];
		}
		$type = qx ( blkid -o udev $df[0] | grep ID_FS_TYPE | awk -F "=" '{ print \$2 }' );
		my $state = "";
		# Check read/write state
		qx(ls \"$LoxBerry::System::lbhomedir/system/storage/usb/$device\");
		if ($? eq 0) {
			$state = "Readonly";
		}
		qx(touch \"$LoxBerry::System::lbhomedir/system/storage/usb/$device/check_loxberry_rw_state.tmp\");
		if ($? eq 0) {
			$state = "Writable";
		}
		qx(rm \"$LoxBerry::System::lbhomedir/system/storage/usb/$device/check_loxberry_rw_state.tmp\");
		if ( ($readwriteonly && $state ne "Writable") || !$state ) {
			next;
		}
		$usbstoragecount++;
		$usbstorage{USBSTORAGE_NO} = $usbstoragecount;
		$usbstorage{USBSTORAGE_DEVICE} = $device;
		$usbstorage{USBSTORAGE_BLOCKDEVICE} = $df[0];
		$usbstorage{USBSTORAGE_TYPE} = $type;
		$usbstorage{USBSTORAGE_STATE} = $state;
		$usbstorage{USBSTORAGE_USED} = $used;
		$usbstorage{USBSTORAGE_AVAILABLE} = $available;
		$usbstorage{USBSTORAGE_CAPACITY} = $df[5];
		$usbstorage{USBSTORAGE_DEVICEPATH} = "$LoxBerry::System::lbhomedir/system/storage/usb/$device";
		push(@usbstorages, \%usbstorage);
	}

	return @usbstorages;

}

sub get_all_storage
{

	my ($readwriteonly) = @_;
	
	my @storages;
	
	# Network Shares
	my @netshares = LoxBerry::Storage::get_netshares($readwriteonly);
	foreach my $netshare (@netshares) {
		my %storage;
		# print STDERR "$netshare->{NETSHARE_NO} $netshare->{NETSHARE_TYPE} $netshare->{NETSHARE_SHAREPATH}\n";
		$storage{GROUP} = 'net';
		$storage{TYPE} = $netshare->{NETSHARE_TYPE};
		$storage{PATH} = $netshare->{NETSHARE_SHAREPATH};
		$storage{WRITEABLE} = $netshare->{NETSHARE_STATE} eq 'Writable' ? 1 : 0;
		$storage{NAME} = $netshare->{NETSHARE_SERVER} . '::' . $netshare->{NETSHARE_SHARENAME};
		# Fields only per group
		$storage{NETSHARE_SERVER} =  $netshare->{NETSHARE_SERVER};
		$storage{NETSHARE_SHARENAME} = $netshare->{NETSHARE_SHARENAME}; 
		
		push(@storages, \%storage);
	}
	
	# USB devices
	my @usbdevices = LoxBerry::Storage::get_usbstorages(undef, $readwriteonly);
	foreach my $usbdevice (@usbdevices) {
		my %storage;
		# print STDERR "$usbdevice->{USBSTORAGE_NO} $usbdevice->{USBSTORAGE_DEVICE} $usbdevice->{USBSTORAGE_DEVICEPATH}\n";
		$storage{GROUP} = 'usb';
		$storage{TYPE} = $usbdevice->{USBSTORAGE_TYPE};
		$storage{PATH} = $usbdevice->{USBSTORAGE_DEVICEPATH};
		$storage{WRITEABLE} = $usbdevice->{USBSTORAGE_STATE} eq 'Writable' ? 1 : 0;
		$storage{NAME} = $usbdevice->{USBSTORAGE_DEVICE};
		# Fields only per group
		$storage{USBSTORAGE_DEVICE} = $usbdevice->{USBSTORAGE_DEVICE};
		$storage{USBSTORAGE_BLOCKDEVICE} = $usbdevice->{USBSTORAGE_BLOCKDEVICE};
		
		push(@storages, \%storage);
	}
	
	# Local Plugin data directory
	if ($LoxBerry::System::lbpdatadir) {
		my %storage;
		$storage{GROUP} = 'local';
		$storage{TYPE} = 'local';
		$storage{PATH} = $LoxBerry::System::lbpdatadir;
		$storage{WRITEABLE} = 1;
		$storage{NAME} = 'Local Plugin Datadir';
		push(@storages, \%storage);
	}

	return @storages;

}

sub get_storage_html
{










}
#####################################################
# Finally 1; ########################################
#####################################################
1;

