#!/usr/bin/perl

# Copyright 2016-2020 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


##########################################################################
# Modules
##########################################################################

use File::Path qw(make_path remove_tree);
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use LoxBerry::System;
use LoxBerry::System::PluginDB;
use LoxBerry::JSON;
use LoxBerry::Log;
use CGI;
use version;
use warnings;
use strict;

# Version of this script
my $version = "2.0.1.3";

if ($<) {
	print "This script has to be run as root or with sudo.\n";
	exit (1);
}

##########################################################################
# Variable declarations
##########################################################################


my $exitcode;
my $tempfile;
my $tempfolder;
my $is_cgi;
my $pcfg;
my $lbversion;
my $aptfile;
my $openerr;
my $lastaptupdate;
my $aptpackages;
my $log;
my $logfile;
my $statusfile;
my $chkhcpath;
my $pid;

my $pauthorname;
my $pauthoremail;
my $pversion;
my $pname;
my $ptitle;
my $pfolder;
my $pautoupdates;
my $preleasecfg;
my $pprereleasecfg;
my $pinterface;
my $preboot;
my $pcustomlog;
my $plbmin;
my $plbmax;
my $parch;

my $plugin;

##########################################################################
# Variables / Commandline
##########################################################################

# Command line options
my $cgi = CGI->new;
$cgi->import_names('R');

# Remove 'only used once' warnings
$R::cgi if 0;

# Command line or CGI?
if ( $R::cgi ) {
	$is_cgi = 1;
	print "We are in CGI mode.\n";
} else {
	$is_cgi = 0;
	print "We are in Command line mode.\n";
}

##########################################################################
# Read Settings
##########################################################################

my $bins = LoxBerry::System::get_binaries();
my $bashbin		= $bins->{BASH};
my $aptbin		= $bins->{APT};
my $sudobin		= $bins->{SUDO};
my $chmodbin		= $bins->{CHMOD};
my $chownbin		= $bins->{CHOWN};
my $unzipbin		= $bins->{UNZIP};
my $findbin		= $bins->{FIND};
my $grepbin		= $bins->{GREP};
my $dpkgbin		= $bins->{DPKG};
my $dos2unix		= $bins->{DOS2UNIX};
my $wgetbin		= $bins->{WGET};

##########################################################################
# Language Settings
##########################################################################

my $lang = lblanguage();

# Read phrases from language_LANG.ini
our %SL = LoxBerry::System::readlanguage(undef);
our %LL = localphrases();

##########################################################################
# Plugindb State
##########################################################################

my $statefile = "$lbstmpfslogdir/plugins_state.json";
my $stateobj = LoxBerry::JSON->new();
my $statedata = $stateobj->open(filename => $statefile, writeonclose => 1);

##########################################################################
# Checks
##########################################################################

my $message;
my @errors;
my @warnings;
$pname = "Plugininstall"; # set dummy at this point
if ( $R::action ne "install" && $R::action ne "uninstall" && $R::action ne "autoupdate" ) {
	$message = "$LL{'ERR_ACTION'}";
	&logfail;
}
if ( $R::action eq "install" ) {
	if ( (!$R::folder && !$R::file) || ($R::folder && $R::file) ) {
		$message = "$LL{'ERR_NOFOLDER_OR_ZIP'}";
		&logfail;
	}
	if ( !$R::pin && $R::action ne "autoupdate" ) {
		$message = "$LL{'ERR_NOPIN'}";
		&logfail;
	}
}
if ( $R::action eq "uninstall" || $R::action eq "autoupdate" ) {
	if ( !$R::pid ) {
		$message = "$LL{'ERR_NOPID'}";
		&logfail;
	}
}

# ZIP or Folder mode?
my $zipmode = defined $R::file ? 1 : 0;

# Which Action should be perfomred?
if ($R::action eq "install" || $R::action eq "autoupdate" ) {
	&install;
}
if ($R::action eq "uninstall" ) {
	&uninstall;
}

exit (0);

#####################################################
# UnInstall
#####################################################

sub uninstall {
	
	$pid = $R::pid;
	
	$plugin = LoxBerry::System::PluginDB->plugin( md5 => $pid );
		
	if ( !$plugin ) {
		$message = "$LL{'ERR_PIDNOTEXIST'}";
		&logfail;
	}

	$pname = $plugin->{name};
	$pfolder = $plugin->{folder};
	$ptitle = $plugin->{title};
	$pversion = $plugin->{version};
	
	# Create Logfile with lib to have it in database
	$log = LoxBerry::Log->new(
		package => 'Plugin Installation',
		name => 'Uninstall',
		filename => "$lbhomedir/log/system/plugininstall/".$pname."_uninstall.log",
		loglevel => 7,
		addtime => 1
	);
	LOGSTART "Plugin Uninstallation $ptitle";

	# Set logfile
	$logfile = $log->filename();
	LOGINF "Logfile name is $logfile";
	
	LOGINF "Requesting lock";
	eval {
		my $lockstate = LoxBerry::System::lock( lockfile => 'plugininstall', wait => 10 );

		if ($lockstate) {
			$message = "$LL{'ERR_LOCKING'}";
			&logerr;
			$message = "$LL{'ERR_LOCKING_REASON'} $lockstate";
			&logfail;
		}
	};
	
	LOGINF "Setting systemwide information about plugin uninstall";
	$statedata->{db_updated} = time;
	$statedata->{last_plugin_uninstall} = time;
	
	&purge_installation("all");
	
	# Purge plugin notifications
	if($pfolder) {
		LOGINF "Deleting notifications of plugin $pfolder";
		LoxBerry::Log::delete_notifications($pfolder);
	}

	# Remove Lock
	LOGINF "Removing lock";
	LoxBerry::System::unlock( lockfile => 'plugininstall' );
	
	## No idea what this is for
	## Saving Logfile
	# $message = "$LL{'INF_SAVELOG'}";
	# &loginfo;
	# system("cp -v /tmp/$tempfile.log $lbhomedir/log/system/plugininstall/".$pname."_uninstall.log 2>&1");
	# &setowner ("loxberry", "0", "$lbhomedir/log/system/plugininstall/".$pname."_uninstall.log", "LOG Save");
	
	LOGEND();
	
	exit (0);

}

#####################################################
# Install
#####################################################

