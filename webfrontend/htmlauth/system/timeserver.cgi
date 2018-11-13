#!/usr/bin/perl

# Copyright 2016-2017 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::Web;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use LWP::UserAgent;
use Config::Simple;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################


my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_timeserver.html";


our $cfg;
our $phrase;
our $namef;
our $value;
our %query;
our $lang;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $languagefile;
our $error;
our $saveformdata;
our $output;
our $message;
our $do;
my  $url;
my  $ua;
my  $response;
my  $urlstatus;
my  $urlstatuscode;
our @lines;
our $timezonelist;
our $timezones;
our $zeitserver;
our $ntpserverurl;
our $zeitzone;
our $checked1;
our $checked2;
our $nexturl;
our $datebin;
our $systemdatetime;
our $systemtimezone;
our $ntpdate;
our $awkbin;
our $grepbin;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.2.3.1";

$cfg                = new Config::Simple("$lbsconfigdir/general.cfg");

# $lang               = $cfg->param("BASE.LANG");
$zeitserver         = $cfg->param("TIMESERVER.METHOD");
$ntpserverurl       = $cfg->param("TIMESERVER.SERVER");
$zeitzone           = $cfg->param("TIMESERVER.ZONE");
$datebin            = $cfg->param("BINARIES.DATE");
$ntpdate            = $cfg->param("BINARIES.NTPDATE");
$awkbin             = $cfg->param("BINARIES.AWK");
$grepbin            = $cfg->param("BINARIES.GREP");
$do                 = "";
$helptext           = "";

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/timeserver.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $cfg,
			%htmltemplate_options,
			# debug => 1,
			);

my %SL = LoxBerry::System::readlanguage($maintemplate);


#########################################################################
# Parameter
#########################################################################

# Everything from URL
foreach (split(/&/,$ENV{'QUERY_STRING'})){
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# And this one we really want to use
$do           = $query{'do'};

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

# Everything we got from forms
$saveformdata         = param('saveformdata');

$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

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
  print STDERR "FORM called\n";
  $maintemplate->param("FORM", 1);
  &form;
} else {
  print STDERR "SAVE called\n";
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
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();

	exit;
}

#####################################################
# Save
#####################################################

sub save {

	# Everything from Forms
	$zeitserver   = param('zeitserver');
	$ntpserverurl = param('ntpserverurl');
	$zeitzone     = param('zeitzone');

	# Test if NTP-Server is reachable
	our $ntp_check="0"; 
	if ( ${zeitserver} eq "ntp" )
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
	$tzchanged = 1 if ($cfg->param("TIMESERVER.ZONE") ne $zeitzone);
	
		
	# Write configuration file(s)
	$cfg->param("TIMESERVER.SERVER", "$ntpserverurl");
	$cfg->param("TIMESERVER.METHOD", "$zeitserver");
	$cfg->param("TIMESERVER.ZONE", "$zeitzone");
	$cfg->save();

	# Trigger timesync
	$output = qx($lbhomedir/sbin/setdatetime.pl);
	$output = qx($datebin);


	my $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/success.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $cfg,
				%htmltemplate_options,
				# debug => 1,
				);

	my %SL = LoxBerry::System::readlanguage($maintemplate);



	# print "Content-Type: text/html\n\n";
	# $template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0021");
	# $help = "timeserver";

	$message = "$SL{'TIMESERVER.SAVE_OK_SETTINGS_STORED'}<br>$output";
	
	if ($tzchanged) {
		reboot_required($SL{'TIMESERVER.MSG_TZCHANGED'});
		$message = $message . "<p>" . $SL{'TIMESERVER.MSG_TZCHANGED'} . "</p>";
	}
	

	$maintemplate->param("MESSAGE", $message);
	$maintemplate->param("NEXTURL", "/admin/system/index.cgi?form=system");

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'TIMESERVER.WIDGETLABEL'};
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
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
	print STDERR "timeserver.cgi: sub error called with message $error.\n";
	$errtemplate->param( "ERROR", $error);
	LoxBerry::System::readlanguage($errtemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $errtemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;

}
