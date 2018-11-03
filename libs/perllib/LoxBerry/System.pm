# Please increment version number on EVERY change 
# Major.Minor represents LoxBerry version (e.g. 0.3.1.12 = LoxBerry V0.3.1 the 12th change)

use strict;
use Config::Simple;
use URI::Escape;
use Cwd 'abs_path';
use Carp;
use Sys::Hostname;

package LoxBerry::System;
our $VERSION = "1.2.5.5";
our $DEBUG = 0;

use base 'Exporter';

# Every exported sub or variable is accessable directly in the main namespace
# Not exported subs and global (our) variables can be accessed by specifying the 
# namespace, e.g. 
# $text = LoxBerry::System::is_enabled($text);
# my $variable = LoxBerry::System::$systemvariable;

our @EXPORT = qw (
	$lbhomedir
	$lbpplugindir
	$lbcgidir
	$lbphtmldir
	$lbphtmlauthdir
	$lbptemplatedir
	$lbpdatadir
	$lbplogdir
	$lbpconfigdir
	$lbpbindir
	
	lblanguage
	readlanguage
	lbhostname
	lbfriendlyname
	lbwebserverport

	$lbshtmldir
	$lbshtmlauthdir
	$lbstemplatedir
	$lbsdatadir
	$lbslogdir
	$lbsconfigdir
	$lbssbindir
	$lbsbindir
		
	canonical_path
	is_enabled 
	is_disabled
	begins_with
	trim 
	ltrim
	rtrim
	currtime
	reboot_required
	vers_tag
);

=head1 NAME

LoxBerry::System - LoxBerry platform system module to ease writing plugins for LoxBerry. See http://www.loxwiki.eu:80/x/o4CO

=head1 SYNOPSIS

	use LoxBerry::System;
	
	# LoxBerry::System defines globals for plugin directory
	print "Config Directory: $lbpconfigdir";
	print "HTMLAUTH directory:    $lbphtmlauthdir";
	print "HTML directory:   $lbphtmldir";
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
	$lbpplugindir	# The unique directory name of the plugin, e.g. squeezelite
	$lbcgidir		# Legacy variable, points to the HTMLAUTH dir . e.g. /opt/loxberry/webfrontend/htmlauth/plugins/squeezelite
	$lbphtmlauthdir	# Full path to the HTMLAUTH directory of the current plugin. e.g. /opt/loxberry/webfrontend/htmlauth/plugins/squeezelite
	$lbphtmldir		# Full path to the HTML directory of the current plugin, e.g. /opt/loxberry/webfrontend/html/plugins/squeezelite
	$lbptemplatedir	# Full path to the Template directory of the current plugin, e.g. /opt/loxberry/templates/plugins/squeezelite
	$lbpdatadir		# Full path to the Data directory of the current plugin, e.g. /opt/loxberry/data/plugins/squeezelite
	$lbplogdir		# Full path to the Log directory of the current plugin, e.g. /opt/loxberry/data/plugins/squeezelite
	$lbpconfigdir	# Full path to the Config directory of the current plugin, e.g. /opt/loxberry/config/plugins/squeezelite

	$lbshtmlauthdir	# Full path to the SYSTEM CGI directory /opt/loxberry/webfrontend/htmlauth/system
	$lbshtmldir		# Full path to the SYSTEM HTML directory /opt/loxberry/webfrontend/html/system
	$lbstemplatedir	# Full path to the SYSTEM Template directory /opt/loxberry/templates/system
	$lbsdatadir		# Full path to the SYSTEM Data directory /opt/loxberry/data/system
	$lbslogdir		# Full path to the SYSTEM Log directory /opt/loxberry/data/system
	$lbsconfigdir	# Full path to the SYSTEM Config directory /opt/loxberry/config/system


$lbhomedir is detected in the following order:

=over 12

=item 1. System environment variable -> $LBHOMEDIR

=item 2. Relative to a path in the environment variable PERL5LIB

=item 3. Static -> /opt/loxberry

=back

=cut

sub canonical_path {
	my $path = shift;
	my @ret = ();
	$path .= '/' if $path =~ /[.\/]$/;
	for my $tok (split(/\/+/, $path . '-')) {
		next if $tok eq '.';
		if ($tok eq '..') {
			pop @ret;
			next;
		}
		push @ret, $tok if $tok;
	}
	'/' . substr(join('/', @ret), 0, -1)
}

