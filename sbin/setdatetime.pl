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

use LWP::UserAgent;
use XML::Simple qw(:strict);
use Config::Simple;
use File::Copy;
use LoxBerry::System;
#use strict;
#use warnings;

##########################################################################
# Variables
##########################################################################

my $verbose = 1;

my $cfg;
my $miniserverip;
my $miniserverport;
my $miniserveradmin;
my $miniserverpass;
my $miniserverclouddns;
my $miniservermac;
my $timemethod;
my $url;
my $ua;
my $response;
our $error;
my $rawxml;
my $xml;
my @fields;
my $hour;
my $min;
my $sec;
my $day;
my $mon;
my $year;
my $success;
my $output;
my $timeserver;
my $timezone;
my $timezoneresult;
our $logmessage;
our $errormessage;
my $ntpbin;
my $datebin;
my $sudobin;
my $installdir;

##########################################################################
# Read Configuration
##########################################################################

# Version of this script
my $version = "0.0.4";

$cfg                 = new Config::Simple("$lbhomedir/config/system/general.cfg");
$miniserverip        = $cfg->param("MINISERVER1.IPADDRESS");
$miniserverport      = $cfg->param("MINISERVER1.PORT");
$miniserveradmin     = $cfg->param("MINISERVER1.ADMIN");
$miniserverpass      = $cfg->param("MINISERVER1.PASS");
$miniserverclouddns  = $cfg->param("MINISERVER1.USECLOUDDNS");
$miniservermac       = $cfg->param("MINISERVER1.CLOUDURL");
$timemethod          = $cfg->param("TIMESERVER.METHOD");
$timeserver          = $cfg->param("TIMESERVER.SERVER");
$timezone            = $cfg->param("TIMESERVER.ZONE");
$ntpbin              = $cfg->param("BINARIES.NTPDATE");
$datebin             = $cfg->param("BINARIES.DATE");
$sudobin             = $cfg->param("BINARIES.SUDO");
$installdir          = $cfg->param("BASE.INSTALLFOLDER");

##########################################################################
# Main program
##########################################################################

# Set timezone
$timezoneresult = qx(sudo /usr/bin/timedatectl set-timezone "$timezone");
$logmessage = "Setting Timezone to '$timezone'\n $timezoneresult\n";
&log;
$timezoneresult = qx(/usr/bin/timedatectl status);
$logmessage = "Timezone status: \n $timezoneresult \n";
&log;

# If Method is Miniserver
if ($timemethod eq "miniserver") {

  # Use Cloud DNS?
  if ($miniserverclouddns) {
    $output = qx($lbhomedir/bin/showclouddns.pl $miniservermac);
    @fields = split(/:/,$output);
    $miniserverip   =  @fields[0];
    $miniserverport = @fields[1];
  }

  # Get Time from Miniserver
  $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sys/time";
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    if (!$response->is_success) {
      $errormessage = "Unable to fetch Time from Miniserver. Giving up.";
      &error;
      exit;
    } else {
      $success = 1;
    }
  };
  alarm(0);

  if (!$success) {
      $errormessage = "Unable to fetch Time from Miniserver. Giving up.";
      &error;
      exit;
  }
  $success = 0;
 
  $rawxml = $response->decoded_content();
  $xml = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
  #print Dumper($xml);

  @fields = split(/:/,$xml->{value});
  $hour = $fields[0];
  $min  = $fields[1];
  $sec  = $fields[2];

  # Get Date from Miniserver
  $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sys/date";
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    if (!$response->is_success) {
      $errormessage = "Unable to fetch Date from Miniserver. Giving up.";
      &error;
      exit;
    } else {
      $success = 1;
    }
  };
  alarm(0);

  if (!$success) {
      $errormessage = "Unable to fetch Time from Miniserver. Giving up.";
      &error;
      exit;
  }
  $success = 0;

  $rawxml = $response->decoded_content();
  $xml = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
  #print Dumper($xml);

  @fields = split(/-/,$xml->{value});
  $year = $fields[0];
  $mon  = $fields[1];
  $day  = $fields[2];

  # Set system date and time
  $output = qx($sudobin $datebin -s '$year-$mon-$day $hour:$min:$sec');
  $logmessage = "Sync Date/Time with Miniserver: $output";
  &log;
  exit;

}

# If Method is NTP
if ($timemethod eq "ntp" && $timeserver) {

  # Set system date and time via NTP
  $output = qx($sudobin $ntpbin -u $timeserver);
  $logmessage = "Sync Date/Time with NTP Server: $output";
  &log;
  exit;

}

# Neither Miniserver nor NTP Server? Error!
$errormessage = "You haven't choose neither Miniserver nor NTP Server or no NTP-Server given. Giving up.";
&error;
exit;

##########################################################################
# Subroutinen
##########################################################################

# Logfile
sub log {
# Today's date for logfile
  (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime();
  $year = $year+1900;
  $mon = $mon+1;
  $mon = sprintf("%02d", $mon);
  $mday = sprintf("%02d", $mday);
  $hour = sprintf("%02d", $hour);
  $min = sprintf("%02d", $min);
  $sec = sprintf("%02d", $sec);

  if ($verbose || $error) {print "$logmessage";}

  # Logfile
  open(F,">>$installdir/log/system/datetime.log");
    print F "$year-$mon-$mday $hour:$min:$sec $logmessage";
  close (F);

  return ();
}

# Error Message
sub error {
  $error = "1";
  $logmessage = "ERROR: $errormessage\n";
  &log;
  exit;
}
