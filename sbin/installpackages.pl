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

use Config::Simple;
use Getopt::Long;
#use warnings;
#use strict;

##########################################################################
# Variables
##########################################################################

our $cfg;
our $file;
our $home = $ENV{'LBHOMEDIR'};
our $aptbin;
our $test;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.3";

$cfg             = new Config::Simple("$home/config/system/general.cfg.default");
$aptbin          = $cfg->param("BINARIES.APT");
$sudobin         = $cfg->param("BINARIES.SUDO");

#########################################################################
# Parameter
#########################################################################
  
GetOptions ('file=s' => \$file,
            'test' => \$test,
);

# Filter
quotemeta($file);

##########################################################################
# Main program
##########################################################################

if (!$file) {
  print "You must specify the packages-file\n";
  print "Usage: $0 --file PACKAGESFILE [--test]\n";
  print "Use --test to print out which packages would be installed - but do nothing.\n";
  exit;
}

# Install
open(F,"$file") || die "Cannot open file: $!";
  my $packages="";
  while (<F>) {
    # Pase only installed packages
    if ($_ =~ /^ii  /) {
      $_ =~ s/^ii  (\S*)(.*)$/$1/g;
      chomp($_);
      # Print line
      if ($test) 
      {
        print "$_\n";
      } 
      else 
      {
      	$packages = $packages." ".$_;
      }
    }
  }
  system("$sudobin $aptbin -y install $packages --no-install-recommends");
close(F);

exit;

