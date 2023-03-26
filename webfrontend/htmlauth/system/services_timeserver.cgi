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
our $zeitserver;
our $ntpserverurl;
our $zeitzone;
our $checked1;
our $checked2;
our $datebin;
our $systemdatetime;
our $ntpdate;
our $awkbin;
our $grepbin;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "2.0.2.3";

my $cgi = CGI->new;
$cgi->import_names('R');
$R::saveformdata if 0;
$R::ntpserverurl if 0;
$R::zeitserver if 0;
$R::zeitzone if 0;
$R::do if 0;

my $jsonobj = LoxBerry::System::General->new();
my $cfg = $jsonobj->open();

$zeitserver = $cfg->{Timeserver}->{Method};
$ntpserverurl = $cfg->{Timeserver}->{Ntpserver};
$zeitzone = $cfg->{Timeserver}->{Timezone};

my $bins = LoxBerry::System::get_binaries();
$datebin = $bins->{DATE};
$ntpdate = $bins->{NTPDATE};
$awkbin = $bins->{AWK};
$grepbin = $bins->{GREP};

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

# Just for testing via: http://loxberry/admin/system/timeserver.cgi?do=query
if ( $do eq "query" ) 
{
  print "Content-Type: text/plain\n\n";
  if ( $zeitserver eq "ntp" )
  {
  	print `$ntpdate -q $ntpserverurl 2>&1| $grepbin ntp | $awkbin '{for (I=1;I<=NF;I++) if (\$I == "offset") {print \$(I+1)};}'`;
  }
  else
  {
	print "Miniserver configured. No NTP-Query done.";
  }
  exit;
}

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

	# Defaults for template
	if ($zeitserver eq "ntp") {
	  $checked2 = 'checked="checked"';
	  $maintemplate->param("CHECKED2", $checked2);
	  
	} else {
	  $checked1 = 'checked="checked"';
	  $maintemplate->param("CHECKED1", $checked1);
	}

	$maintemplate->param("MSSELECTLIST", mslist_select_html( FORMID => 'msno', SELECTED => $cfg->{Timeserver}->{Timemsno} ) );
	
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
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'TIMESERVER.WIDGETLABEL'};
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
	$zeitserver   = $R::zeitserver;
	$ntpserverurl = $R::ntpserverurl;
	$zeitzone     = $R::zeitzone;
	my $msno 	  = $R::msno;

	# Test if NTP-Server is reachable
	our $ntp_check="0"; 
	if ( $zeitserver eq "ntp" )
	{
	 $ntp_check = system("$ntpdate -q $ntpserverurl >/dev/null 2>&1");
	}
	# Error if we can't get time
	if ($ntp_check) {
	  $error = $SL{'TIMESERVER.ERR_NTP_UNREACHABLE'};
	  &error;
	  exit;
	}

	# Check if the timezone was changed
	my $tzchanged;
	$tzchanged = 1 if ( $cfg->{Timeserver}->{Timezone} ne $zeitzone );
	
		
	# Write configuration file(s)
	$cfg->{Timeserver}->{Ntpserver} = trim($ntpserverurl);
	$cfg->{Timeserver}->{Method} = trim($zeitserver);
	$cfg->{Timeserver}->{Timezone} = trim($zeitzone);
	$cfg->{Timeserver}->{Timemsno} = $msno;
	$jsonobj->write();
	
	# Trigger timesync
	my ($exitcode, $datetime_res) = LoxBerry::System::execute( "$lbhomedir/sbin/setdatetime.pl" );
	if ($exitcode != 0) {
		$error = LoxBerry::Web::logfile_button_html( LOGFILE => $lbstmpfslogdir."/setdatetime.log" );
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

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'TIMESERVER.WIDGETLABEL'};
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
# Error
#####################################################

sub error {

$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'TIMESERVER.WIDGETLABEL'};

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
