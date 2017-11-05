our $VERSION = "0.23_04";
$VERSION = eval $VERSION;
# Please increment version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

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

=head1 NAME

LoxBerry::System - LoxBerry platform system module to ease writing plugins for LoxBerry. See http://www.loxwiki.eu:80/x/o4CO

=head1 SYNOPSIS

	use LoxBerry::System;
	
	# LoxBerry::System defines globals for plugin directory
	print "Config Directory: $lbconfigdir";
	print "CGI directory:    $lbcgidir";
	print "HTML directory:   $lbhtmldir";
	# See more below
	
	# Get all data of configured Miniservers
	my %miniservers = LoxBerry::System::get_miniservers();
	print "Miniserver no. 1 is called $miniservers{1}{Name} and has IP $miniservers{1}{IPAddress}.";
	# See below for all available variables
	
	# Binary paths from the config can be accessed by
	my %bins = LoxBerry::System::get_binaries();
	system("ps aux | $bins->{GREP} perl";
	
	# LoxBerry::System supports  using Loxone CloudDNS
	my $ftpport = LoxBerry::System::get_ftpport($msno);
	# returns the FTP port, either  local or CloudDNS one

=head1 DESCRIPTION

Goal of LoxBerry::System (and LoxBerry::Web) is to simplify creating plugins for the LoxBerry platform. Many time-consuming steps are encapsulated to easy call-able functions.

=head2 Global Variables

LoxBerry::System defines a dozen of variables for easier access to the plugin directories. They are accessable directly after the use LoxBerry::System command.

	$lbhomedir		# Home directory of LoxBerry, usually /opt/loxberry
	$lbplugindir	# The unique directory name of the plugin, e.g. squeezelite
	$lbcgidir		# Full path to the CGI directory of the current plugin. e.g. /opt/loxberry/webfrontend/cgi/plugins/squeezelite
	$lbhtmldir		# Full path to the HTML directory of the current plugin, e.g. /opt/loxberry/webfrontend/html/plugins/squeezelite
	$lbtemplatedir	# Full path to the Template directory of the current plugin, e.g. /opt/loxberry/templates/plugins/squeezelite
	$lbdatadir		# Full path to the Data directory of the current plugin, e.g. /opt/loxberry/data/plugins/squeezelite
	$lblogdir		# Full path to the Log directory of the current plugin, e.g. /opt/loxberry/data/plugins/squeezelite
	$lbconfigdir	# Full path to the Config directory of the current plugin, e.g. /opt/loxberry/config/plugins/squeezelite

$lbhomedir is detected in the following order:

=over 12

=item 1. System environment variable -> $LBHOMEDIR

=item 2. If username is loxberry -> HomeDir

=item 3. Static -> /opt/loxberry

=back

=cut

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
	} elsif ($username eq 'root') {
		$lbhomedir = `su - loxberry -c pwd`;
		$lbhomedir =~ s/\n|\s+//;
	} else {
		# Missing some additional functions if we are running from daemon or cron
		$lbhomedir = '/opt/loxberry';
		Carp::carp ("LoxBerry home was statically set to /opt/loxberry as no home directory could be found.");
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
my $pluginversion;

# Finished everytime code execution
##################################################################

=head2 get_miniservers

This function reads all the configuration variables of all configured Miniservers, including credentials. 
The result is a two-dimensional hash. The first key is the Miniserver number (starting from 1), the second keys are 
configuration settings.

	use LoxBerry::System;
	my %miniservers = LoxBerry::System::get_miniservers();
	
	if (! %miniservers) {
		exit(1); # No Miniservers found
	}
	
	print "Number of Miniservers: " . keys(%miniservers);
	
	print "Miniserver no. 1's name is $miniservers{1}{Name} and has IP $miniservers{1}{IPAddress}.";
	
	foreach my $ms (sort keys %miniservers) {
		print "Miniserver no. $ms is called $miniservers{$ms}{Name} and has IP $miniservers{$ms}{IPAddress}.";
	}

Available keys are:

	Name			# Name of the Miniserver
	IPAddress		# IP address of the Miniserver
	Port			# Web port of the Miniserver
	Admin			# Administrative user (URL-encoded)
	Pass			# Password of administrative user (URL-encoded)
	Credentials		# Admin:Pass (URL-encoded)
	Admin_RAW		# Administrative user (NOT URL-encoded)
	Pass_RAW		# Password of administrative user (NOT URL-encoded)
	Credentials_RAW	# Admin:Pass (NOT URL-encoded)
	Note			# Note to the MS
	UseCloudDNS	 	# CloudDNS enabled
	CloudURL	 	# External URL 
	CloudURLFTPPort	# External FTP port - use get_ftpport instead!

=cut

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

=head2 get_miniserver_by_ip

Returns the Miniserver number using the provided IP address. 

	my $ip = '192.168.0.77';
	my %miniservers = LoxBerry::System::get_miniservers();
	my $msno = LoxBerry::System::get_miniserver_by_ip($ip);
	
	if ($msno) {
		print "Miniserver with address $ip is called $miniservers{$msno}{Name}.";
	}

=cut

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

=head2 get_miniserver_by_name

Returns the number of the Miniserver using the provided Name. This could be useful to get the number of a name selection in a form. The name comparison is case-insensitive.

	my $name = 'MyMiniserver';
	my %miniservers = LoxBerry::System::get_miniservers();
	my $msno = LoxBerry::System::get_miniserver_by_name($name);
	
	if ($msno) {
		print "Miniserver with name $name is called $miniservers{$msno}{Name}.";
	}

=cut

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

=head2 get_binaries

Although LoxBerry in it's fundamental characteristic comes as a ready-to-use Raspberry image, it should be as platform-independent as possible. 
Therefore, system binaries should not be executed with static paths but from variables to these binaries. 

	my $bins = LoxBerry::System::get_binaries();
	print STDERR "The binary of Grep is $bins->{GREP}.";
	system("$bins->{ZIP} myarchive.zip *");

Available binaries:
	APT
	AWK
	BASH
	BZIP2
	CHMOD
	CURL
	DATE
	GREP
	GZIP
	MAIL
	NTPDATE
	POWEROFF
	REBOOT
	SENDMAIL
	SUDO
	TAR
	UNZIP
	WGET
	ZIP

If your plugin needs additional system binaries, it is best practise to read the binary path from your own plugin config file.

=cut

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

##################################################################################
# Get Plugin Version
# Returns plugin version from plugindatabase
##################################################################################
sub pluginversion
{

	if ($pluginversion) {
		# print STDERR "Returning already fetched version\n";
		return $pluginversion;
	} 
	if (!-e "$lbhomedir/data/system/plugindatabase.dat") {
		Carp::carp "LoxBerry::System::pluginversion: Could not find $lbhomedir/data/system/plugindatabase.dat\n";
		return undef;
	}

	# Read Plugin database copied from plugininstall.pl
	my $openerr;
	open(F,"<", "$lbhomedir/data/system/plugindatabase.dat") or ($openerr = 1);
    if ($openerr) {
		Carp::carp "LoxBerry::System::pluginversion: Error opening $lbhomedir/data/system/plugindatabase.dat\n";
		return undef;
		}
    
	my @data = <F>;
    seek(F,0,0);
    truncate(F,0);
    foreach (@data){
		s/[\n\r]//g;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			next;
		}
		my @fields = split(/\|/);
		# print STDERR "Fields: 0:" . $fields[0] . " 1:" . $fields[1] . " 2:" . $fields[2] . " 3:" . $fields[3] . " 4:" . $fields[4] . " 5:" . $fields[5] . " 6:" . $fields[6] . "\n";
		
		if ($fields[5] eq $lbplugindir) {
			$pluginversion = $fields[3];
			close F;
			return $pluginversion;
		}
	}
	return undef;
}



