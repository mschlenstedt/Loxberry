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

use LoxBerry::Web;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $template_title;
my  @fields;
my  @fields1;
my  $error;
my  $chkwifi;
my  @result;
my  $i;
our $version;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "1.2.5.1";

##########################################################################
# Template
##########################################################################

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/listnetworks.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			%htmltemplate_options,
			);

my %SL = LoxBerry::System::readlanguage($maintemplate);

##########################################################################
# Main program
##########################################################################

# Check for Device wlan0
$error = 0;
$chkwifi = qx(/sbin/ifconfig wlan0 2>/dev/null);

if ($? > 0) {
  $maintemplate->param('NOWIFI', 1);
  $error = 1;
}

# Only for testing new hardware
#$error = 0;

# Scan for WLAN Hardware
if (!$error) {
  @result = qx(sudo /sbin/ifconfig wlan0 up 2>/dev/null);
  @result = qx(sudo /sbin/iwlist wlan0 scan 2>/dev/null);

  # For testing new hardware
  #open(F,"/tmp/scan.txt");
  #  @result = <F>;
  #close (F);

  $i = 1;
  
  my @networks;
  my %network;
  foreach (@result){
    
	s/[\n\r]//g;
    @fields = split(/:/);
    $fields[0] =~ s/^\s+//g;
    $fields[1] =~ s/^\s+//g;
    
	
    if ($fields[0] =~ /Cell \d+ - Address/) {
 	  $i++;
      push @networks, \%network;
	  %network = ();
	  # $ssid = "";
      # $encryption = "";
      # $bitrates = "";
      # $quality = "";
      # $force = "";
    }
    if ($fields[0] eq "ESSID") {
      $fields[1] =~ s/"//g;
      $network{ssid} = $fields[1];
    }
    if ($fields[0] eq "Encryption key") {
      if ($fields[1] eq "on") {
      $network{encryption} = $SL{'COMMON.MSG_YES'};
      } else {
      $network{encryption} = $SL{'COMMON.MSG_NO'};
      } 
    }
    # Bit Rates are a little more tricky
    if ($fields[0] eq "Bit Rates" && $network{bitrates}) {
      $network{bitrates} = "$network{bitrates}; $fields[1]";
    }
    if ($fields[0] eq "Bit Rates" && !$network{bitrates}) {
      $network{bitrates} = "$fields[1]";
    }
    if ($fields[0] =~ /^\d+ Mb\/s/) {
      $network{bitrates} = "$network{bitrates}; $fields[0]";
    }
    # We found some different listings for different WLAN adapters here...
    if ($fields[0] =~ /^Quality/) {
      @fields1 = split(/=/,$fields[0]);
      $fields1[1] =~ s/  Signal level$//g;
      $fields1[2] =~ s/\s+$//g;
      $network{quality} = $fields1[1];
      $network{force} = $fields1[2];
    } 
    if ($fields[0] =~ /^Signal level/) {
      $fields[0] =~ s/Signal level=//g;
      @fields1 = split(/\//,$fields[0]);
      $fields1[2] =~ s/\s+$//g;
      $network{quality} = $fields1[1];
      $network{force} = $fields1[0];

    } 
    
  }

   push @networks, \%network;
   $maintemplate->param('networks', \@networks);

}

$template_title = $SL{'NETWORK.WIDGETLABEL'};

LoxBerry::Web::lbheader($template_title, 'nopanels', undef);
print $maintemplate->output();
LoxBerry::Web::foot();
# LoxBerry::Web::lbfooter();


exit;
