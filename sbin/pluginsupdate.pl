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

use strict;
use warnings;


##########################################################################
# Global
##########################################################################

# Version of this script
my $scriptversion="3.0.0.3";

# Global vars
my $update_path = '/tmp/pluginsupdate';
my $cfg = new Config::Simple("$lbsconfigdir/general.cfg");
my $bins = LoxBerry::System::get_binaries();
my @plugins = LoxBerry::System::get_plugins();
my $endpointrelease;
my $endpointprerelease;
my $prereleasecfg;
my $releasefile = "/tmp/pluginsupdate/release.cfg";
my $releasecfg;
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
	my $currentver_raw;
	my $release;
	my $prerelease;
	my $pid;
	my $plugintitle;
	my $pluginname;
	my $pluginmd5;
	my $logfile;
	my $tempfile;
	my $installtype;
	my ($rel_verstr, $rel_archive, $rel_info, $rel_ok);
	my ($pre_verstr, $pre_archive, $pre_info, $pre_ok);


	$pid = $_->{PLUGINDB_MD5_CHECKSUM};
	$currentver_raw = $_->{PLUGINDB_VERSION};
	$plugintitle = $_->{PLUGINDB_TITLE};
	$pluginname = $_->{PLUGINDB_NAME};
	$pluginmd5 = $_->{PLUGINDB_MD5_CHECKSUM};
	$installarchive = "";
	undef $installversion;

	LOGINF "$pluginname: Found plugin $_->{PLUGINDB_TITLE}.";

	#
	# Checks — SemVer + legacy lax compare via LoxBerry::System::plugin_version_compare
	#
	if ( !defined LoxBerry::System::plugin_version_compare($currentver_raw, $currentver_raw) ) {
		LOGCRIT "$pluginname: Cannot check plugin's version number. Is this a real version number? $currentver_raw. Skipping...";
		next;
	}
	LOGINF "$pluginname: Current version is: $currentver_raw";
	
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
	# Fetch release.cfg (AUTOUPDATE.VERSION)
	#
	$rel_ok = 0;
	$rel_verstr = $rel_archive = $rel_info = undef;

	if ( ($release || $notify) && $endpointrelease ) {

		LOGINF "$pluginname: Requesting release file from $endpointrelease";
		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointrelease  2>&1`;
		if ($? ne 0) {
			LOGCRIT "$pluginname: Could not fetch RELEASE file. Error: $resp Continuing with prerelease/other channels if any.";
		}
		else {
			LOGOK "$pluginname: Release file fetched.";
			eval {
				$releasecfg = new Config::Simple("$releasefile");
			};
			if ($@) {
				LOGCRIT "$pluginname: Fetched release.cfg is not a valid release file. Please report to the plugin author.";
			}
			else {
				$rel_verstr = $releasecfg->param("AUTOUPDATE.VERSION");
				$rel_archive = $releasecfg->param("AUTOUPDATE.ARCHIVEURL");
				$rel_info = $releasecfg->param("AUTOUPDATE.INFOURL");

				if ( defined(LoxBerry::System::plugin_version_compare($rel_verstr, $rel_verstr)) ) {
					$rel_ok = 1;
					LOGINF "$pluginname: Found release version: $rel_verstr";
				}
				else {
					LOGCRIT "$pluginname: Cannot check release version number. Is this a real version number?";
					undef $rel_verstr;
					undef $rel_archive;
					undef $rel_info;
				}
			}
		}
	}

	if ( !$rel_ok && ($release || $notify) ) {
		if ( $endpointrelease ) {
			delete_notifications('plugininstall', "lastnotified-rel-$pluginname");
			LOGINF "$pluginname: No valid release VERSION to compare.";
		}
	}
	elsif ( $rel_ok && defined(LoxBerry::System::plugin_version_compare($rel_verstr, $currentver_raw))
		&& LoxBerry::System::plugin_version_compare($rel_verstr, $currentver_raw) != 1 ) {
		LOGINF "$pluginname: Release version is not newer than installed version.";
		delete_notifications('plugininstall', "lastnotified-rel-$pluginname");
	}

	#
	# Fetch prerelease.cfg
	#
	$pre_ok = 0;
	$pre_verstr = $pre_archive = $pre_info = undef;

	if ( ($prerelease || $notify) && $endpointprerelease ) {

		LOGINF "$pluginname: Requesting prerelease from $endpointprerelease";

		$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 --raw -LfksSo $releasefile $endpointprerelease  2>&1`;
		if ($? ne 0) {
			LOGCRIT "$pluginname: Could not fetch PRERELEASE file. Error: $resp Continuing with release/other logic if applicable.";
		}
		else {
			LOGOK "$pluginname: Prerelease file fetched.";
			eval {
				$prereleasecfg = new Config::Simple("$releasefile");
			};
			if ($@) {
				LOGCRIT "$pluginname: Fetched prerelease.cfg is not a valid release file. Please report to the plugin author.";
			}
			else {
				$pre_verstr = $prereleasecfg->param("AUTOUPDATE.VERSION");
				$pre_archive = $prereleasecfg->param("AUTOUPDATE.ARCHIVEURL");
				$pre_info = $prereleasecfg->param("AUTOUPDATE.INFOURL");

				if ( defined(LoxBerry::System::plugin_version_compare($pre_verstr, $pre_verstr)) ) {
					$pre_ok = 1;
					LOGINF "$pluginname: Found prerelease version: $pre_verstr";
				}
				else {
					LOGCRIT "$pluginname: Cannot check prerelease version number. Is this a real version number?";
					undef $pre_verstr;
					undef $pre_archive;
					undef $pre_info;
				}
			}
		}
	}

	if ( !$pre_ok && ($prerelease || $notify) ) {
		if ( $endpointprerelease ) {
			LOGINF "$pluginname: No valid prerelease VERSION to compare.";
			delete_notifications('plugininstall', "lastnotified-prerel-$pluginname");
		}
	}
	elsif ( $pre_ok && defined(LoxBerry::System::plugin_version_compare($pre_verstr, $currentver_raw))
		&& LoxBerry::System::plugin_version_compare($pre_verstr, $currentver_raw) != 1 ) {
		LOGINF "$pluginname: Prerelease channel is not newer than installed version.";
		delete_notifications('plugininstall', "lastnotified-prerel-$pluginname");
	}

	#
	# One chosen update: SemVer + sticky prerelease (stay on beta when both stable and prerelease beat current)
	#
	my $cmp_rel =
		$rel_ok ? LoxBerry::System::plugin_version_compare($rel_verstr, $currentver_raw) : undef;
	my $cmp_pre =
		$pre_ok ? LoxBerry::System::plugin_version_compare($pre_verstr, $currentver_raw) : undef;
	my $rel_gt = (defined($cmp_rel) && $cmp_rel == 1);
	my $pre_gt = (defined($cmp_pre) && $cmp_pre == 1);

	my $pick_type = undef;
	if ( $rel_gt || $pre_gt ) {
		if ( $rel_gt && $pre_gt && LoxBerry::System::plugin_version_has_prerelease($currentver_raw) ) {
			LOGINF "$pluginname: Stable and prerelease both newer - installed is prerelease; staying on prerelease channel (sticky prerelease).";
			$pick_type = 'prerelease';
		}
		elsif ( $rel_gt && $pre_gt ) {
			LOGINF "$pluginname: Stable and prerelease both newer - preferring release.";
			$pick_type = 'release';
		}
		elsif ( $rel_gt ) {
			LOGINF "$pluginname: Preferring newer release.";
			$pick_type = 'release';
		}
		else {
			LOGINF "$pluginname: Preferring newer prerelease.";
			$pick_type = 'prerelease';
		}

		my $picked_ver =
			$pick_type eq 'release'
			? $rel_verstr
			: $pre_verstr;
		my $picked_arch =
			$pick_type eq 'release'
			? $rel_archive
			: $pre_archive;
		my $picked_info =
			$pick_type eq 'release'
			? $rel_info
			: $pre_info;

		$installversion = $picked_ver;
		$installtype = $pick_type;

		if ( !$notify ) {
			$installarchive = $picked_arch;
		}

		delete_notifications('plugininstall', "lastnotified-rel-$pluginname") if ( $pick_type eq 'prerelease' );
		delete_notifications('plugininstall', "lastnotified-prerel-$pluginname") if ( $pick_type eq 'release' );

		my $nh = $pick_type eq 'release' ? "lastnotified-rel-$pluginname" : "lastnotified-prerel-$pluginname";
		if ( $notify ) {
			my @notifications = get_notifications( 'plugininstall', $nh );
			my $last_notified_version = $notifications[0]->{version} if ($notifications[0]);
			delete_notifications('plugininstall', $nh );
			my %notification = (
				PACKAGE => "plugininstall",
				NAME => $nh,
				MESSAGE => $pick_type eq 'release'
					? "This helper notification keeps track of last notified release of $plugintitle"
					: "This helper notification keeps track of last notified pre-release of $plugintitle",
				SEVERITY => 7,
				pluginname => $pluginname,
				pluginmd5 => $pluginmd5,
				version => "$picked_ver",
				installarchive => "$picked_arch",
				releaseinfo => $picked_info,
				type => $pick_type,
				LINK => $picked_info,
			);
			LoxBerry::Log::notify_ext( \%notification );

			if ( $last_notified_version && $last_notified_version eq "$picked_ver" ) {
				LOGOK "$pluginname: Skipping notification because version has already been notified.";
			}
			elsif ($checkonly) {
				LOGINF "$pluginname: Skipping notification because of --checkonly parameter. This is an interactive call.";
			}
			elsif ($_->{PLUGINDB_AUTOUPDATE} eq "1") {
				LOGINF "$pluginname: Skipping notification because automatic updates and notifys are disabled.";
			}
			else {
				if ($pick_type eq 'release') {
					$message =
						"$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_RELEASE_AVAILABLE'} $installversion\n";
					$message .= $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INSTRUCTION'};
				}
				else {
					$message =
						"$plugintitle - $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_PRERELEASE_AVAILABLE'} $installversion\n";
					$message .= $SL{'PLUGININSTALL.UI_NOTIFY_AUTOINSTALL_INSTRUCTION'};
				}
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
				delete_notifications('plugininstall', "lastnotified-prerel-$pluginname") if ($installtype eq "release");
				delete_notifications('plugininstall', "lastnotified-rel-$pluginname") if ($installtype eq "prerelease" || $installtype eq "release");
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

