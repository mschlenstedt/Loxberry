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


##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
#use strict;
#use warnings;
use version;


##########################################################################
# Global
##########################################################################

# Version of this script
my $scriptversion="1.0.0.0";

# Global vars
my $update_path = '/tmp/pluginsupdate';
my $cfg = new Config::Simple("$lbsconfigdir/general.cfg");
my $bins = LoxBerry::System::get_binaries();
my @plugins = LoxBerry::System::get_plugins();
my $endpointrelease;
my $endpointprerelease;
my $notify;
my $prerelease;
my $prereleasefile = "/tmp/pluginsupdate/prerelease.cfg";
my $prereleasecfg;
my $prereleasearchive;
my $prereleaseinfo;
my $prereleasever;
my $release;
my $releasefile = "/tmp/pluginsupdate/release.cfg";
my $releasecfg;
my $releasever;
my $releasearchive;
my $releaseinfo;
my $pid;
my $currentver;
my $resp;
my $installarchive;
my $installversion;
my $tempfile;
my $openerr;
my $timestamp;
my $pluginname;
my $message;
my $check;

# Language
my $lang = lblanguage();

# Read phrases from language_LANG.ini
my %SL = LoxBerry::System::readlanguage(undef);

# Creating temp folder
system ("rm -rf $update_path");
system ("mkdir -p $update_path");


##########################################################################
# Logfile
##########################################################################

my $log = LoxBerry::Log->new(
                package => 'Plugins Update',
                name => 'check',
                filename => "$lbhomedir/log/system_tmpfs/pluginsupdatecheck.log",
                loglevel => 7,
                stderr => 1,
                append => 1,
);

LOGSTART "LoxBerry Plugins Update Check";
LOGINF "Version of $0 is $scriptversion";

my $curruser = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
LOGINF "Executing user of $0 is $curruser";


##########################################################################
# Parse Plugins
##########################################################################

