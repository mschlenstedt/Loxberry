#!/usr/bin/perl

# Copyright 2016-2020 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::System::General;
use LoxBerry::Web;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use LWP::UserAgent;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

our $helpurl = "https://wiki.loxberry.de/konfiguration/widget_help/widget_loxberry_services/system_time";
our $helptemplate ="help_timeserver.html";

our $lang="en";
our $template_title;
our $error;
our $saveformdata=0;
our $output;
our $message;
our $do="form";
our @lines;
our $timezonelist="";
our $timezones;
our $ntpserverurl;
our $zeitzone;
our $syncmode;
our $datebin;
our $systemdatetime;

# DietPi keeps the time in sync; its settings live in dietpi.txt (#1581)
my $dietpitxt = "/boot/dietpi.txt";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "4.0.1.0";

my $cgi = CGI->new;
$cgi->import_names('R');
$R::saveformdata if 0;
$R::ntpserverurl if 0;
$R::syncmode if 0;
$R::zeitzone if 0;
$R::do if 0;

my $jsonobj = LoxBerry::System::General->new();
my $cfg = $jsonobj->open();

# Show what is really in effect: server and sync mode from dietpi.txt,
# timezone from the system. general.json is the fallback.
my %dietpi = read_dietpitxt();
$ntpserverurl = $dietpi{CONFIG_NTP_MIRROR} // $cfg->{Timeserver}->{Ntpserver};
$syncmode = ( defined $dietpi{CONFIG_NTP_MODE} and $dietpi{CONFIG_NTP_MODE} =~ /^[1-4]$/ ) ? $dietpi{CONFIG_NTP_MODE} : 2;
$zeitzone = trim(qx(timedatectl show --property=Timezone --value 2>/dev/null)) || $cfg->{Timeserver}->{Timezone};

my $bins = LoxBerry::System::get_binaries();
$datebin = $bins->{DATE};

$do = "";

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/services_timeserver.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			# associate => $jsonobj,
			%htmltemplate_options,
			# debug => 1,
			);

my %SL = LoxBerry::System::readlanguage($maintemplate);

# Navbar
our %navbar;
$navbar{0}{Name} = "$SL{'SERVICES.TITLE_PAGE_WEBSERVER'}";
$navbar{0}{URL} = 'services.php?load=1';
$navbar{1}{Name} = "$SL{'SERVICES.TITLE_PAGE_WATCHDOG'}";
$navbar{1}{URL} = 'services_watchdog.cgi';
$navbar{4}{Name} = "$SL{'HEADER.PANEL_TIMESERVER'}";
$navbar{4}{URL} = 'services_timeserver.cgi';
$navbar{5}{Name} = "Samba (SMB)";
$navbar{5}{URL} = 'services_samba.cgi';
$navbar{4}{active} = 1;

$navbar{50}{Name} = "$SL{'SERVICES.TITLE_PAGE_OPTIONS'}";
$navbar{50}{URL} = 'services.php?load=3';



#########################################################################
# Parameter
#########################################################################

$do = $R::do;

$saveformdata = $R::saveformdata;

