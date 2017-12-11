#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
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

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use LWP::UserAgent;
use Config::Simple;
use warnings;
use strict;
no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

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
our $installfolder;
our $languagefile;
our $version;
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
$version = "0.0.3";

$cfg                = new Config::Simple('../../../config/system/general.cfg');
$installfolder      = $cfg->param("BASE.INSTALLFOLDER");
$lang               = $cfg->param("BASE.LANG");
$zeitserver         = $cfg->param("TIMESERVER.METHOD");
$ntpserverurl       = $cfg->param("TIMESERVER.SERVER");
$zeitzone           = $cfg->param("TIMESERVER.ZONE");
$datebin            = $cfg->param("BINARIES.DATE");
$ntpdate            = $cfg->param("BINARIES.NTPDATE");
$awkbin             = $cfg->param("BINARIES.AWK");
$grepbin            = $cfg->param("BINARIES.GREP");
$do                 = "";
$helptext           = "";

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

# Filter
quotemeta($query{'lang'});
quotemeta($saveformdata);
quotemeta($do);

$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

##########################################################################
# Language Settings
##########################################################################

# Override settings with URL param
if ($query{'lang'}) {
  $lang = $query{'lang'};
}

# Standard is german
if ($lang eq "") {
  $lang = "de";
}

# If there's no language phrases file for choosed language, use german as default
if (!-e "$installfolder/templates/system/$lang/language.dat") {
  $lang = "de";
}

# Read translations / phrases
$languagefile = "$installfolder/templates/system/$lang/language.dat";
$phrase = new Config::Simple($languagefile);

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
if (!$saveformdata || $do eq "form") 
{
  &form;
} else {
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form {

# Filter
quotemeta($zeitserver);
quotemeta($ntpserverurl);
quotemeta($zeitzone);

# Defaults for template
if ($zeitserver eq "ntp") {
  $checked2 = "checked\=\"checked\"";
} else {
  $checked1 = "checked\=\"checked\"";
}

# Prepare Timezones
open(F,"<$installfolder/templates/system/timezones.dat") || die "Missing template system/timezones.dat";
 flock(F,2);
 @lines = <F>;
 flock(F,8);
close(F);
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

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0021");
$help = "timeserver";

# Print Template
&lbheader;
open(F,"$installfolder/templates/system/$lang/timeserver.html") || die "Missing template system/$lang/timeserver.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

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

# Filter
quotemeta($zeitserver);
quotemeta($ntpserverurl);
quotemeta($zeitzone);

# Test if NTP-Server is reachable
our $ntp_check="0"; 
if ( ${zeitserver} eq "ntp" )
{
 $ntp_check = system("$ntpdate -q $ntpserverurl >/dev/null 2>&1");
}
# Error if we can't get time
if ($ntp_check) {
  $error = $phrase->param("TXT0050");
  &error;
  exit;
}

# Write configuration file(s)
$cfg->param("TIMESERVER.SERVER", "$ntpserverurl");
$cfg->param("TIMESERVER.METHOD", "$zeitserver");
$cfg->param("TIMESERVER.ZONE", "$zeitzone");
$cfg->save();

# Trigger timesync
$output = qx($installfolder/sbin/setdatetime.pl);
$output = qx($datebin);

print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0021");
$help = "timeserver";

$message = $phrase->param("TXT0036") . "<br>" . $output;
$nexturl = "/admin/index.cgi";

# Print Template
&lbheader;
open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/succses.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

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

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0028");
$help = "admin";

print "Content-Type: text/html\n\n";

&lbheader;
open(F,"$installfolder/templates/system/$lang/error.html") || die "Missing template system/$lang/error.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);
&footer;

exit;

}

#####################################################
# Header
#####################################################

sub lbheader {

  # create help page
  $helplink = "http://www.loxwiki.eu:80/x/o4CO";
  open(F,"$installfolder/templates/system/$lang/help/$help.html") || die "Missing template system/$lang/help/$help.html";
    @help = <F>;
    foreach (@help){
      s/[\n\r]/ /g;
      $helptext = $helptext . $_;
    }
  close(F);

  open(F,"$installfolder/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}

#####################################################
# Footer
#####################################################

sub footer {

  open(F,"$installfolder/templates/system/$lang/footer.html") || die "Missing template system/$lang/footer.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}