sub get_plugindir {
	use Cwd 'abs_path';
	my $use_abs = shift;
	my @p = ();
	my $s, my $t, my $i;

	$s = $ENV{SCRIPT_FILENAME}; $t = $0;
	if ($s) {
		$s = cwd() . "/" . $s unless ($s =~ /^\//);
		$s = $use_abs ? Cwd::abs_path($s) : canonical_path($s);
	} else {
		$s = '/';
	}
	$t = cwd() . "/" . $t unless ($t eq "" || $t =~ /^\//);
	if ($s != $t ) {
		$t = $use_abs ? Cwd::abs_path($t) : canonical_path($t);
	} else {
		$t = '/';
	}
	return '' if ($s eq '/' && $t eq '/');

	push @p, $s unless ($s eq '/');
	push @p, $t unless ($t eq '/' || $s eq $t);

	my %parents = (templates => 1, log => 2, data => 3, config => 4, bin => 5);
	foreach $t (@p) {
		print STDERR "Checking '$t' for '/plugins/' ...\n" if ($DEBUG);
		my @pc = split('/', $t);
		for ($i=$#pc-2; $i > 0; $i--) {
			next unless ($pc[$i] eq 'plugins');
			if ($i >= 2 && $pc[$i-2] eq 'webfrontend') {
				return $pc[$i+1];
			} elsif ($parents{$pc[$i-1]}) {
				return $pc[$i+1];
			} elsif ($i >= 2 && $pc[$i-2] eq 'system'
				&& $pc[$i-1] eq 'daemon')
			{
				return $pc[$i+1];
			}
		}
	}
	return ($use_abs) ? '' : get_plugindir(1);
}

##################################################################
# This code is executed on every use
##################################################################

# Set global variables

# Get LoxBerry home directory
our $lbhomedir;
if ($ENV{LBHOMEDIR}) {
	$lbhomedir = $ENV{LBHOMEDIR};
	print STDERR "lbhomedir $lbhomedir detected by environment\n" if ($DEBUG);
} else {
	foreach my $d  (@INC) {
		if (-e $d ."/LoxBerry/Web.pm" && -e $d ."/../phplib/loxberry_web.php") {
			$lbhomedir = canonical_path($d . "/../..");
			print STDERR "$lbhomedir set to " . $lbhomedir . "\n" if ($DEBUG);
		}
	}
}
if (!$lbhomedir) {
	# Missing some additional functions if we are running from daemon or cron
	$lbhomedir = '/opt/loxberry';
	print STDERR "lbhomedir $lbhomedir set to /opt/loxberry as fallback\n" if ($DEBUG);
	Carp::carp ("LoxBerry home was statically set to /opt/loxberry as no home directory could be found.");
}

our $lbpplugindir = get_plugindir();

if ($lbpplugindir) {
	print STDERR "lbpplugindir = $lbpplugindir\n" if ($DEBUG);
	our $lbphtmlauthdir = "$lbhomedir/webfrontend/htmlauth/plugins/$lbpplugindir";
	our $lbphtmldir = "$lbhomedir/webfrontend/html/plugins/$lbpplugindir";
	our $lbcgidir = $lbphtmlauthdir;
	our $lbptemplatedir = "$lbhomedir/templates/plugins/$lbpplugindir";
	our $lbpdatadir = "$lbhomedir/data/plugins/$lbpplugindir";
	our $lbplogdir = "$lbhomedir/log/plugins/$lbpplugindir";
	our $lbpconfigdir = "$lbhomedir/config/plugins/$lbpplugindir";
	# our $lbpsbindir = "$lbhomedir/sbin/plugins/$lbpplugindir";
	our $lbpbindir = "$lbhomedir/bin/plugins/$lbpplugindir";
}

our $lbshtmldir = "$lbhomedir/webfrontend/html/system";
our $lbshtmlauthdir = "$lbhomedir/webfrontend/htmlauth/system";
our $lbstemplatedir = "$lbhomedir/templates/system";
our $lbsdatadir = "$lbhomedir/data/system";
our $lbslogdir = "$lbhomedir/log/system";
our $lbsconfigdir = "$lbhomedir/config/system";
our $lbssbindir = "$lbhomedir/sbin";
our $lbsbindir = "$lbhomedir/bin";

# Variables only valid in this module
my $lang;
my $cfgwasread;
my %miniservers;
my %binaries;
my $lbtimezone;
my $pluginversion;
my $lbhostname;
my $lbfriendlyname;
my $lbversion;
my @plugins;
my $plugins_delcache;
my $webserverport;
my $clouddnsaddress;
my $msClouddnsFetched;
my $sysloglevel;

our %SL; # Shortcut for System language phrases
our %L;  # Shortcut for Plugin language phrases
our $reboot_required_file = "$lbhomedir/log/system_tmpfs/reboot.required";


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
	if ($msClouddnsFetched) {
		return %miniservers;
	}

	if (!%miniservers) {
		read_generalcfg();
	}
	
	# CloudDNS handling
	foreach my $msnr (keys %miniservers) {
		if (LoxBerry::System::is_enabled($miniservers{$msnr}{UseCloudDNS}) && ($miniservers{$msnr}{CloudURL})) {
			set_clouddns($msnr, $clouddnsaddress);
		}
		
		if (! $miniservers{$msnr}{Port}) {
			$miniservers{$msnr}{Port} = 80;
		}

		# Miniserver values consistency check
		# If a Miniserver entry is not plausible, the full Miniserver hash entry is deleted
		if($miniservers{$msnr}{Name} eq '' or $miniservers{$msnr}{IPAddress} eq '' or $miniservers{$msnr}{Admin} eq '' or $miniservers{$msnr}{Pass} eq ''
			or $miniservers{$msnr}{Port} eq '') {
			delete @miniservers{$msnr};
		}
	}
	$msClouddnsFetched = 1;
	return %miniservers;
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
	
	if(!$msClouddnsFetched) {
		LoxBerry::System::get_miniservers();
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
	
	if(!$msClouddnsFetched) {
		LoxBerry::System::get_miniservers();
	}
	
	foreach my $msname (keys %miniservers) {
		if (lc($miniservers{$msname}{Name}) eq $myname) {
			return $msname;
		}
	}
	return undef;
}

=head2 get_binaries

Although LoxBerry in its fundamental characteristic comes as a ready-to-use Raspberry image, it should be as platform-independent as possible. 
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
# With parameter name, returns the version of named plugin
##################################################################################
sub pluginversion
{
	my ($queryname) = @_;
	
	if ($pluginversion && !$queryname) {
		print STDERR "Debug: $pluginversion is cached.\n" if ($DEBUG);
		return $pluginversion;
	}
	
	my $query = $queryname ? $queryname : $lbpplugindir;
	
	my $plugin = LoxBerry::System::plugindata($query);
	return $plugin->{PLUGINDB_VERSION} if ($plugin);
}

##################################################################################
# Get Plugin Loglevel
# Returns plugin loglevel from plugindatabase
# With parameter name, returns the loglevel of named plugin
##################################################################################
sub pluginloglevel
{
	my ($queryname) = @_;
	
	my $query = $queryname ? $queryname : $lbpplugindir;
	
	my $plugin = LoxBerry::System::plugindata($query);
	return $plugin->{PLUGINDB_LOGLEVEL} ? $plugin->{PLUGINDB_LOGLEVEL} : 0;
}

##################################################################################
# Get all Plugin Data of current plugin from plugin database
# With parameter name, returns the plugindata from named plugin
##################################################################################

sub plugindata
{
	my ($queryname) = @_;
	
	my $query = defined $queryname ? $queryname : $lbpplugindir;
	
	print STDERR "plugindata: Query '$query'\n" if ($DEBUG);
	
	my @plugins = LoxBerry::System::get_plugins();
	
	foreach my $plugin (@plugins) {
		if ($queryname && ( $plugin->{PLUGINDB_NAME} eq $query || $plugin->{PLUGINDB_FOLDER} eq $query) ) {
			print STDERR "   Returning plugin $plugin->{PLUGINDB_TITLE}\n" if ($DEBUG);
			return $plugin;
		}
		if (!$queryname && $plugin->{PLUGINDB_FOLDER} eq $query) {
			$pluginversion = $plugin->{PLUGINDB_VERSION};
			return $plugin;
		}
	}
}



##################################################################################
# Get Plugins
# Returns all plugins in a hash
# Parameter: 	1. If defined (=1), returns also comments 
# 				2. If defined (=1), forces to reload the DB
##################################################################################
sub get_plugins
{
	my ($withcomments, $forcereload, $plugindb_file) = @_;
	
	if (@plugins && !$forcereload && !$plugindb_file && !$plugins_delcache) {
		print STDERR "get_plugins: Returning cached version of plugindatabase\n" if ($DEBUG);
		return @plugins;
	} else {
		print STDERR "get_plugins: Re-reading plugindatabase\n" if ($DEBUG);
	}
	
	if (! $plugindb_file) {
		$plugindb_file = "$lbsdatadir/plugindatabase.dat";
	} else {
		$plugins_delcache = 1;
	}
	
	print STDERR "get_plugins: Using file $plugindb_file\n" if ($DEBUG);
	
	if (!-e $plugindb_file) {
		Carp::carp "LoxBerry::System::pluginversion: Could not find $plugindb_file\n";
		return undef;
	}
	my $openerr;
	open(my $fh, "<", $plugindb_file) or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening plugin database $plugindb_file";
		# &error;
		return undef;
		}
	my @data = <$fh>;

	@plugins = ();
	my $plugincount = 0;
	
	foreach (@data){
		s/[\n\r]//g;
		my %plugin;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			if (defined $withcomments) {
				$plugin{PLUGINDB_COMMENT} = $_;
				push(@plugins, \%plugin);
			}
			next;
		}
		
		$plugincount++;
		my @fields = split(/\|/);

		## Start Debug fields of Plugin-DB
		# do {
			# my $field_nr = 0;
			# my $dbg_fields = "Plugin-DB Fields: ";
			# foreach (@fields) {
				# $dbg_fields .= "$field_nr: $_ | ";
				# $field_nr++;
			# }
			# print STDERR "$dbg_fields\n";
		# } ;
		## End Debug fields of Plugin-DB
		
		# From Plugin-DB
		
		$plugin{PLUGINDB_NO} = $plugincount;
		$plugin{PLUGINDB_MD5_CHECKSUM} = $fields[0];
		$plugin{PLUGINDB_AUTHOR_NAME} = $fields[1];
		$plugin{PLUGINDB_AUTHOR_EMAIL} = $fields[2];
		$plugin{PLUGINDB_VERSION} = $fields[3];
		$plugin{PLUGINDB_NAME} = $fields[4];
		$plugin{PLUGINDB_FOLDER} = $fields[5];
		$plugin{PLUGINDB_TITLE} = $fields[6];
		$plugin{PLUGINDB_INTERFACE} = $fields[7];
		$plugin{PLUGINDB_AUTOUPDATE} = $fields[8];
		$plugin{PLUGINDB_RELEASECFG} = $fields[9];
		$plugin{PLUGINDB_PRERELEASECFG} = $fields[10];
		$plugin{PLUGINDB_LOGLEVEL} = $fields[11];
		$plugin{PLUGINDB_LOGLEVELS_ENABLED} = $plugin{PLUGINDB_LOGLEVEL} >= 0 ? 1 : 0;
		$plugin{PLUGINDB_ICONURI} = "/system/images/icons/$plugin{PLUGINDB_FOLDER}/icon_64.png";
		push(@plugins, \%plugin);
		# On changes of the plugindatabase format, please change here 
		# and in libs/phplib/loxberry_system.php / function get_plugins
	}
	return @plugins;

}

