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
my $scriptversion="1.4.0.2";

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
                package => 'Plugin Installation',
                name => 'Update Check',
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
# Parse command line options
##########################################################################

my $checkonly;
foreach my $arg(@ARGV) {
	$checkonly = 1 if (lc($arg) eq "--checkonly");
	$checkonly = 1 if (lc($arg) eq "-c");
}

##########################################################################
# Parse Plugins
##########################################################################

foreach (@plugins) {

	$pid = $_->{PLUGINDB_MD5_CHECKSUM};
	$currentver = $_->{PLUGINDB_VERSION};
	$plugintitle = $_->{PLUGINDB_TITLE};
	$pluginname = $_->{PLUGINDB_NAME};
	$pluginmd5 = $_->{PLUGINDB_MD5_CHECKSUM};
	$installarchive = "";

	LOGINF "$pluginname: Found plugin $_->{PLUGINDB_TITLE}.";

	#
	# Checks
	#
	if ( !version::is_lax(vers_tag($currentver)) ) {
		LOGCRIT "$pluginname: Cannot check plugin's version number. Is this a real version number? $currentver. Skipping...";
		next;
	} else {
		$currentver = version->parse(vers_tag($currentver));
		LOGINF "$pluginname: Current version is: $currentver";
	}
	
	if (!$_->{PLUGINDB_AUTOUPDATE}) {
		LOGINF "$pluginname: Provide no automatic updates. Skipping.";
		next;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "1") {
		LOGINF "$pluginname: Automatic updates are disabled. Skipping.";
		next;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "2") {
		LOGINF "$pluginname: NOTIFY about new versions is enabled.";
		$notify = 1;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "3") {
		LOGINF "$pluginname: RELEASES enabled.";
		$release = 1;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "4") {
		LOGINF "$pluginname: PRERELEASES enabled.";
		$release = 1;
		$prerelease = 1;
	}
	else {
		LOGINF "$pluginname: Unknown option ($_->{PLUGINDB_AUTOUPDATE}). Skipping.";
		next;
	}

	if($checkonly) {
		LOGINF "$pluginname: Commandline parameter --checkonly. Checking for updates only. No installations will be done.";
		$notify = 1;
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
		LOGCRIT "$pluginname: No RELEASE or PRERELEASE URL in plugin configuration. Skipping...";
		next;
	}

	#
	# Check for a release
	#
	
	my $installtype;
	
	if ( ($release || $notify) && $endpointrelease ) {

		LOGINF "$pluginname: Requesting release file from $endpointrelease";
		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointrelease  2>&1`;
		if ($? ne 0) {
			LOGCRIT "$pluginname: Could not fetch RELEASE file. Error: $resp Skipping this plugin...";
			next;
		} else {
			LOGOK "$pluginname: Release file fetched.";
			$releasecfg = new Config::Simple("$releasefile");
			$releasever = $releasecfg->param("AUTOUPDATE.VERSION");
			$releasearchive = $releasecfg->param("AUTOUPDATE.ARCHIVEURL");
			$releaseinfo = $releasecfg->param("AUTOUPDATE.INFOURL");

			if ( version::is_lax(vers_tag($releasever)) ) {
				$releasever = version->parse(vers_tag($releasever));
				LOGINF "$pluginname: Found release version: $releasever";
			} else {
				LOGCRIT "$pluginname: Cannot check release version number. Is this a real version number?";
			}

			if ( $releasever > $currentver ) {
				LOGINF "$pluginname: Release version is newer than current installed version.";
				$installversion = $releasever;
				$installtype = "release";
				if ( !$notify ) {
					$installarchive = $releasearchive;
				} else {
					my @notifications = get_notifications( 'plugininstall', "lastnotified-rel-$pluginname");
					my $last_notified_version;
					$last_notified_version = $notifications[0]->{version} if ($notifications[0]);
					delete_notifications('plugininstall', "lastnotified-rel-$pluginname");
					my %notification = (
								PACKAGE => "plugininstall",
								NAME => "lastnotified-rel-$pluginname",
								MESSAGE => "This helper notification keeps track of last notified release of $plugintitle",
								SEVERITY => 7,
								pluginname => $pluginname,
								pluginmd5 => $pluginmd5,
								version => "$releasever",
								installarchive => "$releasearchive",
								releaseinfo => $releaseinfo,
								type => "release",
								LINK => $releaseinfo
					);
					LoxBerry::Log::notify_ext( \%notification );
					if ($last_notified_version && $last_notified_version eq "$releasever") {
						LOGOK "$pluginname: Skipping notification because version has already been notified.";
					} elsif ($checkonly) {
						LOGINF "$pluginname: Skipping notification because of --checkonly parameter. This is an interactive call.";
					} else {
						$message = "$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_RELEASE_AVAILABLE'} $installversion\n";
						$message .= $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INSTRUCTION'};
						notify ( "plugininstall", "$pluginname", $message);
						LOGINF "$pluginname: Notification saved.";
					}
				
				}

			} else {
				# Installed version is equal or newer. Helper notification can be deleted.
				LOGINF "$pluginname: Release version is not newer than installed version.";
				delete_notifications('plugininstall', "lastnotified-rel-$pluginname");
			}

		}
	}
	
	#
	# Check for a prerelease
	#
	if ( ($prerelease || $notify) && $endpointprerelease ) {

		LOGINF "$pluginname: Requesting prerelease from $endpointprerelease";

		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointprerelease  2>&1`;
		if ($? ne 0) {
			LOGCRIT "$pluginname: Could not fetch PRERELEASE file. Error: $resp Skipping this plugin...";
			next;
		} else {
			LOGOK "$pluginname: Prerelease file fetched.";
			$prereleasecfg = new Config::Simple("$releasefile");
			$prereleasever = $prereleasecfg->param("AUTOUPDATE.VERSION");
			$prereleasearchive = $prereleasecfg->param("AUTOUPDATE.ARCHIVEURL");
			$prereleaseinfo = $prereleasecfg->param("AUTOUPDATE.INFOURL");

			if ( version::is_lax(vers_tag($prereleasever)) ) {
				$prereleasever = version->parse(vers_tag($prereleasever));
				LOGINF "$pluginname: Found prerelease version: $prereleasever";
			} else {
				LOGCRIT "$pluginname: Cannot check prerelease version number. Is this a real version number?";
			}

			if ( $prereleasever > $releasever && $prereleasever > $currentver) {
				LOGINF "$pluginname: Prerelease version is newer than release version, and newer than installed version.";
				$installversion = $prereleasever;
				$installtype = "prerelease";
				if ( !$notify ) {
					$installarchive = $prereleasearchive;
				} else {
					my @notifications = get_notifications( 'plugininstall', "lastnotified-prerel-$pluginname");
					my $last_notified_version;
					$last_notified_version = $notifications[0]->{version} if ($notifications[0]);
					delete_notifications('plugininstall', "lastnotified-prerel-$pluginname");
					my %notification = (
								PACKAGE => "plugininstall",
								NAME => "lastnotified-prerel-$pluginname",
								MESSAGE => "This helper notification keeps track of last notified pre-release of $plugintitle",
								SEVERITY => 7,
								pluginname => $pluginname,
								pluginmd5 => $pluginmd5,
								version => "$prereleasever",
								installarchive => "$prereleasearchive",
								releaseinfo => $prereleaseinfo,
								type => "prerelease",
								LINK => $prereleaseinfo
						);
					LoxBerry::Log::notify_ext( \%notification );
					if ($last_notified_version && $last_notified_version eq "$prereleasever") {
						LOGOK "$pluginname: Skipping notification because version has already been notified.";
					} elsif ($checkonly) {
						LOGINF "$pluginname: Skipping notification because of --checkonly parameter. This is an interactive call.";
					} else {
						$message = "$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_PRERELEASE_AVAILABLE'} $installversion\n";
						$message .= $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INSTRUCTION'};
						notify ( "plugininstall", "$pluginname", $message);
						LOGINF "$pluginname: Notification saved.";
					}
				}
			} else {
				LOGINF "$pluginname: Prerelease version is not newer than release version.";
				delete_notifications('plugininstall', "lastnotified-prerel-$pluginname");
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
			LOGCRIT "$pluginname: Could not fetch archive file. Error: $resp. Skipping this plugin...";
			next;

		} else {

			# Installation
			LOGOK "$pluginname: Archive file fetched.";
			LOGINF "$pluginname: Installing new RELEASE... Logs are going to the plugin's install logfile. Please be patient..." if ($installtype eq "release");
			LOGINF "$pluginname: Installing new PRE-RELEASE... Logs are going to the plugin's install logfile. Please be patient..." if ($installtype eq "prerelease");

			$logfile = "/tmp/$tempfile.log";
			system ("sudo $lbhomedir/sbin/plugininstall.pl action=autoupdate pid=$pid file=/tmp/pluginsupdate/$tempfile.zip cgi=1 tempfile=$tempfile > $logfile 2>&1");
			LOGINF "$pluginname: Installation routine finished. Check plugin's logfile for details.";

			# Create notification
			if ($? eq 0 ) {
				$message = "$pluginname - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_DONE'} $installversion";
				notify ( "plugininstall", "pluginautoupdate", $message);
				delete_notifications('plugininstall', "lastnotified-prerel-$pluginname") if ($installtype eq "release");
				delete_notifications('plugininstall', "lastnotified-rel-$pluginname") if ($installtype eq "prerelease" || $installtype eq "release");
			}

		}

	}

}

# Clean up
LOGINF "Deleting temporary files.";
system ("rm -rf $update_path");

LOGEND "$0 finished.";
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