foreach (@plugins) {

	$pid = $_->{PLUGINDB_MD5_CHECKSUM};
	$currentver = $_->{PLUGINDB_VERSION};
	$plugintitle = $_->{PLUGINDB_TITLE};
	$pluginname = $_->{PLUGINDB_NAME};
	$installarchive = "";

	LOGINF "$_->{PLUGINDB_NAME}: Found plugin $_->{PLUGINDB_TITLE}.";

	#
	# Checks
	#
	if ( !version::is_lax($currentver) ) {
		LOGCRIT "Cannot check plugin's version number. Is this a real version number? $currentver. Skipping...";
		next;
	} else {
		$currentver = version->parse($currentver);
		LOGINF "Current version is: $currentver";
	}
	
	if (!$_->{PLUGINDB_AUTOUPDATE}) {
		LOGINF "$_->{PLUGINDB_NAME}: Provide no automatic updates. Skipping.";
		next;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "1") {
		LOGINF "$_->{PLUGINDB_NAME}: Automatic updates are disabled. Skipping.";
		next;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "2") {
		LOGINF "$_->{PLUGINDB_NAME}: NOTIFY about new versions is enabled.";
		$notify = 1;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "3") {
		LOGINF "$_->{PLUGINDB_NAME}: RELEASES enabled.";
		$release = 1;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "4") {
		LOGINF "$_->{PLUGINDB_NAME}: PRERELEASES enabled.";
		$release = 1;
		$prerelease = 1;
	}
	else {
		LOGINF "$_->{PLUGINDB_NAME}: Unknown option ($_->{PLUGINDB_AUTOUPDATE}). Skipping.";
		next;
	}

	# Read URLs from shadowed plugindatabase for security reasons)
	my @pluginsshadow = LoxBerry::System::get_plugins(0,1,"$lbsdatadir/plugindatabase.dat-");
	foreach (@pluginsshadow) {
		if ($_->{PLUGINDB_MD5_CHECKSUM} eq $pid) {
 			$endpointrelease = $_->{PLUGINDB_RELEASECFG};
 			$endpointprerelease = $_->{PLUGINDB_PRERELEASECFG};
		}
	}

	if ( !$endpointrelease && !$endpointprerelease ) {
		LOGCRIT "No RELEASE or PRERELEASE URL in plugin configuration. Skipping...";
		next;
	}

	#
	# Check for a release
	#
	if ( ($release || $notify) && $endpointrelease ) {

		LOGINF "Requesting release file from $endpointrelease";
		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointrelease  2>&1`;
		if ($? ne 0) {
			LOGCRIT "Could not fetch RELEASE file. Error: $resp Skipping this plugin...";
			next;
		} else {
			LOGOK "Release file fetched.";
			$releasecfg = new Config::Simple("$releasefile");
			$releasever = $releasecfg->param("AUTOUPDATE.VERSION");
			$releasearchive = $releasecfg->param("AUTOUPDATE.ARCHIVEURL");
			$releaseinfo = $releasecfg->param("AUTOUPDATE.INFOURL");

			if ( version::is_lax($releasever) ) {
				$releasever = version->parse($releasever);
				LOGINF "Found release version: $releasever";
			} else {
				LOGCRIT "Cannot check release version number. Is this a real version number?";
			}

			if ( $releasever > $currentver ) {
				LOGINF "Release version is newer than current installed version.";
				$installversion = $releasever;
				if ( !$notify ) {
					$installarchive = $releasearchive;
				} else {
					$message = "<p>$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_AVAILABLE'} $installversion</p>\n";
					$message .= "<p><a href='$releaseinfo' target='_blank'>$SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INFOBUTTON'}</a></p>\n";
					$message .= "<p><a href='$releasearchive'>$SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_DOWNLOADBUTTON'}</a></p>\n";
					$message .= "<p><a href='#install'>$SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INSTALLBUTTON'}</a></p>";
					notify ( "plugininstall", "$pluginname", $message);
					sleep 1;
				}
			} else {
				LOGINF "Release version is not newer than installed version.";
			}

		}

	}
	
	#
	# Check for a prerelease
	#
	if ( ($prerelease || $notify) && $endpointprerelease ) {

		LOGINF "Requesting prerelease from $endpointprerelease";

		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointprerelease  2>&1`;
		if ($? ne 0) {
			LOGCRIT "Could not fetch PRERELEASE file. Error: $resp Skipping this plugin...";
			next;
		} else {
			LOGOK "Prerelease file fetched.";
			$prereleasecfg = new Config::Simple("$releasefile");
			$prereleasever = $prereleasecfg->param("AUTOUPDATE.VERSION");
			$prereleasearchive = $prereleasecfg->param("AUTOUPDATE.ARCHIVEURL");
			$prereleaseinfo = $prereleasecfg->param("AUTOUPDATE.INFOURL");

			if ( version::is_lax($prereleasever) ) {
				$prereleasever = version->parse($prereleasever);
				LOGINF "Found prerelease version: $prereleasever";
			} else {
				LOGCRIT "Cannot check prerelease version number. Is this a real version number?";
			}

			if ( $prereleasever > $releasever ) {
				LOGINF "Prerelease version is newer than release version.";
				$installversion = $prereleasever;
				if ( !$notify ) {
					$installarchive = $releasearchive;
				} else {
					$message = "<p>$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_AVAILABLE'} $installversion</p>\n";
					$message .= "<p><a href='$prereleaseinfo' target='_blank'>$SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INFOBUTTON'}</a></p>\n";
					$message .= "<p><a href='$prereleasearchive'>$SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_DOWNLOADBUTTON'}</a></p>\n";
					$message .= "<p><a href='#install'>$SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INSTALLBUTTON'}</a></p>";
					notify ( "plugininstall", "$pluginname", $message);
				}
			} else {
				LOGINF "Prerelease version is not newer than release version version.";
			}

		}

	}

	#
	# Install new version
	#
	if ($installarchive) {

		# Randomly file naming
        	$tempfile = &generate(10);
		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo /tmp/pluginsupdate/$tempfile.zip $installarchive  2>&1`;
		if ($? ne 0) {
			LOGCRIT "Could not fetch archive file. Error: $resp. Skipping this plugin...";
			next;

		} else {

			# Installation
			LOGOK "Archive file fetched.";
			LOGINF "Installing new (pre-)release... Logs are going to the plugins install logfile. Please be patient...";

			$logfile = "/tmp/$tempfile.log";
			system ("sudo $lbhomedir/sbin/plugininstall.pl action=autoupdate pid=$pid file=/tmp/pluginsupdate/$tempfile.zip cgi=1 tempfile=$tempfile > $logfile 2>&1");
			#system ("sudo $lbhomedir/sbin/plugininstall.pl action=autoupdate pid=$pid file=/tmp/pluginsupdate/$tempfile.zip cgi=1 tempfile=$tempfile");

			# Create notification
			if ($? eq 0 ) {
				$message = "$pluginname - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_DONE'} $installversion";
				notify ( "plugininstall", "pluginautoupdate", $message);
			}

		}

	}

}

# Clean up
system ("rm -rf $update_path");

exit;


#####################################################
# Random
#####################################################

sub generate {
        local($e) = @_;
        my($zufall,@words,$more);

        if($e =~ /^\d+$/){
                $more = $e;
        }else{
                $more = "10";
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}

