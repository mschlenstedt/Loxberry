# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
use LoxBerry::System;

package LoxBerry::Storage;
our $VERSION = "2.2.0.1";
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

				print STDERR "Check share $LoxBerry::System::lbhomedir/system/storage/$type/$server/$share \n" if ($DEBUG);

				# Check read/write state
				qx(ls \"$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share\" 2>/dev/null);

				if ($? eq 0) {
					$state = "Readonly";
				}
				qx(touch \"$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share/check_loxberry_rw_state.tmp\" 2>/dev/null);
				if ($? eq 0) {
					$state = "Writable";
				}
				qx(rm \"$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share/check_loxberry_rw_state.tmp\" 2>/dev/null);
				if ( ($readwriteonly && $state ne "Writable") || !$state ) {
					next;
				}
				
				my %folderinfo = LoxBerry::System::diskspaceinfo("$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share");			
				
				$netsharecount++;
				$netshare{NETSHARE_NO} = $netsharecount;
				$netshare{NETSHARE_SERVER} = $server;
				$netshare{NETSHARE_TYPE} = $type;
				$netshare{NETSHARE_SERVERPATH} = "$LoxBerry::System::lbhomedir/system/storage/$type/$server";
				$netshare{NETSHARE_SHAREPATH} = "$LoxBerry::System::lbhomedir/system/storage/$type/$server/$share";
				$netshare{NETSHARE_SHARENAME} = "$share";
				$netshare{NETSHARE_STATE} = "$state";
				$netshare{NETSHARE_USED} = $folderinfo{used};
				$netshare{NETSHARE_USED_HR} = LoxBerry::System::bytes_humanreadable($folderinfo{used}, "k");
				$netshare{NETSHARE_AVAILABLE} = $folderinfo{available};
				$netshare{NETSHARE_AVAILABLE_HR} = LoxBerry::System::bytes_humanreadable($folderinfo{available}, "k");
				$netshare{NETSHARE_SIZE} = $folderinfo{size};
				$netshare{NETSHARE_SIZE_HR} = LoxBerry::System::bytes_humanreadable($folderinfo{size}, "k");
				$netshare{NETSHARE_USEDPERCENT} = $folderinfo{usedpercent};
		
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
		
		my %serveruser;
		
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
			
			
			if ($netserver{NETSERVER_TYPE} eq "smb" and ! defined $serveruser{$netserver{NETSERVER_SERVER}} ) {
				eval {
					my $samba_cred = new Config::Simple("$LoxBerry::System::lbhomedir/system/samba/credentials/$netserver{NETSERVER_SERVER}");
					if ( defined $samba_cred->param("default.username") ) {
						$serveruser{$netserver{NETSERVER_SERVER}} = $samba_cred->param("default.username");
					} else {
						$serveruser{$netserver{NETSERVER_SERVER}} = "";
					}
				};
			}
			$netserver{NETSERVER_USERNAME} = $serveruser{$netserver{NETSERVER_SERVER}};
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
sub get_usbstorage
{
	my ($sizeunit, $readwriteonly) = @_;
	
	$sizeunit = lc($sizeunit);
	
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
	
	foreach (@usbdevices){
		s/[\n\r]//g;
		if($_ eq "." || $_ eq "..") {
			next;
		}
		my $device = $_;	
		my $used;
		my $size;
		my $available;
	
		my %usbstorage;
		my %disk = LoxBerry::System::diskspaceinfo("$LoxBerry::System::lbhomedir/system/storage/usb/$device");

		if ($sizeunit eq "h") {
			$used = LoxBerry::System::bytes_humanreadable($disk{used}, "k");
			$size = LoxBerry::System::bytes_humanreadable($disk{size}, "k");
			$available = LoxBerry::System::bytes_humanreadable($disk{available}, "k");
		} elsif ($sizeunit eq "mb" ) {
			$used = sprintf "%.1f", $disk{used} / 1024;
			$available = sprintf "%.1f", $disk{available} / 1024;
			$size = sprintf "%.1f", $disk{size} / 1024;
		} elsif ($sizeunit eq "gb" ) {
			$used = sprintf "%.1f", $disk{used} / 1024 / 1024;
			$available = sprintf "%.1f", $disk{available} / 1024 / 1024;
			$size = sprintf "%.1f", $disk{size} / 1024 /1024;
		} else {
			$used = $disk{used};
			$available = $disk{available};
			$size = $disk{size};
		}
		my $type = qx ( blkid -o udev $disk{filesystem} | grep ID_FS_TYPE | awk -F "=" '{ print \$2 }' );
		chomp($type);
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
		$usbstorage{USBSTORAGE_BLOCKDEVICE} = $disk{filesystem};
		$usbstorage{USBSTORAGE_TYPE} = $type;
		$usbstorage{USBSTORAGE_STATE} = $state;
		$usbstorage{USBSTORAGE_USED} = $used;
		$usbstorage{USBSTORAGE_SIZE} = $size;
		$usbstorage{USBSTORAGE_AVAILABLE} = $available;
		$usbstorage{USBSTORAGE_CAPACITY} = $disk{usedpercent};
		$usbstorage{USBSTORAGE_USEDPERCENT} = $disk{usedpercent};
		$usbstorage{USBSTORAGE_DEVICEPATH} = "$LoxBerry::System::lbhomedir/system/storage/usb/$device";
		push(@usbstorages, \%usbstorage);
	}

	return @usbstorages;

}

sub get_storage
{

	my ($readwriteonly, $localdir) = @_;
	
	my @storages;
	
	# Network Shares
	my @netshares = LoxBerry::Storage::get_netshares($readwriteonly);
	foreach my $netshare (@netshares) {
		my %storage;
		print STDERR "$netshare->{NETSHARE_NO} $netshare->{NETSHARE_TYPE} $netshare->{NETSHARE_SHAREPATH}\n" if ($DEBUG);
		$storage{GROUP} = 'net';
		$storage{TYPE} = $netshare->{NETSHARE_TYPE};
		$storage{PATH} = $netshare->{NETSHARE_SHAREPATH};
		$storage{WRITABLE} = $netshare->{NETSHARE_STATE} eq 'Writable' ? 1 : 0;
		$storage{AVAILABLE} = $netshare->{NETSHARE_AVAILABLE};
		$storage{USED} = $netshare->{NETSHARE_USED};
		$storage{SIZE} = $netshare->{NETSHARE_SIZE};
		$storage{SIZE_GB} = int($storage{SIZE}/1024/1024+0.5);
		$storage{NAME} = $netshare->{NETSHARE_SERVER} . '::' . $netshare->{NETSHARE_SHARENAME} . " (" . $storage{SIZE_GB} . " GB)";
		
		# Fields only per group
		$storage{NETSHARE_SERVER} =  $netshare->{NETSHARE_SERVER};
		$storage{NETSHARE_SHARENAME} = $netshare->{NETSHARE_SHARENAME}; 
		
		push(@storages, \%storage);
	}
	
	# USB devices
	my @usbdevices = LoxBerry::Storage::get_usbstorage(undef, $readwriteonly);
	foreach my $usbdevice (@usbdevices) {
		my %storage;
		print STDERR "$usbdevice->{USBSTORAGE_NO} $usbdevice->{USBSTORAGE_DEVICE} $usbdevice->{USBSTORAGE_DEVICEPATH}\n" if ($DEBUG);
		$storage{GROUP} = 'usb';
		$storage{TYPE} = $usbdevice->{USBSTORAGE_TYPE};
		$storage{PATH} = $usbdevice->{USBSTORAGE_DEVICEPATH};
		$storage{WRITABLE} = $usbdevice->{USBSTORAGE_STATE} eq 'Writable' ? 1 : 0;
		$storage{AVAILABLE} = $usbdevice->{USBSTORAGE_AVAILABLE};
		$storage{USED} = $usbdevice->{USBSTORAGE_USED};
		$storage{SIZE} = $usbdevice->{USBSTORAGE_SIZE};
		$storage{SIZE_GB} = int($storage{SIZE}/1024/1024+0.5);
		$storage{NAME} = "USB::" . $usbdevice->{USBSTORAGE_DEVICE} . " (" . $storage{SIZE_GB} . " GB)";
		# Fields only per group
		$storage{USBSTORAGE_DEVICE} = $usbdevice->{USBSTORAGE_DEVICE};
		$storage{USBSTORAGE_BLOCKDEVICE} = $usbdevice->{USBSTORAGE_BLOCKDEVICE};
		
		push(@storages, \%storage);
	}
	
	# Local Plugin data directory
	if ($LoxBerry::System::lbpdatadir || $localdir) {
		my %storage;
		$storage{GROUP} = 'local';
		$storage{TYPE} = 'local';
		$storage{PATH} = $localdir ? $localdir : $LoxBerry::System::lbpdatadir;
		$storage{WRITABLE} = 1;
		my %disk = LoxBerry::System::diskspaceinfo($storage{PATH});
		$storage{AVAILABLE} = $disk{available};
		$storage{USED} = $disk{used};
		$storage{SIZE} = $disk{size};
		$storage{SIZE_GB} = int($disk{size}/1024/1024+0.5);
		
		$storage{NAME} = 'Local Datadir (' . $storage{SIZE_GB} . ' GB)';
		push(@storages, \%storage);
	}

	return @storages;

}

# EXTERNAL function to query storage form HTML
# Returns a HTML to select storage (see http://www.loxwiki.eu/x/BgHgAQ)
# This function creates a POST request to the ajax-storage-handler, that by itself calls LoxBerry::Storage::get_storage
# This kind of processing simplifies AJAX requests and scripting language independency

sub get_storage_html
{
	
	#shift;
	my %args = @_;
	
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	 
	my $server_endpoint = "http://localhost:" . LoxBerry::System::lbwebserverport() . "/admin/system/tools/ajax-storage-handler.cgi";
	 
	# set custom HTTP request header fields
	my $req = HTTP::Request->new(POST => $server_endpoint);
	$req->header('content-type' => 'application/x-www-form-urlencoded; charset=utf-8');
	 
	# add POST data to HTTP request body
	my $post_data;
	$post_data = "action=init&";
	
	if($LoxBerry::System::lbpdatadir) {
		$post_data .= 'localdir=' . URI::Escape::uri_escape($LoxBerry::System::lbpdatadir) . '&';
	}
	
	foreach my $param (keys %args) {
		print STDERR "Storage.pm: $param --> $args{$param}\n" if ($DEBUG);
		$post_data .= URI::Escape::uri_escape($param) . '=' . URI::Escape::uri_escape($args{$param}) . '&'; 
		# $post_data .= $param . '=' . $args{$param} . '&'; 
	}
	
	$req->content($post_data);
	 
	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		return $message;
	}
	else {
		print STDERR "get_storage_html: HTTP POST error code: ", $resp->code, "\n" if ($DEBUG);
		print STDERR "get_storage_html: HTTP POST error message: ", $resp->message, "\n" if ($DEBUG);
		return undef;
	}

}

#####################################################
# Finally 1; ########################################
#####################################################
1;