##################################################################################
# Get System Version
# Returns LoxBerry version
##################################################################################
sub lbversion
{

	if ($lbversion ne "") {
		return $lbversion;
	} 
	read_generalcfg();
	return $lbversion;
}

##################################################################################
# systemloglevel
# Returns LoxBerry System Loglevel
##################################################################################

sub systemloglevel
{
	return $sysloglevel if ($sysloglevel);
	read_generalcfg();
	return $sysloglevel if ($sysloglevel);
	return 6;
}

##################################################################
# Read general.cfg
# This INTERNAL is called from several functions and not exported
##################################################################
sub read_generalcfg
{
	my $miniservercount;
	
	if ($cfgwasread) {
		return 1;
	}
	
	my $cfg = new Config::Simple("$lbhomedir/config/system/general.cfg") or return undef;
	$cfgwasread = 1;
	$LoxBerry::System::lang = $cfg->param("BASE.LANG") or Carp::carp ("BASE.LANG is not defined in general.cfg\n");
	$miniservercount = $cfg->param("BASE.MINISERVERS") or Carp::carp ("BASE.MINISERVERS is 0 or not defined in general.cfg\n");
	$clouddnsaddress = $cfg->param("BASE.CLOUDDNS"); # or Carp::carp ("BASE.CLOUDDNS not defined in general.cfg\n");
	$lbtimezone		= $cfg->param("TIMESERVER.ZONE"); # or Carp::carp ("TIMESERVER.ZONE not defined in general.cfg\n");
	$lbfriendlyname = $cfg->param("NETWORK.FRIENDLYNAME"); # or Carp::carp ("NETWORK.FRIENDLYNAME not defined in general.cfg\n");
	$lbversion		= $cfg->param("BASE.VERSION") or Carp::carp ("BASE.VERSION not defined in general.cfg\n");
	$webserverport  = $cfg->param("WEBSERVER.PORT"); # or Carp::carp ("WEBSERVER.PORT not defined in general.cfg\n");
	$sysloglevel	= $cfg->param("BASE.SYSTEMLOGLEVEL");
	# print STDERR "read_generalcfg lbfriendlyname: $lbfriendlyname\n";
	# Binaries
	$LoxBerry::System::binaries = $cfg->get_block('BINARIES');

	if (($miniservercount) && ($miniservercount < 1)) {
		return undef;
	}
	
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
		
		$miniservers{$msnr}{SecureGateway} = $cfg->param("MINISERVER$msnr.SECUREGATEWAY");
		$miniservers{$msnr}{EncryptResponse} = $cfg->param("MINISERVER$msnr.ENCRYPTRESPONSE");
		
	}
	return 1;
}
####################################################
# set_clouddns
# INTERNAL function to set CloudDNS IP and Port
####################################################
sub set_clouddns
{
	my ($msnr, $clouddnsaddress) = @_;
	require LWP::UserAgent;
	require JSON;
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->max_redirect( 0 );
	my $checkurl = "http://$clouddnsaddress?getip&snr=" . $miniservers{$msnr}{CloudURL}."&json=true";
	my $resp 	 = $ua->get($checkurl);
	my $respjson = JSON::decode_json($resp->content);
	($miniservers{$msnr}{IPAddress}, $miniservers{$msnr}{Port}) = split(/:/, $respjson->{IP}, 2);
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
	require XML::Simple;
	require LWP::UserAgent;
	
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
	require IO::Socket::INET;
	my $sock = IO::Socket::INET->new(
						   PeerAddr=> "8.8.8.8",
						   PeerPort=> 53,
						   Proto   => "udp");
	return ($sock->sockhost);
	# close $sock;
	# return $localip;

}