sub install {

	# Create tmp dir
	if (!-e "$lbsdatadir/tmp/uploads") {
		make_path("$lbsdatadir/tmp/uploads" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	}
	# Choose random temp filename
	if ( !$R::tempfile ) {;
		$tempfile = &generate(10);
	} else {
		$tempfile = $R::tempfile;
	}
	# Create status and logfile
	$logfile = "/tmp/$tempfile.log";
	$statusfile = "/tmp/$tempfile.status";
	if (-e "$statusfile") {
		$message = "$LL{'ERR_TEMPFILES_EXISTS'}";
		&logfail;
	}

	$message = "Statusfile: $statusfile";
	&loginfo;
	open (F, ">$statusfile");
	flock(F,2);
		print F "1";
	flock(F,8);
	close (F);

	# Check secure PIN
	if ( $R::action ne "autoupdate" ) {
		my $pin = $R::pin;

		if ( LoxBerry::System::check_securepin($pin) ) {
			$message = "$LL{'ERR_SECUREPIN_WRONG'}";
			&logfail;
		}
	}

	# Check if plugin is installed (autoupdate)
	if ( $R::action eq "autoupdate" ) {

		$pid = $R::pid;
		my $found = 0;
		my @plugins = LoxBerry::System::get_plugins();

		foreach (@plugins) {
			if ( $_->{PLUGINDB_MD5_CHECKSUM} eq $pid ) {
				$found = 1;
			}
		}
		if ( !$found ) {
			$message = "$LL{'ERR_PIDNOTEXIST'}";
			&logfail;
		}

	}

	if (!$zipmode) { 
		$tempfolder = $R::folder;
		if (!-e $tempfolder) {
			$message = "$LL{'ERR_FOLDER_DOESNT_EXIST'}";
			&logfail;
		}
	} else {
		$tempfolder = "$lbsdatadir/tmp/uploads/$tempfile";
		if (!-e $R::file) {
			$message = "$LL{'ERR_FILE_DOESNT_EXIST'}";
			&logfail;
		}

		open(F, $R::file);
		if(read(F, my $buffer, 2))
		{
			close(F);
			if($buffer ne 'PK')
			{
				$message = "$LL{'ERR_ARCHIVEFORMAT'}";
				&logfail;
			}
		}
		make_path("$tempfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	}
	$tempfolder =~ s/(.*)\/$/$1/eg; # Clean trailing /
	$message = "Temp Folder: $tempfolder";
	&loginfo;

	$message = "Logfile: $logfile";
	&loginfo;
	if ( ! $is_cgi ) {
		open (F, ">$logfile");
		flock(F,2);
			print F "";
		flock(F,8);
		close (F);
	}

	# Check free space in tmp
	my $pluginsize;
	my %folderinfo;
	if ( $zipmode ) {
		$pluginsize = `$unzipbin -l $R::file | tail -1 | xargs | cut -d' ' -f1`;
		$pluginsize = $pluginsize / 1000; # kBytes
		%folderinfo = LoxBerry::System::diskspaceinfo("$lbsdatadir/tmp/uploads");
		if ($folderinfo{available} < $pluginsize * 1.1) { # exstracted size + 10%
			$message = "$LL{'ERR_NO_SPACE_IN_TMP'} " . $folderinfo{available} . " kB";
			&logfail;
		}
	} else {
		$pluginsize = `du -bs $tempfolder | tail -1 | xargs | cut -d' ' -f1`;
		$pluginsize = $pluginsize / 1000; # kBytes
	}

	# Check free space in $lbhomedir
	%folderinfo = LoxBerry::System::diskspaceinfo($lbhomedir);
	if ($folderinfo{available} < $pluginsize * 1.1) { # exstracted size + 10%
		$message = "$LL{'ERR_NO_SPACE_IN_ROOT'} " . $folderinfo{available} . " kB";
		&logfail;
	}

	# Locking
	$message = "$LL{'INF_LOCKING'}";
	&loginfo;
	eval {
		my $lockstate = LoxBerry::System::lock( lockfile => 'plugininstall', wait => 600 );

		if ($lockstate) {
			$message = "$LL{'ERR_LOCKING'}";
			&logerr;
			$message = "$LL{'ERR_LOCKING_REASON'} $lockstate";
			&logfail;
		}
	};

	$message = "$LL{'OK_LOCKING'}";
	&logok;

	# Starting
	$message = "$LL{'INF_START'}";
	&loginfo;

	# UnZipping
	if ( $zipmode ) {

		$message = "$LL{'INF_EXTRACTING'}";
		&loginfo;

		$message = "Command: $sudobin -n -u loxberry $unzipbin -d $tempfolder $R::file";
		&loginfo;

		system("$sudobin -n -u loxberry $unzipbin -d $tempfolder $R::file 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_EXTRACTING'}";
			&logfail;
		} else {
			$message = "$LL{'OK_EXTRACTING'}";
			&logok;
		}

	}

	# Check for plugin.cfg
	if (!-f "$tempfolder/plugin.cfg") {
		my $exists = 0;
		opendir(DIR, "$tempfolder");
		my @data = readdir(DIR);
		closedir(DIR);
		foreach(@data) {
			if (-f "$tempfolder/$_/plugin.cfg" && $_ ne "." && $_ ne "..") {
				$tempfolder = $tempfolder . "/$_";
				$exists = 1;
				last;
			}
		}
		if (!$exists) {
			$message = "$LL{'ERR_ARCHIVEFORMAT'}";
			&logfail;
		}
	}

	# Read Plugin-Config
	eval {
		$pcfg = new Config::Simple("$tempfolder/plugin.cfg") or	die Config::Simple->error();
	};
	if ($@) {
		$message = "$LL{'ERR_UNKNOWN_FORMAT_PLUGINCFG'}";
		&logfail;
	}

	$pauthorname		= $pcfg->param("AUTHOR.NAME");
	$pauthoremail		= $pcfg->param("AUTHOR.EMAIL");
	$pversion		= $pcfg->param("PLUGIN.VERSION");
	$pname			= $pcfg->param("PLUGIN.NAME");
	$ptitle			= $pcfg->param("PLUGIN.TITLE");
	$pfolder		= $pcfg->param("PLUGIN.FOLDER");
	$pautoupdates		= $pcfg->param("AUTOUPDATE.AUTOMATIC_UPDATES");
	$preleasecfg		= $pcfg->param("AUTOUPDATE.RELEASECFG");
	$pprereleasecfg		= $pcfg->param("AUTOUPDATE.PRERELEASECFG");
	$pinterface		= $pcfg->param("SYSTEM.INTERFACE");
	$preboot		= $pcfg->param("SYSTEM.REBOOT");
	$pcustomlog		= $pcfg->param("SYSTEM.CUSTOM_LOGLEVELS");
	$plbmin			= $pcfg->param("SYSTEM.LB_MINIMUM");
	$plbmax			= $pcfg->param("SYSTEM.LB_MAXIMUM");
	$parch			= $pcfg->param("SYSTEM.ARCHITECTURE");

	# Filter
	$pname =~ tr/A-Za-z0-9_-//cd;
	$pfolder =~ tr/A-Za-z0-9_-//cd;
	if (length($ptitle) > 25) {
		$ptitle = substr($ptitle,0,22);
		$ptitle = $ptitle . "...";
	}

	if ( is_disabled ($pautoupdates) || $preleasecfg eq "" ) {
		$preleasecfg = "";
		$pprereleasecfg = "";
		$pautoupdates = "False";
	} else {
		$pautoupdates = "True";
	}

	if ( is_disabled($parch) || $parch eq "" ) {
		$parch = "False";
	}

	if ( is_disabled($preboot) || $preboot eq "" ) {
		$preboot = "False";
	} else {
		$preboot = "True";
	}

	if ( is_disabled($pcustomlog) || $pcustomlog eq "" ) {
		$pcustomlog = "False";
	} else {
		$pcustomlog = "True";
	}

	if ( is_disabled($plbmin) || $plbmin eq "" ) {
		$plbmin = "False";
	}

	if ( is_disabled($plbmax) || $plbmax eq "" ) {
		$plbmax = "False";
	}

	$message = "Author:         $pauthorname";
	&loginfo;
	$message = "Email:          $pauthoremail";
	&loginfo;
	$message = "Version:        $pversion";
	&loginfo;
	$message = "Name:           $pname";
	&loginfo;
	$message = "Folder:         $pfolder";
	&loginfo;
	$message = "Title:          $ptitle";
	&loginfo;
	$message = "Autoupdate:     $pautoupdates";
	&loginfo;
	$message = "Release:        $preleasecfg";
	&loginfo;
	$message = "Prerelease:     $pprereleasecfg";
	&loginfo;
	$message = "Reboot:         $preboot";
	&loginfo;
	$message = "Min LB Vers:    $plbmin";
	&loginfo;
	$message = "Max LB Vers:    $plbmax";
	&loginfo;
	$message = "Architecture:   $parch";
	&loginfo;
	$message = "Custom Log:     $pcustomlog";
	&loginfo;
	$message = "Interface:      $pinterface";
	&loginfo;

	# Create Logfile with lib to have it in database
	$log = LoxBerry::Log->new(
		package => 'Plugin Installation',
		name => 'Installation',
		filename => "$lbhomedir/log/system/plugininstall/$pname.log",
		loglevel => 7,
	);
	LOGSTART "LoxBerry Plugin Installation $ptitle";

	# Use 0/1 for enabled/disabled from here on
	$pautoupdates = is_disabled($pautoupdates) ? 0 : 1;
	$preboot = is_disabled($preboot) ? 0 : 1;
	$pcustomlog = is_enabled($pcustomlog) ? 1 : 0;

	# Some checks
	if (!$pauthorname || !$pauthoremail || !$pversion || !$pname || !$ptitle || !$pfolder || !$pinterface) {
		$message = "$LL{'ERR_PLUGINCFG'}";
		&logfail;
	}	else {
		$message = "$LL{'OK_PLUGINCFG'}";
		&logok;
	}

	if ( $pinterface ne "1.0" && $pinterface ne "2.0" ) {
		$message = "$LL{'ERR_UNKNOWNINTERFACE'}";
		&logfail; 
	}

	if ( $pinterface eq "1.0" ) {
		# $message = "*** DEPRECIATED *** This Plugin uses the outdated PLUGIN Interface V1.0. It will be compatible with this Version of LoxBerry but may not work with the next Major LoxBerry release! Please inform the PLUGIN Author at $pauthoremail";
		# &logwarn; 
		# push(@warnings,"PLUGININTERFACE: $message");
		# Always reboot with V1 plugins
		$preboot = 1;
	}

	# Arch check
	if ( is_enabled($parch) ) {
		my $archcheck = 0;
		foreach (split(/,/,$parch)){
			if (-e "$lbsconfigdir/is_$_.cfg") {
				$archcheck = 1;
				$message = "$LL{'OK_ARCH'}";
				&logok;
				last;
			} 
		}
		if (!$archcheck) {
			$message = "$LL{'ERR_ARCH'}";
			&logfail;
		}
	}

	# Version check
	my $versioncheck = 0;
	if (version::is_lax(vers_tag(LoxBerry::System::lbversion()))) {
		$versioncheck = 1;
		$lbversion = version->parse(vers_tag(LoxBerry::System::lbversion()));
		$message = $LL{'INF_LBVERSION'} . $lbversion;
		&loginfo;
	} else {
		$versioncheck = 0;
	}

	if ( !is_disabled($plbmin) && $versioncheck) {

		if ( (version::is_lax(vers_tag($plbmin))) ) {
			$plbmin = version->parse(vers_tag($plbmin));
			$message = $LL{'INF_MINVERSION'} . $plbmin;
			&loginfo;
		if ($lbversion < $plbmin) {
			my $generalcfg = new Config::Simple("$lbsconfigdir/general.cfg");
			if ($generalcfg->param("UPDATE.RELEASETYPE") and $generalcfg->param("UPDATE.RELEASETYPE") eq "latest") {
				$message = $LL{'INF_MINVERSION'} . $plbmin;
				push(@warnings, "$message");
				&logwarn;
				$message = "This plugin requests a newer LoxBerry version than installed. As you have set LoxBerry Update ";
				push(@warnings, "$message");
				&logwarn;
				$message = "to 'Latest commit', this plugin installation is allowed at your own risk. To test this plugin, you should ";
				push(@warnings, "$message");
				&logwarn;
				$message = "now also run LoxBerry Update. Don't bother the plugin developer if you haven't done so. Happy testing!";
				push(@warnings, "$message");
				&logwarn;
			} else {
				$message = "$LL{'ERR_MINVERSION'}";
				&logfail;
			}
			} else {
				$message = "$LL{'OK_MINVERSION'}";
				&logok;
			}
		} 

	}

	if ( !is_disabled($plbmax) && $versioncheck) {

		if ( (version::is_lax(vers_tag($plbmax))) ) {
			$plbmax = version->parse(vers_tag($plbmax));
			$message = $LL{'INF_MAXVERSION'} . $plbmax;
			&loginfo;

			if ($lbversion > $plbmax) {
			my $generalcfg = new Config::Simple("$lbsconfigdir/general.cfg");
			if ($generalcfg->param("UPDATE.RELEASETYPE") and $generalcfg->param("UPDATE.RELEASETYPE") eq "latest") {
				$message = $LL{'INF_MAXVERSION'} . $plbmin;
				push(@warnings, "$message");
				&logwarn;
				$message = "This plugin requests an older LoxBerry version than installed. As you have set LoxBerry Update ";
				push(@warnings, "$message");
				&logwarn;
				$message = "to 'Latest commit', this plugin installation is allowed at your own risk. Don't bother the plugin ";
				push(@warnings, "$message");
				&logwarn;
				$message = "developer if he hadn't asked you to do so. Happy testing!";
				push(@warnings, "$message");
				&logwarn;
			} else {
				$message = "$LL{'ERR_MAXVERSION'}";
				&logfail;
			}
			} else {
				$message = "$LL{'OK_MAXVERSION'}";
				&logok;
			}
		}

	}

	## Create or update database entry ##
	
	$plugin = LoxBerry::System::PluginDB->plugin(
        author_name => $pauthorname,
        author_email => $pauthoremail,
        name => $pname,
        folder => $pfolder,
        version => $pversion,
        title => $ptitle,
        interface => $pinterface,
        autoupdate => $pautoupdates,
        releasecfg => $preleasecfg,
        prereleasecfg => $pprereleasecfg,
        # loglevel => 
        loglevels_enabled => $pcustomlog
	);
	
	if(!$plugin) {
		$message = "$LL{'ERR_DATABASE'}";
		&logfail;
	}
	
	LOGINF "The unique plugin id (md5) of this plugin is: " . $plugin->{md5};
	
	my $isupgrade = 0;
	
	
	# Everything for an UPGRADE
	if(! $plugin->{_isnew}) {
		$message = "$LL{'INF_ISUPDATE'}";
		&loginfo;
		$isupgrade = 1;
		$plugin->{epoch_lastupdated} = time;
		$statedata->{db_updated} = time;
		$statedata->{last_plugin_update} = time;
		$message = "$LL{'OK_DBENTRY'}";
		&logok;
	
		
	} else {
		# Everything for a NEW installation
		$plugin->{epoch_firstinstalled} = time;
		$statedata->{db_updated} = time;
		$statedata->{last_plugin_install} = time;
		# Set default loglevel to 3 for new plugins
		$plugin->{loglevel} = "3";
		if(is_enabled($pautoupdates)) {
			# Set new installations to automatic release updates
			$plugin->{autoupdate} = 3;
		}
		
		# Check for existance of same folder or name 
		
		# Temporary store the original name and folder
		$plugin->{_tmp_orig_folder} = $pfolder;
		$plugin->{_tmp_orig_name} = $pname;
		
		my @searchresult = LoxBerry::System::PluginDB->search( 
			name => $pname,
			folder => $pfolder,
			_condition => 'or'
		);
		if(@searchresult) {
			# Add 3 chars of md5 hash to pname and folder
			$pname = $pname.'_'.substr($plugin->{md5}, 0, 3);
			$pfolder = $pfolder.'_'.substr($plugin->{md5}, 0, 3);
			# Check again
			@searchresult = LoxBerry::System::PluginDB->search( 
				name => $pname,
				folder => $pfolder,
				_condition => 'or'
			);
			if(@searchresult) {
				# Also in use -> stop
				$message = "$LL{'ERR_DBENTRY'}";
				&logfail;
			} else {
				# Save original and new name/folder to the plugindb
				$plugin->{name} = $pname;
				$plugin->{folder} = $pfolder;
				$plugin->{orig_name} = $plugin->{_tmp_orig_name};
				$plugin->{orig_folder} = $plugin->{_tmp_orig_folder};
			}
		}
	}
	
	$message = $LL{'INF_PNAME_IS'} . " $pname";
	&loginfo;
	$message = $LL{'INF_PFOLDER_IS'} . " $pfolder";
	&loginfo;
	
	$plugin->save();
	

	# Create shadow plugindatabase.json- and backup of plugindatabase
	$message = $LL{'INF_SHADOWDB'};
	&loginfo;
	system("cp -v $LoxBerry::System::PLUGINDATABASE $LoxBerry::System::PLUGINDATABASE- 2>&1");
	&setrights ("644", "0", "$LoxBerry::System::PLUGINDATABASE-", "PLUGIN DATABASE");
	&setowner ("root", "0", "$LoxBerry::System::PLUGINDATABASE-", "PLUGIN DATABASE");
	system("cp -v $LoxBerry::System::PLUGINDATABASE $LoxBerry::System::PLUGINDATABASE.bkp 2>&1");
	&setrights ("644", "0", "$LoxBerry::System::PLUGINDATABASE.bkp", "PLUGIN DATABASE");
	&setowner ("loxberry", "0", "$LoxBerry::System::PLUGINDATABASE.bkp", "PLUGIN DATABASE");

	# Starting installation

	# Getting text file list
	my @textfilelist = getTextFiles($tempfolder);
	
	# Checking for hardcoded /opt/loxberry strings
	if ( $pinterface ne "1.0" ) {
		$message = "Checking for hardcoded paths to /opt/loxberry";
		&loginfo;
		my @extensionExcludeList = ( ".md", ".html", ".txt", ".dat", ".log" );
		my @searchfilelist;
		foreach my $filename ( @textfilelist ) {
			my $slashpos = rindex($filename, '/');
			my $dotpos = rindex($filename, '.');
			if($dotpos == -1 or $slashpos > $dotpos) {
				push @searchfilelist, $filename;
				next;
			}
			my $ext = substr( $filename, $dotpos );
			# print "Filename: $filename Extension: $ext\n";
			next if ( !$ext or grep { "/$ext/" } @extensionExcludeList );
			push @searchfilelist, $filename;
		}
		
		if(@searchfilelist) {
			my $searchfilestring = join(' ', @searchfilelist);
			$chkhcpath = `$grepbin -li '/opt/loxberry' $searchfilestring`;
		}

		if ($chkhcpath) {
			$message = $SL{'PLUGININSTALL.WARN_HARDCODEDPATHS'} . $pauthoremail;
			&logwarn;
			print $chkhcpath;
			push(@warnings,"HARDCODED PATH'S: $message");
			
			
		} else {
			$message = "No hardcoded paths to /opt/loxberry found";
			&logok;
		}
	}

		
	# Replacing Environment strings
	replaceenv("loxberry", \@textfilelist);
	
	# Executing DOS2UNIX for all textfiles
	if (-e "$tempfolder" ) {
		dos2unix("loxberry", \@textfilelist);
	}

	# Executing preroot script
	if (-f "$tempfolder/preroot.sh") {
		$message = "$LL{'INF_START_PREROOT'}";
		&loginfo;

		$message = "Command: cd \"$tempfolder\" && \"$tempfolder/preroot.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\"";
		&loginfo;

		system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/preroot.sh\" 2>&1");
		system("cd \"$tempfolder\" && \"$tempfolder/preroot.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1");
		$exitcode	= $? >> 8;
		if ($exitcode eq 1) {
			$message = "$LL{'ERR_SCRIPT'}";
			&logerr; 
			push(@errors,"PREROOT: $message");
		} 
		elsif ($exitcode > 1) {
			$message = "$LL{'FAIL_SCRIPT'}";
			&logfail; 
		}
		else {
			$message = "$LL{'OK_SCRIPT'}";
			&logok;
		}
	}

	# Executing preupgrade script
	if ($isupgrade) {
		if (-f "$tempfolder/preupgrade.sh") {

			$message = "$LL{'INF_START_PREUPGRADE'}";
			&loginfo;

			$message = "Command: cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/preupgrade.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\"";
			&loginfo;

			system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/preupgrade.sh\" 2>&1");
			system("cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/preupgrade.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1");
			$exitcode	= $? >> 8;
			if ($exitcode eq 1) {
				$message = "$LL{'ERR_SCRIPT'}";
				&logerr; 
				push(@errors,"PREUPGRADE: $message");
			} 
			elsif ($exitcode > 1) {
				$message = "$LL{'FAIL_SCRIPT'}";
				&logfail; 
			}
			else {
				$message = "$LL{'OK_SCRIPT'}";
				&logok;
			}
		}
		# Purge old installation
		$message = "$LL{'INF_REMOVING_OLD_INSTALL'}";
		&loginfo;

		&purge_installation;
	}

	# Executing preinstall script
	if (-f "$tempfolder/preinstall.sh") {
		$message = "$LL{'INF_START_PREINSTALL'}";
		&loginfo;

		$message = "Command: cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/preinstall.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\"";
		&loginfo;

		system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/preinstall.sh\" 2>&1");
		system("cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/preinstall.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1");
		$exitcode	= $? >> 8;
		if ($exitcode eq 1) {
			$message = "$LL{'ERR_SCRIPT'}";
			&logerr; 
			push(@errors,"PREINSTALL: $message");
		} 
		elsif ($exitcode > 1) {
			$message = "$LL{'FAIL_SCRIPT'}";
			&logfail; 
		}
		else {
			$message = "$LL{'OK_SCRIPT'}";
			&logok;
		}
	}	

	# Copy Config files
	make_path("$lbhomedir/config/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/config")) {
		$message = "$LL{'INF_CONFIG'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -r -v $tempfolder/config/* $lbhomedir/config/plugins/$pfolder/ 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"CONFIG files: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}
		&setowner ("loxberry", "1", "$lbhomedir/config/plugins/$pfolder", "CONFIG files");

	}

	# Copy bin files
	make_path("$lbhomedir/bin/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/bin")) {
		$message = "$LL{'INF_BIN'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -r -v $tempfolder/bin/* $lbhomedir/bin/plugins/$pfolder/ 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"BIN files: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

		&setrights ("755", "1", "$lbhomedir/bin/plugins/$pfolder", "BIN files");
		&setowner ("loxberry", "1", "$lbhomedir/bin/plugins/$pfolder", "BIN files");

	}

	# Copy Template files
	make_path("$lbhomedir/templates/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/templates")) {
		$message = "$LL{'INF_TEMPLATES'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -r -v $tempfolder/templates/* $lbhomedir/templates/plugins/$pfolder/ 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"TEMPLATE files: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

		&setowner ("loxberry", "1", "$lbhomedir/templates/plugins/$pfolder", "TEMPLATE files");
		
	}

	# Copy Cron files
	my @cronfolders = qw( 
		cron.reboot
		cron.01min 
		cron.03min 
		cron.05min 
		cron.10min 
		cron.15min 
		cron.30min 
		cron.hourly 
		cron.daily 
		cron.weekly 
		cron.monthly 
		cron.yearly 
	);
	
	
	if (!&is_folder_empty("$tempfolder/cron")) {
		$message = "$LL{'INF_CRONJOB'}";
		&loginfo;
		$openerr = 0;
		if (-e "$tempfolder/cron/crontab" && !-e "$lbhomedir/system/cron/cron.d/$pname") {
			system("cp -r -v $tempfolder/cron/crontab $lbhomedir/system/cron/cron.d/$pname 2>&1");
			if ($? ne 0) {
				$openerr = 1;
			}
			&setrights ("644", "0", "$lbhomedir/system/cron/cron.d/*", "CRONTAB files");
			&setowner	("root", "0", "$lbhomedir/system/cron/cron.d/*", "CRONTAB files");
		} 
		
		foreach my $cronfolder ( @cronfolders ) {
			if (-e "$tempfolder/cron/$cronfolder") {
				system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/$cronfolder $lbhomedir/system/cron/$cronfolder/$pname 2>&1");
				if ($? ne 0) {
					$openerr = 1;
				}
				&setrights ("755", "1", "$lbhomedir/system/cron/$cronfolder", "CRONJOB files");
				&setowner	("loxberry", "1", "$lbhomedir/system/cron/$cronfolder", "CRONJOB files");
			} 
		}
		
		if ($openerr) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"CRONJOB files: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}
	}

	# Copy Data files
	make_path("$lbhomedir/data/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/data")) {
		$message = "$LL{'INF_DATAFILES'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -r -v $tempfolder/data/* $lbhomedir/data/plugins/$pfolder/ 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"DATA files: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

		&setowner ("loxberry", "1", "$lbhomedir/data/plugins/$pfolder", "DATA files");

	}

	# Copy Log files
	make_path("$lbhomedir/log/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/log")) {

		$message = "$LL{'INF_LOGFILES'}";
		&loginfo;

		if ( $pinterface ne "1.0" ) {
			$message = "*** DEPRECIATED *** With plugin interface 2.0 (and above), the plugin must not ship with a log folder. Please inform the PLUGIN Author at $pauthoremail";
			&logwarn; 
			push(@warnings,"LOG files: $message");
		}

		system("$sudobin -n -u loxberry cp -r -v $tempfolder/log/* $lbhomedir/log/plugins/$pfolder/ 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"LOG files: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

		&setowner ("loxberry", "1", "$lbhomedir/log/plugins/$pfolder", "LOG files");

	}

	# Copy CGI files - DEPRECIATED!!!
	if ( $pinterface eq "1.0" ) {
		make_path("$lbhomedir/webfrontend/htmlauth/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
		if (!&is_folder_empty("$tempfolder/webfrontend/cgi")) {
			$message = "$LL{'INF_HTMLAUTHFILES'}";
			&loginfo;
			system("$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/cgi/* $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1");
			if ($? ne 0) {
				$message = "$LL{'ERR_FILES'}";
				&logerr; 
				push(@errors,"HTMLAUTH files: $message");
			} else {
				$message = "$LL{'OK_FILES'}";
				&logok;
			}

			&setowner ("loxberry", "1", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files");
			&setrights ("755", "1", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files");

		}
	}

	# Copy HTMLAUTH files
	if ( $pinterface ne "1.0" ) {
		make_path("$lbhomedir/webfrontend/htmlauth/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
		if (!&is_folder_empty("$tempfolder/webfrontend/htmlauth")) {
			$message = "$LL{'INF_HTMLAUTHFILES'}";
			&loginfo;
			system("$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/htmlauth/* $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1");
			if ($? ne 0) {
				$message = "$LL{'ERR_FILES'}";
				&logerr; 
				push(@errors,"HTMLAUTH files: $message");
			} else {
				$message = "$LL{'OK_FILES'}";
				&logok;
			}

			&setrights ("755", "0", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files", ".*\\.cgi\\|.*\\.pl\\|.*\\.sh");
			&setowner ("loxberry", "1", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files");

		}
	}

	# Copy HTML files
	make_path("$lbhomedir/webfrontend/html/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/webfrontend/html")) {
		$message = "$LL{'INF_HTMLFILES'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/html/* $lbhomedir/webfrontend/html/plugins/$pfolder/ 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"HTML files: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

			&setrights ("755", "0", "$lbhomedir/webfrontend/html/plugins/$pfolder", "HTML files", ".*\\.cgi\\|.*\\.pl\\|.*\\.sh");
			&setowner ("loxberry", "1", "$lbhomedir/webfrontend/html/plugins/$pfolder", "HTML files");

	}

	# Copy Icon files
	make_path("$lbhomedir/webfrontend/html/system/images/icons/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	$message = "$LL{'INF_ICONFILES'}";
	&loginfo;
	system("$sudobin -n -u loxberry cp -r -v $tempfolder/icons/* $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
	if ($? ne 0) {
		system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/* $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		$message = "$LL{'ERR_ICONFILES'}";
		&logerr; 
		push(@errors,"ICON files: $message");
	} else {
		$openerr = 0;
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_64.png") {
			$openerr = 1;
			system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_64.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_128.png") {
			$openerr = 1;
			system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_128.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_256.png") {
			$openerr = 1;
			system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_256.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_512.png") {
			$openerr = 1;
			system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_512.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if ($openerr) {
			$message = "$LL{'ERR_ICONFILES'}";
			&logerr;
			push(@errors,"ICON files: $message");
		} else { 
			$message = "$LL{'OK_ICONFILES'}";
			&logok;
		}

		&setowner ("loxberry", "1", "$lbhomedir/webfrontend/html/system/images/icons/$pfolder", "ICON files");

	}

	# Copy Daemon file
	if (-f "$tempfolder/daemon/daemon") {
		$message = "$LL{'INF_DAEMON'}";
		&loginfo;
		system("cp -v $tempfolder/daemon/daemon $lbhomedir/system/daemons/plugins/$pname 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"DAEMON FILE: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

		if ( $pinterface eq "1.0" ) {
			setrights ("777", "1", "$lbhomedir/system/daemons/plugins", "Plugin interface V1.0 DAEMON script");
		}
		
		&setrights ("755", "0", "$lbhomedir/system/daemons/plugins/$pname", "DAEMON script");
		&setowner ("root", "0", "$lbhomedir/system/daemons/plugins/$pname", "DAEMON script");

	}

	# Copy Uninstall file
	if (-f "$tempfolder/uninstall/uninstall") {
		$message = "$LL{'INF_UNINSTALL'}";
		&loginfo;
		system("cp -r -v $tempfolder/uninstall/uninstall $lbhomedir/data/system/uninstall/$pname 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"UNINSTALL Script: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

		&setrights ("755", "0", "$lbhomedir/data/system/uninstall/$pname", "UNINSTALL script");
		&setowner ("root", "0", "$lbhomedir/data/system/uninstall/$pname", "UNINSTALL script");

	}

	# Copy Sudoers file
	if (-f "$tempfolder/sudoers/sudoers") {
		$message = "$LL{'INF_SUDOERS'}";
		&loginfo;
		system("cp -v $tempfolder/sudoers/sudoers $lbhomedir/system/sudoers/$pname 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"SUDOERS file: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}

		&setrights ("644", "0", "$lbhomedir/system/sudoers/$pname", "SUDOERS file");
		&setowner ("root", "0", "$lbhomedir/system/sudoers/$pname", "SUDOERS file");

	}

	# Installing additional packages
	if ( $pinterface eq "1.0" ) {
		$aptfile="$tempfolder/apt";
	} else {
		$aptfile="$tempfolder/dpkg/apt";
	}

	if (-e "$aptfile") {

		$lastaptupdate = LoxBerry::System::read_file("$lbhomedir/data/system/lastaptupdate.dat");
		$lastaptupdate = 0 if(!$lastaptupdate);
		my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";
		
		my $now = time;
		# If last run of apt-get update is longer than 24h ago, do a refresh.
		if ($now > $lastaptupdate+86400) {
			system("$wgetbin -q --timeout 5 -O /tmp/yarnpkg.gpg.pub https://dl.yarnpkg.com/debian/pubkey.gpg 2>&1");
			if ( -r "/tmp/yarnpkg.gpg.pub" )
			{
				system(substr($aptbin,0,-3)."key add /tmp/yarnpkg.gpg.pub >/dev/null 2>&1");
				unlink "/tmp/yarnpkg.gpg.pub";
				$message = "$LL{'INF_FIXYARN'}";
				&loginfo;
			}
			$message = "$LL{'INF_APTREFRESH'}";
			&loginfo;
			$message = "Command: $dpkgbin --configure -a";
			&loginfo;
			system("$dpkgbin --configure -a 2>&1");
			$message = "Command: $export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove";
			&loginfo;
			system("$export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove 2>&1");
			$message = "Command: $export $aptbin -q -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-releaseinfo-change update";
			&loginfo;
			system("$export $aptbin -q -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-releaseinfo-change update 2>&1");
			if ($? ne 0) {
				$message = "$LL{'ERR_APTREFRESH'}";
				&logerr; 
				push(@errors,"APT refresh: $message");
			} else {
				$message = "$LL{'OK_APTREFRESH'}";
				&logok;
				open(F,">$lbhomedir/data/system/lastaptupdate.dat");
				flock(F,2);
				print F $now;
				flock(F,8);
				close(F);
			}
		}
		$message = "$LL{'INF_APT'}";
		&loginfo;
		$openerr = 0;
		open(F,"<$aptfile") or ($openerr = 1);
		if ($openerr) {
			$message = "$LL{'ERR_APT'}";
			&logerr;
			push(@errors,"APT install: $message");
		}
		my @data = <F>;
		
		$aptpackages = "";
		
		foreach (@data){
			s/[\n\r]//g;
			# Comments
			if ($_ =~ /^\s*#.*/) {
				next;
			}
			$aptpackages = $aptpackages . " " . $_;
		}
		close (F);

		$message = "Command: $dpkgbin --configure -a";
		&loginfo;
		system("$dpkgbin --configure -a 2>&1");
		$message = "Command: $export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove";
		&loginfo;
		system("$export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove 2>&1");
		$message = "Command: $export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install $aptpackages";
		&loginfo;
		system("$export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install $aptpackages 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_PACKAGESINSTALL'}";
			&logwarn; 
			# If it failed, maybe due to an outdated apt-database... So
			# do a apt-get update once more
			$message = "Command: $dpkgbin --configure -a";
			&loginfo;
			system("$dpkgbin --configure -a 2>&1");
			$message = "Command: $export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove";
			&loginfo;
			system("$export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove 2>&1");
			$message = "Command: $export $aptbin -q -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages update";
			&loginfo;
			system("$export $aptbin -q -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages update 2>&1");
			if ($? ne 0) {
				$message = "$LL{'ERR_APTREFRESH'}";
				&logerr; 
				push(@errors,"APT refresh: $message");
			} else {
				$message = "$LL{'OK_APTREFRESH'}";
				&logok;
				open(F,">$lbhomedir/data/system/lastaptupdate.dat");
				flock(F,2);
				print F $now;
				flock(F,8);
				close(F);
			}
			# And try to install packages again...
			$message = "Command: $export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove";
			&loginfo;
			system("$export $aptbin -y -q --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove 2>&1");
			$message = "Command: $export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install $aptpackages";
			&loginfo;
			system("$export $aptbin --no-install-recommends -q -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install $aptpackages 2>&1");
			if ($? ne 0) {
				$message = "$LL{'ERR_PACKAGESINSTALL'}";
				&logwarn; 
				push(@errors,"APT install: $message");
			} else {
				$message = "$LL{'OK_PACKAGESINSTALL'}";
				&logok;
			}
		} else {
			$message = "$LL{'OK_PACKAGESINSTALL'}";
			&logok;
		}
	}

	# Supplied packages by architecture
	if ( $pinterface ne "1.0" ) {
		my $thisarch;
		if (-e "$lbsconfigdir/is_raspberry.cfg") {
			$thisarch = "raspberry";
		}
		elsif (-e "$lbsconfigdir/is_x86.cfg") {
			$thisarch = "x86";
		}
		elsif (-e "$lbsconfigdir/is_x64.cfg") {
			$thisarch = "x64";
		}
		if ( $thisarch ) {
			my @debfiles = glob("$tempfolder/dpkg/$thisarch/*.deb");
			if( my $cnt = @debfiles ){
				$message = "Command: $dpkgbin -i -R $tempfolder/dpkg/$thisarch";
				&loginfo;
				system("$dpkgbin -i -R $tempfolder/dpkg/$thisarch 2>&1");
				if ($? ne 0) {
					$message = "$LL{'ERR_PACKAGESINSTALL'}";
					&logerr; 
					push(@errors,"APT install: $message");
				} else {
					$message = "$LL{'OK_PACKAGESINSTALL'}";
					&logok;
				}
			}
		}
	}

	# We have to recreate the skels for system log folders in tmpfs
	$message = "$LL{'INF_LOGSKELS'}";
	&loginfo;
	$message = "Command: $lbssbindir/createskelfolders.pl";
	system("$lbssbindir/createskelfolders.pl 2>&1");
	$exitcode = $? >> 8;
	if ($exitcode eq 1) {
		$message = "$LL{'ERR_SCRIPT'}";
		&logerr; 
		push(@errors,"SKEL FOLDERS: $message");
	} 
	else {
		$message = "$LL{'OK_SCRIPT'}";
		&logok;
	}

	# Executing postinstall script
	if (-f "$tempfolder/postinstall.sh") {
		$message = "$LL{'INF_START_POSTINSTALL'}";
		&loginfo;

		$message = "Command: cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/postinstall.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\"";
		&loginfo;

		system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/postinstall.sh\" 2>&1");
		system("cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/postinstall.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1");
		$exitcode	= $? >> 8;
		if ($exitcode eq 1) {
			$message = "$LL{'ERR_SCRIPT'}";
			&logerr; 
			push(@errors,"POSTINSTALL: $message");
		} 
		elsif ($exitcode > 1) {
			$message = "$LL{'FAIL_SCRIPT'}";
			&logfail; 
		}
		else {
			$message = "$LL{'OK_SCRIPT'}";
			&logok;
		}

	}

	# Executing postupgrade script
	if ($isupgrade) {
		if (-f "$tempfolder/postupgrade.sh") {
			$message = "$LL{'INF_START_POSTUPGRADE'}";
			&loginfo;

			$message = "Command: cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/postupgrade.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\"";
			&loginfo;

			system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/postupgrade.sh\" 2>&1");
			system("cd \"$tempfolder\" && $sudobin -n -u loxberry \"$tempfolder/postupgrade.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1");
			$exitcode	= $? >> 8;
			if ($exitcode eq 1) {
				$message = "$LL{'ERR_SCRIPT'}";
				&logerr; 
				push(@errors,"POSTUPGRADE: $message");
			} 
			elsif ($exitcode > 1) {
				$message = "$LL{'FAIL_SCRIPT'}";
				&logfail; 
			}
			else {
				$message = "$LL{'OK_SCRIPT'}";
				&logok;
			}

		}
	}

	# Executing postroot script
	if (-f "$tempfolder/postroot.sh") {
		$message = "$LL{'INF_START_POSTROOT'}";
		&loginfo;

		$message = "Command: cd \"$tempfolder\" && \"$tempfolder/postroot.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\"";
		&loginfo;

		system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/postroot.sh\" 2>&1");
		system("cd \"$tempfolder\" && \"$tempfolder/postroot.sh\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1");
		$exitcode	= $? >> 8;
		if ($exitcode eq 1) {
			$message = "$LL{'ERR_SCRIPT'}";
			&logerr; 
			push(@errors,"POSTROOT: $message");
		} 
		elsif ($exitcode > 1) {
			$message = "$LL{'FAIL_SCRIPT'}";
			&logfail; 
		}
		else {
			$message = "$LL{'OK_SCRIPT'}";
			&logok;
		}

	}

	# Copy installation files
	make_path("$lbhomedir/data/system/install/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	my @installfiles = glob("$tempfolder/*.sh");
	if( my $cnt = @installfiles ){
		$message = "$LL{'INF_INSTALLSCRIPTS'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -v $tempfolder/*.sh $lbhomedir/data/system/install/$pfolder 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"INSTALL scripts: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}
		&setowner ("loxberry", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
		&setrights ("755", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
	}
	if( -e "$tempfolder/apt" ){
		$message = "$LL{'INF_INSTALLAPT'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -rv $tempfolder/apt $lbhomedir/data/system/install/$pfolder 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"INSTALL scripts: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}
		&setowner ("loxberry", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
		&setrights ("755", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
	}
	if( -e "$tempfolder/dpkg" ){
		$message = "$LL{'INF_INSTALLAPT'}";
		&loginfo;
		system("$sudobin -n -u loxberry cp -rv $tempfolder/dpkg $lbhomedir/data/system/install/$pfolder 2>&1");
		if ($? ne 0) {
			$message = "$LL{'ERR_FILES'}";
			&logerr; 
			push(@errors,"INSTALL scripts: $message");
		} else {
			$message = "$LL{'OK_FILES'}";
			&logok;
		}
		&setowner ("loxberry", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
		&setrights ("755", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
	}

	# Cleaning
	$message = "$LL{'INF_END'}";
	&loginfo;
	print "Tempfolder is: $tempfile\n";
	if ( -e "$lbsdatadir/tmp/uploads/$tempfile" ) {
		system("$sudobin -n -u loxberry rm -vrf $lbsdatadir/tmp/uploads/$tempfile 2>&1");
	}
	if ( $R::tempfile ) {
		system("$sudobin -n -u loxberry rm -vf $lbsdatadir/tmp/uploads/$tempfile.zip 2>&1");
	} 

	# Finished
	$message = "$LL{'OK_END'}";
	&logok;

	# Set Status
	if (-e $statusfile) {
		if ($preboot) {
			open (F, ">$statusfile");
			flock(F,2);
			print F "3";
			flock(F,8);
			close (F);
			reboot_required("$LL{'INF_REBOOT'} $ptitle");
		} else {
			open (F, ">$statusfile");
			flock(F,2);
			print F "0";
			flock(F,8);
			close (F);
		}
	}

	# Log errora
	if (@errors || @warnings) {
		LOGWARN "An error or warning occurred";
	} else {
		LOGOK "Everything seems to be OK";
	}
	LOGEND;

	# Saving Logfile
	$message = "$LL{'INF_SAVELOG'}";
	&loginfo;
	system("cp -v /tmp/$tempfile.log $lbhomedir/log/system/plugininstall/$pname.log 2>&1");
	&setowner ("loxberry", "0", "$lbhomedir/log/system/plugininstall/$pname.log", "LOG Save");

	$message = "$SL{'PLUGININSTALL.INF_LAST'}";
	&logok;

	print "\n\n";

	# Error summarize
	if (@errors || @warnings) {
		$message = "==================================================================================";
		&loginfo;
		$message = "$SL{'PLUGININSTALL.INF_ERRORSUMMARIZE'}";
		&loginfo;
		$message = "==================================================================================";
		&loginfo;
		foreach(@errors) {
			$message = $_;
			&logerr;
		}
		foreach(@warnings) {
			$message = $_;
			&logwarn;
		}
	}
	if ($chkhcpath) {
		print "$chkhcpath";
	}

	# Remove Lock
	LoxBerry::System::unlock( lockfile => 'plugininstall' );

	exit (0);

}

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Purge installation
#####################################################

sub purge_installation {

	my $option = shift;
	$option = $option ? $option : "";

	my $exitcode;
	my $output;

	# 1. Delete cron jobs
	if($pname) {
		# Cron jobs
		$message = "Removing cron jobs";
		&loginfo;
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.01min/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.03min/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.05min/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.10min/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.15min/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.30min/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.hourly/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.daily/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.weekly/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.monthly/$pname 2>&1" );
		execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.yearly/$pname 2>&1" );
	
		# 2. Delete individual crontab file (only on uninstall)
		if ($option eq "all") {
			# Crontab
			$message = "Removing crontab";
			&loginfo;
			execute( command => "rm -vf $lbhomedir/system/cron/cron.d/$pname 2>&1" );
		}
	}

	# 3. Run uninstall script (only on uninstall)
	if( $pname and $option eq "all" ) {
			# Executing uninstall script
		if (-f "$lbhomedir/data/system/uninstall/$pname") {
			$message = "$LL{'INF_START_UNINSTALL_EXE'}";
			&loginfo;
			my $commandline = qq(cd /tmp && "$lbhomedir/data/system/uninstall/$pname" "/tmp" "$pname" "$pfolder" "$pversion" "$lbhomedir" 2>&1);
			($exitcode, $output) = execute( command => $commandline );
			if ($exitcode eq 1) {
				$message = "$LL{'ERR_SCRIPT'}";
				&logerr;
				$message = "Script output:";
				&loginfo;
				$message = $output;
				&loginfo;
				push(@errors,"UNINSTALL execution: $LL{'ERR_SCRIPT'}");
			} 
			elsif ($exitcode > 1) {
				$message = "$LL{'FAIL_SCRIPT'}";
				&logfail;
				$message = "Script output:";
				&loginfo;
				$message = $output;
				&loginfo;
			}
			else {
				$message = "$LL{'OK_SCRIPT'}";
				&logok;
				$message = "Script output:";
				&loginfo;
				$message = $output;
				&loginfo;
			}
		} else {
			$message = "No uninstall script provided.";
			&loginfo;
		}
	}
	
	if ($pname) {
		# 4. Delete uninstall file
		if (-f "$lbhomedir/data/system/uninstall/$pname") {
			$message = "Deleting uninstall file";
			&loginfo;
			execute( command => "rm -fv $lbhomedir/data/system/uninstall/$pname 2>&1");
		}
		# 5. Delete daemon
		$message =  "Deleting daemon";
		&loginfo;
		execute( command => "rm -fv $lbhomedir/system/daemons/plugins/$pname 2>&1");
		# 6. Delete Sudoers
		$message = "Deleting sudoers file";
		&loginfo;
		execute( command => "rm -fv $lbhomedir/system/sudoers/$pname 2>&1");
		
		# DON NOT DELETE the install Log anymore
		# system("rm -fv $lbhomedir/log/system/plugininstall/$pname.log 2>&1");
	}
	
	# 7. Delete plugin folders
	if ($pfolder) {
		# Plugin Folders
		$message = "Deleting plugin folders";
		&loginfo;
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/config/plugins/$pfolder/ 2>&1");
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/bin/plugins/$pfolder/ 2>&1");
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/data/plugins/$pfolder/ 2>&1");
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/templates/plugins/$pfolder/ 2>&1");
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1");
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/html/plugins/$pfolder/ 2>&1");
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/data/system/install/$pfolder 2>&1");
		# Icons for Main Menu
		$message = "Deleting plugin icons";
		&loginfo;
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
	}

	# 8. Remove Plugin from plugin database
	if ($option eq "all") {
		if ($plugin) {
			$message = "Removing plugin from plugin database";
			&loginfo;
			$plugin->remove();
			undef $plugin;
		} else {
			$message = "$LL{'ERR_DATABASE'}";
			&logerr;
		}
	}
	
	# 9. Delete Log folder
	if ($option eq "all" and $pfolder) {
		$message = "Deleting plugins log folder";
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/log/plugins/$pfolder/ 2>&1");
	}

	return;

}

#####################################################
# Logging installation
#####################################################

sub logerr {

	my $currtime = currtime('hr');
	if ( !$is_cgi ) {
		print "$currtime \e[1m\e[31mERROR:\e[0m $message\n";
		open (LOG, ">>$logfile");
		flock(LOG,2);
		print LOG "$currtime <ERROR> $message\n";
		flock(LOG,8);
		close (LOG);
	} else {
		print "$currtime <ERROR> $message\n";
	}
	
	# Notify
	notify ( "plugininstall", "$pname", $LL{'UI_NOTIFY_INSTALL_ERROR'} . " " . $ptitle . ": " . $message);

	return();

}

sub logfail {

	my $currtime = currtime('hr');
	if ( !$is_cgi ) {
		print "$currtime \e[1m\e[31mFAIL:\e[0m $message\n";
		open (LOG, ">>$logfile");
		flock(LOG,2);
		print LOG "$currtime <FAIL> $message\n";
		flock(LOG,8);
		close (LOG);
	} else {
		print "$currtime <FAIL> $message\n";
	}

	if ( -e "/tmp/uploads/$tempfile" ) {
		system("$sudobin -n -u loxberry rm -rf /tmp/uploads/$tempfile 2>&1");
	}
	if ( $R::tempfile ) {
		system("$sudobin -n -u loxberry rm -vf /tmp/$tempfile.zip 2>&1");
	} 

	if (-e $statusfile) {
		open (F, ">$statusfile");
		flock(F,2);
		print F "2";
		flock(F,8);
		close (F);
	}
	
	# Notify
	$message = $message . " " . $LL{'UI_INSTALL_LABEL_ERROR'};
	notify ( "plugininstall", "$pname", $LL{'UI_NOTIFY_INSTALL_FAIL'} . " " . $ptitle . ": " . $message, 1);

	# Unlock and exit
	LoxBerry::System::unlock( lockfile => 'plugininstall' );
	exit (1);

}

sub logwarn {

	my $currtime = currtime('hr');
	if ( !$is_cgi ) {
		print "$currtime \e[1m\e[31mWARNING:\e[0m $message\n";
		open (LOG, ">>$logfile");
		flock(LOG,2);
		print LOG "$currtime <WARNING> $message\n";
		flock(LOG,8);
		close (LOG);
	} else {
		print "$currtime <WARNING> $message\n";
	}
	
	# Notify
	notify ( "plugininstall", "$pname", $LL{'UI_NOTIFY_INSTALL_WARN'} . " " . $ptitle . ": " . $message);

	return();

}


sub loginfo {

	my $currtime = currtime('hr');
	if ( !$is_cgi ) {
		print "$currtime \e[1mINFO:\e[0m $message\n";
		open (LOG, ">>$logfile");
		flock(LOG,2);
		print LOG "$currtime <INFO> $message\n";
		flock(LOG,8);
		close (LOG);
	} else {
		print "$currtime <INFO> $message\n";
	}

	return();

}

sub logok {

	my $currtime = currtime('hr');
	if ( !$is_cgi ) {
		print "$currtime \e[1m\e[32mOK:\e[0m $message\n";
		open (LOG, ">>$logfile");
		flock(LOG,2);
		print LOG "$currtime <OK> $message\n";
		flock(LOG,8);
		close (LOG);
	} else {
		print "$currtime <OK> $message\n";
	}

	return();

}

#####################################################
# Random
#####################################################

sub generate {
	my ($count) = @_;
	my($zufall,@words,$more);

	if($count =~ /^\d+$/){
		$more = $count;
	} else {
		$more = 10;
	}

	@words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

	foreach (1..$more){
		$zufall .= $words[int rand($#words+1)];
	}

	return($zufall);
}

#####################################################
# Check if folder is empty
#####################################################

sub is_folder_empty {
	return -1 if not -e $_[0];   # does not exist
    return -2 if not -d $_[0];   # in not a directory
    opendir my $dir, $_[0] or    # likely a permissions issue
        print "is_folder_empty: Cannot opendir '".$_[0]."', because: $!\n";
    readdir $dir;	# Skip .
    readdir $dir;	# Skip ..
    return 0 if( readdir $dir ); # 3rd times a charm
    return 1;
}

#####################################################
# Set owner
#####################################################

# &setowner ("loxberry", "1", "path/to/folder", "CONFIG files");
# &setowner ("root", "0", "path/to/file", "DAEMON script");

sub setowner {

	my $owner = shift;
	my $group = $owner;
	my $recursive = shift;
	my $target = shift;
	my $type = shift;
	my $chownoptions;

	if ( $recursive ) {
		$chownoptions = "-Rv";
	} else {
		$chownoptions = "-v";
	}

	$message = $LL{'INF_FILE_OWNER'} . " $chownbin $chownoptions $owner.$group $target";
	&loginfo;
	system("$chownbin $chownoptions $owner.$group $target 2>&1");
	if ($? ne 0) {
		$message = "$LL{'ERR_FILE_OWNER'}";
		&logerr; 
		push(@errors,"$type: $message");
	} else {
		$message = "$LL{'OK_FILE_OWNER'}";
		&logok;
	}

}

#####################################################
# Set permissions
#####################################################

# &setrights ("755", "1", "path/to/folder", "CONFIG files" [,"Regex"]);
# &setrights ("644", "0", "path/to/file", "DAEMON script" [,"Regex"]);

sub setrights {

	my $rights = shift;
	my $recursive = shift;
	my $target = shift;
	my $type = shift;
	my $regex = shift;
	my $chmodoptions;

	if ( $recursive ) {
		$chmodoptions = "-Rv";
	} else {
		$chmodoptions = "-v";
	}

	if ($regex) {

		$chmodoptions = "-v";
		$message = $LL{'INF_FILE_PERMISSIONS'} . " $findbin $target -iregex '$regex' -exec $chmodbin $chmodoptions $rights {} \\;";
		&loginfo;
		system("$sudobin -n -u loxberry $findbin $target -iregex '$regex' -exec $chmodbin $chmodoptions $rights {} \\; 2>&1");

	} else {

		$message = $LL{'INF_FILE_PERMISSIONS'} . " $chmodbin $chmodoptions $rights $target";
		&loginfo;
		system("$chmodbin $chmodoptions $rights $target 2>&1");

	}
	if ($? ne 0) {
		$message = "$LL{'ERR_FILE_PERMISSIONS'}";
		&logerr; 
		push(@errors,"$type: $message");
	} else {
		$message = "$LL{'OK_FILE_PERMISSIONS'}";
		&logok;
	}

}

#####################################################
# Replace strings in pluginfiles
#####################################################
# replaceenv ($user, @filelist);
# &replaceenv ("loxberry", @arrayOfFiles);

sub replaceenv {

	$message = "$LL{'INF_REPLACEENVIRONMENT'}";
	&loginfo;
	
	my $user = shift;
	my $replacefiles = shift;

	if( ref($replacefiles) eq "" ) {
		$replacefiles = ( $replacefiles );
	}
	if( ref($replacefiles) ne "ARRAY" ) {
		$message = "replaceenv: Incoming filelist is not an ARRAY.";
		&logerr;
		return;
	}

	my $sed_replace_query =  
			"s#REPLACELBHOMEDIR#$lbhomedir#g; " .
			"s#REPLACELBPPLUGINDIR#$pfolder#g; " .
			"s#REPLACELBPHTMLAUTHDIR#$lbhomedir/webfrontend/htmlauth/plugins/$pfolder#g; " .
			"s#REPLACELBPHTMLDIR#$lbhomedir/webfrontend/html/plugins/$pfolder#g; " .
			"s#REPLACELBPTEMPLATEDIR#$lbhomedir/templates/plugins/$pfolder#g; " .
			"s#REPLACELBPDATADIR#$lbhomedir/data/plugins/$pfolder#g; " .
			"s#REPLACELBPLOGDIR#$lbhomedir/log/plugins/$pfolder#g; " . 
			"s#REPLACELBPCONFIGDIR#$lbhomedir/config/plugins/$pfolder#g; " .
			"s#REPLACELBPBINDIR#$lbhomedir/bin/plugins/$pfolder#g;";

	$message = "Running replacement for " . scalar @$replacefiles . " files";
	&loginfo;
	my $counter = 0;
	foreach(@$replacefiles) {
		$counter++;
		if($counter%20 == 0) {
			$message = "  $counter of " . scalar @$replacefiles . " finished ...";
			&loginfo;
		}
		# # Debug
		# $message="File: $_";
		# &loginfo;
		
		`$sudobin -n -u $user /bin/sed -i '$sed_replace_query' "$_" 2>&1`;
	}
	$message = "Replace of $counter files finished";
	&logok;
		
	return;

}

#####################################################
# Conerting all files to unix fileformat
#####################################################

# &dos2unix ("loxberry", "1", "path/to/folder");

sub dos2unix {

	my $user = shift;
	my ($filelist) = @_;

	if( ref($filelist) eq "" ) {
		$filelist = ( $filelist );
	}
	if( ref($filelist) ne "ARRAY" ) {
		$message = "dos2unix: Incoming filelist is not an ARRAY.";
		&logerr;
		return;
	}

	$message = "$LL{'INF_DOS2UNIX'}";
	&loginfo;

	foreach(@$filelist) 
	{
		system("$sudobin -n -u $user $dos2unix -- '" . $_ . "' 2>&1");
	}

	return;

}

#####################################################
# Querying all files from a $target to be text files
#####################################################

# @textfiles = getTextFiles("/path/to/folder");

sub getTextFiles 
{
	my ($target) = @_;

	$message = "Getting file list from $target";
	&loginfo;

	require File::Find::Rule;
	my @files = File::Find::Rule
		->file()
		->name( '*' )
		->nonempty
		->in($target);

	$message = "Found " . scalar @files . " files";
	&loginfo;

	$message = "Filtering out binary files";
	&loginfo;
	my @textfiles;
	my $counter = 0;
	foreach(@files) 
	{
		$counter++;
		my $bin_text = `file -b "$_"`;
		push @textfiles, "$_" if ( index( "$bin_text", 'text' ) != -1 );
		if( $counter%20 == 0 ) 
		{
			$message = "  " . scalar @textfiles . " textfiles found out of $counter files scanned...";
			&loginfo;
		}
	}
	$message = "  " . scalar @textfiles . " textfiles found out of $counter files scanned...";
	&loginfo;
	$message = "Found " . scalar @textfiles . " files to be text files";
	&logok;
	return @textfiles;
}

# Local phases 
# This phrases are English only, and only used in this script
# Usage: $LL{'ERR_NOFOLDER_OR_ZIP'} ( instead of system phrases $SL{'PLUGININSTALL.SOMETHING'} )

sub localphrases {

	my %local_lang = (
	ERR_NOFOLDER_OR_ZIP => "You have to specify a folder OR ZIP file with PLUGIN data.",
	ERR_FOLDER_DOESNT_EXIST => "Plugin folder does not exist.",
	ERR_FILE_DOESNT_EXIST => "Plugin file does not exist.",
	ERR_TEMPFILES_EXISTS => "Temporary files already exist.",
	INF_START => "Starting Plugin installation.",
	ERR_ARCHIVEFORMAT => "The plugin archive seems to be in an invalid format. Please contact the plugin author or try again.",
	ERR_ACTION => "You have to specify 'action=install', 'action=uninstall' or 'action=autoupdate'.",
	INF_EXTRACTING => "Extracting plugin archive",
	ERR_EXTRACTING => "Error while extracting from plugin archive.",
	OK_EXTRACTING => "Plugin archive extracted successfully.",
	ERR_PLUGINCFG => "Mandatory configuration parameters missing in the plugin archive. Please contact the plugin author.",
	OK_PLUGINCFG => "All mandatory configuration parameters found.",
	ERR_DATABASE => "Could not open plugin database or database does not exist.",
	INF_ISUPDATE => "Plugin is already installed -> proceeding with upgrade.",
	OK_DBENTRY => "Found free database entry.",
	ERR_DBENTRY => "No free database entry available.",
	INF_PNAME_IS => "Using plugin name:",
	INF_PFOLDER_IS => "Using installation folder:",
	INF_START_PREROOT => "Starting script PREROOT.",
	INF_START_PREINSTALL => "Starting script PREINSTALL.",
	INF_START_PREUPGRADE => "Starting script PREUPGRADE.",
	ERR_SCRIPT => "Script finished with errors. I will try to continue installation.",
	OK_SCRIPT => "Script executed successfully.",
	FAIL_SCRIPT => "Script fails. Installation cannot be continued.",
	INF_CONFIG => "Installing configuration files.",
	INF_BIN => "Installing bin files.",
	ERR_FILES => "Not all file(s) could be installed successfully.",
	OK_FILES => "All file(s) were installed successfully.",
	INF_TEMPLATES => "Installing template files.",
	INF_DAEMON => "Installing DAEMON.",
	INF_FILE_PERMISSIONS => "Setting file permissions:",
	ERR_FILE_PERMISSIONS => "File permissions could not be set.",
	OK_FILE_PERMISSIONS => "File permissions set successfully.",
	INF_FILE_OWNER => "Setting file ownership:",
	ERR_FILE_OWNER => "File ownership could not be set.",
	OK_FILE_OWNER => "File ownership set successfully.",
	INF_UNINSTALL => "Installing uninstall script.",
	INF_SUDOERS => "Installing sudoers file.",
	INF_CRONJOB => "Installing cronjob files.",
	INF_DATAFILES => "Installing data files.",
	INF_LOGFILES => "Installing log files.",
	INF_HTMLAUTHFILES => "Installing htmlauth files.",
	INF_HTMLFILES => "Installing html files.",
	INF_ICONFILES => "Installing icon files.",
	ERR_ICONFILES => "Icons could not be (completely) installed. Using some default icons.",
	OK_ICONFILES => "Icons installed successfully.",
	INF_APTREFRESH => "Refreshing APT database.",
	ERR_APTREFRESH => "APT database could not be refreshed.",
	OK_APTREFRESH => "APT database refreshed successfully.",
	INF_APT => "Installing additional software packages.",
	ERR_APT => "Cannot open APT file.",
	ERR_PACKAGESINSTALL => "(Some) Packages could not be installed.",
	OK_PACKAGESINSTALL => "Package installed successfully.",
	INF_START_POSTINSTALL => "Starting script POSTINSTALL.",
	INF_START_POSTUPGRADE => "Starting script POSTUPGRADE.",
	INF_START_POSTROOT => "Starting script POSTROOT.",
	INF_END => "Cleaning and removing temporary files.",
	OK_END => "All Plugin files were installed successfully and system was cleaned up.",
	INF_REMOVING_OLD_INSTALL => "Removing old installation.",
	INF_INSTALLSCRIPTS => "Saving all package installation scripts.",
	INF_INSTALLAPT => "Saving package apt and dpkg files.",
	INF_REPLACEENVIRONMENT => "Replacing environment strings.",
	INF_REPLACEING => "Replacing:",
	ERR_NOPID => "You have to specify the PID.",
	ERR_PIDNOTEXIST => "The PID does not exist.",
	INF_START_UNINSTALL_EXE => "Executing uninstall script.",
	ERR_ARCH => "This system has the wrong architecture.",
	OK_ARCH => "The system's architecture is supported.",
	INF_LBVERSION => "Current LoxBerry version: ",
	INF_MINVERSION => "Installation limited from: ",
	ERR_MINVERSION => "Minimal required LoxBerry version is greater than current LoxBerry version. Cannot install.",
	OK_MINVERSION => "Current LoxBerry version is greater than minimal required LoxBerry version.",
	INF_MAXVERSION => "Installation limited to: ",
	ERR_MAXVERSION => "Current LoxBerry version is greater than maximal allowed LoxBerry version. Cannot install.",
	OK_MAXVERSION => "Maximal allowed LoxBerry version is greater than current LoxBerry version.",
	ERR_NOPIN => "You have to specify the SecurePIN for installation.",
	ERR_SECUREPIN_WRONG => "The entered SecurePIN is wrong.",
	ERR_NO_SPACE_IN_TMP => "There's not enough RAM in your RAM-disk (/tmp) to extract the ZIP archive. Please reboot and retry. Disk free: ",
	ERR_NO_SPACE_IN_ROOT => "There's not enough space left in the LoxBerry home folder. Free space: ",
	INF_SAVELOG => "Saving logfile.",
	INF_LOCKING => "Locking plugininstall - delaying up to 10 minutes...",
	ERR_LOCKING => "Could not get lock for plugininstall. Skipping this installation.",
	ERR_LOCKING_REASON => "The reason is:",
	OK_LOCKING => "Lock successfully set.",
	ERR_UNKNOWNINTERFACE => "The Plugin Interface is unknown. I cannot proceed with the installation.",
	INF_DOS2UNIX => "Converting all plugin files (ASCII) to Unix fileformat.",
	INF_LOGSKELS => "Updating skels for Logfiles in tmpfs.",
	INF_SHADOWDB => "Creating shadow version of plugindatabase.",
	ERR_UNKNOWN_FORMAT_PLUGINCFG => "Could not parse plugin.cfg. Maybe it has a wrong format.",
	INF_FIXYARN => "Updating Yarn Key if internet connection is available.",

	);

	return %local_lang;

}



