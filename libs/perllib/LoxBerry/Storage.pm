# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
use LoxBerry::System;

package LoxBerry::Storage;
our $VERSION = "1.0.4.10";
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
				if ( ($readwriteonly && $state ne "rw") || !$state ) {
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
##################################################################################
sub get_usbstorages
{
	my ($size) = @_;

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

		$usbstoragecount++;
		$usbstorage{USBSTORAGE_NO} = $usbstoragecount;
		$usbstorage{USBSTORAGE_DEVICE} = $device;
		$usbstorage{USBSTORAGE_BLOCKDEVICE} = $df[0];
		$usbstorage{USBSTORAGE_TYPE} = $df[1];
		$usbstorage{USBSTORAGE_USED} = $used;
		$usbstorage{USBSTORAGE_AVAILABLE} = $available;
		$usbstorage{USBSTORAGE_CAPACITY} = $df[5];
		$usbstorage{USBSTORAGE_DEVICEPATH} = "$LoxBerry::System::lbhomedir/system/storage/usb/$device";
		push(@usbstorages, \%usbstorage);
	}

	return @usbstorages;

}

#####################################################
# Finally 1; ########################################
#####################################################
1;

