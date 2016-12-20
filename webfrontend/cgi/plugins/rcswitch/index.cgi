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
use Config::Simple;
use File::HomeDir;
use Cwd 'abs_path';
#use warnings;
#use strict;
#no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

our $cfg;
our $lang;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $installfolder;
our $version;
my  $home = File::HomeDir->my_home;
our $psubfolder;
our $pcfg;
our $transPIN;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.4";

# Figure out in which subfolder we are installed
$psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/(.*)$/$2/g;

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$pcfg            = new Config::Simple("$home/config/plugins/$psubfolder/RCSwitch.cfg");
$transPIN        = $pcfg->param("general.TransmissionPIN");

# Init Language
# Clean up lang variable
$lang =~ tr/a-z//cd;
$lang = substr($lang,0,2);

# If there's no file in our language, use german as default
if (!-e "$installfolder/templates/plugins/$psubfolder/$lang/main.html") {
	$lang = "de";
}

##########################################################################
# Main program
##########################################################################

print "Content-Type: text/html\n\n";

# Vars for template
$template_title = "LoxBerry: RCSwitch Plugin";

# Save settings
if ( param('savesettings') ) {

  $transPIN = param('gpiopin');
  quotemeta($transPIN);
  $pcfg->param("general.TransmissionPIN", "$transPIN");

  # Save Config
  $pcfg->save();

  $output = qx(sudo /etc/init.d/pilight stop);
  our $found = 0;
  open(F,"+<$home/config/plugins/$psubfolder/pilight/config.json");
    flock(F,2);
    our @data = <F>;
    seek(F,0,0);
    truncate(F,0);
    foreach (@data){
      s/[\n\r]//g;
      if ( $_ =~ /433gpio/ ) {
        $found = 1;
      }
      if ( $_ =~ /sender/ && $found ) {
        print F "		\"sender\": $transPIN,\n";
        $found = 0;
        next;
      }
      print F "$_\n";
    }

  close(F);
  $output = qx(sudo /etc/init.d/pilight start);

} 

# Select GPIO Pin
if ( $transPIN eq "7" ) { our $selectedpin4 = "selected=selected" }
elsif ( $transPIN eq "0" ) { our $selectedpin17 = "selected=selected" }
elsif ( $transPIN eq "1" ) { our $selectedpin18 = "selected=selected" }
elsif ( $transPIN eq "3" ) { our $selectedpin22 = "selected=selected" }
elsif ( $transPIN eq "4" ) { our $selectedpin23 = "selected=selected" }
elsif ( $transPIN eq "5" ) { our $selectedpin24 = "selected=selected" }
elsif ( $transPIN eq "6" ) { our $selectedpin25 = "selected=selected" }
else { our $selectedpin17 = "selected=selected" };

# Calculate Elro commands
if ( param('type')  eq "elro" ) {

  our $valueb0 = param('b[0]');
  if ( $valueb0 ) { our $statusb0 = "on" } else { our $statusb0 = "off" };
  our $valueb1 = param('b[1]');
  if ( $valueb1 ) { our $statusb1 = "on" } else { our $statusb1 = "off" };
  our $valueb2 = param('b[2]');
  if ( $valueb2 ) { our $statusb2 = "on" } else { our $statusb2 = "off" };
  our $valueb3 = param('b[3]');
  if ( $valueb3 ) { our $statusb3 = "on" } else { our $statusb3 = "off" };
  our $valueb4 = param('b[4]');
  if ( $valueb4 ) { our $statusb4 = "on" } else { our $statusb4 = "off" };
  our $valueb5 = param('b[5]');
  if ( $valueb5 ) { our $statusb5 = "on" } else { our $statusb5 = "off" };
  our $valueb6 = param('b[6]');
  if ( $valueb6 ) { our $statusb6 = "on" } else { our $statusb6 = "off" };
  our $valueb7 = param('b[7]');
  if ( $valueb7 ) { our $statusb7 = "on" } else { our $statusb7 = "off" };
  our $valueb8 = param('b[8]');
  if ( $valueb8 ) { our $statusb8 = "on" } else { our $statusb8 = "off" };
  our $valueb9 = param('b[9]');
  if ( $valueb9 ) { our $statusb9 = "on" } else { our $statusb9 = "off" };

  our $group1 = "$valueb0$valueb1$valueb2$valueb3$valueb4";
  if ( $group1 eq "" ) { $group1 = "0"; }

 if ( ($valueb5 + $valueb6 + $valueb7 + $valueb8 + $valueb9) eq 1 ) {
	if ( param('b[5]') ) { our $unit1 = "1" }
	elsif ( param('b[6]') ) { our $unit1 = "2" }
	elsif ( param('b[7]') ) { our $unit1 = "3" }
	elsif ( param('b[8]') ) { our $unit1 = "4" }
	elsif ( param('b[9]') ) { our $unit1 = "5" }
	else { our $unit1 = "0" } ;
  } else {
	our $unit1 = "$valueb5$valueb6$valueb7$valueb8$valueb9";
	if ( $unit1 eq "" ) { $unit1 = "0"; }
  }

} else {

  our $statusb0 = "off";
  our $valueb0 = "0";
  our $statusb1 = "off";
  our $valueb1 = "0";
  our $statusb2 = "off";
  our $valueb2 = "0";
  our $statusb3 = "off";
  our $valueb3 = "0";
  our $statusb4 = "off";
  our $valueb4 = "0";
  our $statusb5 = "off";
  our $valueb5 = "0";
  our $statusb6 = "off";
  our $valueb6 = "0";
  our $statusb7 = "off";
  our $valueb7 = "0";
  our $statusb8 = "off";
  our $valueb8 = "0";
  our $statusb9 = "off";
  our $valueb9 = "0";
  our $group1 = "0";
  our $unit1 = "0";

}