##################################################################
# Get LoxBerry URL parameter or System language
##################################################################
sub lblanguage 
{
	print STDERR "current \$lang: $LoxBerry::System::lang\n" if ($DEBUG);
	# Return if $lang is already set
	
	# Legacy: $lang in LoxBerry::Web
	if ($LoxBerry::Web::lang) {
		return $LoxBerry::Web::lang;
	}
	if ($LoxBerry::System::lang) {
		return $LoxBerry::System::lang;
	}
	# Get lang from query 
	require CGI;
	my $query = CGI->new();
	my $querylang = $query->param('lang');
	if ($querylang) 
		{ $LoxBerry::System::lang = substr $querylang, 0, 2;
		  print STDERR "\$lang in CGI: $LoxBerry::System::lang" if ($DEBUG);
		  return $LoxBerry::System::lang;
	}
	# If nothing found, get language from system settings
	read_generalcfg();
	
	#my  $syscfg = new Config::Simple("$LoxBerry::System::lbhomedir/config/system/general.cfg");
	#$LoxBerry::System::lang = $syscfg->param("BASE.LANG");
	print STDERR "\$lang from general.cfg: $LoxBerry::System::lang" if ($DEBUG);
	return $LoxBerry::System::lang;
}

	
#####################################################
# readlanguage
# Read the language for a plugin 
# Example Call:
# my %Phrases = LoxBerry::Web::readlanguage($template, "language.ini");
#####################################################
sub readlanguage
{
	my ($template, $langfile, $syslang) = @_;

	my $lang = LoxBerry::System::lblanguage();
	# my $issystem = LoxBerry::System::is_systemcall();
	my $issystem;
#	if ($syslang || LoxBerry::System::is_systemcall()) {
	if ($syslang || !$LoxBerry::System::lbpplugindir) {
		$issystem = 1;
	}
	
	if(!$issystem && $template && !$template->isa("HTML::Template")) {
		# Plugin only gave us a language 
		$langfile = $template;
	}
	
	# Return if we already have them in memory.
	if (!$issystem && !$langfile) { 
		Carp::carp("WARNING: \$langfile is empty, setting to language.ini. If file is missing, error will occur.") if ($DEBUG);
		$langfile = "language.ini"; }
	# if ($issystem and %SL) { return %SL; }
	# if (!$issystem and %L) { return %L; }

	# SYSTEM Language
	if ($issystem) {
		print STDERR "This is a system call\n" if ($DEBUG);
		# System language is "hardcoded" to file language_*.ini
		my $langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
		
		if (!%SL) {
			# print STDERR "READ\n";
			
			my $langfile_en = $langfile . "_en.ini";
			my $langfile_foreign = $langfile . "_" . $lang . ".ini";
			
			if ( $lang ne 'en' and (-e $langfile_foreign)) {
				# Config::Simple->import_from($langfile_foreign, \%SL) or Carp::carp(Config::Simple->error());
				my $cont_foreign = LoxBerry::System::read_file($langfile_foreign);
				LoxBerry::System::_parse_lang_file($cont_foreign, \%SL);
				undef $cont_foreign;
			}
			
			# Config::Simple->import_from($langfile_en, \%SL) or Carp::carp(Config::Simple->error());
			my $cont_en = LoxBerry::System::read_file($langfile_en);
			LoxBerry::System::_parse_lang_file($cont_en, \%SL);
			undef $cont_en;

			# Read foreign language if exists and not English and overwrite English strings
			
			if (!%SL) {
				Carp::confess ("ERROR: Could not read any language phrases. Exiting.\n");
			}
		}
		
		if ($template and $template->isa("HTML::Template")) {
			#while (my ($name, $value) = each %SL) {
			#	$template->param("$name" => $value);
			#}
			$template->param(%SL);
		}
		return %SL;
	
	} else {
	# PLUGIN language
		# Plugin language got in format language.ini
		# Need to re-parse the name
		print STDERR "This is a plugin call\n" if ($DEBUG);
		$langfile =~ s/\.[^.]*$//;
		$langfile  = "$LoxBerry::System::lbptemplatedir/lang/$langfile";
		
		# Read English language as default
		# Missing phrases in foreign language will fall back to English
		if (!%L) {
			my $langfile_en = $langfile . "_en.ini";
			my $langfile_foreign = $langfile . "_" . $lang . ".ini";
			
			if ( $lang ne 'en' and (-e $langfile_foreign)) {
				# Config::Simple->import_from($langfile_foreign, \%L) or Carp::carp(Config::Simple->error());
				my $cont_foreign = LoxBerry::System::read_file($langfile_foreign);
				LoxBerry::System::_parse_lang_file($cont_foreign, \%L);
				undef $cont_foreign;
			}
			
			if (-e $langfile_en) {
				# Config::Simple->import_from($langfile . "_en.ini", \%L) or Carp::carp(Config::Simple->error());
				my $cont_en = LoxBerry::System::read_file($langfile_en);
				LoxBerry::System::_parse_lang_file($cont_en, \%L);
				undef $cont_en;
				
			}
						
			if (! %L) {
				Carp::carp ("ERROR: Could not read any language phrases from $langfile.\n");
			}
		}
		if ($template and $template->isa("HTML::Template")) {
			#while (my ($name, $value) = each %L) {
			#	$template->param("$name" => $value);
			#}
			$template->param(%L);
		}
		return %L;
	}
}

