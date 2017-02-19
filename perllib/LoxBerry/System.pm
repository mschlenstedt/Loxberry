use strict;
use Config::Simple;
use File::HomeDir;
use URI::Escape;
use Cwd 'abs_path';
use LWP::UserAgent;
use XML::Simple;
use Carp;


package LoxBerry::System;
use base 'Exporter';

# Every exported sub or variable is accessable directly in the main namespace
# Not exported subs and global (our) variables can be accessed by specifying the 
# namespace, e.g. 
# $text = LoxBerry::System::is_enabled($text);
# my $variable = LoxBerry::System::$systemvariable;

our @EXPORT = qw (
	$lbhomedir
	$lbplugindir
	$lbcgidir
	$lbhtmldir
	$lbtemplatedir
	$lbdatadir
	$lblogdir
	$lbconfigdir
	is_enabled 
	is_disabled
	trim 
	ltrim
	rtrim
);

##################################################################
# This code is executed on every use
##################################################################

# Set global variables

# Get LoxBerry home directory
our $lbhomedir;
if ($ENV{LBHOMEDIR}) {
	$lbhomedir = $ENV{LBHOMEDIR};
} else {
	my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
	if ($username eq 'loxberry') {
		$lbhomedir = File::HomeDir->my_home;
	} else {
		# Missing some additional functions if we are running from daemon or cron
		$lbhomedir = '/opt/loxberry';
		carp ("LoxBerry home was statically set to /opt/loxberry as no home directory could be found.");
	}
}

