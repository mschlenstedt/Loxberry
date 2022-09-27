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
use LoxBerry::Update;
use File::Basename;
use LoxBerry::System::PluginDB;
use LoxBerry::JSON;
use LoxBerry::Log;
use CGI;
use version;
use warnings;
use strict;

# Version of this script
my $version = "3.0.0.4";

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
my $lbversionmajor;
my $aptfile;
my $openerr;
my $lastaptupdate;
my $aptpackages;
our $log;
my $logfile;
my $statusfile;
my $chkhcpath;
my $pid;
my $pauthorname;
my $pauthoremail;
my $pversion;
my $pname = "unknown"; # set dummy at this point
my $ptitle = "Unknown Plugin"; # set dummy at this point;
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
my $script;
our $output;
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
our $errors; # Will be filled by LoxBerry::Uupdate
my @warnings;

if ( !$R::action || ($R::action ne "install" && $R::action ne "uninstall" && $R::action ne "autoupdate") ) {
	print STDERR "$LL{'ERR_ACTION'}" . "\n";
	exit (1);
}
if ( $R::action eq "install" ) {
	if ( (!$R::folder && !$R::file) || ($R::folder && $R::file) ) {
		print STDERR "$LL{'ERR_NOFOLDER_OR_ZIP'}" . "\n";
		exit (1);
	}
	if ( !$R::pin && $R::action ne "autoupdate" ) {
		print STDERR "$LL{'ERR_NOPIN'}" . "\n";
		exit(1);
	}
}
if ( $R::action eq "uninstall" || $R::action eq "autoupdate" ) {
	if ( !$R::pid ) {
		print STDERR "$LL{'ERR_NOPID'}" . "\n";
		exit (1);
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
		&fail($message);
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
	if ($is_cgi eq 0) {
		$log->stdout(1);
	}
	LOGSTART ("Plugin Uninstallation $ptitle");

	LOGINF ("Requesting lock");
	$errors = 0;
	eval {
		my $lockstate = LoxBerry::System::lock( lockfile => 'plugininstall', wait => 10 );
		$errors = $lockstate if ($lockstate);
	};
	if ($errors) {
		LOGERR ("$LL{'ERR_LOCKING'}");
		LOGFAIL ("$LL{'ERR_LOCKING_REASON'} $errors");
		&fail;
	}
	LOGOK ("$LL{'OK_LOCKING'}");
	
	LOGINF ("Setting systemwide information about plugin uninstall");
	$statedata->{db_updated} = time;
	$statedata->{last_plugin_uninstall} = time;
	
	&purge_installation("all");
	
	# Purge plugin notifications
	if($pfolder) {
		LOGINF ("Deleting notifications of plugin $pfolder");
		LoxBerry::Log::delete_notifications($pfolder);
	}

	# Remove Lock
	LOGINF ("Removing lock");
	LoxBerry::System::unlock( lockfile => 'plugininstall' );
	
	LOGEND;
	
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
	
	# Create Logfile with lib to have it in database
	$log = LoxBerry::Log->new(
		package => 'Plugin Installation',
		name => 'Install',
		filename => $logfile,
		loglevel => 7,
		addtime => 1
	);

	if ($is_cgi eq 0) {
		$log->stdout(1);
	}
	LOGSTART "Plugin Installation";

	if (-e "$statusfile") {
		$message = "$LL{'ERR_TEMPFILES_EXISTS'}";
		LOGCRIT $message;
		&fail($message);
	}

	LOGINF "Statusfile: $statusfile";
	($exitcode) = LoxBerry::System::write_file("$statusfile", "1");
	if ($exitcode) {
		$message = "$LL{'ERR_TEMPFILES_EXISTS'}" . " $exitcode";
		LOGCRIT $message;
		&fail($message);
	}

	# Check secure PIN
	if ( $R::action ne "autoupdate" ) {
		my $pin = $R::pin;

		if ( LoxBerry::System::check_securepin($pin) ) {
			$message = "$LL{'ERR_SECUREPIN_WRONG'}";
			LOGCRIT $message;
			&fail($message);
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
			LOGCRIT $message;
			&fail($message);
		}

	}

	if (!$zipmode) { 
		require Cwd;
		$tempfolder = abs_path($R::folder);
		if (!-e $tempfolder) {
			$message = "$LL{'ERR_FOLDER_DOESNT_EXIST'}";
			LOGCRIT $message;
			&fail($message);
		}
	} else {
		$tempfolder = "$lbsdatadir/tmp/uploads/$tempfile";
		if (!-e $R::file) {
			$message = "$LL{'ERR_FILE_DOESNT_EXIST'}";
			LOGCRIT $message;
			&fail($message);
		}

		open(F, $R::file);
		if(read(F, my $buffer, 2))
		{
			close(F);
			if($buffer ne 'PK')
			{
				$message = "$LL{'ERR_ARCHIVEFORMAT'}";
				LOGCRIT $message;
				&fail($message);
			}
		}
		make_path("$tempfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	}
	$tempfolder =~ s/(.*)\/$/$1/eg; # Clean trailing /
	LOGINF "Temp Folder: $tempfolder";
	LOGINF "Logfile: $logfile";

	# Check free space in tmp
	my $pluginsize;
	my %folderinfo;
	if ( $zipmode ) {
		$pluginsize = `$unzipbin -l $R::file | tail -1 | xargs | cut -d' ' -f1`;
		$pluginsize = $pluginsize / 1000; # kBytes
		%folderinfo = LoxBerry::System::diskspaceinfo("$lbsdatadir/tmp/uploads");
		if ($folderinfo{available} < $pluginsize * 1.1) { # exstracted size + 10%
			$message = "$LL{'ERR_NO_SPACE_IN_TMP'} " . $folderinfo{available} . " kB";
			LOGCRIT $message;
			&fail($message);
		}
	} else {
		$pluginsize = `du -bs $tempfolder | tail -1 | xargs | cut -d' ' -f1`;
		$pluginsize = $pluginsize / 1000; # kBytes
	}

	# Check free space in $lbhomedir
	%folderinfo = LoxBerry::System::diskspaceinfo($lbhomedir);
	if ($folderinfo{available} < $pluginsize * 1.1) { # exstracted size + 10%
		$message = "$LL{'ERR_NO_SPACE_IN_ROOT'} " . $folderinfo{available} . " kB";
		LOGCRIT $message;
		&fail($message);
	}

	# Locking
	LOGINF "$LL{'INF_LOCKING'}";
	$errors = 0;
	eval {
		my $lockstate = LoxBerry::System::lock( lockfile => 'plugininstall', wait => 600 );
		$errors = $lockstate if ($lockstate);
	};
	if ($errors) {
		LOGCRIT "$LL{'ERR_LOCKING'}";
		$message = "$LL{'ERR_LOCKING_REASON'} $errors";
		LOGCRIT $message;
		&fail($message);
	}
	LOGOK "$LL{'OK_LOCKING'}";

	# Starting
	LOGINF "$LL{'INF_START'}";

	# UnZipping
	if ( $zipmode ) {

		LOGINF "$LL{'INF_EXTRACTING'}";
		#system("$sudobin -n -u loxberry $unzipbin -d $tempfolder $R::file 2>&1");
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry $unzipbin -d $tempfolder $R::file 2>&1",
			log => $log,
		} );
		if ($exitcode > 0) {
			$message = "$LL{'ERR_EXTRACTING'}";
			LOGCRIT $message;
			&fail($message);
		}
		LOGOK "$LL{'OK_EXTRACTING'}";

	}

	# Check for plugin.cfg
	# If ZIP contains subfolder, add them to tempfolder
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
			LOGCRIT $message;
			&fail($message);
		}
	}

	# Read Plugin-Config
	eval {
		$pcfg = new Config::Simple("$tempfolder/plugin.cfg") or	die Config::Simple->error();
	};
	if ($@) {
		$message = "$LL{'ERR_UNKNOWN_FORMAT_PLUGINCFG'}";
		LOGCRIT $message;
		&fail($message);
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

	LOGINF "Author:         $pauthorname";
	LOGINF "Email:          $pauthoremail";
	LOGINF "Version:        $pversion";
	LOGINF "Name:           $pname";
	LOGINF "Folder:         $pfolder";
	LOGINF "Title:          $ptitle";
	LOGINF "Autoupdate:     $pautoupdates";
	LOGINF "Release:        $preleasecfg";
	LOGINF "Prerelease:     $pprereleasecfg";
	LOGINF "Reboot:         $preboot";
	LOGINF "Min LB Vers:    $plbmin";
	LOGINF "Max LB Vers:    $plbmax";
	LOGINF "Architecture:   $parch";
	LOGINF "Custom Log:     $pcustomlog";
	LOGINF "Interface:      $pinterface";

	# Add Plugintitle to Logfile title
	LOGTITLE "Plugin Installation $ptitle";

	# Use 0/1 for enabled/disabled from here on
	$pautoupdates = is_disabled($pautoupdates) ? 0 : 1;
	$preboot = is_disabled($preboot) ? 0 : 1;
	$pcustomlog = is_enabled($pcustomlog) ? 1 : 0;

	# Some checks
	if (!$pauthorname || !$pauthoremail || !$pversion || !$pname || !$ptitle || !$pfolder || !$pinterface) {
		$message = "$LL{'ERR_PLUGINCFG'}";
		LOGCRIT $message;
		&fail($message);
	}
	LOGOK "$LL{'OK_PLUGINCFG'}";

	if ( $pinterface ne "1.0" && $pinterface ne "2.0" ) {
		$message = "$LL{'ERR_UNKNOWNINTERFACE'}";
		LOGCRIT $message;
		&fail($message);
	}

	if ( $pinterface eq "1.0" ) {
		$message = "$LL{'ERR_INTERFACENOTSUPPORTED'}";
		LOGCRIT $message;
		&fail($message);
	}

	# Arch check
	if ( is_enabled($parch) ) {
		my $archcheck = 0;
		foreach (split(/,/,$parch)){
			if (-e "$lbsconfigdir/is_$_.cfg") {
				$archcheck = 1;
				LOGOK "$LL{'OK_ARCH'}";
				last;
			} 
		}
		if (!$archcheck) {
			$message = "$LL{'ERR_ARCH'}";
			LOGCRIT $message;
			&fail($message);
		}
	}

	# Version check
	my $versioncheck = 0;
	if (version::is_lax(vers_tag(LoxBerry::System::lbversion()))) {
		$versioncheck = 1;
		$lbversion = version->parse(vers_tag(LoxBerry::System::lbversion()));
		$lbversionmajor = $lbversion =~ s/^v(\d+)\..*/$1/r; # Major Version, e. g. "2"
		LOGINF $LL{'INF_LBVERSION'} . $lbversion;
	} else {
		$versioncheck = 0;
	}

	if ( !is_disabled($plbmin) && $versioncheck) {

		if ( (version::is_lax(vers_tag($plbmin))) ) {
			$plbmin = version->parse(vers_tag($plbmin));
			LOGINF $LL{'INF_MINVERSION'} . $plbmin;
		if ($lbversion < $plbmin) {
			my $generalcfg = new Config::Simple("$lbsconfigdir/general.cfg");
			if ($generalcfg->param("UPDATE.RELEASETYPE") and $generalcfg->param("UPDATE.RELEASETYPE") eq "latest") {
				$message = $LL{'INF_MINVERSION'} . $plbmin;
				push(@warnings, "$message");
				LOGWARN $message;
				$message = "This plugin requests a newer LoxBerry version than installed. As you have set LoxBerry Update ";
				push(@warnings, "$message");
				LOGWARN $message;
				$message = "to 'Latest commit', this plugin installation is allowed at your own risk. To test this plugin, you should ";
				push(@warnings, "$message");
				LOGWARN $message;
				$message = "now also run LoxBerry Update. Don't bother the plugin developer if you haven't done so. Happy testing!";
				push(@warnings, "$message");
				LOGWARN $message;
			} else {
				$message = "$LL{'ERR_MINVERSION'}";
				LOGCRIT $message;
				&fail($message);
			}
		} else {
				LOGOK "$LL{'OK_MINVERSION'}";
			}
		} 

	}

	if ( !is_disabled($plbmax) && $versioncheck) {

		if ( (version::is_lax(vers_tag($plbmax))) ) {
			$plbmax = version->parse(vers_tag($plbmax));
			LOGINF $LL{'INF_MAXVERSION'} . $plbmax;

			if ($lbversion > $plbmax) {
				my $generalcfg = new Config::Simple("$lbsconfigdir/general.cfg");
				if ($generalcfg->param("UPDATE.RELEASETYPE") and $generalcfg->param("UPDATE.RELEASETYPE") eq "latest") {
					$message = $LL{'INF_MAXVERSION'} . $plbmin;
					push(@warnings, "$message");
					LOGWARN $message;
					$message = "This plugin requests an older LoxBerry version than installed. As you have set LoxBerry Update ";
					push(@warnings, "$message");
					LOGWARN $message;
					$message = "to 'Latest commit', this plugin installation is allowed at your own risk. Don't bother the plugin ";
					push(@warnings, "$message");
					LOGWARN $message;
					$message = "developer if he hadn't asked you to do so. Happy testing!";
					push(@warnings, "$message");
					LOGWARN $message;
				} else {
					$message = "$LL{'ERR_MAXVERSION'}";
					LOGCRIT $message;
					&fail($message);
				}
			} else {
				LOGOK "$LL{'OK_MAXVERSION'}";
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
		LOGCRIT $message;
		&fail($message);
	}
	
	LOGINF "The unique plugin id (md5) of this plugin is: " . $plugin->{md5};
	
	my $isupgrade = 0;
	
	# Everything for an UPGRADE
	if(!$plugin->{_isnew}) {
		LOGINF "$LL{'INF_ISUPDATE'}";
		$isupgrade = 1;
		$plugin->{epoch_lastupdated} = time;
		$statedata->{db_updated} = time;
		$statedata->{last_plugin_update} = time;
		LOGOK "$LL{'OK_DBENTRY'}";
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
				LOGCRIT $message;
				&fail($message);
			} else {
				# Save original and new name/folder to the plugindb
				$plugin->{name} = $pname;
				$plugin->{folder} = $pfolder;
				$plugin->{orig_name} = $plugin->{_tmp_orig_name};
				$plugin->{orig_folder} = $plugin->{_tmp_orig_folder};
			}
		}
	}
	
	LOGINF $LL{'INF_PNAME_IS'} . " $pname";
	LOGINF $LL{'INF_PFOLDER_IS'} . " $pfolder";
	
	$plugin->save();
	
	# Create shadow plugindatabase.json- and backup of plugindatabase
	LOGINF $LL{'INF_SHADOWDB'};
	#system("cp -v $LoxBerry::System::PLUGINDATABASE $LoxBerry::System::PLUGINDATABASE- 2>&1");
	execute( {
		command => "cp -v $LoxBerry::System::PLUGINDATABASE $LoxBerry::System::PLUGINDATABASE- 2>&1",
		log => $log,
	} );
	&setrights ("644", "0", "$LoxBerry::System::PLUGINDATABASE-", "PLUGIN DATABASE");
	&setowner ("root", "0", "$LoxBerry::System::PLUGINDATABASE-", "PLUGIN DATABASE");
	#system("cp -v $LoxBerry::System::PLUGINDATABASE $LoxBerry::System::PLUGINDATABASE.bkp 2>&1");
	execute( {
		command => "cp -v $LoxBerry::System::PLUGINDATABASE $LoxBerry::System::PLUGINDATABASE.bkp 2>&1",
		log => $log,
	} );
	&setrights ("644", "0", "$LoxBerry::System::PLUGINDATABASE.bkp", "PLUGIN DATABASE");
	&setowner ("loxberry", "0", "$LoxBerry::System::PLUGINDATABASE.bkp", "PLUGIN DATABASE");

	# Starting installation

	# Getting text file list
	my @textfilelist = getTextFiles($tempfolder);
	
	# Checking for hardcoded /opt/loxberry strings
	LOGINF "Checking for hardcoded paths to /opt/loxberry";
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
		LOGWARN $message;
		LOGWARN $chkhcpath;
		push(@warnings,"HARDCODED PATH'S: $message: $chkhcpath");
		
		
	} else {
		LOGOK "No hardcoded paths to /opt/loxberry found";
	}
		
	# Replacing Environment strings
	replaceenv("loxberry", \@textfilelist);
	
	# Executing DOS2UNIX for all textfiles
	if (-e "$tempfolder" ) {
		dos2unix("loxberry", \@textfilelist);
	}

	# Executing preroot script
	if (my @files = glob("$tempfolder/preroot*")) {
		LOGINF "$LL{'INF_START_PREROOT'}";
		foreach my $script ( @files ) {
			if (-f "$script") {
				&setrights ("a+x", "0", "$script", "$script file");
				($exitcode) = execute( {
					command => "cd \"$tempfolder\" && \"$script\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1",
					log => $log,
				} );
				if ($exitcode eq 1) {
					$message = "$LL{'ERR_SCRIPT'}";
					LOGERR $message; 
					push(@errors,"PREROOT: $message");
				} 
				elsif ($exitcode > 1) {
					$message = "$LL{'FAIL_SCRIPT'}";
					LOGCRIT $message;
					&fail($message);
				}
				else {
					LOGOK "$LL{'OK_SCRIPT'}";
				}
			}
		}
	}

	# Executing preupgrade script
	if ($isupgrade) {
		if (my @files = glob("$tempfolder/preupgrade*")) {
			LOGINF "$LL{'INF_START_PREUPGRADE'}";
			foreach my $script ( @files ) {
				if (-f "$script" ) {
					&setrights ("a+x", "0", "$script", "$script file");
					($exitcode) = execute( {
						command => "cd \"$tempfolder\" && $sudobin -n -u loxberry \"$script\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1",
						log => $log,
					} );
					if ($exitcode eq 1) {
						$message = "$LL{'ERR_SCRIPT'}";
						LOGERR $message;
						push(@errors,"PREUPGRADE: $message");
					} 
					elsif ($exitcode > 1) {
						$message = "$LL{'FAIL_SCRIPT'}";
						LOGCRIT $message;
						&fail($message);
					}
					else {
						LOGOK "$LL{'OK_SCRIPT'}";
					}
				}
			}
		}
		
		# Purge old installation
		LOGINF "$LL{'INF_REMOVING_OLD_INSTALL'}";
		&purge_installation;
	}

	# Executing preinstall script
	if (my @files = glob("$tempfolder/preinstall*")) {
		LOGINF "$LL{'INF_START_PREINSTALL'}";
		foreach my $script ( @files ) {
			if (-f $script ) {
				&setrights ("a+x", "0", "$script", "$script file");
				($exitcode) = execute( {
					command => "cd \"$tempfolder\" && $sudobin -n -u loxberry \"$script\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1",
					log => $log,
				} );
				if ($exitcode eq 1) {
					$message = "$LL{'ERR_SCRIPT'}";
					LOGERR $message;
					push(@errors,"PREINSTALL: $message");
				} 
				elsif ($exitcode > 1) {
					$message = "$LL{'FAIL_SCRIPT'}";
					LOGCRIT $message;
					&fail($message);
				}
				else {
					LOGOK "$LL{'OK_SCRIPT'}";
				}
			}
		}
	}

	# Copy Config files
	make_path("$lbhomedir/config/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/config")) {
		LOGINF "$LL{'INF_CONFIG'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -r -v $tempfolder/config/* $lbhomedir/config/plugins/$pfolder 2>&1",
			log => $log,
		} );
		#system("$sudobin -n -u loxberry cp -r -v $tempfolder/config/* $lbhomedir/config/plugins/$pfolder/ 2>&1");
		if ($exitcode > 0) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"CONFIG files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setowner ("loxberry", "1", "$lbhomedir/config/plugins/$pfolder", "CONFIG files");

	}

	# Copy bin files
	make_path("$lbhomedir/bin/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/bin")) {
		LOGINF "$LL{'INF_BIN'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -r -v $tempfolder/bin/* $lbhomedir/bin/plugins/$pfolder/ 2>&1",
			log => $log,
		} );
		if ($exitcode > 0) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message;
			push(@errors,"BIN files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setrights ("755", "1", "$lbhomedir/bin/plugins/$pfolder", "BIN files");
		&setowner ("loxberry", "1", "$lbhomedir/bin/plugins/$pfolder", "BIN files");

	}

	# Copy Template files
	make_path("$lbhomedir/templates/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/templates")) {
		LOGINF "$LL{'INF_TEMPLATES'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -r -v $tempfolder/templates/* $lbhomedir/templates/plugins/$pfolder/ 2>&1",
			log => $log,
		} );
		if ($exitcode > 0) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"TEMPLATE files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
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
		LOGINF "$LL{'INF_CRONJOB'}";
		$openerr = 0;
		if (-e "$tempfolder/cron/crontab" && !-e "$lbhomedir/system/cron/cron.d/$pname") {
			($exitcode) = execute( {
				command => "cp -r -v $tempfolder/cron/crontab $lbhomedir/system/cron/cron.d/$pname 2>&1",
				log => $log,
			} );
			if ($exitcode > 0) {
				$openerr = 1;
			}
			&setrights ("644", "0", "$lbhomedir/system/cron/cron.d/*", "CRONTAB files");
			&setowner ("root", "0", "$lbhomedir/system/cron/cron.d/*", "CRONTAB files");
		} 
		foreach my $cronfolder ( @cronfolders ) {
			if (-e "$tempfolder/cron/$cronfolder") {
				($exitcode) = execute( {
					command => "$sudobin -n -u loxberry cp -r -v $tempfolder/cron/$cronfolder $lbhomedir/system/cron/$cronfolder/$pname 2>&1",
					log => $log,
				} );
				if ($exitcode > 0) {
					$openerr = 1;
				}
				&setrights ("755", "1", "$lbhomedir/system/cron/$cronfolder", "CRONJOB files");
				&setowner ("loxberry", "1", "$lbhomedir/system/cron/$cronfolder", "CRONJOB files");
			} 
		}
		if ($openerr) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"CRONJOB files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
	}

	# Copy Data files
	make_path("$lbhomedir/data/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/data")) {
		LOGINF "$LL{'INF_DATAFILES'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -r -v $tempfolder/data/* $lbhomedir/data/plugins/$pfolder/ 2>&1",
			log => $log,
		} );
		if ($exitcode > 0) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"DATA files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setowner ("loxberry", "1", "$lbhomedir/data/plugins/$pfolder", "DATA files");

	}

	# Copy Log files
	make_path("$lbhomedir/log/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/log")) {
		LOGINF "$LL{'INF_LOGFILES'}";
		$message = "*** DEPRECIATED *** With plugin interface 2.0 (and above), the plugin must not ship with a log folder. Please inform the PLUGIN Author at $pauthoremail";
		LOGWARN $message; 
		push(@warnings,"LOG files: $message");
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -r -v $tempfolder/log/* $lbhomedir/log/plugins/$pfolder/ 2>&1",
			log => $log,
		} );
		if ($exitcode > 0) {
			LOGERR "$LL{'ERR_FILES'}";
			push(@errors,"LOG files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setowner ("loxberry", "1", "$lbhomedir/log/plugins/$pfolder", "LOG files");
	}

	# Copy HTMLAUTH files
	make_path("$lbhomedir/webfrontend/htmlauth/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/webfrontend/htmlauth")) {
		LOGINF "$LL{'INF_HTMLAUTHFILES'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/htmlauth/* $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1",
			log => $log,
		} );
		if ($exitcode > 0) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"HTMLAUTH files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setrights ("755", "0", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files", ".*\\.cgi\\|.*\\.pl\\|.*\\.sh");
		&setowner ("loxberry", "1", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files");
	}

	# Copy HTML files
	make_path("$lbhomedir/webfrontend/html/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	if (!&is_folder_empty("$tempfolder/webfrontend/html")) {
		LOGINF "$LL{'INF_HTMLFILES'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/html/* $lbhomedir/webfrontend/html/plugins/$pfolder/ 2>&1",
			log => $log,
		} );
		#system("$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/html/* $lbhomedir/webfrontend/html/plugins/$pfolder/ 2>&1");
		if ($exitcode > 0) {
			LOGERR "$LL{'ERR_FILES'}";
			push(@errors,"HTML files: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setrights ("755", "0", "$lbhomedir/webfrontend/html/plugins/$pfolder", "HTML files", ".*\\.cgi\\|.*\\.pl\\|.*\\.sh");
		&setowner ("loxberry", "1", "$lbhomedir/webfrontend/html/plugins/$pfolder", "HTML files");
	}

	# Copy Icon files
	make_path("$lbhomedir/webfrontend/html/system/images/icons/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	LOGINF "$LL{'INF_ICONFILES'}";
	($exitcode) = execute( {
		command => "$sudobin -n -u loxberry cp -r -v $tempfolder/icons/* $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1",
		log => $log,
	} );
	if ($exitcode > 0) {
		execute ("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/* $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		$message = "$LL{'ERR_ICONFILES'}";
		LOGERR $message; 
		push(@errors,"ICON files: $message");
	} else {
		$openerr = 0;
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_64.png") {
			$openerr = 1;
			execute("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_64.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_128.png") {
			$openerr = 1;
			execute("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_128.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_256.png") {
			$openerr = 1;
			execute("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_256.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_512.png") {
			$openerr = 1;
			execute("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_512.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
		} 
		if ($openerr) {
			$message = "$LL{'ERR_ICONFILES'}";
			LOGERR $message;
			push(@errors,"ICON files: $message");
		} else { 
			LOGOK "$LL{'OK_ICONFILES'}";
		}
		&setowner ("loxberry", "1", "$lbhomedir/webfrontend/html/system/images/icons/$pfolder", "ICON files");
	}

	# Copy Daemon file
	if (my @files = glob("$tempfolder/daemon/daemon*")) {
		LOGINF "$LL{'INF_DAEMON'}";
		my $i = "";
		foreach my $script ( @files ) {
			if (-f "$script" ) {
				($exitcode) = execute( {
					command => "cp -v $script $lbhomedir/system/daemons/plugins/$pname$i 2>&1",
					log => $log,
				} );
				if ($exitcode > 0) {
					$message = "$LL{'ERR_FILES'}";
					LOGERR $message;
					push(@errors,"DAEMON FILE: $message");
				} else {
					LOGOK "$LL{'OK_FILES'}";
				}
				&setrights ("755", "0", "$lbhomedir/system/daemons/plugins/$pname$i", "DAEMON script");
				&setowner ("root", "0", "$lbhomedir/system/daemons/plugins/$pname$i", "DAEMON script");
				$i = 0 if ($i eq "");
				$i++;
			}
		}

	}

	# Copy Uninstall file
	if (my @files = glob("$tempfolder/uninstall/uninstall*")) {
		LOGINF "$LL{'INF_UNINSTALL'}";
		my $i = "";
		foreach my $script ( @files ) {
			if (-f "$script" ) {
				($exitcode) = execute( {
					command => "cp -r -v $script $lbhomedir/data/system/uninstall/$pname$i 2>&1",
					log => $log,
				} );
				if ($exitcode > 0) {
					$message = "$LL{'ERR_FILES'}";
					LOGERR $message; 
					push(@errors,"UNINSTALL Script: $message");
				} else {
					LOGOK "$LL{'OK_FILES'}";
				}
				&setrights ("755", "0", "$lbhomedir/data/system/uninstall/$pname$i", "UNINSTALL script");
				&setowner ("root", "0", "$lbhomedir/data/system/uninstall/$pname$i", "UNINSTALL script");
				$i = 0 if ($i eq "");
				$i++;
			}
		}
	}

	# Copy Sudoers file
	if (-f "$tempfolder/sudoers/sudoers") {
		LOGINF "$LL{'INF_SUDOERS'}";
		($exitcode) = execute( {
			command => "cp -v $tempfolder/sudoers/sudoers $lbhomedir/system/sudoers/$pname 2>&1",
			log => $log,
		} );
		#system("cp -v $tempfolder/sudoers/sudoers $lbhomedir/system/sudoers/$pname 2>&1");
		if ($exitcode > 0) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"SUDOERS file: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setrights ("644", "0", "$lbhomedir/system/sudoers/$pname", "SUDOERS file");
		&setowner ("root", "0", "$lbhomedir/system/sudoers/$pname", "SUDOERS file");
	}

	# Installing additional packages
	$aptfile="$tempfolder/dpkg/apt";
	if ( $lbversionmajor && -e "$tempfolder/dpkg/apt$lbversionmajor" ) {
		$aptfile="$tempfolder/dpkg/apt$lbversionmajor";
	}

	if (-e "$aptfile") {

		LOGINF "$LL{'INF_APTREFRESH'}";
		apt_update('update');
		if ($errors) {
			$message = "$LL{'ERR_APTREFRESH'}";
			push(@warnings, "$message");
			LOGWARN $message;
		}

		LOGINF "$LL{'INF_APT'}";
		my $content = LoxBerry::System::read_file("$aptfile");
		if (!$content) {
			$message = "$LL{'ERR_APT'}";
			LOGERR $message;
			push(@errors,"APT install: $message");
		}
		
		$aptpackages = "";
		my @content = split ("\n",$content);
		foreach (@content){
			if ($_ =~ /^\s*#.*/) { # comments
				next;
			}
			$aptpackages = $aptpackages . " " . $_;
		}

		$errors = 0;
		apt_install("$aptpackages");
		if ($errors) {
			$message = "$LL{'ERR_PACKAGESINSTALL'}";
			LOGWARN $message;
			push(@errors,"APT install: $message");
		} else {
			LOGOK "$LL{'OK_PACKAGESINSTALL'}";
		}

	}

	# Supplied packages by architecture
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
			($exitcode) = execute( {
				command => "$dpkgbin -i -R $tempfolder/dpkg/$thisarch 2>&1",
				log => $log,
			} );
			#system("$dpkgbin -i -R $tempfolder/dpkg/$thisarch 2>&1");
			if ($exitcode > 0) {
				$message = "$LL{'ERR_PACKAGESINSTALL'}";
				LOGERR $message; 
				push(@errors,"APT install: $message");
			} else {
				LOGOK "$LL{'OK_PACKAGESINSTALL'}";
			}
		}
	}

	# We have to recreate the skels for system log folders in tmpfs
	LOGINF "$LL{'INF_LOGSKELS'}";
	($exitcode) = execute( {
		command => "$lbssbindir/createskelfolders.pl 2>&1",
		log => $log,
	} );
	if ($exitcode > 0) {
		$message = "$LL{'ERR_SCRIPT'}";
		LOGERR $message; 
		push(@errors,"SKEL FOLDERS: $message");
	} else {
		LOGOK "$LL{'OK_SCRIPT'}";
	}

	# Executing postinstall script
	if (my @files = glob("$tempfolder/postinstall*")) {
		LOGINF "$LL{'INF_START_POSTINSTALL'}";
		foreach my $script ( @files ) {
			if (-f "$script" ) {
				&setrights ("a+x", "0", "$script", "$script file");
				($exitcode) = execute( {
					command => "cd \"$tempfolder\" && $sudobin -n -u loxberry \"$script\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1",
					log => $log,
				} );
				if ($exitcode eq 1) {
					LOGERR "$LL{'ERR_SCRIPT'}";
					push(@errors,"POSTINSTALL: $message");
				} 
				elsif ($exitcode > 1) {
					$message = "$LL{'FAIL_SCRIPT'}";
					LOGCRIT $message;
					&fail($message);
				}
				else {
					LOGOK "$LL{'OK_SCRIPT'}";
				}
			}
		}
	}

	# Executing postupgrade script
	if ($isupgrade) {
		if (my @files = glob("$tempfolder/postupgrade*")) {
			LOGINF "$LL{'INF_START_POSTUPGRADE'}";
			foreach my $script ( @files ) {
				if (-f "$script" ) {
					&setrights ("a+x", "0", "$script", "$script file");
					($exitcode) = execute( {
						command => "cd \"$tempfolder\" && $sudobin -n -u loxberry \"$script\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1",
						log => $log,
					} );
					if ($exitcode eq 1) {
						$message = "$LL{'ERR_SCRIPT'}";
						LOGERR $message;
						push(@errors,"POSTUPGRADE: $message");
					} 
					elsif ($exitcode > 1) {
						$message = "$LL{'FAIL_SCRIPT'}";
						LOGCRIT $message;
						&fail($message);
					}
					else {
						LOGOK "$LL{'OK_SCRIPT'}";
					}
				}
			}
		}
	}

	# Executing postroot script
	if (my @files = glob("$tempfolder/postroot*")) {
		LOGINF "$LL{'INF_START_POSTROOT'}";
		foreach my $script ( @files ) {
			if (-f "$script" ) {
				&setrights ("a+x", "0", "$script", "$script file");
				($exitcode) = execute( {
					command => "cd \"$tempfolder\" && \"$script\" \"$tempfile\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" \"$tempfolder\" 2>&1",
					log => $log,
				} );
				if ($exitcode eq 1) {
					$message = "$LL{'ERR_SCRIPT'}";
					LOGERR $message; 
					push(@errors,"POSTROOT: $message");
				} 
				elsif ($exitcode > 1) {
					$message = "$LL{'FAIL_SCRIPT'}";
					LOGCRIT $message;
					&fail($message);
				}
				else {
					LOGOK "$LL{'OK_SCRIPT'}";
				}
			}
		}
	}

	# Copy installation files
	make_path("$lbhomedir/data/system/install/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	LOGINF "$LL{'INF_INSTALLSCRIPTS'}";
	if (my @files = glob("$tempfolder/pre*")) {
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -v $tempfolder/pre* $lbhomedir/data/system/install/$pfolder 2>&1",
			log => $log,
		} );
		if ($exitcode) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"INSTALL scripts: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
	}
	if (my @files = glob("$tempfolder/post*")) {
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -v $tempfolder/post* $lbhomedir/data/system/install/$pfolder 2>&1",
			log => $log,
		} );
		if ($exitcode) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"INSTALL scripts: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
	}
	&setowner ("loxberry", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
	&setrights ("755", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
	
	if( -e "$tempfolder/apt" ){
		LOGINF "$LL{'INF_INSTALLAPT'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -rv $tempfolder/apt $lbhomedir/data/system/install/$pfolder 2>&1",
			log => $log,
		} );
		if ($exitcode) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"INSTALL scripts: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setowner ("loxberry", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
		&setrights ("755", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
	}
	if( -e "$tempfolder/dpkg" ){
		LOGINF "$LL{'INF_INSTALLAPT'}";
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry cp -rv $tempfolder/dpkg $lbhomedir/data/system/install/$pfolder 2>&1",
			log => $log,
		} );
		if ($exitcode) {
			$message = "$LL{'ERR_FILES'}";
			LOGERR $message; 
			push(@errors,"INSTALL scripts: $message");
		} else {
			LOGOK "$LL{'OK_FILES'}";
		}
		&setowner ("loxberry", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
		&setrights ("755", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");
	}

	# Cleaning
	LOGINF "$LL{'INF_END'}";
	if ( -e "$lbsdatadir/tmp/uploads/$tempfile" ) {
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry rm -vrf $lbsdatadir/tmp/uploads/$tempfile 2>&1",
			log => $log,
		} );
	}
	if ( $R::tempfile ) {
		($exitcode) = execute( {
			command => "$sudobin -n -u loxberry rm -vf $lbsdatadir/tmp/uploads/$tempfile.zip 2>&1",
			log => $log,
		} );
	} 

	# Finished
	LOGOK "$LL{'OK_END'}";

	# Set Status
	if (-e $statusfile) {
		if ($preboot) {
			($exitcode) = LoxBerry::System::write_file("$statusfile", "3");
			reboot_required("$LL{'INF_REBOOT'} $ptitle");
		} else {
			($exitcode) = LoxBerry::System::write_file("$statusfile", "0");
		}
	}

	# Log errora
	if (@errors || @warnings) {
		LOGWARN "An error or warning occurred";
	} else {
		LOGOK "Everything seems to be OK";
	}

	# Error summarize
	if (@errors || @warnings) {
		LOGDEB "==================================================================================";
		LOGDEB "$SL{'PLUGININSTALL.INF_ERRORSUMMARIZE'}";
		foreach(@errors) {
			if ($_ && $_ ne "") {
				LOGERR "$_";
				notify ( "plugininstall", "$pname", $LL{'ERR_NOTIFY'} . " " . $ptitle . ": " . $_ );
			}
		}
		foreach(@warnings) {
			if ($_ && $_ ne "") {
				LOGWARN "$_";
				notify ( "plugininstall", "$pname", $LL{'WARN_NOTIFY'} . " " . $ptitle . ": " . $_ );
			}
		}
		LOGDEB "==================================================================================";
	}
	if ($chkhcpath) {
		LOGDEB "$chkhcpath";
	}
	
	# Saving Logfile
	LOGINF "$LL{'INF_SAVELOG'}";
	system("cp -v /tmp/$tempfile.log $lbhomedir/log/system/plugininstall/$pname.log 2>&1");
	&setowner ("loxberry", "0", "$lbhomedir/log/system/plugininstall/$pname.log", "LOG Save");

	LOGOK "$SL{'PLUGININSTALL.INF_LAST'}";
	LOGEND;


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

	# 1. Delete cron jobs
	if($pname) {
		# Cron jobs
		LOGINF "Removing cron jobs...";
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
		foreach my $cronfolder ( @cronfolders ) {
			if (-e "$lbhomedir/system/cron/$cronfolder/$pname") {
				execute( command => "$sudobin -n -u loxberry rm -fv $lbhomedir/system/$cronfolder/$pname 2>&1", log => $log );
			}
		}
	
		# 2. Delete individual crontab file (only on uninstall)
		if ($option eq "all") {
			# Crontab
			LOGINF "Removing crontab";
			execute( command => "rm -vf $lbhomedir/system/cron/cron.d/$pname 2>&1", log => $log );
		}
	}

	# 3. Run uninstall script (only on uninstall)
	if( $pname and $option eq "all" ) {
		# Executing uninstall script
		if (my @files = glob("$lbhomedir/data/system/uninstall/$pname*")) {
			LOGINF "$LL{'INF_START_UNINSTALL_EXE'}";
			foreach my $file ( @files ) {
				if (-f "$script" ) {
					my $commandline = qq(cd /tmp && "$script" "/tmp" "$pname" "$pfolder" "$pversion" "$lbhomedir" 2>&1);
					($exitcode, $output) = execute( command => $commandline, log => $log );
					if ($exitcode eq 1) {
						$message = "$LL{'ERR_SCRIPT'}";
						LOGERR $message;
						push(@errors,"UNINSTALL execution: $LL{'ERR_SCRIPT'}");
					} 
					elsif ($exitcode > 1) {
						$message = "$LL{'FAIL_SCRIPT'}";
						LOGCRIT $message;
						&fail($message);
					}
					else {
						LOGOK "$LL{'OK_SCRIPT'}";
					}
				}
			}
		} else {
			LOGINF "No uninstall script provided.";
		}
	}
	
	if ($pname) {
		# 4. Delete uninstall file
		if (-f "$lbhomedir/data/system/uninstall/$pname") {
			LOGINF "Deleting uninstall file...";
			execute( command => "rm -fv $lbhomedir/data/system/uninstall/$pname* 2>&1", log => $log );
		}
		# 5. Delete daemon
		LOGINF "Deleting daemon...";
		execute( command => "rm -fv $lbhomedir/system/daemons/plugins/$pname* 2>&1", log => $log );
		# 6. Delete Sudoers
		LOGINF "Deleting sudoers file";
		execute( command => "rm -fv $lbhomedir/system/sudoers/$pname 2>&1", log => $log );
	}
	
	# 7. Delete plugin folders
	if ($pfolder) {
		# Plugin Folders
		LOGINF "Deleting plugin folders";
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/config/plugins/$pfolder/ 2>&1", log => $log );
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/bin/plugins/$pfolder/ 2>&1", log => $log );
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/data/plugins/$pfolder/ 2>&1", log => $log );
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/templates/plugins/$pfolder/ 2>&1", log => $log );
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1", log => $log );
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/html/plugins/$pfolder/ 2>&1", log => $log );
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/data/system/install/$pfolder 2>&1", log => $log );
		# Icons for Main Menu
		LOGINF "Deleting plugin icons";
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1", log => $log );
	}

	# 8. Remove Plugin from plugin database
	if ($option eq "all") {
		if ($plugin) {
			LOGINF "Removing plugin from plugin database";
			$plugin->remove();
			undef $plugin;
		} else {
			LOGERR "$LL{'ERR_DATABASE'}";
		}
	}
	
	# 9. Delete Log folder
	if ($option eq "all" and $pfolder) {
		LOGINF "Deleting plugins log folder...";
		execute( command => "$sudobin -n -u loxberry rm -rfv $lbhomedir/log/plugins/$pfolder/ 2>&1", log => $log );
	}

	return;

}