sub _parse_lang_file
{
	my ($content, $langhash) = @_;
	my @cont = split(/\n/, $content);

	my $section = 'default';

	foreach my $line (@cont) {
		# Trim
		$line =~ s/^\s+|\s+$//g;	
		my $firstletter = substr($line, 0, 1);
		# print "Firstletter: $firstletter\n";
		# Comments
		if($firstletter eq '' or $firstletter eq '#' or $firstletter eq '/' or $firstletter eq ';') {
			next;}
		# Sections
		if ($firstletter eq '[') {
			my $closebracket = index($line, ']', 1);
			if($closebracket == -1) {
				next;
			}
			$section = substr($line, 1, $closebracket-1);
			# print "\n[$section]\n";
			next;
		}
		# Define variables
		my ($param, $value) = split(/=/, $line, 2);
		$param =~ s/^\s+|\s+$//g;	
		next if ($langhash->{"$section.$param"});
		$value =~ s/^\s+|\s+$//g;
		my $firsthyphen=substr($value, 0, 1);
		my $lasthyphen=substr($value, -1, 1);
		if ($firsthyphen eq '"' and $lasthyphen eq '"') {
			$value = substr($value, 1, -1);
		}
		# print "$param=$value\n";
		$langhash->{"$section.$param"} = $value;
	}
}



