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

my $version = "1.4.2.0";
my $cfgfilejson = "$lbsconfigdir/general.json";
my $jsonobj = LoxBerry::JSON->new();
my $cfgjson = $jsonobj->open(filename => $cfgfilejson);
my $now = currtime("hr");

##########################################################################
# Temperature
##########################################################################
my $sensor = $cfgjson->{Watchdog}->{Tempsensor};
my $temp = qx(cat $sensor);
chomp $temp;
$temp = sprintf("%.1f", $temp/1000);

my $errlimit = $cfgjson->{Watchdog}->{Maxtemp} * 0.95;
my $warnlimit = $cfgjson->{Watchdog}->{Maxtemp} * 0.90;

open(my $fh, '>>', "$lbstmpfslogdir/healthcheck_temp.log");
	flock($fh,2);
	print $fh "$now ";
	if ($temp < $warnlimit) {
		print $fh "<OK> ";
	} elsif ($temp < $errlimit) {
		print $fh "<WARNING> ";
	} else {
		print $fh "<ERROR> ";
	}
	print $fh "CPU Temperature is $temp C.\n";
	flock($fh,8);
close ($fh);

# Clean Up: Max. 24h
my $openerr;
open($fh, "+<", "$lbstmpfslogdir/healthcheck_temp.log");
	flock($fh,2);
	my @data = <$fh>;
	my $i;
  	foreach (@data){
		$i++;
	}
  	seek($fh,0,0);
	truncate($fh,0);
	foreach (@data){
		if ($i > 96) {
			$i--;
			next;
		}
		print $fh $_;
	}
	flock($fh,8);
close ($fh);

exit;
