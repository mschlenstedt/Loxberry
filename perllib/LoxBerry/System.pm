use strict;
use Config::Simple;
use File::HomeDir;
use URI::Escape;
use Cwd 'abs_path';
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

# Hash only valid in this module
my %miniservers;
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
		
		$miniservers{$msnr}{Admin_RAW} = uri_unescape($miniservers{$msnr}{Admin});
		$miniservers{$msnr}{Pass_RAW} = uri_unescape($miniservers{$msnr}{Pass});
		$miniservers{$msnr}{Credentials_RAW} = $miniservers{$msnr}{Admin_RAW} . ':' . $miniservers{$msnr}{Pass_RAW};
	}
	return 1;
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