=head2 lbhostname

This exported function returns the current system hostname

=cut

####################################################
# lbhostname - Returns the current system hostname
####################################################
sub lbhostname
{
	return Sys::Hostname::hostname();
}

=head2 lbfriendlyname

This exported function returns the friendly (user defined) name

=cut

####################################################
# lbfriendlyname - Returns the friendly name
####################################################
sub lbfriendlyname
{
	if (! $cfgwasread) 
		{ read_generalcfg(); 
	}
	
	# print STDERR "LBSYSTEM lbfriendlyname $lbfriendlyname\n";
	return $lbfriendlyname;
	
}

=head2 lbwebserverport

This exported function returns the webserver port 

=cut

####################################################
# lbwebserverport - Returns the friendly name
####################################################
sub lbwebserverport
{
	if (! $cfgwasread) 
		{ read_generalcfg(); 
	}
	if (! $webserverport) {
		$webserverport = 80;
	}
	return $webserverport;
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
	if ($text eq "check") { return 1;}
	if ($text eq "checked") { return 1;}
	if ($text eq "select") { return 1;}
	if ($text eq "selected") { return 1;}
	return undef;
}

####################################################
# is_disabled - tries to detect if a string says 'True'
####################################################
sub is_disabled
{ 
	my ($text) = @_;
	if (! $text) { return 1;} 
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


######################################################
# Returns a value if str2 is the at the beginning of str1
######################################################

sub begins_with
{	
		
    return substr($_[0], 0, length($_[1])) eq $_[1];
}		

######################################################
# Returns a string with the current time
# Parameter is format:
#		'hr' or (empty)		human readable 21.12.2017 19:32:11
#		'file'				filename ready 20171221_193211
#		'iso'				ISO 8601 but it is not real ISO as the time is not UTC but local time YYYY-MM-DDThh:mm:ssTZD
#####################################################
sub currtime
{
	my ($format) = @_;
	my $timestr;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	$year += 1900;
	$mon++;
	if (!$format || $format eq 'hr') {
		$timestr = sprintf("%02d.%02d.%04d %02d:%02d:%02d", $mday, $mon, $year, $hour, $min, $sec);
	}
	elsif ($format eq 'hrtime') {
		$timestr = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
	} 
	elsif ($format eq 'hrtimehires') {
		require Time::HiRes;
		my (undef, $nsec) = Time::HiRes::gettimeofday();
		$timestr = sprintf("%02d:%02d:%02d.%03d", $hour, $min, $sec, $nsec/1000);
	} 
	elsif ($format eq 'file') {
		$timestr = sprintf("%04d%02d%02d_%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec);
	} 
	elsif ($format eq 'filehires') {
		require Time::HiRes;
		my (undef, $nsec) = Time::HiRes::gettimeofday();
		$timestr = sprintf("%04d%02d%02d_%02d%02d%02d_%03d", $year, $mon, $mday, $hour, $min, $sec, $nsec/1000);
	}
	
	elsif ($format eq 'iso') {
		$timestr = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year, $mon, $mday, $hour, $min, $sec);
	}
	
	return $timestr;

	# my $iso = $now->format_cldr("yyyy-MM-dd'T'HH:mm:ss") . sprintf("%04d", ($hour - $now->hour));
	# print $iso . "\n";

}
######################################################
# check_securepin
# Parameter is the entered secure pin
# Returns 0 or undef if successful, or an error code if not ok
# Error code 1 is 
#####################################################

sub check_securepin
{
	my ($securepin) = shift;
	
	open (my $fh, "<" , "$LoxBerry::System::lbsconfigdir/securepin.dat") or 
		do {
			Carp::carp("check_securepin: Cannot open $LoxBerry::System::lbsconfigdir/securepin.dat\n");
			return (2);
			};
	my $securepinsaved = <$fh>;
	close ($fh);

	if (crypt($securepin, $securepinsaved) ne $securepinsaved) {
			# Not equal
			return (1);
	} else {
			# OK
			return (undef);
	}
}

#########################################################
sub reboot_required
{
	my ($message) = shift;
	open(my $fh, ">>", $LoxBerry::System::reboot_required_file) or Carp::carp "Cannot open/create reboot.required file $reboot_required_file.";
	flock($fh,2);
	if (! $message) {
		print $fh "A reboot was requested by $0\n";
	} else {
		print $fh "$message\n";
	}
	flock($fh,8);
	close $fh;
	eval {
		my ($login,$pass,$uid,$gid) = getpwnam("loxberry");
		chown $uid, $gid, $LoxBerry::System::reboot_required_file;
		};
}

sub diskspaceinfo
{
	my ($folder) = shift;
	
	my $output;
	$output = qx ( df -P "$folder" ) if ($folder);
	$output = qx ( df -P ) if (!$folder);
	
	# my $output = qx ( df -P );
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		print STDERR "diskspaceinfo: Error calling df with path $folder.\n";
		return undef;
	}
	my @outarr = split(/\n/, $output);
	my %disklist;
	
	my $linenr = 0;
	foreach my $line (@outarr) {
		my %diskhash;
		$linenr++;
		next if ($linenr == 1);
		
		# Find first double-blank
		my $dblblanc = index($line, '  ');
		my $fs = substr($line, 0, 	$dblblanc);
		# print STDERR "FS: $fs\n";
		# Remove fs from line
		$line = trim(substr($line, $dblblanc));
		# Remove other blanks
		$line =~ s/ +/ /g;
		# print STDERR "Line: '$line'\n";
		my ($size, $used, $available, $usedpercent, $mountpoint) = split (/ /, $line);
		$diskhash{filesystem} = $fs;
		$diskhash{size} = $size;
		$diskhash{used} = $used;
		$diskhash{available} = $available;
		$diskhash{usedpercent} = $usedpercent;
		$diskhash{mountpoint} = $mountpoint;
		return %diskhash if ($folder);
		$disklist{$mountpoint} = \%diskhash;
		
	}
	return %disklist;
	}


