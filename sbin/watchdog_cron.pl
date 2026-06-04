#!/usr/bin/perl

# Copyright 2019 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::JSON;
use warnings;
use strict;

##########################################################################
# Read Settings
##########################################################################

my $version = "1.4.2.2";
my $cfgfilejson = "$lbsconfigdir/general.json";
my $jsonobj = LoxBerry::JSON->new();
my $cfgjson = $jsonobj->open(filename => $cfgfilejson);
my $now = currtime("hr");

##########################################################################
# Log values
##########################################################################
open(my $fh, '>>', "$lbslogdir/watchdogdata.log");
	flock($fh,2);

	my $sensor = $cfgjson->{Watchdog}->{Tempsensor};
	print $fh "$now ";
	if (-e "$sensor") {
		my $temp = qx(cat $sensor);
		chomp $temp;
		$temp = sprintf("%.1f", $temp/1000);
	
		my $errlimit = $cfgjson->{Watchdog}->{Maxtemp} * 0.90;
		my $warnlimit = "60";

		if ($temp < $warnlimit) {
			print $fh "<OK> ";
		} elsif ($temp < $errlimit) {
			print $fh "<WARNING> ";
		} else {
			print $fh "<ERROR> ";
		}
		print $fh "CPU Temperature is $temp C.\n";
	} else {
		print $fh "<INFO> No temp data available.\n";
	}

	print $fh "$now ";
	if (-e "/sys/devices/platform/soc/soc:firmware/get_throttled") {

			my $message;
			my $output = qx(cat /sys/devices/platform/soc/soc:firmware/get_throttled);
			chomp $output;
	
			## DEBUG
			# $output = "10005";
			# $output = "10003";
			# $output = "5";
	
			my $byte1 = length($output)>0 ? substr( $output, -2 ) : 0 ;
			my $byte2 = length($output)>=3 ? substr( $output, -4, 2 ) : 0;
			my $byte3 = length($output)>=5 ? substr( $output, -6, 2 ) : 0;

			# print STDERR "Byte3 | Byte2 | Byte1\n";
			# print STDERR "  $byte3  |  $byte2  |  $byte1\n";
	
			my @bits;
			# See https://github.com/mschlenstedt/Loxberry/issues/952
			$bits[0] = ($byte1 >> 0) & 0x01;
			$bits[1] = ($byte1 >> 1) & 0x01;
			$bits[2] = ($byte1 >> 2) & 0x01;
			$bits[3] = ($byte1 >> 3) & 0x01;
			$bits[16] = ($byte3 >> 0) & 0x01;
			$bits[17] = ($byte3 >> 1) & 0x01;
			$bits[18] = ($byte3 >> 2) & 0x01;
			$bits[19] = ($byte3 >> 3) & 0x01;
		
			if($bits[0]) {
				$message .="(0) Under-voltage detected. ";
			}
			if($bits[1]) {
				$message .= "(1) ARM frequency capped. ";
			}
			if($bits[2]) {
				$message .= "(2) Currently throttled. ";
			}
			if($bits[3]) {
				$message .= "(3) Soft temperature limit active. ";
			}
			if($bits[16]) {
				$message .="(16) Under-voltage has occurred. ";
			}
			if($bits[17]) {
				$message .= "(17) Arm frequency capped has occurred. ";
			}
			if($bits[18]) {
				$message .= "(18) Throttling has occurred ";
			}
			if($bits[19]) {
				$message .= "(19) Soft temperature limit has occurred ";
			}
			if ($message) {
				$message = "<ERROR> $message";
			} else {
				$message = "<OK> No under-voltage nor system throttling nor capped ARM frequency detected."
			}
			print $fh "$message\n";

	} else {

		print $fh "<INFO> No throttling data available\n";

	}

	flock($fh,8);
close ($fh);

# Clean Up: Max. 24h
open($fh, "+<", "$lbslogdir/watchdogdata.log");
	flock($fh,2);
	my @data = <$fh>;
	my $i;
  	foreach (@data){
		$i++;
	}
  	seek($fh,0,0);
	truncate($fh,0);
	foreach (@data){
		if ($i > 2880) {
			$i--;
			next;
		}
		print $fh $_;
	}
	flock($fh,8);
close ($fh);

exit;
