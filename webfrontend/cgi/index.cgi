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
use CGI::Session;
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
our $startsetup;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $installdir;
our $nostartsetup;
our $languagefile;
our $step;
our $sid;
our $version;

##########################################################################
# Read Configuration
##########################################################################

# Version of this script
$version = "0.0.1";

$cfg             = new Config::Simple('/opt/loxberry/config/system/general.cfg');
$installdir      = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$startsetup      = $cfg->param("BASE.STARTSETUP");

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

$nostartsetup   = $query{'nostartsetup'};
$step           = $query{'step'};
$sid            = $query{'sid'};

# Filter 
if (defined $query{'nostartsetup'})
{
  $query{'nostartsetup'} =~ tr/0-1//cd;
  $query{'nostartsetup'} =  substr($query{'nostartsetup'},0,1);
}
##########################################################################
# Language Settings
##########################################################################

if (defined $query{'lang'} ) 
{
 $query{'lang'}         =~ tr/a-z//cd;
 $query{'lang'}         =  substr($query{'lang'},0,2);
 $lang = $query{'lang'};
}
else
{
  $lang = "de";
}
# If there's no template, use german
if (!-e "$installdir/templates/system/$lang/language.dat") {
  $lang = "de";
}

# Read translations
$languagefile = "$installdir/templates/system/$lang/language.dat";
$phrase = new Config::Simple($languagefile);

##########################################################################
# Main program
##########################################################################

##########################################################################
# Check for first start and setup assistent
##########################################################################

# If no setup assistant is wanted, don't bother user anymore
if ($nostartsetup) {
  $startsetup = 0;
  $cfg->param("BASE.STARTSETUP", "0");
  $cfg->save();
}

# If Setup assistant wasn't started yet, ask user
if ($startsetup) {

  print "Content-Type: text/html\n\n";

  $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017");
  $help = "setup00";

  # Print Template
  &lbheader;
  open(F,"$installdir/templates/system/$lang/firststart.html") || die "Missing template admin/$lang/firststart.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);
  &footer;

  exit;

}

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
#if ($step eq "0" || !$step) {
#  &step0;
#}


# Nothing todo? Goto Main menu
&mainmenu;

exit;

#####################################################
# Main Meenu
#####################################################

sub mainmenu {

print "Content-Type: text/html\n\n";

$template_title = $phrase->param('TXT0000');
$help = "setup00";



our $systemdatetime = time()*1000;
 (our $sec, our $min, our $hour, our $mday, our $mon, our $year, our $wday, our $yday, our $isdst) = localtime();
our $systemdate         = $year + 1900 . "-" . sprintf ('%02d' ,$mon) . "-" . sprintf ('%02d' ,$mday);

# Print Template
&lbheader;
open(F,"$installdir/templates/system/$lang/mainmenu_start.html") || die "Missing template admin/$lang/mainmenu_start.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);






open(F,"$installdir/templates/system/$lang/mainmenu_end.html") || die "Missing template admin/$lang/mainmenu_end.html";
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
# Header
#####################################################

sub lbheader {

  # create help page
  $helptext = "";
  $helplink = "http://www.loxwiki.eu/display/LOX/Loxone+Community+Wiki";
  open(F,"$installdir/templates/system/$lang/help/$help.html") || die "Missing template admin/$lang/help/$help.html";
    @help = <F>;
    foreach (@help){
      s/[\n\r]/ /g;
      $helptext = $helptext . $_;
    }
  close(F);

  open(F,"$installdir/templates/system/$lang/header.html") || die "Missing template admin/$lang/header.html";
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

  open(F,"$installdir/templates/system/$lang/footer.html") || die "Missing template admin/$lang/footer.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}
