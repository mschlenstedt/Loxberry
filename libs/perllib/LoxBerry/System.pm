# Please increment version number on EVERY change 
# Major.Minor represents LoxBerry version (e.g. 0.3.1.12 = LoxBerry V0.3.1 the 12th change)

use strict;
use Config::Simple;
use URI::Escape;
use Cwd 'abs_path';
use Carp;
use Sys::Hostname;

package LoxBerry::System;
our $VERSION = "2.0.0.7";
our $DEBUG;

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
	$lbstmpfslogdir
	$lbsconfigdir
	$lbssbindir
	$lbsbindir
		
	is_enabled 
	is_disabled
	begins_with
	execute
	trim 
	ltrim
	rtrim
	currtime
	epoch2lox
	lox2epoch
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

=item 2. If username is loxberry -> HomeDir

=item 3. Static -> /opt/loxberry

=back

=cut

##################################################################
# This code is executed on every use
##################################################################

print STDERR "=== " . currtime('hr') . " === DEBUG ENABLED (executing $0) =======================\n" if ($DEBUG);

# Set global variables

# Get LoxBerry home directory
our $lbhomedir;
if ($ENV{LBHOMEDIR}) {
	$lbhomedir = $ENV{LBHOMEDIR};
	print STDERR "lbhomedir $lbhomedir detected by environment\n" if ($DEBUG);
} else {
	require File::HomeDir;
	my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
	if ($username eq 'loxberry') {
		$lbhomedir = File::HomeDir->my_home;
		print STDERR "lbhomedir $lbhomedir detected by loxberry HomeDir\n" if ($DEBUG);
	} elsif ($username eq 'root') {
		$lbhomedir = `su - loxberry -c pwd`;
		$lbhomedir =~ s/\n|\s+//;
		print STDERR "lbhomedir $lbhomedir detected as user root by loxberry's pwd HomeDir\n" if ($DEBUG);
	} else {
		# Missing some additional functions if we are running from daemon or cron
		$lbhomedir = '/opt/loxberry';
		print STDERR "lbhomedir $lbhomedir set to /opt/loxberry as fallback\n" if ($DEBUG);
		Carp::carp ("LoxBerry home was statically set to /opt/loxberry as no home directory could be found.");
	}
}

my $abspath;
our $lbpplugindir;

if ($ENV{SCRIPT_FILENAME}) { 
		$abspath = Cwd::abs_path($ENV{SCRIPT_FILENAME});
	} elsif ($0) {
		$abspath = Cwd::abs_path($0);
	}

print STDERR "Script call \$0 is $0 abspath is $abspath\n" if ($DEBUG);
my $lbhomedirlength = length($lbhomedir);

my $rindex = rindex($abspath, ".");
print STDERR "rindex is $rindex\n" if ($DEBUG);
$rindex = length($abspath) if ($rindex < 0);

my $part = substr ($abspath, ($lbhomedirlength+1), $rindex-$lbhomedirlength-1);

print STDERR "part is $part\n" if ($DEBUG);