##################################################################
# Read general.cfg
# This INTERNAL is called from several functions and not exported
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
	
	$clouddnsaddress = $cfg->param("BASE.CLOUDDNS") or Carp::carp ("BASE.CLOUDDNS not defined.\n");
	$lbtimezone		= $cfg->param("TIMESERVER.ZONE") or Carp::carp ("TIMESERVER.ZONE not defined.\n");

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
# INTERNAL function to set CloudDNS IP and Port
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

=head2 get_ftpport

The internal FTP port of the Miniserver is not configured in the LoxBerry configuration but can be queried by this function.
It supports CloudDNS FTP port (which IS defined in the LoxBerry config), therefore using this functions returns either the
internal or the CloudDNS FTP port, so you do not need to spy yourself.

	my $ftpport = LoxBerry::System::get_ftpport($msnr);
	# Returns the FTP port of Miniserver $msnr.
	my $ftpport = LoxBerry::System::get_ftpport();
	# Returns the FTP port of the first Miniserver.

=cut

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
			Carp::carp("Cannot query FTP port because Loxone Miniserver is not reachable.");
			return undef;
		} 
		my $rawxml = $response->decoded_content();
		my $xml = XML::Simple::XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
		$miniservers{$msnr}{FTPPort} = $xml->{value};
	}
	return $miniservers{$msnr}{FTPPort};
}

=head2 get_localip

Returns the current LoxBerry IP address as string.

	my $ip = LoxBerry::System::get_localip();
	print "Current LoxBerry IP is $ip.";

=cut

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

=head2 is_enabled and is_disabled

This function "guesses" is a string variable is enabled/true (disabled/false) by a couple of usual keywords. This is useful when parsing configuration files. 
The check is case-insensitive. It returns 1 if the check is successful,  or undef if the keyword does not match.

Keywords for is_enabled: true, yes, on, enabled, enable, 1.

Keywords for is_disabled: false, no, off, disabled, disable, 0.

	my $configstring = "enable_plugin = True";
	my ($plugin_enabled, $value) = split /=/, $configstring;
	if (is_enabled($value)) {
		print "Plugin is enabled.";
	}

=cut

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

=head2 trim, ltrim, rtrim

Developers from other languages feel inconvenient using RegEx for simple string operations. LoxBerry::System adopts the familiar ltrim, rtrim and trim to remove leading, trailing or both whitespaces.

trim, ltrim and rtrim are exported (you don't have to prefix the command with LoxBerry::System::).

	my $dirty_string = "    What a mess!        ";
	print ltrim($dirty_string); 	# Shows 'What a mess!        '
	print rtrim($dirty_string); 	# Shows '    What a mess!'
	print trim($dirty_string); 		# Shows 'What a mess!'

=cut

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

=head1 EXCEPTION HANDLING

All functions usually return undef if an error occurs, nothing was found or the input parameters are out of scope. You have to handle this is your plugin. Functions may inform in STDERR about warnings and errors.

=head1 SEE ALSO

Further features especially for language and HTML support are found in LoxBerry::Web.

=cut
