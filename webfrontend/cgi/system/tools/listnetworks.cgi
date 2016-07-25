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

use Config::Simple;
#use warnings;
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
our $installdir;
our $languagefile;
my  @fields;
my  @fields1;
my  $error;
our $table;
my  $result;
my  @result;
my  $i;
our $ssid;
our $quality;
our $force;
our $bitrates;
our $encryption;
our $version;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.1";

$cfg             = new Config::Simple('../../../../config/system/general.cfg');
$installdir      = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");

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

# No one here

# Filter
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

# Check for Device wlan0
$error = 0;
$result = qx(/sbin/ifconfig wlan0 2>/dev/null);

if ($? > 0) {
  $table = "<tr><td>" . $phrase->param("TXT0016") . "</td></tr>\n";
  $error = 1;
}

# For testing new hardware
$error = 0;

# Scan for WLAN Hardware
if (!$error) {
  @result = qx(sudo /sbin/iwlist wlan0 scan 2>/dev/null);

  # For testing new hardware
  open(F,"/tmp/scan.txt");
    @result = <F>;
  close (F);

  $table = "";
  $i = 1;
  foreach (@result){
    s/[\n\r]//g;
    @fields = split(/:/);
    $fields[0] =~ s/^\s+//g;
    $fields[1] =~ s/^\s+//g;
    # Tabellenkopf
    if ($i == 1) {
      $table = "<thead><tr><th>" . $phrase->param("TXT0011") . "</th><th>" . $phrase->param("TXT0012") . "</th><th>" . $phrase->param("TXT0013") . "</th><th>" . $phrase->param("TXT0014") . "</th><th>" . $phrase->param("TXT0015") . "</th><th>&nbsp;</th></tr></thead>\n<tbody>\n";
    }
    if ($fields[0] =~ /Cell \d+ - Address/) {
      if ($i ne 1) {
        # Create Table row from previous entry
        $table = "$table<tr><th style=\"vertical-align: middle; text-align: left\"><b>$ssid</b></th>";
        $table = "$table<td style=\"vertical-align: middle; text-align: center\">$encryption</td>";
        $table = "$table<td  style=\"vertical-align: middle; text-align: center\">$bitrates</td>";
        $table = "$table<td style=\"vertical-align: middle; text-align: center\">$quality</td>";
        $table = "$table<td style=\"vertical-align: middle; text-align: center\">$force</td>";
        $table = "$table<td style=\"vertical-align: middle; text-align: center\"><button type=\"button\" data-role=\"button\" data-inline=\"true\" data-mini=\"true\" onClick=\"window.opener.document.getElementById('netzwerkssid').value = '$ssid';window.close()\"> <font size=\"-1\">Übernehmen</font></button></td></tr>\n";
      }
      $i++;
      $ssid = "";
      $encryption = "";
      $bitrates = "";
      $quality = "";
      $force = "";
    }
    if ($fields[0] eq "ESSID") {
      $fields[1] =~ s/"//g;
      $ssid = $fields[1];
    }
    if ($fields[0] eq "Encryption key") {
      if ($fields[1] eq "on") {
      $encryption = $phrase->param("TXT0001");
      } else {
      $encryption = $phrase->param("TXT0002");
      } 
    }
    # Bit Rates are a little more tricky
    if ($fields[0] eq "Bit Rates" && $bitrates) {
      $bitrates = "$bitrates\; $fields[1]";
    }
    if ($fields[0] eq "Bit Rates" && !$bitrates) {
      $bitrates = "$fields[1]";
    }
    if ($fields[0] =~ /^\d+ Mb\/s/) {
      $bitrates = "$bitrates\; $fields[0]";
    }
    # We found some different listings for different WLAN adapters here...
    if ($fields[0] =~ /^Quality/) {
      @fields1 = split(/=/,$fields[0]);
      $fields1[1] =~ s/  Signal level$//g;
      $fields1[2] =~ s/\s+$//g;
      $quality = $fields1[1];
      $force = $fields1[2];
    } 
    if ($fields[0] =~ /^Signal level/) {
      $fields[0] =~ s/Signal level=//g;
      @fields1 = split(/\//,$fields[0]);
      $fields1[2] =~ s/\s+$//g;
      $quality = $fields1[1];
      $force = $fields1[0];

    } 
    
  }

}

# Create last Table row
$table = "$table<tr><th style=\"vertical-align: middle; text-align: left\"><b>$ssid</b></th>";
$table = "$table<td style=\"vertical-align: middle; text-align: center\">$encryption</td>";
$table = "$table<td  style=\"vertical-align: middle; text-align: center\">$bitrates</td>";
$table = "$table<td style=\"vertical-align: middle; text-align: center\">$quality</td>";
$table = "$table<td style=\"vertical-align: middle; text-align: center\">$force</td>";
$table = "$table<td style=\"vertical-align: middle; text-align: center\"><button type=\"button\" data-role=\"button\" data-inline=\"true\" data-mini=\"true\" onClick=\"window.opener.document.getElementById('netzwerkssid').value = '$ssid';window.close()\"> <font size=\"-1\">Übernehmen</font></button></td></tr>\n";
$table = "$table</tbody>\n";

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0009");

# Print Template
open(F,"$installdir/templates/system/$lang/listnetworks.html") || die "Missing template system/$lang/listnetworks.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

exit;