#########################################################
# File locking features
# To keep LoxBerry consistent 
#########################################################
	
######################################
# lock a file
# Parameter: [lockfile => $name]
# 			 [wait => $timesecs]
# Returns undef if ok
# Returns lock reason string if not ok
######################################

sub lock 
{
	
	my %p = @_;	
	
	if ($p{wait} && $p{wait} < 5) {
		print STDERR "Setting wait to 5\n" if ($DEBUG);
		$p{wait} = 5;
	}
		
	print STDERR "lock: file $p{lockfile} wait $p{wait}\n"  if ($DEBUG);
	
	# Read important lock files list
	my $importantlockfilesfile = "$LoxBerry::System::lbsconfigdir/lockfiles.default";
	my $openerr;
	open(my $fh, "<", $importantlockfilesfile) or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening important lock files file  $importantlockfilesfile";
		return "Error opening important lock files list";
		}
	my @data = <$fh>;
	close $fh;
	
	push (@data, $p{lockfile}) if $p{lockfile};
	
	my $seemsrunning;
	my $delay = 0;
	my $lockfilename;
	do {
		$seemsrunning = 0;
		print STDERR "running loop delay $delay from $p{wait}\n" if ($DEBUG);
		foreach my $lockfile (@data) {
			my $pid;
			$lockfile = LoxBerry::System::trim($lockfile);
			$lockfilename = "/var/lock/$lockfile.lock";
			print STDERR "Current: $lockfile ($lockfilename)\n"  if ($DEBUG);
			print STDERR "    Skipping $lockfile (not existent)\n" if (! -e $lockfilename && $DEBUG);
			next if (! -e $lockfilename);
			
			print STDERR "    Reading $lockfilename\n"  if ($DEBUG);
			open my $file, '<', $lockfilename; 
			$pid = LoxBerry::System::trim(<$file>); 
			close $file;
			print STDERR "    Content is $pid\n"  if ($DEBUG);
			if (! $pid) {
				# PID file is empty
				print STDERR "    PID-File is empty - trying to delete file\n"  if ($DEBUG);
				my $unlockstatus = LoxBerry::System::unlock( 'lockfile' => $lockfile );
				if ($unlockstatus) {
					print STDERR "    Could not unlock file\n"  if ($DEBUG);
					$seemsrunning = $lockfile;
					return "$lockfile: Cannot unlock $p{lockfile}" if (! $p{wait});
				} else {
					print STDERR "    Orphaned lock file deleted\n"  if ($DEBUG);
					next;
				}
			} elsif (-d "/proc/$pid") {
				# PID is running
				print STDERR "    PID $pid is running\n" if ($DEBUG);
				return $lockfile if ( ! $p{wait} );
				$seemsrunning = $lockfile;
			} else {
				# PID is NOT running
				print STDERR "    $pid not running - unlocking orphaned lock" if ($DEBUG);
				my $unlockstatus = LoxBerry::System::unlock( 'lockfile' => $lockfile );
				if ($unlockstatus) {
					print STDERR "    Could not unlock file\n"  if ($DEBUG);
					$seemsrunning = $lockfile;
					return "$lockfile: Cannot unlock $p{lockfile}" if (! $p{wait});
				} else {
					print STDERR "    Orphaned lock file deleted\n"  if ($DEBUG);
					next;
				}
			}
			print STDERR "Seemsrunning: $seemsrunning // pwait: $p{wait} // delay: $delay\n" if ($DEBUG);
			if ($seemsrunning && $p{wait}) {
				print STDERR "Waiting..." if ($DEBUG);
				sleep(5);
				$delay += 5;
			}
			
		}
	print "seemsrunning: $seemsrunning\n";
	} while ($seemsrunning && $p{wait} && $delay < $p{wait});
	return $seemsrunning if ($seemsrunning);
	
	# Set own lockfile
	if ($p{lockfile}) {
		$seemsrunning = 0;
		$lockfilename = "/var/lock/$p{lockfile}.lock";
		print STDERR "Other tests ok - Locking $p{lockfile} ($lockfilename) \n" if ($DEBUG);				
		#my $pidfile = File::Pid->new( { file => $lockfilename } );
		
		do {
			print STDERR "running loop delay $delay from $p{wait}\n" if ($DEBUG);
			print STDERR "    Open $p{lockfile} for writing\n" if ($DEBUG);
			print STDERR "    My PID is $$\n" if ($DEBUG);

			eval {
				open my $file, '>', $lockfilename; 
				print $file "$$"; 
				close $file;
			};  
			if ($@) {
				# Error writing the PID
				print STDERR "    Error writing PID file: $@\n" if ($DEBUG);
				$seemsrunning = 1;
				return "$p{lockfile}: $@" if ( ! $p{wait} );
			} else {
				# Writing was ok
				print STDERR "    Lock file successfully created.\n" if ($DEBUG);
				print STDERR "    Changing permissions to 0666\n" if ($DEBUG);
				eval {
					my ($login,$pass,$uid,$gid) = getpwnam("loxberry");
					chown $uid, $gid, $lockfilename;
					chmod 0666, $lockfilename;
					};
				print STDERR "    Could not change permissions (but lock file was created)\n" if ($@ && $DEBUG);
				print STDERR "Lock is set - returning undef to indicate success\n" if ($DEBUG);
				return undef;
			}
			sleep(5) if ( ! $p{wait} );
			$delay += 5;
		} while ($delay < $p{wait});
		return $p{lockfile};
	}
	
	return undef;
}