# Calculate Intertechno V1 commands
if ( param('type')  eq "arctechv1" ) {

  our $family2 = param('familyarcv1');
  if ( $family2 eq "A" ) { our $selectedarcv1A = "selected=selected" }
  elsif ( $family2 eq "B" ) { our $selectedarcv1B = "selected=selected" }
  elsif ( $family2 eq "C" ) { our $selectedarcv1C = "selected=selected" }
  elsif ( $family2 eq "D" ) { our $selectedarcv1D = "selected=selected" }
  elsif ( $family2 eq "E" ) { our $selectedarcv1E = "selected=selected" }
  elsif ( $family2 eq "F" ) { our $selectedarcv1F = "selected=selected" }
  elsif ( $family2 eq "G" ) { our $selectedarcv1G = "selected=selected" }
  elsif ( $family2 eq "H" ) { our $selectedarcv1H = "selected=selected" }
  elsif ( $family2 eq "I" ) { our $selectedarcv1I = "selected=selected" }
  elsif ( $family2 eq "J" ) { our $selectedarcv1J = "selected=selected" }
  elsif ( $family2 eq "K" ) { our $selectedarcv1K = "selected=selected" }
  elsif ( $family2 eq "L" ) { our $selectedarcv1L = "selected=selected" }
  elsif ( $family2 eq "M" ) { our $selectedarcv1M = "selected=selected" }
  elsif ( $family2 eq "N" ) { our $selectedarcv1N = "selected=selected" }
  elsif ( $family2 eq "O" ) { our $selectedarcv1O = "selected=selected" }
  elsif ( $family2 eq "P" ) { our $selectedarcv1P = "selected=selected" };

  our $unittemp = param('unitarcv1');
  if ( $unittemp eq "1" ) { our $selectedarcv11 = "selected=selected" }
  elsif ( $unittemp eq "2" ) { our $selectedarcv12 = "selected=selected" }
  elsif ( $unittemp eq "3" ) { our $selectedarcv13 = "selected=selected" }
  elsif ( $unittemp eq "4" ) { our $selectedarcv14 = "selected=selected" }
  elsif ( $unittemp eq "5" ) { our $selectedarcv15 = "selected=selected" }
  elsif ( $unittemp eq "6" ) { our $selectedarcv16 = "selected=selected" }
  elsif ( $unittemp eq "7" ) { our $selectedarcv17 = "selected=selected" }
  elsif ( $unittemp eq "8" ) { our $selectedarcv18 = "selected=selected" }
  elsif ( $unittemp eq "9" ) { our $selectedarcv19 = "selected=selected" }
  elsif ( $unittemp eq "10" ) { our $selectedarcv110 = "selected=selected" }
  elsif ( $unittemp eq "11" ) { our $selectedarcv111 = "selected=selected" }
  elsif ( $unittemp eq "12" ) { our $selectedarcv112 = "selected=selected" }
  elsif ( $unittemp eq "13" ) { our $selectedarcv113 = "selected=selected" }
  elsif ( $unittemp eq "14" ) { our $selectedarcv114 = "selected=selected" }
  elsif ( $unittemp eq "15" ) { our $selectedarcv115 = "selected=selected" }
  elsif ( $unittemp eq "16" ) { our $selectedarcv116 = "selected=selected" };

  if ( $unittemp > 0 && $unittemp <= 4) {
    our $group2 = "1";
    our $unit2 = $unittemp;
  }
  elsif ( $unittemp > 4 && $unittemp <= 8) {
    our $group2 = "2";
    our $unit2 = $unittemp - 4;
  }
  elsif ( $unittemp > 8 && $unittemp <= 12) {
    our $group2 = "3";
    our $unit2 = $unittemp - 8;
  }
  elsif ( $unittemp > 12 && $unittemp <= 16) {
    our $group2 = "4";
    our $unit2 = $unittemp - 12;
  }

} else {

  our $family2 = "0";
  our $group2 = "0";
  our $unit2 = "0";

}

