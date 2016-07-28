#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
#                Wörsty, git@loxberry.woerstenfeld.de
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

use File::HomeDir;
use Config::Simple;
use Getopt::Long;
#use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $cfg;
my $namef;
my $value;
my %query;
my $home = File::HomeDir->my_home;
my $logfile;
my $logfilepath;
my $header;
my $format;
my $version;
my $installfolder;
my $cgi;
my $length;
my $offset;
my $i;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.1";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");

#########################################################################
# Parameter
#########################################################################
# Are we called from a browser/web enviroment?
if ($ENV{'HTTP_HOST'}) {

  use CGI::Carp qw(fatalsToBrowser);
  use CGI qw/:standard/;

  $cgi = 1;

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
  $header           = $query{'header'};
  $logfile          = $query{'logfile'};
  $format           = $query{'format'};
  $offset           = $query{'offset'};
  $length           = $query{'length'};

# Or from a terminal?
} else {
  
  GetOptions ('header=s'  => \$header,
              'logfile=s' => \$logfile,
              'format=s'  => \$format,
              'offset=i'  => \$offset,
              'length'    => \$length,
  );

}

# Filter
quotemeta($header);
quotemeta($logfile);
quotemeta($format);
quotemeta($offset);
quotemeta($length);
$logfile =~ s/^\///;

##########################################################################
# Main program
##########################################################################

# Which header
if ($header eq "txt") {
  print "Content-Type: text/plain\n\n";
}
if ($header eq "html" || ($cgi && !$header) ) {
  print "Content-Type: text/html\n\n";
}

# Which Output Format
if (!$format) {
  $format = "plain";
}

# Check if logfile exists
# Note: Only ~/log, ~/webfrontend/html/tmp and /tmp are allowed
# for security reasons
if (!$logfile) {
  if ($cgi) {
    print "You must specify a logfile by adding ?logfile=YOURFILE to the URL<br><br>";
    print "Usage: $ENV{'SCRIPT_NAME'}?logfile=FILE[&length] [&offset] [&header= txt|html|none] [&format=html|terminal|plain]";
  } else {
    print "You must specify a logfile with --logfile YOURFILE\n\n";
    print "Usage: $0 --logfile FILE [--length] [--offset]\n";
    print "       [--header txt|html|none] [--format html|terminal|plain]\n\n";
  }
  exit;
}

if (-e "/tmp/$logfile") {
  $logfilepath = "/tmp";
} elsif (-e "$home/log/$logfile") {
  $logfilepath = "$home/log";
} elsif (-e "$home/webfrontend/html/tmp/$logfile") {
  $logfilepath = "$home/webfrontend/html/tmp";
} else {
  if ($cgi) {
    print "Logfile does not exist. Use file in ~/log, ~/webfrontend/html/tmp or /tmp und give relative path started from these folders.<br><br>";
    print "Usage: $ENV{'SCRIPT_NAME'}?logfile=FILE[&length] [&offset] [&header= txt|html|none] [&format=html|terminal|plain]";
  } else {
    print "Logfile does not exist. Use file in ~/log, ~/webfrontend/html/tmp or\n";
    print "/tmp und give relative path started from these folders.\n\n";
    print "Usage: $0 --logfile FILE [--length] [--offset]\n";
    print "       [--header txt|html|none] [--format html|terminal|plain]\n\n";
  }
  exit;
}

# Print number of lines of logfile
if ($length) {
  $i = 0;
  open(F,"$logfilepath/$logfile") || die "Cannot open file: $!";
    while (<F>) {
      $i++
    }
  close(F);
  print $i;
  exit;
}

# Print Logfile
$i = 0;
open(F,"$logfilepath/$logfile") || die "Cannot open file: $!";
  while (<F>) {
    # Offset
    if ($offset) {
      $i++;
      if ($i <= $offset) {
        next;
      }
    }
    # HTML Output
    if ($format eq "html") {
      $_ =~ s/^(.*?)\s*<OK>\s*(.*?)$/<div id='logok'>$1 <FONT color=green><B>OK:<\/B><\/FONT> $2/g;
      $_ =~ s/<\/OK>//g;
      $_ =~ s/^(.*?)\s*<ERROR>\s*(.*?)$/<div id='logerr'>$1 <FONT color=red><B>ERROR:<\/B><\/FONT> $2/g;
      $_ =~ s/<\/ERROR>//g;
      $_ =~ s/^(.*?)\s*<FAIL>\s*(.*?)$/<div id='logfail'>$1 <FONT color=red><B>FAIL:<\/B><\/FONT> $2/g;
      $_ =~ s/<\/FAIL>//g;
      $_ =~ s/^(.*?)\s*<INFO>\s*(.*?)$/<div id='loginfo'>$1 <FONT color=black><B>INFO:<\/B><\/FONT> $2/g;
      $_ =~ s/<\/INFO>//g;
      $_ =~ s/^(.*?)\s*<WARNING>\s*(.*?)$/<div id='logwarn'>$1 <FONT color=red><B>WARNING:<\/B><\/FONT> $2/g;
      $_ =~ s/<\/WARNING>//g;
    }
    # Terminal Output Colorized
    # http://misc.flogisoft.com/bash/tip_colors_and_formatting
    if ($format eq "terminal") { 
      $_ =~ s/^(.*?)(\s*)<OK>\s*(.*?)$/$1$2\\e[1m\\e[32mOK:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<ERROR>\s*(.*?)$/$1$2\\e[1m\\e[31mERROR:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<FAIL>\s*(.*?)$/$1$2 \\e[1m\\e[31mFAIL:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<INFO>\s*(.*?)$/$1$2\\e[1mINFO:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<WARNING>\s*(.*?)$/$1$2\\e[1m\\e[31mWARNING:\\e[0m $3/g;
    }

    if ($format ne "plain") { 
      # If someone uses end tags, remove them
      $_ =~ s/<\/OK>$//g;
      $_ =~ s/<\/ERROR>$//g;
      $_ =~ s/<\/FAIL>$//g;
      $_ =~ s/<\/WARNING>$//g;
      $_ =~ s/<\/INFO>//g;
    } 

    # Print line
    print $_;
  }
close(F);

exit;