#####################################################
# Exit, Cleanup on Fail
#####################################################

sub fail {

	my $failmessage = shift;

	if ( -e "/tmp/uploads/$tempfile" ) {
		execute( command => "$sudobin -n -u loxberry rm -rf /tmp/uploads/$tempfile 2>&1", log => $log );
	}
	if ( $R::tempfile ) {
		execute( command => "$sudobin -n -u loxberry rm -vf /tmp/$tempfile.zip 2>&1", log => $log );
	} 

	# Status file
	if (-e $statusfile) {
		($exitcode) = LoxBerry::System::write_file("$statusfile", "2");
	}
	
	# Notify
	if ($failmessage) {
		notify ( "plugininstall", "$pname", $LL{'FAIL_NOTIFY'} . " " . $ptitle . ": " . $failmessage, 1);
	}

	# Unlock and exit
	LoxBerry::System::unlock( lockfile => 'plugininstall' );

	exit (1);

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
		LOGERR "is_folder_empty: Cannot opendir '".$_[0]."', because: $!";
		readdir $dir;	# Skip .
		readdir $dir;	# Skip ..
		return 0 if( readdir $dir ); # 3rd times a charm
	return 1;
}

#####################################################
# Set owner
# &setowner ("loxberry", "1", "path/to/folder", "CONFIG files");
# &setowner ("root", "0", "path/to/file", "DAEMON script");
#####################################################

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

	LOGINF $LL{'INF_FILE_OWNER'} . " $chownbin $chownoptions $owner.$group $target";
	system("$chownbin $chownoptions $owner.$group $target 2>&1");
	if ($? ne 0) {
		$message = "$LL{'ERR_FILE_OWNER'}";
		LOGERR $message; 
		push(@errors,"$type: $message");
	} else {
		LOGOK "$LL{'OK_FILE_OWNER'}";
	}

}

