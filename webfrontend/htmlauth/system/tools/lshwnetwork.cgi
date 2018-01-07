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

use LoxBerry::System;
use LoxBerry::Web;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $cfg;
my $template_title;
my @fields;
my $table;
my @result;
my $i;
my $version;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.3.2.2";

$cfg             = new Config::Simple('$lbsconfigdir/general.cfg');

#########################################################################
# Parameter
#########################################################################


##########################################################################
# Language Settings
##########################################################################

my $lang = lblanguage();

our $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/lshwnetwork.html",
				global_vars => 0,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				# associate => $cfg,
				#debug => 1,
				#stack_debug => 1,
				);

my %SL = LoxBerry::Web::readlanguage($maintemplate);

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
    $table = "$table<tr><td colspan=2><b>$i. " . $SL{'NETWORK.LSHW_LABEL_NETWORKDEVICE'} . "</b></td></tr>\n";
    $i++;
  }
  if ($fields[0] eq "description") {
    $fields[1] =~ s/ interface//g;
    $table = "$table<tr><td>" . $SL{'NETWORK.LSHW_LABEL_INTERFACE'} . "</td><td>$fields[1]</td></tr>\n";
  }
  if ($fields[0] eq "logical name") {
    $table = "$table<tr><td>" . $SL{'NETWORK.LSHW_LABEL_PORT'} . "</td><td>$fields[1]</td></tr>\n";
  }
  if ($fields[0] eq "serial") {
    $table = "$table<tr><td>" . $SL{'NETWORK.LSHW_LABEL_MACADDRESS'} . "</td><td>$fields[1]</td></tr>\n";
  }
  if ($fields[0] eq "configuration") {
    $fields[1]=trim($fields[1]);
	my @configarray = split(/ /, $fields[1]);
	foreach my $setting (@configarray) {
		my ($key, $value) = split(/=/, $setting);
		if ($key eq "driver") 
			{ $table = "$table<tr><td>" . $SL{'NETWORK.LSHW_LABEL_KERNELDRIVER'} . "</td><td>$value</td></tr>\n";
		} elsif ($key eq "ip") {
			$table = "$table<tr><td>" . $SL{'NETWORK.LSHW_LABEL_IPADDRESS'} . "</td><td>$value</td></tr>\n";
		} elsif ($key eq "speed") {
			$table = "$table<tr><td>" . $SL{'NETWORK.LSHW_LABEL_SPEED'} . "</td><td>$value</td></tr>\n";
		}
	}
  }
  
}

$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . " - " . $SL{'NETWORK.WIDGETLABEL'};
$maintemplate->param('TABLE' => $table);
LoxBerry::Web::head();
print $maintemplate->output();
LoxBerry::Web::foot();

exit;