my ($p1, $p2, $p3, $p4, $p5, $p6) = split(/\//, $part);
if ($DEBUG) {
	print STDERR "P1 = $p1\n" if ($p1);
	print STDERR "P2 = $p2\n" if ($p2);
	print STDERR "P3 = $p3\n" if ($p3);
	print STDERR "P4 = $p4\n" if ($p4);
	print STDERR "P5 = $p5\n" if ($p5);
	print STDERR "P6 = $p6\n" if ($p6);
}

if 		($p1 eq 'webfrontend' && $p3 eq 'plugins' && $p4 )  { $lbpplugindir = $p4; }
elsif 	($p1 eq 'templates' && $p2 eq 'plugins' && $p3 ) { $lbpplugindir = $p3; }
elsif	($p1 eq 'log' && $p2 eq 'plugins' && $p3 ) { $lbpplugindir = $p3; }
elsif	($p1 eq 'data' && $p2 eq 'plugins' && $p3 ) { $lbpplugindir = $p3; }
elsif	($p1 eq 'config' && $p2 eq 'plugins' && $p3 ) { $lbpplugindir = $p3; }
elsif	($p1 eq 'bin' && $p2 eq 'plugins' && $p3 ) { $lbpplugindir = $p3; }
elsif	($p1 eq 'system' && $p2 eq 'daemons' && $p3 eq 'plugins' && $p4 ) { $lbpplugindir = $p4; }

if ($lbpplugindir) {
	# our ($lbpplugindir) = (split(/\//, $part))[3];
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
our $lbstmpfslogdir = "$lbhomedir/log/system_tmpfs";
our $lbsconfigdir = "$lbhomedir/config/system";
our $lbssbindir = "$lbhomedir/sbin";
our $lbsbindir = "$lbhomedir/bin";

our %SL; # Shortcut for System language phrases
our %L;  # Shortcut for Plugin language phrases
our $reboot_required_file = "$lbstmpfslogdir/reboot.required";
our $reboot_force_popup_file = "$lbstmpfslogdir/reboot.force";
our $PLUGINDATABASE = "$lbsdatadir/plugindatabase.json";

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
my $plugindb_timestamp = 0;
my $plugindb_timestamp_last = 0;
my $plugindb_lastchecked = 0;

my $webserverport;
my $clouddnsaddress;
my $msClouddnsFetched;
my $sysloglevel;



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
	my ($withcomments_obsolete, $forcereload, $plugindb_file_obsolete) = @_;
	
	# withcomments parameter is legacy for LoxBerry 1.x and not used.
	if( defined $withcomments_obsolete ) {
		Carp::carp "<INFO> get_plugins first parameter (withcomments) is outdated and ignored";
	}
	# $plugindb_file parameter is not allowed anymore
	if (defined $plugindb_file_obsolete) {
		Carp::croak "<ERROR> get_plugins third parameter (plugindb_file) is outdated and not allowed anymore. To read a custom plugindatabase, use LoxBerry::System::PluginDB instead.";
	}
	
	my $plugindb_file = $PLUGINDATABASE;
	
	# When the plugindb has changed, always force a reload of the plugindb
	if($plugindb_timestamp_last != plugindb_changed_time()) {
			# Changed
			my $plugindb_timestamp_new = plugindb_changed_time();
			$forcereload = 1;
			print STDERR "get_plugins: Plugindb timestamp has changed (old: $plugindb_timestamp_last new: $plugindb_timestamp_new)\n" if ($DEBUG);
			$plugindb_timestamp_last = $plugindb_timestamp_new;
		}
		
	if (@plugins && !$forcereload && !$plugins_delcache) {
		print STDERR "get_plugins: Returning cached version of plugindatabase\n" if ($DEBUG);
		return @plugins;
	} else {
		print STDERR "get_plugins: Re-reading plugindatabase\n" if ($DEBUG);
	}
	
	print STDERR "get_plugins: Using file $plugindb_file\n" if ($DEBUG);
	
	require JSON;
	my $plugindbdata;
	eval {
		$plugindbdata = JSON::from_json( LoxBerry::System::read_file( $LoxBerry::System::PLUGINDATABASE ) );
	};
	if ($@) {
		Carp::carp "LoxBerry::System::get_plugins: Could not read $plugindb_file\n";
		return;
	}
	
	# my $plugindbobj = LoxBerry::JSON->new();
	# my $plugindbdata = $plugindbobj->open(filename => $plugindb_file, readonly => 1);
		
	@plugins = ();
	my $plugincount = 0;
	
	foreach my $pluginkey ( sort { lc $plugindbdata->{plugins}->{$a}->{title} cmp lc $plugindbdata->{plugins}->{$b}->{title} } keys %{$plugindbdata->{plugins}} ){
		my $plugindata = $plugindbdata->{plugins}->{$pluginkey};
		my %plugin;
		$plugincount++;
		
		$plugin{PLUGINDB_NO} = $plugincount;
		$plugin{PLUGINDB_MD5_CHECKSUM} = $plugindata->{md5};
		$plugin{PLUGINDB_AUTHOR_NAME} = $plugindata->{author_name};
		$plugin{PLUGINDB_AUTHOR_EMAIL} = $plugindata->{author_email};
		$plugin{PLUGINDB_VERSION} = $plugindata->{version};
		$plugin{PLUGINDB_NAME} = $plugindata->{name};
		$plugin{PLUGINDB_FOLDER} = $plugindata->{folder};
		$plugin{PLUGINDB_TITLE} = $plugindata->{title};
		$plugin{PLUGINDB_INTERFACE} = $plugindata->{interface};
		$plugin{PLUGINDB_AUTOUPDATE} = $plugindata->{autoupdate};
		$plugin{PLUGINDB_RELEASECFG} = $plugindata->{releasecfg};
		$plugin{PLUGINDB_PRERELEASECFG} = $plugindata->{prereleasecfg};
		$plugin{PLUGINDB_LOGLEVEL} = $plugindata->{loglevel};
		$plugin{PLUGINDB_LOGLEVELS_ENABLED} = $plugindata->{loglevel} >= 0 ? 1 : 0;
		$plugin{PLUGINDB_ICONURI} = "/system/images/icons/$plugin{PLUGINDB_FOLDER}/icon_64.png";
		push(@plugins, \%plugin);
		# On changes of the plugindatabase format, please change here 
		# and in libs/phplib/loxberry_system.php / function get_plugins
	}
	return @plugins;

}

##################################################################################
# INTERNAL function plugindb_changed
# Returns the timestamp of the plugindb. Only really checks every minute
##################################################################################

sub plugindb_changed_time
{
	
	# If it was never checked, it cannot have changed
	if ($plugindb_timestamp == 0 or $plugindb_lastchecked+60 < time) {
		$plugindb_timestamp = (stat $PLUGINDATABASE)[9];
		$plugindb_lastchecked = time;
		print STDERR "Updating plugindb timestamp variable to $plugindb_timestamp\n" if ($DEBUG);
	}
	
	return $plugindb_timestamp;	

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
	
	require LoxBerry::JSON;
	my $memfile = "$lbhomedir/log/system_tmpfs/clouddns_cache.json";
	my $jsonobj = LoxBerry::JSON->new();
	my $cache = $jsonobj->open(filename => $memfile);
	my $cachekey = $miniservers{$msnr}{CloudURL};
		
	if(
		defined $cache->{$cachekey}->{refresh_timestamp} and 
		$cache->{$cachekey}->{refresh_timestamp} > time and
		defined $cache->{$cachekey}->{IPAddress} #and 
		#defined $cache->{$msnr}->{Port}
	) {
		print STDERR "Reading data from cachefile $memfile\n" if ($DEBUG);
		$miniservers{$msnr}{IPAddress} = $cache->{$cachekey}->{IPAddress};
		$miniservers{$msnr}{Port} = $cache->{$cachekey}->{Port};
		return;
	}
	
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	
	print STDERR "Reading data online from CloudDNS\n" if ($DEBUG);
		
	$ua->timeout(5);
	$ua->max_redirect( 0 );
	my $checkurl = "http://$clouddnsaddress?getip&snr=" . $miniservers{$msnr}{CloudURL}."&json=true";
	my $resp 	 = $ua->get($checkurl);
	if (! $resp->is_success ) 
	{
		$miniservers{$msnr}{IPAddress} = "0.0.0.0";
		$miniservers{$msnr}{Port} = "0";
		delete $cache->{$cachekey};
		$jsonobj->write();
		
		require Time::Piece;
		my $t = Time::Piece->localtime;
		print STDERR $t->strftime("%Y-%m-%d %H:%M:%S")." System.pm: Timeout when reading IP and Port from $checkurl \n";
	}
	else
	{
		my $respjson = JSON::decode_json($resp->content);
		($miniservers{$msnr}{IPAddress}, $miniservers{$msnr}{Port}) = split(/:/, $respjson->{IP}, 2);
		my %cachehash;
		$cachehash{IPAddress} = $miniservers{$msnr}{IPAddress};
		$cachehash{Port} = $miniservers{$msnr}{Port};
		$cachehash{refresh_timestamp} = time + 3600 + int(rand(3600));
		$cache->{$cachekey} = \%cachehash;
		$jsonobj->write();
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
	if (!$text) { return undef;} 
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
	if (!$text) { return 1;} 
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
# Converts an Epoche (Unix Timestamp, seconds from 1.1.1970 00:00:00 UTC) to Loxone Epoche (seconds from 1.1.2009 00:00:00)
#####################################################
sub epoch2lox
{
	my ($epoche) = @_;
	if (!$epoche) {
		$epoche = time();
	}
	my $offset = "1230764400"; # 1.1.2009 00:00:00
	my $tz_delta = tz_offset();
	my $loxepoche = $epoche - $offset + $tz_delta - 3600;

	return $loxepoche;

}

######################################################
# Converts an Loxone Epoche (seconds from 1.1.2009 00:00:00) to Epoche (Unix Timestamp, seconds from 1.1.1970 00:00:00 UTC)
#####################################################
sub lox2epoch
{
	my ($loxepoche) = @_;
	my $epoche;
		
	if (!$loxepoche) {
		# For compatibility reasons to epoch2lox - but makes no sense here...
		$epoche = time();
	} else {
		my $offset = "1230764400"; # 1.1.2009 00:00:00
		my $tz_delta = tz_offset();
		$epoche = $loxepoche + $offset - $tz_delta + 3600;
	}
	return $epoche;

}

# INTERNAL FUNCTION
# Returns the delta of local time to 
sub tz_offset
{
    my @l = localtime();
    my @g = gmtime();

    my $minutes = ($l[2] - $g[2] + ((($l[5]<<9)|$l[7]) <=> (($g[5]<<9)|$g[7])) * 24) * 60 + $l[1] - $g[1];
    return $minutes*60;
    
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
	
	my $pinerror_file = "$lbhomedir/log/system_tmpfs/securepin.errors";
	my $pinerrobj;
	my $pinerr;
	
	open (my $fh, "<" , "$LoxBerry::System::lbsconfigdir/securepin.dat") or 
		do {
			Carp::carp("check_securepin: Cannot open $LoxBerry::System::lbsconfigdir/securepin.dat\n");
			return (2);
			};
	my $securepinsaved = <$fh>;
	close ($fh);

	# In case we have an active SupportVPN connmection
	my $securepinsavedsupportvpn;;
	if (-e "$LoxBerry::System::lbsconfigdir/securepin.dat.supportvpn") {
		# Check Online Status
		use Net::Ping;
		for (my $i=0; $i < 3; $i++) {
			my $p = Net::Ping->new();
			my $hostname = '10.98.98.1';
			my ($ret, $duration, $ip) = $p->ping($hostname);
			if (!$ret) {
			sleep (1);
				next;
			} else {
				open (my $fh, "<" , "$LoxBerry::System::lbsconfigdir/securepin.dat.supportvpn"); 
				$securepinsavedsupportvpn = <$fh>;
				close ($fh);
				last;
			}
		}
	}
	
	if (-e $pinerror_file) {
		require LoxBerry::JSON;
		$pinerrobj = LoxBerry::JSON->new();
		$pinerr = $pinerrobj->open(filename => $pinerror_file);
		
		if ( $pinerr and $pinerr->{locked} ) {
			if( time < ($pinerr->{locked}+5*60) ) {
				print STDERR "SecurePIN is locked";
				sleep(3);
				return (3);
			} else {
				delete $pinerr->{locked};
				delete $pinerr->{failure_count};
				
			}
		}
		$pinerrobj->write();
		undef $pinerrobj;
	}
	
	if ( crypt($securepin, $securepinsaved) eq $securepinsaved || crypt($securepin, $securepinsavedsupportvpn) eq $securepinsavedsupportvpn ) {
		# OK
		unlink $pinerror_file;
		return (undef);
	} else {
		# Not equal
		require LoxBerry::JSON;
		$pinerrobj = LoxBerry::JSON->new();
		$pinerr = $pinerrobj->open(filename => $pinerror_file, writeonclose => 1);
		$pinerr->{failure_count} = 0 if (! $pinerr->{failure_count});
		sleep($pinerr->{failure_count});
		$pinerr->{failure_count} += 1;
		
		$pinerr->{failure_time} = time if (! $pinerr->{failure_time});
		if( $pinerr->{failure_count} > 5) {
			print STDERR "SecurePIN was locked";
			$pinerr->{locked} = time;
			return (3);
		}
		return (1);
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

sub reboot_force
{
	my ($message) = shift;
	open(my $fh, ">>", $LoxBerry::System::reboot_force_popup_file) or Carp::carp "Cannot open/create reboot.force file $reboot_force_popup_file.";
	flock($fh,2);
	if (! $message) {
		print $fh "A reboot is necessary to continue updates.";
	} else {
		print $fh "$message";
	}
	flock($fh,8);
	close $fh;
	eval {
		my ($login,$pass,$uid,$gid) = getpwnam("loxberry");
		chown $uid, $gid, $LoxBerry::System::reboot_force_popup_file;
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
		Carp::carp "Error opening important lock files file $importantlockfilesfile";
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
		
		# Check for apt-get and dpkg updates running
		# pgrep: Exitcode 1 -> not found. 0 -> found
		
		my $rc_apt;
		my $rc_dpkg;
		($rc_apt) = LoxBerry::System::execute( 'pgrep apt-get' );
		($rc_dpkg) = LoxBerry::System::execute( 'pgrep dpkg' );
		if( $rc_apt eq "0" or $rc_dpkg eq "0") {
			$seemsrunning = 'apt-get' if ($rc_apt eq "0");
			$seemsrunning = 'dpkg' if ($rc_dpkg eq "0");
		
			if ($p{wait}) {
				print STDERR "Waiting..." if ($DEBUG);
				sleep(5);
				$delay += 5;
			}
		} 
		
		# Check for lock files
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
	print STDERR "seemsrunning: $seemsrunning\n" if ($DEBUG);
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

# Exec a shell command, return exitcode and output
sub execute
{
	my @params = @_;
	my $log;
	my $uselog;
	my $command;
	my %arghash;
	my $args = \%arghash;
		
	# Check command parameter
	
	print STDERR "execute: Number of params: " . scalar @params . "\n" if ($DEBUG);
	print STDERR "execute: Ref of first param: " . ref($params[0]) . "\n" if ($DEBUG);
		
	if( scalar @params == 1 and ref($params[0]) eq "" ) {
		print STDERR "execute: Parameter was a string and will be used as command\n" if ($DEBUG);
		$args->{command} = $params[0];
	} elsif ( scalar @params == 1 and ref($params[0]) eq "HASH" ) {
		print STDERR "execute: Parameter was a hash\n" if ($DEBUG);
		$args = $params[0];
	} elsif ( scalar @params > 1 and scalar(@params)%2 == 0 ) {
		print STDERR "execute: Parameter was an array\n" if ($DEBUG);
		%arghash = @params;
	} elsif ( scalar @params > 1 and scalar(@params)%2 == 1 ) {
		Carp::croak("execute: Uneven number of arguments");
	} else {
		Carp::croak("execute: Unknown type of arguments.");
	}
	
	if ( !defined $args->{command} ) {
		Carp::croak("execute: Argument command missing");
	} else {
		$command = $args->{command};
	}
	
	# Check log parameter
	if( ref($args) and $args->{log}) {
		print STDERR "execute: log argument given\n" if ($DEBUG);
		$uselog = 1;
		
		# Test the log object
		require LoxBerry::Log;
		$log = $args->{log};
		eval {
			$log->loglevel();
		};
		if($@) {
			# No log object present
			print STDERR "execute: Warning: Parameter log given, but log not defined.\n";
			$uselog = 0;
		}
	}
		
	if($uselog) {
		# Define default values
		$args->{intro} = "Executing command '$command'..." if( !defined $args->{intro} ); 
		$args->{ok} = "Command executed successfully." if( !defined $args->{ok} ); 
		$args->{error} = "ERROR executing command"  if( !defined $args->{error} and !defined $args->{warn} );
		$args->{okcode} = 0 if( !defined $args->{okcode} );

		# Log intro
		$log->INF($args->{intro});
	}
		
	my $output = qx { $command };
	my $exitcode  = $? >> 8;
	
	# All of the following code is only relevant if something needs to be logged
	if($uselog) {
		if( $exitcode eq $args->{okcode} ) {
			# OK
			$log->OK( $args->{ok} . " - Exitcode $exitcode");
		} else {
			# Not OK
			if( defined $args->{warn} ) {
				$log->WARN( $args->{warn} . " - Exitcode $exitcode" );
			} else {
				$log->ERR( $args->{error} . " - Exitcode $exitcode" );
			}
			$log->DEB ( $output );
		}
	}
	
	return ($exitcode, $output);

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
