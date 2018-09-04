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
use Digest::MD5 qw( md5_hex );

if ($<) {
	print "This script has to be run as root.\n";
	exit (1);
}

my $logfilename = "$lbhomedir/log/system_tmpfs/setswap.log";
my $log = LoxBerry::Log->new ( package => "core", name => "setswap", filename => $logfilename, append => 1, addtime => 1 );

$log->loglevel(6);
LOGSTART "LogBerry setswap";
$log->stdout(1);

my $output = qx { which swapon };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGERR "dphys-swapfile seems not be be installed. Giving up.";
	exit 1;
}

if ( !-e "$lbhomedir/system/dphys-swapfile/97-swappiness.conf" || !-e "$lbhomedir/system/dphys-swapfile/dphys-swapfile" ) {
        LOGERR "Could not find all needed config files. Giving up.";
	exit 1;
}

$output = qx { service dphys-swapfile stop };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGWARN "Could not stop service dphys-swapfile.";
}

$output = qx { swapoff -a };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
        LOGWARN "Could not turn off all swap files.";
}

$output = qx { rm -r /var/swap };
$output = qx { rm -r /etc/dphys-swapfile };
$output = qx { rm -r /etc/sysctl.d/97-swappiness.conf };

# Check if $lbhomedir/system/dphys-swapfile/dphys-swapfile was modified
my $currmd5;
if ( -e "$lbhomedir/system/dphys-swapfile/dphys-swapfile" ) {
	open my $fh, '<', "$lbhomedir/system/dphys-swapfile/dphys-swapfile";
		$currmd5 = Digest::MD5->new->addfile($fh)->hexdigest;
	close $fh;
} else {
        LOGERR "dphys-swapfile config cannot be found at $lbhomedir/system/dphys-swapfile/dphys-swapfile. Giving up.";
	exit 1;
}
my $oldmd5;
if ( -e "$lbhomedir/system/dphys-swapfile/dphys-swapfile.md5" ) {
	open my $fh, '<', "$lbhomedir/system/dphys-swapfile/dphys-swapfile.md5";
		$oldmd5 = <$fh>;
	close $fh;
}

# Create new $lbhomedir/system/dphys-swapfile/dphys-swapfile
if ( $currmd5 eq $oldmd5 || !-e "$lbhomedir/system/dphys-swapfile/dphys-swapfile.md5" ) {
	LOGINF "Creating new $lbhomedir/system/dphys-swapfile/dphys-swapfile";
	my %folderinfo = LoxBerry::System::diskspaceinfo('/var');
	my $free = sprintf "%.0f",$folderinfo{available}/1000;
	my $maxswap = sprintf "%.0f",$free/2;
	LOGINF "Free discspace on /var is $free MB. Using a maximum of 50% ($maxswap MB) for SWAP file.";
	$output = qx { awk -v s="CONF_MAXSWAP=$maxswap" '/^CONF_MAXSWAP=/{\$0=s;f=1} {a[++n]=\$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $lbhomedir/system/dphys-swapfile/dphys-swapfile };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
        	LOGWARN "Could not change $lbhomedir/system/dphys-swapfile/dphys-swapfile";
	}
	open my $fh, '<', "$lbhomedir/system/dphys-swapfile/dphys-swapfile";
		$currmd5 = Digest::MD5->new->addfile($fh)->hexdigest;
	close $fh;
	open my $fh, '>', "$lbhomedir/system/dphys-swapfile/dphys-swapfile.md5";
		print $fh "$currmd5";
	close $fh;
} else {
       	LOGWARN "It seems that $lbhomedir/system/dphys-swapfile/dphys-swapfile was changed manually. Leaving it untouched.";
}

# Check if $lbhomedir/system/dphys-swapfile/97-swappiness.conf was modified
if ( -e "$lbhomedir/system/dphys-swapfile/97-swappiness.conf" ) {
	open my $fh, '<', "$lbhomedir/system/dphys-swapfile/97-swappiness.conf";
		$currmd5 = Digest::MD5->new->addfile($fh)->hexdigest;
	close $fh;
} else {
        LOGERR "97-swappiness.conf cannot be found at $lbhomedir/system/dphys-swapfile/97-swappiness.conf. Giving up.";
	exit 1;
}
if ( -e "$lbhomedir/system/dphys-swapfile/97-swappiness.conf.md5" ) {
	open my $fh, '<', "$lbhomedir/system/dphys-swapfile/97-swappiness.conf.md5";
		$oldmd5 = <$fh>;
	close $fh;
}

# Create new $lbhomedir/system/dphys-swapfile/97-swappiness.conf
if ( $currmd5 eq $oldmd5 || !-e "$lbhomedir/system/dphys-swapfile/97-swappiness.conf.md5" ) {
	LOGINF "Creating new $lbhomedir/system/dphys-swapfile/97-swappiness.conf";
	LOGINF "Set swappiness to 1.";
	open my $fh, '>', "$lbhomedir/system/dphys-swapfile/97-swappiness.conf";
		print $fh "vm.swappiness = 1";
	close $fh;
	open my $fh, '<', "$lbhomedir/system/dphys-swapfile/97-swappiness.conf";
		$currmd5 = Digest::MD5->new->addfile($fh)->hexdigest;
	close $fh;
	open my $fh, '>', "$lbhomedir/system/dphys-swapfile/97-swappiness.conf.md5";
		print $fh "$currmd5";
	close $fh;
	$output = qx { sysctl vm.swappiness=1 };
	$exitcode  = $? >> 8;
	if ($exitcode != 0) {
        	LOGWARN "Could not activate sysctl vm.swappiness=1 We will try it on next reboot again.";
	}
} else {
       	LOGWARN "It seems that $lbhomedir/system/dphys-swapfile/97-swappiness.conf was changed manually. Leaving it untouched.";
}

LOGINF "Creating symbolic links...";
$output = qx { ln -s $lbhomedir/system/dphys-swapfile/97-swappiness.conf /etc/sysctl.d/97-swappiness.conf };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Cannot create needed symlink to $lbhomedir/system/dphys-swapfile/97-swappiness.conf.";
}
$output = qx { ln -s $lbhomedir/system/dphys-swapfile/dphys-swapfile /etc/dphys-swapfile };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Cannot create needed symlink to $lbhomedir/system/dphys-swapfile/dphys-swapfile.";
}

LOGINF "Reactivating Swap...";
$output = qx { service dphys-swapfile start };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Cannot start service dphys-swapfile.";
}

LOGEND "Finished successfully.";
exit;
