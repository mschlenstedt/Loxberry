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
#use strict;

##########################################################################
# Variables
##########################################################################

our $cfg;
our $file;
our $home = File::HomeDir->my_home;
our $aptbin;
our $test;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "2.0.0.1";

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
      $_ =~ s/(.*):armhf$/$1/g;
      chomp($_);
      # Print line
      if ($test) 
      {
        print "$_\n";
      } 
      else 
      {
        my $output = qx { /usr/bin/apt-cache show $_ > /dev/null 2>&1 };
        my $exitcode  = $? >> 8;
        if ($exitcode != 0) {
          next;
	} else {
      	  $packages = $packages." ".$_;
        }
      }
    }
  }
  if (!$test)
  {
    system("$sudobin $aptbin -y install $packages --no-install-recommends");
  }
close(F);

exit;

