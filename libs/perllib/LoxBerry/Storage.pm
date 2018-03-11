# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
use LoxBerry::System;

package LoxBerry::Storage;
our $VERSION = "1.0.4.1";
our $DEBUG;

use base 'Exporter';

# Every exported sub or variable is accessable directly in the main namespace
# Not exported subs and global (our) variables can be accessed by specifying the 
# namespace, e.g. 
# $text = LoxBerry::System::is_enabled($text);
# my $variable = LoxBerry::System::$systemvariable;

our @EXPORT = qw (
);


##################################################################
# This code is executed on every use
##################################################################

# Variables only valid in this module
my @netshares;
my $netshares_delcache;
my @usbstorage;
my $usbstorage_delcache;


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
	
	if (!-e "$LoxBerry::System::lbsdatadir/netshares.dat") {
		Carp::carp "LoxBerry::Storage::get_netshares: Could not find $LoxBerry::System::lbsdatadir/netshares.dat\n";
		return undef;
	}
	my $openerr;
	open(my $fh, "<", "$LoxBerry::System::lbsdatadir/netshares.dat") or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening netshares database $LoxBerry::System::lbsdatadir/netshares.dat";
		return undef;
	}
	my @data = <$fh>;
	close ($fh);

	@netshares = ();
	my $netsharecount = 0;
	
	foreach (@data){
		s/[\n\r]//g;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			next;
		}
		
		my @fields = split(/\|/);

		opendir(my $fh2, "$LoxBerry::System::lbhomedir/system/storage/@fields[1]/@fields[0]") or ($openerr = 1);
		if ($openerr) {
			Carp::carp "Error opening netshare $LoxBerry::System::lbhomedir/system/storage/@fields[1]/@fields[0]";
			return undef;
		}
  		my @sharefolders = readdir($fh2);
		closedir($fh2);

		foreach(@sharefolders) {
			my %netshare;
			my $state;
			s/[\n\r]//g;
			if($_ ne "." && $_ ne "..") {
				# Check read/write state
				qx(ls $LoxBerry::System::lbhomedir/system/storage/@fields[1]/@fields[0]/$_);
				if ($? eq 0) {
					$state .= "r";
				}
				qx(touch $LoxBerry::System::lbhomedir/system/storage/@fields[1]/@fields[0]/$_/check_loxberry_rw_state.tmp);
				if ($? eq 0) {
					$state .= "w";
				}
				qx(rm $LoxBerry::System::lbhomedir/system/storage/@fields[1]/@fields[0]/$_/check_loxberry_rw_state.tmp);
				if ($readwriteonly && $state ne "rw") {
					next;
				}
				$netsharecount++;
				$netshare{NETSHARE_NO} = $netsharecount;
				$netshare{NETSHARE_SERVER} = $fields[0];
				$netshare{NETSHARE_TYP} = $fields[1];
				$netshare{NETSHARE_SERVERPATH} = "$LoxBerry::System::lbhomedir/system/storage/@fields[1]/@fields[0]";
				$netshare{NETSHARE_SERVERNAME} = $fields[3];
				$netshare{NETSHARE_SHAREPATH} = "$LoxBerry::System::lbhomedir/system/storage/@fields[1]/@fields[0]/$_";
				$netshare{NETSHARE_SHARENAME} = "$_";
				$netshare{NETSHARE_STATE} = "$state";
				push(@netshares, \%netshare);
				# On changes of the plugindatabase format, please change here 
				# and in libs/phplib/loxberry_system.php / function get_plugins
			}
		}
	}

	return @netshares;

}





#####################################################
# Finally 1; ########################################
#####################################################
1;

