#!/usr/bin/perl

# Copyright 2018 Michael Schlenstedt, michael@loxberry.de
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

use LoxBerry::Log;

if ($<) {
	print "This script has to be run as root.\n";
	exit (1);
}

my $logfilename = "$lbhomedir/log/system_tmpfs/setswap.log";
my $log = LoxBerry::Log->new ( package => "core", name => "setswap", filename => $logfilename, append => 1, addtime => 1 );

LOGSTART "LogBerry Setswap";
$log->stdout(1);

if (-e "/boot/dietpi/.hw_model") {
        LOGiOK "This is a DietPi system. Swap is handled by DietPi. Nothing to do.";
	exit 0;
}

my $output = qx { which dphys-swapfile };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "dphys-swapfile seems not be be installed. Giving up.";
	exit 1;
}

if ( !-e "$lbhomedir/system/dphys-swapfile/97-swappiness.conf" || !-e "$lbhomedir/system/dphys-swapfile/dphys-swapfile" ) {
        LOGERR "Could not find all needed config files. Giving up.";
	exit 1;
}

# Check if we should change something
my $currentsize = -s "/var/swap"; # Bytes
my %folderinfo = LoxBerry::System::diskspaceinfo('/var');
my $free = $folderinfo{available}*1024 + $currentsize; # Bytes
$free = sprintf "%.0f",$free / 1024 / 1024; # Megabytes
my $maxswap = sprintf "%.0f",$free/4; # Use a maximum of 25% free discspace
if ($maxswap > 2048) {$maxswap = 2048}; # Limit to 2048 MB

# Create new $lbhomedir/system/dphys-swapfile/dphys-swapfile
LOGINF "Creating new $lbhomedir/system/dphys-swapfile/dphys-swapfile";
LOGINF "Free discspace on /var is $free MB. Using a maximum of $maxswap MB for SWAP file.";
$output = qx { awk -v s="CONF_MAXSWAP=$maxswap" '/^CONF_MAXSWAP=/{\$0=s;f=1} {a[++n]=\$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $lbhomedir/system/dphys-swapfile/dphys-swapfile };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
       	LOGWARN "Could not change $lbhomedir/system/dphys-swapfile/dphys-swapfile";
}

# Setup dphys-swapfile
LOGINF "Setup dphys-swapfile...";
$output = qx { /sbin/dphys-swapfile setup };
chomp $output;
LOGINF "$output";
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Cannot setup dphys-swapfile.";
} else {
	LOGOK "Setup dphys-swapfile successfully.";
}

# Enable Swap
LOGINF "Enable dphys-swapfile...";
$output = qx { systemctl enable dphys-swapfile };
chomp $output;
LOGINF "$output";
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Cannot enable dphys-swapfile.";
} else {
	LOGOK "Enabling dphys-swapfile successfully.";
}

# Start Swap
LOGINF "Start dphys-swapfile...";
$output = qx { systemctl restart dphys-swapfile };
chomp $output;
LOGINF "$output";
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Cannot start dphys-swapfile.";
} else {
	LOGOK "Starting dphys-swapfile successfully.";
}

LOGEND "Finished successfully.";
exit 0;
