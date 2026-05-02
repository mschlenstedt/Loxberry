#!/usr/bin/perl

# Copyright 2018-2020 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::System::PluginDB;
use LoxBerry::PluginSemVer qw( cmp_versions has_prerelease comparable );

use strict;
use warnings;


##########################################################################
# Global
##########################################################################

# Version of this script
my $scriptversion="3.1.0.0";

# Global vars
my $update_path = '/tmp/pluginsupdate';
my $cfg = new Config::Simple("$lbsconfigdir/general.cfg");
my $bins = LoxBerry::System::get_binaries();
my @plugins = LoxBerry::System::get_plugins();
my $endpointrelease;
my $endpointprerelease;
my $prereleasefile = "/tmp/pluginsupdate/prerelease.cfg";
my $prereleasecfg;
my $prereleasearchive;
my $prereleaseinfo;
my $releasefile = "/tmp/pluginsupdate/release.cfg";
my $releasecfg;
my $releasearchive;
my $releaseinfo;
my $resp;
my $installarchive;
my $installversion;
my $openerr;
my $timestamp;
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

	my $notify;
	my $currentver_str;
	my $release;
	my $prerelease;
	my $pid;
	my $plugintitle;
	my $pluginname;
	my $pluginmd5;
	my $logfile;
	my $tempfile;


	$pid = $_->{PLUGINDB_MD5_CHECKSUM};
	$currentver_str = trim( $_->{PLUGINDB_VERSION} );
	$plugintitle = $_->{PLUGINDB_TITLE};
	$pluginname = $_->{PLUGINDB_NAME};
	$pluginmd5 = $_->{PLUGINDB_MD5_CHECKSUM};
	$installarchive = "";

	LOGINF "$pluginname: Found plugin $_->{PLUGINDB_TITLE}.";

	#
	# Checks — SemVer prereleases (-beta.N) plus legacy Perl lax versions.
	#
	if ( !comparable($currentver_str) ) {
		LOGCRIT "$pluginname: Cannot check plugin's version number. Is this a real version number? $currentver_str. Skipping...";
		next;
	}
	LOGINF "$pluginname: Current version is: $currentver_str";
	
	if (!$_->{PLUGINDB_AUTOUPDATE}) {
		LOGINF "$pluginname: Provide no automatic updates. Skipping.";
		next;
	}
	elsif ($_->{PLUGINDB_AUTOUPDATE} eq "1") {
		LOGINF "$pluginname: Automatic updates are disabled. Check only.";
		$notify = 1;
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
	my $pluginshadow = LoxBerry::System::PluginDB->plugin( 
		md5 => $pid,
		_dbfile => "$lbsdatadir/plugindatabase.json-"
	);
	if(!$pluginshadow) {
		LOGCRIT "$pluginname: Plugin $pid not found in shadow copy. Skipping...";
		next;
	}
	$endpointrelease = $pluginshadow->{releasecfg};
	$endpointprerelease = $pluginshadow->{prereleasecfg};
	
	if ( !$endpointrelease && !$endpointprerelease ) {
		LOGCRIT "$pluginname: No RELEASE or PRERELEASE URL in plugin configuration. Skipping...";
		next;
	}

	#
	# Fetch release.cfg / prerelease.cfg (SemVer prereleases + legacy lax versions)
	#
	my $installtype;

	my ( $releasever_str, $releasearchive, $releaseinfo ) =
	  ( undef, undef, undef );
	my $release_cmp_ok = 0;

	my ( $prereleasever_str, $prereleasearchive, $prereleaseinfo ) =
	  ( undef, undef, undef );
	my $prerelease_cmp_ok = 0;

	if ( ( $release || $notify ) && $endpointrelease ) {

		LOGINF "$pluginname: Requesting release file from $endpointrelease";
		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointrelease  2>&1`;
		if ( $? ne 0 ) {
			LOGCRIT "$pluginname: Could not fetch RELEASE file. Error: $resp Skipping this plugin...";
			next;
		}
		LOGOK "$pluginname: Release file fetched.";
		eval { $releasecfg = new Config::Simple("$releasefile"); };
		if ($@) {
			LOGCRIT "$pluginname: Fetched release.cfg is not a valid release file. Please report to the plugin author.";
			next;
		}
		$releasever_str = trim( $releasecfg->param("AUTOUPDATE.VERSION") );
		$releasearchive = $releasecfg->param("AUTOUPDATE.ARCHIVEURL");
		$releaseinfo    = $releasecfg->param("AUTOUPDATE.INFOURL");

		if ( !$releasever_str || !comparable($releasever_str) ) {
			LOGCRIT "$pluginname: Cannot check release version number. Is this a real version number?";
		}
		else {
			LOGINF "$pluginname: Found release version: $releasever_str";
			if ( cmp_versions( $releasever_str, $currentver_str ) > 0 ) {
				LOGINF "$pluginname: Release version is newer than current installed version.";
				$release_cmp_ok = 1;
			}
			else {
				LOGINF "$pluginname: Release version is not newer than installed version.";
				delete_notifications( 'plugininstall', "lastnotified-rel-$pluginname" );
			}
		}
	}

	if ( ( $prerelease || $notify ) && $endpointprerelease ) {

		LOGINF "$pluginname: Requesting prerelease from $endpointprerelease";
		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointprerelease  2>&1`;
		if ( $? ne 0 ) {
			LOGCRIT "$pluginname: Could not fetch PRERELEASE file. Error: $resp Skipping this plugin...";
			next;
		}
		LOGOK "$pluginname: Prerelease file fetched.";
		eval { $prereleasecfg = new Config::Simple("$releasefile"); };
		if ($@) {
			LOGCRIT "$pluginname: Fetched prerelease.cfg is not a valid release file. Please report to the plugin author.";
			next;
		}
		$prereleasever_str = trim( $prereleasecfg->param("AUTOUPDATE.VERSION") );
		$prereleasearchive = $prereleasecfg->param("AUTOUPDATE.ARCHIVEURL");
		$prereleaseinfo    = $prereleasecfg->param("AUTOUPDATE.INFOURL");

		if ( !$prereleasever_str || !comparable($prereleasever_str) ) {
			LOGCRIT "$pluginname: Cannot check prerelease version number. Is this a real version number?";
		}
		else {
			LOGINF "$pluginname: Found prerelease version: $prereleasever_str";
			if ( cmp_versions( $prereleasever_str, $currentver_str ) > 0 ) {
				LOGINF "$pluginname: Prerelease version is newer than current installed version.";
				$prerelease_cmp_ok = 1;
			}
			else {
				LOGINF "$pluginname: Prerelease version is not newer than installed version.";
				delete_notifications( 'plugininstall', "lastnotified-prerel-$pluginname" );
			}
		}
	}

	my ( $chosen_type, $chosen_ver_str, $chosen_archive, $chosen_info );

	if ( $release_cmp_ok && $prerelease_cmp_ok ) {
		if (   has_prerelease($currentver_str)
			&& cmp_versions( $prereleasever_str, $releasever_str ) < 0 )
		{
			LOGINF "$pluginname: Preferring newer prerelease (installed version is a prerelease; SemVer ranks it below release).";
			$chosen_type   = "prerelease";
			$chosen_ver_str    = $prereleasever_str;
			$chosen_archive    = $prereleasearchive;
			$chosen_info       = $prereleaseinfo;
		}
		else {
			LOGINF "$pluginname: Preferring release over prerelease.";
			$chosen_type   = "release";
			$chosen_ver_str    = $releasever_str;
			$chosen_archive    = $releasearchive;
			$chosen_info       = $releaseinfo;
		}
	}
	elsif ($release_cmp_ok) {
		$chosen_type    = "release";
		$chosen_ver_str = $releasever_str;
		$chosen_archive = $releasearchive;
		$chosen_info    = $releaseinfo;
	}
	elsif ($prerelease_cmp_ok) {
		$chosen_type    = "prerelease";
		$chosen_ver_str = $prereleasever_str;
		$chosen_archive = $prereleasearchive;
		$chosen_info    = $prereleaseinfo;
	}

	if ($chosen_type) {
		$installversion = trim($chosen_ver_str);
		$installtype = $chosen_type;
		if ( !$notify ) {
			$installarchive = $chosen_archive;
		}
		else {
			if ( $chosen_type eq 'release' ) {
				delete_notifications( 'plugininstall', "lastnotified-prerel-$pluginname" );
			}
			else {
				delete_notifications( 'plugininstall', "lastnotified-rel-$pluginname" );
			}
			my $notname =
			    $chosen_type eq "prerelease"
			  ? "lastnotified-prerel-$pluginname"
			  : "lastnotified-rel-$pluginname";

			my @notifications = get_notifications( 'plugininstall', $notname );
			my $last_notified_version;
			$last_notified_version = $notifications[0]->{version} if ($notifications[0]);

			delete_notifications( 'plugininstall', $notname );
			my %notification = (
				PACKAGE    => "plugininstall",
				NAME       => $notname,
				MESSAGE    =>
				  "Helper notification tracking last notified "
				  . (
					$chosen_type eq "prerelease" ? "pre-release" : "release" )
				  . " of $plugintitle",
				SEVERITY   => 7,
				pluginname => $pluginname,
				pluginmd5  => $pluginmd5,
				version       => $installversion,
				installarchive => $chosen_archive,
				releaseinfo    => $chosen_info,
				type        => $chosen_type,
				LINK        => $chosen_info
			);
			LoxBerry::Log::notify_ext( \%notification );

			if ($last_notified_version && $last_notified_version eq $installversion) {
				LOGOK "$pluginname: Skipping notification because version has already been notified.";
			}
			elsif ($checkonly) {
				LOGINF "$pluginname: Skipping notification because of --checkonly parameter. This is an interactive call.";
			}
			elsif ( $_->{PLUGINDB_AUTOUPDATE} eq "1" ) {
				LOGINF "$pluginname: Skipping notification because automatic updates and notifys are disabled.";
			}
			else {
				if ( $chosen_type eq "release" ) {
					$message = "$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_RELEASE_AVAILABLE'} $installversion\n";
				}
				else {
					$message = "$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_PRERELEASE_AVAILABLE'} $installversion\n";
				}
				$message .= $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INSTRUCTION'};
				notify( "plugininstall", "$pluginname", $message );
				LOGINF "$pluginname: Notification saved.";
			}
		}
	}

	#
	# Install new version
	#
	if ($installarchive) {

		# Randomly file naming
        $tempfile = generate(10);
		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 -LfksSo /tmp/pluginsupdate/$tempfile.zip $installarchive 2>&1`;
		if ($? ne 0) {
			LOGCRIT "$pluginname: Could not fetch archive file. Error: $resp. Skipping this plugin...";
			next;

		} else {

			$logfile = "/tmp/$tempfile.log";
						
			# Installation
			LOGOK "$pluginname: Archive file fetched.";
			LOGINF "$pluginname: Installing new RELEASE... Logs are going to the plugin's install logfile. Please be patient..." if ($installtype eq "release");
			LOGINF "$pluginname: Installing new PRE-RELEASE... Logs are going to the plugin's install logfile. Please be patient..." if ($installtype eq "prerelease");
			LOGINF "$pluginname: Temporary logfile name is $logfile";
			my $returnCode = system ("sudo $lbhomedir/sbin/plugininstall.pl action=autoupdate pid=$pid file=/tmp/pluginsupdate/$tempfile.zip cgi=1 tempfile=$tempfile > $logfile 2>&1");
			# Create notification
			if ($? eq 0 ) {
				LOGINF "$pluginname: Installation routine finished. Check plugin's logfile for details.";
				$message = "$pluginname - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_DONE'} $installversion";
				notify ( "plugininstall", "pluginautoupdate", $message);
				delete_notifications( 'plugininstall', "lastnotified-rel-$pluginname" );
				delete_notifications( 'plugininstall', "lastnotified-prerel-$pluginname" );
			} else {
				LOGERR "$pluginname: Installation seems to have failed! Please try to manually install the plugin.";
			}

		}

	}

}

LOGINF "Exiting.";
exit;

# Final executions
END 
{
	# Clean up
	LOGINF "Deleting temporary files.";
	system ("rm -rf $update_path");
	LOGEND "$0 finished.";
}



#####################################################
# Random
#####################################################

sub generate {
        my ($e) = @_;
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