######################################
# unlock a file
# Parameter: lockfile => $name
# Returns undef if ok
# Returns reason as string if not ok
######################################
sub unlock
{
	
	my %p = @_;

	print STDERR "unlock: file $p{lockfile}\n"  if ($DEBUG);
	my $lockfilename = "/var/lock/$p{lockfile}.lock";
	if (-e $lockfilename) {
		my $unlinkstatus = unlink $lockfilename;
		if (! $unlinkstatus) {
			print STDERR "    Cannot delete lock file: $!\n"  if ($DEBUG);
			return "$p{lockfile}: Cannot delete lock file - $!";
		} else {
			print STDERR "    Lock file deleted\n" if ($DEBUG);
			return;
		}
	}
}

sub vers_tag
{
	my ($vers, $reverse) = @_;
	$vers = lc(LoxBerry::System::trim($vers));
	$vers = "v$vers" if (substr($vers, 0, 1) ne 'v' && ! $reverse);
	$vers = substr($vers, 1) if (substr($vers, 0, 1) eq 'v' && $reverse);
	
	return $vers;

}

sub bytes_humanreadable
{
	my ($size, $inputfactor) = @_;
	
	my $outputfactor;
	
	$inputfactor = uc($inputfactor);
	$size = $size*1024 if ($inputfactor eq 'K');
	$size = $size*1024*1024 if ($inputfactor eq 'M');
	$size = $size*1024*1024*1024 if ($inputfactor eq 'G');
	$size = $size*1024*1024*1024*1024 if ($inputfactor eq 'T');
	
	if ($size > (1024*1024*1024*1024)) {
		$outputfactor = "T";
		$size = $size/1024/1024/1024/1024;
		
	} elsif ($size > (1024*1024*1024)) {
		$outputfactor = "G";
		$size = $size/1024/1024/1024;
	} elsif ($size > (1024*1024)) {
		$outputfactor = "M";
		$size = $size/1024/1024;
	} elsif ($size > (1024)) {
		$outputfactor = "K";
		$size = $size/1024;
	} else {
		$outputfactor = "";
	}

	my $outstring = sprintf "%.1f", $size;
	$outstring .= $outputfactor . "B";
	return $outstring;
	
}

sub read_file
{
	my ($filename) = @_;
	local $/=undef;
	open FILE, $filename or return undef;
	my $string = <FILE>;
	close FILE;
	return $string;
}


#####################################################
# Finally 1; ########################################
#####################################################
1;

=head1 EXCEPTION HANDLING

All functions usually return undef if an error occurs, nothing was found or the input parameters are out of scope. You have to handle this is your plugin. Functions may inform in STDERR about warnings and errors.

=head1 SEE ALSO

Further features especially for language and HTML support are found in LoxBerry::Web.

=cut