# Calculate Intertechno V2 commands
if ( param('type')  eq "arctechv2" ) {

  our $unit3 = param('unitarcv2');
  if ( $unit3 eq "0" ) { our $selectedarcv20 = "selected=selected" }
  elsif ( $unit3 eq "1" ) { our $selectedarcv21 = "selected=selected" }
  elsif ( $unit3 eq "2" ) { our $selectedarcv22 = "selected=selected" }
  elsif ( $unit3 eq "3" ) { our $selectedarcv23 = "selected=selected" }
  elsif ( $unit3 eq "4" ) { our $selectedarcv24 = "selected=selected" }
  elsif ( $unit3 eq "5" ) { our $selectedarcv25 = "selected=selected" }
  elsif ( $unit3 eq "6" ) { our $selectedarcv26 = "selected=selected" }
  elsif ( $unit3 eq "7" ) { our $selectedarcv27 = "selected=selected" }
  elsif ( $unit3 eq "8" ) { our $selectedarcv28 = "selected=selected" }
  elsif ( $unit3 eq "9" ) { our $selectedarcv29 = "selected=selected" }
  elsif ( $unit3 eq "10" ) { our $selectedarcv210 = "selected=selected" }
  elsif ( $unit3 eq "11" ) { our $selectedarcv211 = "selected=selected" }
  elsif ( $unit3 eq "12" ) { our $selectedarcv212 = "selected=selected" }
  elsif ( $unit3 eq "13" ) { our $selectedarcv213 = "selected=selected" }
  elsif ( $unit3 eq "14" ) { our $selectedarcv214 = "selected=selected" }
  elsif ( $unit3 eq "15" ) { our $selectedarcv215 = "selected=selected" }

  our $group3 = param('grouparcv2');

  our $all3 = param('allarcv2');
  if ( $all3 eq "0" ) { our $selectedarcv2all0 = "selected=selected" }
  else { our $selectedarcv2all1 = "selected=selected" }

} else {

  our $family3 = "0";
  our $group3 = "0";
  our $unit3 = "0";
  our $all3 = "0";
  our $selectedarcv2all0 = "selected=selected";

}

# Some vars for the template
our $host = "$ENV{HTTP_HOST}";
our $loginname = "$ENV{REMOTE_USER}";

# Print Template

# Create Help page
$helplink = "http://www.loxwiki.eu:80/x/JATL";
open(F,"$installfolder/templates/plugins/$psubfolder/$lang/help.html") || die "Missing template plugins/$psubfolder/$lang/help.html";
  @help = <F>;
  foreach (@help)
  {
    s/[\n\r]/ /g;
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    $helptext = $helptext . $_;
  }
close(F);

# Header
open(F,"$installfolder/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
  while (<F>) 
  {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

# Main
open(F,"$installfolder/templates/plugins/$psubfolder/$lang/main.html") || die "Missing template plugins/$psubfolder/$lang/main.html";
while (<F>) 
  {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

# Footer
open(F,"$installfolder/templates/system/$lang/footer.html") || die "Missing template system/$lang/footer.html";
  while (<F>) 
  {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

exit;
