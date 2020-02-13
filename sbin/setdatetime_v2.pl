#!/usr/bin/perl

# Copyright 2016-2020 Michael Schlenstedt, michael@loxberry.de
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

use LoxBerry::Log;
use LoxBerry::IO;
use LoxBerry::JSON;

my $log = LoxBerry::Log->new ( 
	name => 'setdatetime', 
	package => 'core', 
	addtime => 1, 
	stderr => 1, 
	logdir => $lbstmpfslogdir,
	loglevel => 7);
LOGSTART "Sync time";

# Version of this script
my $version = "2.0.2.2";
LOGINF "Version of setdatetime: $version";

my $cfgfile = $lbsconfigdir."/general.json";

LOGINF "Opening general.json ($cfgfile)";
my $jsonobj = LoxBerry::JSON->new();
my $cfg = $jsonobj->open( filename => $cfgfile, readonly => 1 );
if (!$cfg) {
    LOGWARN "Could not load config. Using fallback defaults.";
} else {
    LOGOK "Configuration loaded";
}

LOGINF "Reading config to local variables...";
my $ts = $cfg->{Timeserver};

$method = $ts->{Method};
$timezone = $ts->{Timezone};
$timeserver = $ts->{Ntpserver};
$timemsno = $ts->{Timemsno};

LOGWARN "Method not defined - using default" if( ! defined $method );
LOGWARN "Timezone not defined - using default" if( ! defined $timezone );
LOGWARN "Timeserver not defined - using default" if( ! defined $timeserver and $method eq 'ntp' );
LOGWARN "Miniserver not defined - using MS 1" if( ! defined $timemsno and $method eq 'miniserver' );

# Default values:
$method = defined $method ? $method : "ntp";
$timezone = defined $timezone ? $timezone : "Europe/Berlin";
$timeserver = defined $timeserver ? $timeserver : "0.pool.ntp.org";
$timemsno = defined $timemsno ? $timemsno : 1;

my %miniservers;
if( $method eq 'miniserver' ) {
	# Check if configured Miniserver exists
	%miniservers = LoxBerry::System::get_miniservers();
	if( ! defined %miniservers{$timemsno} and $timemsno != 1) {
		$timemsno = 1;
	}
	if( ! defined %miniservers{$timemsno} ) {
			LOGCRIT "Cannot aquire Miniserver - Miniserver configuration completed?";
			exit(1);
	}
}

LOGDEB "Current values used:";
LOGDEB "Timezone:    $timezone";
LOGDEB "Time method: $method";
LOGDEB "Miniserver:  $miniservers{$timemsno}{Name}" if( $method eq 'miniserver' );
LOGDEB "NTP Server:  $timeserver" if( $method eq 'ntp' );

LOGINF "Setting timezone";

my $timezoneresult = qx(sudo /usr/bin/timedatectl set-timezone "$timezone");
LOGINF "Setting Timezone to '$timezone'";
LOGDEB "Result: $timezoneresult" if( $timezoneresult );

$timezoneresult = qx(/usr/bin/timedatectl status);
LOGINF "Timezone status:\n$timezoneresult";

if( $method eq 'miniserver') {
	my $value;
	my $status;
	my $code;
	my $year;
	my $mon;
	my $day;
	my $hour;
	my $min;
	my $sec;
	
	eval {
		LOGTITLE "Time sync with Miniserver $miniservers{$timemsno}{Name}";
		
		# Getting time
		LOGINF "Getting time from Miniserver $timemsno ($miniservers{$timemsno}{Name})...";
		($value, $status, $resp) = LoxBerry::IO::mshttp_call($timemsno, "/dev/sys/time");
		LOGDEB "Response $resp";
		if($status < 200 or $status >= 300) {
			LOGCRIT "Could not get time from Miniserver";
			LOGDEB "Status $status";
			exit(1);
		}
		( $hour, $min, $sec ) = split(':', $value);
		
		# Getting date
		LOGINF "Getting date from Miniserver $timemsno ($miniservers{$timemsno}{Name})...";
		($value, $status, $resp) = LoxBerry::IO::mshttp_call($timemsno, "/dev/sys/date");
		LOGDEB "Response $resp";
		if($status < 200 or $status >= 300) {
			LOGCRIT "Could not get date from Miniserver";
			LOGDEB "Status $status";
			exit(1);
		}
		( $year, $mon, $day ) = split('-', $value);
		
		LOGINF "Setting LoxBerry time to Miniserver time: $year-$mon-$day $hour:$min:$sec";
		my $output = qx(sudo date -s '$year-$mon-$day $hour:$min:$sec');
		LOGINF "Response: $output";
	};
	if($@) {
		LOGCRIT "Updating time from Miniserver failed: $@";
	}
	exit(0);
}

if ( $method eq 'ntp' ) {
	LOGTITLE "Time sync with NTP server $timeserver";
	LOGINF "Updating time with NTP server $timeserver ...";
	my $output = qx(sudo ntpdate -u $timeserver);
	LOGINF "Response: $output";
	exit(0);
}

LOGTITLE "Unknown time sync method";
LOGCRIT "Unknown time sync method. Check your Timeserver configuration";
exit(1);


END 
{
	if (defined $log) {
		LOGEND "Execution end";
	}
}