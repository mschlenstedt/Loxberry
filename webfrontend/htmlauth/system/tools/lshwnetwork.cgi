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
my  $error;
our $table;
my  @result;
my  $i;
our $ssid;
our $version;
our $ENV;

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

# Scan for WLAN Hardware
@result = qx(sudo /usr/bin/lshw -class network 2>/dev/null);

$table = "";
$i = 1;
foreach (@result){
  s/[\n\r]//g;
  @fields = split(/: /);
  $fields[0] =~ s/^\s+//g;
  $fields[1] =~ s/^\s+//g;
  if ($fields[0] =~ /\*-/) {
    if ($i != 1) { 
      $table = "$table<tr><td colspan=2>&nbsp;</td></tr>\n";
    }
    $table = "$table<tr><td colspan=2><b>$i. " . $phrase->param("TXT0009") . "</b></td></tr>\n";
    $i++;
  }
  if ($fields[0] eq "description") {
    $fields[1] =~ s/ interface//g;
    $table = "$table<tr><td>" . $phrase->param("TXT0006") . "</td><td>$fields[1]</td></tr>\n";
  }
  if ($fields[0] eq "logical name") {
    $table = "$table<tr><td>" . $phrase->param("TXT0007") . "</td><td>$fields[1]</td></tr>\n";
  }
  if ($fields[0] eq "serial") {
    $table = "$table<tr><td>" . $phrase->param("TXT0008") . "</td><td>$fields[1]</td></tr>\n";
  }
  if ($fields[0] eq "configuration") {
    $fields[1] =~ s/.*driver=(\S*) (.*)/$1/g;
    $table = "$table<tr><td>" . $phrase->param("TXT0010") . "</td><td>$fields[1]</td></tr>\n";
  }
  
}

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0009");

# Print Template
open(F,"$installdir/templates/system/$lang/lshwnetwork.html") || die "Missing template system/$lang/lshwnetwork.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

exit;
