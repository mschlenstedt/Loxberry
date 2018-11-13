#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
# Copyright 2016 Christian Wörstenfeld
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
use JSON;
#use warnings;
#use strict;

##########################################################################
# Variables
##########################################################################

our $cfg;
our $clouddnsaddress;
our $curlbin;
our $awkbin;
our $grepbin;
our $version;
our $home = $ENV{'LBHOMEDIR'};

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.2";

$cfg                = new Config::Simple($home.'/config/system/general.cfg');
$clouddnsaddress    = $cfg->param("BASE.CLOUDDNS");
$curlbin            = $cfg->param("BINARIES.CURL");
$grepbin            = $cfg->param("BINARIES.GREP");
$awkbin             = $cfg->param("BINARIES.AWK");

##########################################################################
# Main program
##########################################################################

# Check for argument
if (!$ARGV[0]) {
  print "Missing MAC Address. Usage: $0 MACADDRESS\n";
  exit;
}

# Grep IP Address from Cloud Service
#our $dns_info = `$curlbin -I http://$clouddnsaddress/$ARGV[0] --connect-timeout 5 -m 5 2>/dev/null |$grepbin Location |$awkbin -F/ '{print \$3}'`;
my $ip_info = `$curlbin 'http://'$clouddnsaddress'/?getip&snr='$ARGV[0]'&json=true' 2>/dev/null`;
my $json = JSON->new;
my $ip_info = $json->decode($ip_info);
our $dns_info = $ip_info->{IP};

my @dns_info_pieces = split /:/, $dns_info;

if ($dns_info_pieces[1]) {
  $dns_info_pieces[1] =~ s/^\s+|\s+$//g;
} else {
  $dns_info_pieces[1] = 80;
}

if ($dns_info_pieces[0]) {
  $dns_info_pieces[0] =~ s/^\s+|\s+$//g;
} else {
  $dns_info_pieces[0] = "[DNS-Error]";
}

# Print
print "$dns_info_pieces[0]:$dns_info_pieces[1]";