my $part = substr ((Cwd::abs_path($0)), (length($lbhomedir)+1));
our ($lbplugindir) = (split(/\//, $part))[3];
our $lbcgidir = "$lbhomedir/webfrontend/cgi/plugins/$lbplugindir";
our $lbhtmldir = "$lbhomedir/webfrontend/html/plugins/$lbplugindir";
our $lbtemplatedir = "$lbhomedir/templates/plugins/$lbplugindir";
our $lbdatadir = "$lbhomedir/data/plugins/$lbplugindir";
our $lblogdir = "$lbhomedir/log/plugins/$lbplugindir";
our $lbconfigdir = "$lbhomedir/config/plugins/$lbplugindir";

# Hash only valid in this module
my %miniservers;
my %binaries;
my $lbtimezone;

# Finished everytime code execution
##################################################################

####### Get Miniserver hash #######
sub get_miniservers
{
	# If config file was read already, directly return the saved hash
	if (%miniservers) {
		return %miniservers;
	}

	if (read_generalcfg()) {
		return %miniservers;
	}
	return undef;
}

####### Get Miniserver key by IP Address #######
sub get_miniserver_by_ip
{
	my ($ip) = @_;
	$ip = trim(lc($ip));
	
	if (! %miniservers) {
		if (! read_generalcfg()) {
			return undef;
		}
	}
	
	foreach my $msip (keys %miniservers) {
		if (lc($miniservers{$msip}{IPAddress}) eq $ip) {
			return $msip;
		}
	}
	return undef;
}

####### Get Miniserver key by Name #######
sub get_miniserver_by_name
{
	my ($myname) = @_;
	$myname = trim(lc($myname));
	
	if (! %miniservers) {
		if (! read_generalcfg()) {
			return undef;
		}
	}
	
	foreach my $msname (keys %miniservers) {
		if (lc($miniservers{$msname}{Name}) eq $myname) {
			return $msname;
		}
	}
	return undef;
}

####### Get Binaries #######
sub get_binaries
{

	if ($LoxBerry::System::binaries) {
		# print STDERR "Returning existing hashref\n";
		return $LoxBerry::System::binaries;
	} 

	if (read_generalcfg()) {
			# print STDERR "Reading config and returning hashref\n";
			#%LoxBerry::System::binaries ? print STDERR "Hash is defined\n" : print STDERR "Hash NOT defined\n";
			return $LoxBerry::System::binaries;
	}
	return undef;
}




##################################################################
# Read general.cfg
# This is called from several functions and is not exported
##################################################################
sub read_generalcfg
{
	my $miniservercount;
	my $clouddnsaddress;
	
	my $cfg = new Config::Simple("$lbhomedir/config/system/general.cfg") or return undef;
	$miniservercount = $cfg->param("BASE.MINISERVERS") or return undef;
	
	if (($miniservercount) && ($miniservercount < 1)) {
		return undef;
	}
	
	$clouddnsaddress = $cfg->param("BASE.CLOUDDNS") or carp ("BASE.CLOUDDNS not defined.\n");
	$lbtimezone		= $cfg->param("TIMESERVER.ZONE") or carp ("TIMESERVER.ZONE not defined.\n");

	# Binaries
	$LoxBerry::System::binaries = $cfg->get_block('BINARIES');
		
	for (my $msnr = 1; $msnr <= $miniservercount; $msnr++) {
		$miniservers{$msnr}{Name} = $cfg->param("MINISERVER$msnr.NAME");
		$miniservers{$msnr}{IPAddress} = $cfg->param("MINISERVER$msnr.IPADDRESS");
		$miniservers{$msnr}{Admin} = $cfg->param("MINISERVER$msnr.ADMIN");
		$miniservers{$msnr}{Pass} = $cfg->param("MINISERVER$msnr.PASS");
		$miniservers{$msnr}{Credentials} = $miniservers{$msnr}{Admin} . ':' . $miniservers{$msnr}{Pass};
		$miniservers{$msnr}{Note} = $cfg->param("MINISERVER$msnr.NOTE");
		$miniservers{$msnr}{Port} = $cfg->param("MINISERVER$msnr.PORT");
		$miniservers{$msnr}{UseCloudDNS} = $cfg->param("MINISERVER$msnr.USECLOUDDNS");
		$miniservers{$msnr}{CloudURLFTPPort} = $cfg->param("MINISERVER$msnr.CLOUDURLFTPPORT");
		$miniservers{$msnr}{CloudURL} = $cfg->param("MINISERVER$msnr.CLOUDURL");
		
		$miniservers{$msnr}{Admin_RAW} = URI::Escape::uri_unescape($miniservers{$msnr}{Admin});
		$miniservers{$msnr}{Pass_RAW} = URI::Escape::uri_unescape($miniservers{$msnr}{Pass});
		$miniservers{$msnr}{Credentials_RAW} = $miniservers{$msnr}{Admin_RAW} . ':' . $miniservers{$msnr}{Pass_RAW};

		# CloudDNS handling
		if (LoxBerry::System::is_enabled($miniservers{$msnr}{UseCloudDNS}) && ($miniservers{$msnr}{CloudURL})) {
			set_clouddns($msnr);
		}
		
		if (! $miniservers{$msnr}{Port}) {
			$miniservers{$msnr}{Port} = 80;
		}

	}
	return 1;
}
####################################################
# set_clouddns
# Internal function to set CloudDNS IP and Port
####################################################
sub set_clouddns
{
	my ($msnr) = @_;
	
	# Grep IP Address from Cloud Service
	my $dns_info = qx( $LoxBerry::System::binaries->{CURL} -I http://$LoxBerry::System::clouddnsaddress/$miniservers{$msnr}{CloudURL} --connect-timeout 5 -m 5 2>/dev/null |$LoxBerry::System::binaries->{GREP} Location |$LoxBerry::System::binaries->{AWK} -F/ '{print \$3}');
	my @dns_info_pieces = split /:/, $dns_info;

	if ($dns_info_pieces[1]) {
	  $miniservers{$msnr}{Port} =~ s/^\s+|\s+$//g;
	} else {
	  $miniservers{$msnr}{Port} = 80;
	}

	if ($dns_info_pieces[0]) {
	  $miniservers{$msnr}{IPAddress} =~ s/^\s+|\s+$//g;
	} else {
	  $miniservers{$msnr}{IPAddress} = "127.0.0.1";
	}
}

#####################################################
# get_ftpport
# Function to get FTP port  considering CloudDNS Port
# Input: $msnr
# Output: $port
#####################################################
sub get_ftpport
{
	my ($msnr) = @_;
	
	$msnr = defined $msnr ? $msnr : 1;
	
	# If we have no MS list, read the config
	if (! %miniservers) {
		# print STDERR "get_ftpport: Readconfig\n";
		read_generalcfg();
	}
	
	# If CloudDNS is enabled, return the CloudDNS FTP port
	if (LoxBerry::System::is_enabled($miniservers{$msnr}{UseCloudDNS}) && $miniservers{$msnr}{CloudURLFTPPort}) {
		# print STDERR "get_ftpport: Use CloudDNS FTP Port\n";
		return $miniservers{$msnr}{CloudURLFTPPort};
	}
	
	# If MS hash does not have FTP set, read FTP from Miniserver and save it in FTPPort
	if (! $miniservers{$msnr}{FTPPort}) {
		# print STDERR "get_ftpport: Read FTP Port from MS\n";
		# Get FTP Port from Miniserver
		my $url = "http://$miniservers{$msnr}{Credentials}\@$miniservers{$msnr}{IPAddress}\:$miniservers{$msnr}{Port}/dev/cfg/ftp";
		my $ua = LWP::UserAgent->new;
		$ua->timeout(5);
		my $response = $ua->get($url);
		if (!$response->is_success) {
			carp("Cannot query FTP port because Loxone Miniserver is not reachable.");
			return undef;
		} 
		my $rawxml = $response->decoded_content();
		my $xml = XML::Simple::XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
		$miniservers{$msnr}{FTPPort} = $xml->{value};
	}
	return $miniservers{$msnr}{FTPPort};
}







####################################################
# get_localip - Get local ip address
####################################################
sub get_localip
{
	my $sock = IO::Socket::INET->new(
						   PeerAddr=> "example.com",
						   PeerPort=> 80,
						   Proto   => "tcp");
	return ($sock->sockhost);
	# close $sock;
	# return $localip;

}


####################################################
# is_enabled - tries to detect if a string says 'True'
####################################################
sub is_enabled
{ 
	my ($text) = @_;
	$text =~ s/^\s+|\s+$//g;
	$text = lc $text;
	if ($text eq "true") { return 1;}
	if ($text eq "yes") { return 1;}
	if ($text eq "on") { return 1;}
	if ($text eq "enabled") { return 1;}
	if ($text eq "enable") { return 1;}
	if ($text eq "1") { return 1;}
	return undef;
}

####################################################
# is_disabled - tries to detect if a string says 'True'
####################################################
sub is_disabled
{ 
	my ($text) = @_;
	$text =~ s/^\s+|\s+$//g;
	$text = lc $text;
	if ($text eq "false") { return 1;}
	if ($text eq "no") { return 1;}
	if ($text eq "off") { return 1;}
	if ($text eq "disabled") { return 1;}
	if ($text eq "disable") { return 1;}
	if ($text eq "0") { return 1;}
	return undef;
}

#####################################################
# Strings trimmen
#####################################################

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };
sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };

#####################################################
# Finally 1; ########################################
#####################################################
1;