##########################################################################
# Language Settings
##########################################################################
$lang = lblanguage();
$maintemplate->param( "LBHOSTNAME", lbhostname());
$maintemplate->param( "LANG", $lang);
$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
if (!$saveformdata || $do eq "form") {
  print STDERR "Calling subfunction FORM\n";
  $maintemplate->param("FORM", 1);
  &form;
} else {
  print STDERR "Calling subfunction SAVE\n";
  $maintemplate->param("SAVE", 1);
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form {

	# Sync modes of DietPi (CONFIG_NTP_MODE). Mode 0 (no sync) is not offered:
	# a Raspberry Pi without RTC would start with a wrong time after every boot.
	my @syncmodes;
	foreach my $mode ( 1..4 ) {
		push @syncmodes, {
			VALUE => $mode,
			LABEL => $SL{"TIMESERVER.SYNC_MODE_$mode"},
			SELECTED => $mode == $syncmode ? 'selected="selected"' : '',
		};
	}
	$maintemplate->param("SYNCMODES", \@syncmodes);
	
	# Prepare Timezones
	$timezones = qx( timedatectl  list-timezones|grep Europe/; timedatectl  list-timezones|grep -v  Europe/) || die "Problem reading timezones";
    @lines = split(/\n/,$timezones);
	foreach (@lines){
	  s/[\n\r]//g;
	  if ($zeitzone eq $_) {
		$timezonelist = "$timezonelist<option selected=\"selected\" value=\"$_\">$_</option>\n";
	  } else {
		$timezonelist = "$timezonelist<option value=\"$_\">$_</option>\n";
	  }
	}
	
	# Create Date/Time for template
	if ($lang eq "de") {
	  $systemdatetime         = qx(LANG="de_DE" $datebin);
	} else {
	  $systemdatetime         = qx($datebin);
	}
	chomp($systemdatetime);

	$maintemplate->param("TIMEZONELIST", $timezonelist);
	$maintemplate->param("SYSTEMDATETIME", $systemdatetime);
	$maintemplate->param("NTPSERVERURL", $ntpserverurl);
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'SERVICES.WIDGETLABEL'};
	LoxBerry::Web::lbheader($template_title, $helpurl, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();

	exit;
}

#####################################################
# Save
#####################################################

sub save {

	# Everything from Forms
	my $oldserver = $ntpserverurl;
	my $newserver = join( ' ', split( ' ', $R::ntpserverurl // '' ) );
	my $newmode   = $R::syncmode // '';
	my $newzone   = trim( $R::zeitzone // '' );

	# Host names, IP addresses or the DietPi keywords default/gateway, separated
	# by spaces - settimeserver.sh checks the same
	if ( !$newserver or grep { !/^[A-Za-z0-9]([A-Za-z0-9.:-]*[A-Za-z0-9])?$/ } split( ' ', $newserver ) ) {
		$error = $SL{'TIMESERVER.MSG_VAL_INVALID_HOST'};
		&error;
		exit;
	}
	$newmode = 2 if ( $newmode !~ /^[1-4]$/ );

	# DietPi turns every entry ending in pool.ntp.org into the servers 0-3 of
	# that pool, so "0.pool.ntp.org" would become "0.0.pool.ntp.org"
	my @hosts;
	foreach my $host ( split( ' ', $newserver ) ) {
		$host =~ s/^\d+\.(.*pool\.ntp\.org)$/$1/;
		push @hosts, $host if ( !grep { $_ eq $host } @hosts );
	}
	$newserver = join( ' ', @hosts );

	# Check if the timezone was changed
	my $tzchanged;
	$tzchanged = 1 if ( $zeitzone ne $newzone );

	# Write configuration file - general.json still provides lbtimezone and the
	# legacy general.cfg
	my $oldjsonserver = $cfg->{Timeserver}->{Ntpserver};
	my $oldjsonzone = $cfg->{Timeserver}->{Timezone};
	$cfg->{Timeserver}->{Ntpserver} = $newserver;
	$cfg->{Timeserver}->{Method} = "ntp";
	$cfg->{Timeserver}->{Timezone} = $newzone;
	delete $cfg->{Timeserver}->{Timemsno};
	$jsonobj->write();

	# Hand the settings to DietPi and sync once
	my ($exitcode) = LoxBerry::System::execute( "sudo -n $lbhomedir/sbin/settimeserver.sh $newmode" );
	if ($exitcode != 0) {
		my $logbutton = LoxBerry::Web::logfile_button_html( LOGFILE => $lbstmpfslogdir."/settimeserver.log" );
		if ($exitcode == 2) {
			# The new server does not answer - settimeserver.sh changed nothing
			$cfg->{Timeserver}->{Ntpserver} = $oldjsonserver;
			$cfg->{Timeserver}->{Timezone} = $oldjsonzone;
			$jsonobj->write();
			$error = $SL{'TIMESERVER.ERR_SYNC_FAILED'};
			$error =~ s/%NEW%/$newserver/g;
			$error =~ s/%OLD%/$oldserver/g;
			$error .= " " . $logbutton;
		} else {
			$error = $logbutton;
		}
		&error;
		exit;
	}

	$output = qx($datebin);

	my $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/success.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $jsonobj,
				%htmltemplate_options,
				# debug => 1,
				);

	my %SL = LoxBerry::System::readlanguage($maintemplate);

	$message = "$SL{'TIMESERVER.SAVE_OK_SETTINGS_STORED'}<br>$output";
	
	if ($tzchanged) {
		reboot_required($SL{'TIMESERVER.MSG_TZCHANGED'});
		$message = $message . "<p>" . $SL{'TIMESERVER.MSG_TZCHANGED'} . "</p>";
	}

	$maintemplate->param("MESSAGE", $message);
	$maintemplate->param("NEXTURL", $ENV{REQUEST_URI});

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'SERVICES.WIDGETLABEL'};
	LoxBerry::Web::lbheader($template_title, $helpurl, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;
}

exit;

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Read the settings of dietpi.txt (KEY=VALUE lines)
#####################################################

sub read_dietpitxt {
	my %values;
	open( my $fh, '<', $dietpitxt ) or return %values;
	while ( my $line = <$fh> ) {
		next if ( $line =~ /^\s*#/ );
		if ( $line =~ /^\s*([A-Z0-9_]+)=(.*?)\s*$/ ) {
			$values{$1} = $2;
		}
	}
	close $fh;
	return %values;
}

#####################################################
# Error
#####################################################

sub error {

$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'SERVICES.WIDGETLABEL'};

	my $errtemplate = HTML::Template->new(
				filename => "$lbstemplatedir/error.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				# associate => $cfg,
				);
	print STDERR "services_timeserver.cgi: Sub ERROR called with message $error.\n";
	$errtemplate->param( "ERROR", $error);
	LoxBerry::System::readlanguage($errtemplate);
	LoxBerry::Web::lbheader($template_title, $helpurl, $helptemplate);
	print $errtemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}