#####################################################
# Set permissions
# &setrights ("755", "1", "path/to/folder", "CONFIG files" [,"Regex"]);
# &setrights ("644", "0", "path/to/file", "DAEMON script" [,"Regex"]);
#####################################################

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
		LOGINF $LL{'INF_FILE_PERMISSIONS'} . " $findbin $target -iregex '$regex' -exec $chmodbin $chmodoptions $rights {} \\;";
		system("$sudobin -n -u loxberry $findbin $target -iregex '$regex' -exec $chmodbin $chmodoptions $rights {} \\; 2>&1");

	} else {

		LOGINF $LL{'INF_FILE_PERMISSIONS'} . " $chmodbin $chmodoptions $rights $target";
		system("$chmodbin $chmodoptions $rights $target 2>&1");

	}
	if ($? ne 0) {
		$message = "$LL{'ERR_FILE_PERMISSIONS'}";
		LOGERR $message; 
		push(@errors,"$type: $message");
	} else {
		LOGOK "$LL{'OK_FILE_PERMISSIONS'}";
	}

}

#####################################################
# Replace strings in pluginfiles
# replaceenv ($user, @filelist);
# &replaceenv ("loxberry", @arrayOfFiles);
#####################################################

sub replaceenv {

	LOGINF "$LL{'INF_REPLACEENVIRONMENT'}";
	
	my $user = shift;
	my $replacefiles = shift;

	if( ref($replacefiles) eq "" ) {
		$replacefiles = ( $replacefiles );
	}
	if( ref($replacefiles) ne "ARRAY" ) {
		LOGERR "replaceenv: Incoming filelist is not an ARRAY.";
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

	LOGINF "Running replacement for " . scalar @$replacefiles . " files";
	my $counter = 0;
	foreach(@$replacefiles) {
		$counter++;
		if($counter%20 == 0) {
			LOGINF "$counter of " . scalar @$replacefiles . " finished ...";
		}
		`$sudobin -n -u $user /bin/sed -i '$sed_replace_query' "$_" 2>&1`;
	}
	LOGOK "Replace of $counter files finished";
		
	return;

}

#####################################################
# Conerting all files to unix fileformat
# &dos2unix ("loxberry", "1", "path/to/folder");
#####################################################

sub dos2unix {

	my $user = shift;
	my ($filelist) = @_;

	if( ref($filelist) eq "" ) {
		$filelist = ( $filelist );
	}
	if( ref($filelist) ne "ARRAY" ) {
		LOGERR "dos2unix: Incoming filelist is not an ARRAY.";
		return;
	}

	LOGINF "$LL{'INF_DOS2UNIX'}";

	foreach(@$filelist) 
	{
		system("$sudobin -n -u $user $dos2unix -- '" . $_ . "' 2>&1");
	}

	return;

}

#####################################################
# Querying all files from a $target to be text files
# @textfiles = getTextFiles("/path/to/folder");
#####################################################

sub getTextFiles 
{
	my ($target) = @_;

	LOGINF "Getting file list from $target";

	require File::Find::Rule;
	my @files = File::Find::Rule
		->file()
		->name( '*' )
		->nonempty
		->in($target);

	LOGINF "Found " . scalar @files . " files";

	LOGINF "Filtering out binary files";
	my @textfiles;
	my $counter = 0;
	foreach(@files) 
	{
		$counter++;
		my $bin_text = `file -b "$_"`;
		push @textfiles, "$_" if ( index( "$bin_text", 'text' ) != -1 );
		if( $counter%20 == 0 ) 
		{
			LOGINF "  " . scalar @textfiles . " textfiles found out of $counter files scanned...";
		}
	}
	LOGINF "  " . scalar @textfiles . " textfiles found out of $counter files scanned...";
	LOGOK "Found " . scalar @textfiles . " files to be text files";
	return @textfiles;
}

#####################################################
# Local phases 
# This phrases are English only, and only used in this script
# Usage: $LL{'ERR_NOFOLDER_OR_ZIP'} ( instead of system phrases $SL{'PLUGININSTALL.SOMETHING'} )
#####################################################

sub localphrases {

	my %local_lang = (
	FAIL_NOTIFY => "FAIL",
	WARN_NOTIFY => "WARNING",
	ERR_NOTIFY => "ERROR",
	ERR_NOFOLDER_OR_ZIP => "You have to specify a folder OR ZIP file with plugin data: folder=/path/to/folder OR file=/path/to/file.zip",
	ERR_FOLDER_DOESNT_EXIST => "Plugin folder does not exist.",
	ERR_FILE_DOESNT_EXIST => "Plugin file does not exist.",
	ERR_TEMPFILES_EXISTS => "Temporary files already exist or aren't writeable.",
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
	ERR_SCRIPT => "Script/Command finished with errors. I will try to continue installation.",
	OK_SCRIPT => "Script/Command executed successfully.",
	FAIL_SCRIPT => "Script/Command fails. Installation cannot be continued.",
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
	ERR_NOPIN => "You have to specify the SecurePIN for installation: pin=YOURPIN",
	ERR_SECUREPIN_WRONG => "The entered SecurePIN is wrong.",
	ERR_NO_SPACE_IN_TMP => "There's not enough RAM in your RAM-disk (/tmp) to extract the ZIP archive. Please reboot and retry. Disk free: ",
	ERR_NO_SPACE_IN_ROOT => "There's not enough space left in the LoxBerry home folder. Free space: ",
	INF_SAVELOG => "Saving logfile.",
	INF_LOCKING => "Locking plugininstall - delaying up to 10 minutes...",
	ERR_LOCKING => "Could not get lock for plugininstall. Skipping this installation.",
	ERR_LOCKING_REASON => "The reason is:",
	OK_LOCKING => "Lock successfully set.",
	ERR_UNKNOWNINTERFACE => "The Plugin Interface is unknown. I cannot proceed with the installation.",
	ERR_INTERFACENOTSUPPORTED => "The Plugin Interface is not supported by this LoxBerry Version. I cannot proceed with the installation.",
	INF_DOS2UNIX => "Converting all plugin files (ASCII) to Unix fileformat.",
	INF_LOGSKELS => "Updating skels for Logfiles in tmpfs.",
	INF_SHADOWDB => "Creating shadow version of plugindatabase.",
	ERR_UNKNOWN_FORMAT_PLUGINCFG => "Could not parse plugin.cfg. Maybe it has a wrong format.",
	INF_FIXYARN => "Updating Yarn Key if internet connection is available.",

	);

	return %local_lang;

}

END {
	if ($log) {
		LOGEND;
	}
}

