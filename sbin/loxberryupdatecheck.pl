#!/usr/bin/perl
#######################################################
# Parameters
#	querytype
#		release
#		prerelease
#		testing (= latest commit of a branch)  not implemented
#
#	update
#		1 	Do an update
#		(not existing) Notify only
#
# 	output
#		(not existing) STDERR
#		json Return json with version and vers info
#
#	keepupdatefiles
#		1	do not update loxberryupdate*.pl and exclude-Files
#		(not existing) update these files
#
#	dryrun
#		1	do not update loxberryupdate*.pl, exlude-file, and let rsync run dry
#
#######################################################

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use strict;
use warnings;
use CGI;
use JSON;
use Time::HiRes qw(usleep);
use version;
use URI::Escape;
use File::Path;
use File::Copy qw(copy);
use LWP::UserAgent;
use Encode;
require HTTP::Request;

# Version of this script
my $scriptversion="1.2.0.3";

# print currtime('file') . "\n";

# Predeclare logging functions
#sub LOGOK { my ($s)=@_; print ERRORLOG "<OK>" . $s . "\n"; }
#sub LOGINF { my ($s)=@_;print ERRORLOG "<INFO>" . $s . "\n"; }
#sub LOGWARN { my ($s)=@_;print ERRORLOG "<WARNING>" . $s . "\n"; }
#sub LOGERR { my ($s)=@_;print ERRORLOG"<ERROR>" . $s . "\n"; }
#sub LOGCRIT { my ($s)=@_;print ERRORLOG "<FAIL>" . $s . "\n"; }

my $release_url;
my $oformat;
my %joutput;
my %updhistory;
my $updhistoryfile = "$lbslogdir/loxberryupdate/history.json";
my %thisupd;
my $cfg;
my $download_path = '/tmp';
my $update_path = '/tmp/loxberryupdate';
# Filter - everything above or below is possible - ignore others
my $min_version = "v0.3.0";
my $max_version = "v1.99.99";

my $querytype;
my $update;
my $output;
my $cron;
my $dryrun;
my $nofork;
my $nobackup;
my $nodiscspacecheck;
my $keepupdatefiles;
my $formatjson;
my $failed_script;

# Web Request options
my $cgi = CGI->new;

my $log = LoxBerry::Log->new(
		package => 'LoxBerry Update',
		name => 'check',
		filename => "$lbhomedir/log/system_tmpfs/loxberryupdate/updatecheck.log",
		loglevel => 7,
		stderr => 1,
		append => 1,
);
$joutput{'logfile'} = $log->filename;

#my $logfile ="$lbslogdir/loxberryupdate/log$.log";
#open ERRORLOG, '>', $logfile;

LOGSTART "LoxBerry Update Check";
LOGINF "Version of loxberrycheck.pl is $scriptversion";

$cfg = new Config::Simple("$lbsconfigdir/general.cfg");

# Read system language
my %SL = LoxBerry::System::readlanguage();
# LOGINF "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}\n";

if (!$cgi->param) {
	$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_NO_PARAMETERS'};
	&err;
	LOGCRIT $joutput{'error'};
	exit (1);
}

# If general.cfg's UPDATE.DRYRUN is defined, do nothing
if ( is_enabled($cfg->param('UPDATE.DRYRUN')) ) {
	$cgi->param('dryrun', 1)
}
if ( is_enabled($cfg->param('UPDATE.KEEPUPDATEFILES')) ){
	$cgi->param('keepupdatefiles', 1)
}

if ($cgi->param('dryrun')) {
	$cgi->param('keepupdatefiles', 1);
}

$dryrun = $cgi->param('dryrun') ? "dryrun=1" : undef;

if ($cgi->param('cron')) {
	$cron = 1;
} 
if ($cgi->param('nofork')) {
	$nofork = 1;
} 
if ($cgi->param('nobackup')) {
	$nobackup = 1;
} 
if ($cgi->param('nodiscspacecheck')) {
	$nodiscspacecheck = 1;
} 

$querytype = $cgi->param('querytype');

$formatjson = $cgi->param('output') && $cgi->param('output') eq 'json' ? 1 : undef;

my $latest_sha = defined $cfg->param('UPDATE.LATESTSHA') ? $cfg->param('UPDATE.LATESTSHA') : "0";


if ($formatjson || $cron ) {
	$querytype = $cfg->param('UPDATE.RELEASETYPE');
}

if ($cfg->param('UPDATE.FAILED_SCRIPT')) {
	$failed_script = version->parse(vers_tag($cfg->param('UPDATE.FAILED_SCRIPT')));
	LOGWARN "In a previous run of LoxBerry Update this update script failed: $failed_script";
	$joutput{'failed_script'} = "$failed_script";
}

if (!$querytype || ($querytype ne 'release' && $querytype ne 'prerelease' && $querytype ne 'latest')) {
	$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_WRONG_QUERY_TYPE'};
	&err;
	LOGCRIT $joutput{'error'};
	exit(1);
}

my $curruser = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
LOGINF "Executing user of loxberryupdatecheck is $curruser";


LOGOK "Parameters/settings of this update:";
LOGINF "   querytype:       $querytype\n";
LOGINF "   cron:            $cron\n";
LOGINF "   keepupdatefiles: " . $cgi->param('keepupdatefiles');
LOGINF "   dryrun: " . $cgi->param('dryrun') . "\n";
LOGINF "   output: " . $formatjson;

my $lbversion;
if (version::is_lax(vers_tag(LoxBerry::System::lbversion()))) {
	$lbversion = version->parse(vers_tag(LoxBerry::System::lbversion()));
	LOGINF "   Current LoxBerry version: $lbversion";

} else {
	$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_CANNOT_READ_CURRENT_VERSION'};
	&err;
	LOGCRIT $joutput{'error'};
	exit(1);
}

if (version::is_lax($min_version)) {
	$min_version = version->parse($min_version);
	LOGINF "   Updates limited from : $min_version";
} else {
	$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_INVALID_MIN_VERSION_PREFIX'} . $min_version . $SL{'UPDATES.UPGRADE_ERROR_INVALID_MIN_VERSION_SUFFIX'};
	&err;
	LOGCRIT $joutput{'error'};
	exit(1);
}
if (version::is_lax($max_version)) {
	$max_version = version->parse($max_version);
	LOGINF "   Updates limited to   : $max_version";
} else {
	$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_INVALID_MAX_VERSION_PREFIX'} . $max_version . $SL{'UPDATES.UPGRADE_ERROR_INVALID_MAX_VERSION_SUFFIX'};
	&err;
	LOGCRIT $joutput{'error'};
	exit(1);
}

if ($querytype eq 'release' or $querytype eq 'prerelease') {
	LOGINF "Start checking releases...";
	my ($release_version, $release_url, $release_name, $release_body, $release_published, $release_isprerelease) = check_releases($querytype, $lbversion);
	if (! defined $release_url || $release_url eq "") {
		$joutput{'info'} = $SL{'UPDATES.INFO_NO_NEW_VERSION_FOUND'};
		$joutput{'release_version'} = "$release_version";
		$joutput{'release_zipurl'} = "";
		$joutput{'release_name'} = $release_name;
		$joutput{'release_body'} = $release_body;
		$joutput{'published_at'} = $release_published;
		$joutput{'releasetype'} = $release_isprerelease eq 1 ? "prerelease" : "release";
		
		&err;
		LOGOK $joutput{'info'};
		exit 0;
	}

	LOGOK  "New version found:";
	LOGINF "   Version     : $release_version";
	LOGINF "   Name        : $release_name";
	LOGINF "   Published   : $release_published";
	LOGINF "   Releasetype : " . ($release_isprerelease eq 1 ? "Pre-Release" : "Release");
		
	$joutput{'info'} = $SL{'UPDATES.INFO_NEW_VERSION_FOUND'};
	$joutput{'release_version'} = "$release_version";
	$joutput{'release_zipurl'} = $release_url;
	$joutput{'release_name'} = $release_name;
	$joutput{'release_body'} = $release_body;
	$joutput{'published_at'} = $release_published;
	$joutput{'release_new'} = 1;
	$joutput{'releasetype'} = $release_isprerelease eq 1 ? "prerelease" : "release";
		
	
	if ($cron && $cfg->param('UPDATE.INSTALLTYPE') eq 'notify') {
		my @notifications = get_notifications( 'updates', 'lastnotifiedrelease');
		if ($notifications[0] && $notifications[0]->{version} eq "$release_version") {
			LOGOK "Skipping notification because version has already been notified.";
		} else {
			# Delete old helper notification
			delete_notifications('updates', 'lastnotifiedrelease');
			# Set a new helper notification with the new version
			my %notification = (
						PACKAGE => "updates",
						NAME => "lastnotifiedrelease",
						MESSAGE => "This helper notification keeps track of last notified releases",
						SEVERITY => 7,
						version => "$release_version",
				);
			LoxBerry::Log::notify_ext( \%notification );
			
			# Create the normal user notification
			notify('updates', 'check', "LoxBerry Updatecheck: " . $SL{'UPDATES.LBU_NOTIFY_CHECK_RELEASE'} . " $release_version") if $querytype eq 'release';
			notify('updates', 'check', "LoxBerry Updatecheck: " . $SL{'UPDATES.LBU_NOTIFY_CHECK_PRERELEASE'} . " $release_version") if $querytype eq 'prerelease';
			delete_notifications('updates', 'check', 1);
		}
	}
	
	if ( $cgi->param('update') || ( $cfg->param('UPDATE.INSTALLTYPE') eq 'install' && $cron ) ) {
		LOGEND "Installing new update - see the update log for update status!";
		
		my $log = LoxBerry::Log->new(
			package => 'LoxBerry Update',
			name => 'update',
			logdir => "$lbslogdir/loxberryupdate",
			loglevel => 7,
			stderr => 1,
			addtime => 1,
		);
		my $logfilename = $log->filename;
		
		$joutput{'logfile'} = $log->filename;
		
		LOGSTART "Update from $lbversion to $release_version";
		LOGINF "   Version     : $release_version";
		LOGINF "   Name        : $release_name";
		LOGINF "   Description : $release_body";
		LOGINF "   Published   : $release_published";
		LOGINF "   Releasetype : " . ($release_isprerelease eq 1 ? "Pre-Release" : "Release");
		
		LOGINF "Checking if another update is running..."; 
		my $pids = `pidof loxberryupdate.pl`;
		# LOGINF "PIDOF LENGTH: " . length($pids) . "\n";
		if (length($pids) > 0) {
			$joutput{'info'} = $SL{'UPDATES.UPGRADE_ERROR_ANOTHER_UPDATE_RUNNING'};
			&err;
			LOGCRIT $joutput{'info'};
			exit(1);
		} 
		LOGOK "No other update running.";			
		
		$joutput{'info'} = "$SL{'UPDATES.INFO_UPDATE_STARTED_PREFIX'} $release_version $SL{'UPDATES.INFO_UPDATE_STARTED_SUFFIX'}"; 
		LOGOK $joutput{'info'};
		&err;
		my $download_file = "$download_path/loxberry.$release_version.zip";
		LOGINF "Starting download procedure for $download_file...";
		my $filename = download($release_url, $download_file);
		if (!$filename) {
			LOGCRIT "Error downloading file.";
		} else {
			LOGOK "Download successfully stored in $filename.";
			LOGINF "Starting unzip procedure for $filename...";
			my $unzipdir = unzip($filename, $update_path);
			if (!defined $unzipdir) {
				LOGERR "Unzipping failed.";
				LOGINF "Deleting download file";
				unlink ($filename);
				LOGCRIT "Update failed because file cound not be unzipped.";
				exit(1);
			}
			LOGINF "Deleting zipfile after unzip was successful";
			unlink ($filename);
			LOGINF "Starting prepare update procedure...";
			my $updatedir = prepare_update($unzipdir);
			if (!$updatedir) {
				LOGCRIT "prepare update returned an error. Exiting.\n";
				exit(1);
			}
			LOGOK "Prepare update successful.";
			# This is the place where we can hand over to the real update
			
			if (!$nofork) {
				LOGINF "Forking loxberryupdate...";
				my $pid = fork();
				if (not defined $pid) {
					LOGCRIT "Cannot fork loxberryupdate.";
				} 
				if (not $pid) {	
					LOGINF "Executing LoxBerry Update forked...";
					# exec never returns
					# exec("$lbhomedir/sbin/loxberryupdate.pl", "updatedir=$updatedir", "release=$release_version", "$dryrun 1>&2");
					exec("$lbhomedir/sbin/loxberryupdate.pl updatedir=$updatedir release=$release_version $dryrun logfilename=$logfilename cron=$cron nobackup=$nobackup nodiscspacecheck=$nodiscspacecheck </dev/null >/dev/null 2>&1 &");
					exit(0);
				} 
				exit(0);
			} else {
				LOGINF "Executing LoxBerry Update...";
				# exec never returns
				# exec("$lbhomedir/sbin/loxberryupdate.pl", "updatedir=$updatedir", "release=$release_version", "$dryrun 1>&2");
				exec("$lbhomedir/sbin/loxberryupdate.pl updatedir=$updatedir release=$release_version dryrun=$dryrun logfilename=$logfilename cron=$cron nobackup=$nobackup nodiscspacecheck=$nodiscspacecheck");
			}
		}
	}
	
	my $jsntext = to_json(\%joutput);
	LOGINF "JSON: " . $jsntext . "\n";
	#print $cgi->header('application/json');
	print $jsntext;
	
	# LOGINF "ZIP URL: $release_url\n";
	
	} elsif ($querytype eq 'latest') {
		LOGINF "Start checking commits...";
		check_commits($querytype);
				
	} else {
		LOGINF "Nothing to do. Exiting";
		exit 0;
	}

exit;

##################################################
# Check Releases List
# Parameters
#		1. querytype ('release' or 'prerelease')
#		2. Version object of current version
# Returns
#		1. $release_version (version object)
#		2. $release->{zipball_url} (URL to the ZIP)
#		3. $release->{name} (Name of the release)
#		4. $release->{body}) (Description of the release)
#		Returns undef if no new version found
##################################################
sub check_releases
{

	my ($querytype, $currversion) = @_;
	my $endpoint = 'https://api.github.com';
	my $resource = '/repos/mschlenstedt/Loxberry/releases';
	#my $resource = '/repos/christianTF/LoxBerry-Plugin-SamplePlugin-V2-PHP/releases';

	LOGINF "Checking for releases from $endpoint$resource";
	my $release_version;

	my $ua = LWP::UserAgent->new;
	my $request = HTTP::Request->new(GET => $endpoint . $resource);
	$request->header('Accept' => 'application/vnd.github.v3+json', 'Accept-Charset' => 'utf-8');
	# LOGINF "Request: " . $request->as_string;
	LOGINF "Requesting release list from GitHub...";
    my $response;
	for (my $x=1; $x<=5; $x++) {
		LOGINF "   Try $x: Getting release list... (" . currtime() . ")"; 
		$response = $ua->request($request);
		last if ($response->is_success);
		LOGWARN "   API call try $x has failed. (" . currtime() . ") HTTP " . $response->code . " " . $response->message;
		usleep (100*1000);
	}
	
	if ($response->is_error) {
		$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_FETCHING_RELEASE_LIST'} . $response->code . " " . $response->message;
		&err;
		LOGCRIT $joutput{'error'};
		exit(1);
	}
	LOGOK "Release list fetched.";
	#LOGINF $response->decoded_content;
	#LOGINF "\n\n";
	LOGINF "Parsing release list...";
	my $releases = JSON->new->allow_nonref->convert_blessed->decode($response->decoded_content);
	
	my $release_safe; # this was thought to be safe, not save!
	
	foreach my $release ( @$releases ) {
		$release_version = undef;
		#LOGINF "   Checking release version tag of " . $release->{tag_name};
		if (!version::is_lax(vers_tag($release->{tag_name}))) {
			LOGWARN "   check_releases: " . vers_tag($release->{tag_name}) . " seems not to be a correct version number. Skipping.";
			next;
		} else {
			$release_version = version->parse(vers_tag($release->{tag_name}));
		}
		#split_version($release->{tag_name});
		LOGINF "   Release version : $release_version";
		
		if ($release_version < $min_version || $release_version > $max_version) {
			LOGWARN "   Release $release_version is outside min or max version ($min_version/$max_version)\n";
			next;
		}
		LOGOK "   Filter check passed.";
		
		if ($querytype eq 'release' and ($release->{prerelease} eq 1))
			{ LOGOK "   Skipping pre-release because requested release type is RELEASE";
			  next;
		}
		
		if (! $release_safe || version->parse($release_version) > version->parse(vers_tag($release_safe->{tag_name}))) {
			$release_safe = $release;
		}
		
		# Check against current version
		LOGINF "   Current Version: $currversion <--> Release Version: $release_version";
		if ($currversion == $release_version) {
			LOGOK "   Skipping - this is the same version.\n";  
			next;
		}
		if ($release_version < $currversion) {
			LOGOK "  Skipping  - the release is older than current version.";
			next;
		}
		
		# At this point we know that the version is newer
		LOGOK "This release $release_version is the newest.";

		return ($release_version, $release->{zipball_url}, $release->{name}, $release->{body}, $release->{published_at}, $release->{prerelease});
	}
	#LOGINF "TAG_NAME: " . $releases->[1]->{tag_name} . "\n";
	#LOGINF $releases->[1]->{prerelease} eq 1 ? "This is a pre-release" : "This is a RELEASE";
	LOGOK "No new version found: Latest version is " . vers_tag($release_safe->{tag_name});
	return (vers_tag($release_safe->{tag_name}), undef, $release_safe->{name}, $release_safe->{body}, $release_safe->{published_at}, $release_safe->{prerelease});
}


##################################################
# Check Commit List
# OLD - we don't need this, because the branch
#       always has the same url
##################################################
sub check_commits
{
	my ($querytype, $currversion) = @_;
	my $endpoint = 'https://api.github.com';
	my $resource = '/repos/mschlenstedt/Loxberry/commits';
	my $branch = 'master';
	
	# Download URL of latest commit 
	my $release_url = "https://github.com/mschlenstedt/Loxberry/archive/" . uri_escape($branch) . ".zip";
	my $download_file = "$download_path/$branch.zip";
	
	LOGINF "Checking for commits from $endpoint$resource";
	$branch = uri_escape($branch);
	my $ua = LWP::UserAgent->new;
	my $request = HTTP::Request->new(GET => $endpoint . $resource . "?sha=" . $branch);
	$request->header('Accept' => 'application/vnd.github.v3+json',
					 'Accept-Charset' => 'utf-8',
					 );
	LOGDEB "Request: " . $request->as_string;
	LOGINF "Requesting commit list from GitHub...";
    my $response;
	for (my $x=1; $x<=5; $x++) {
		LOGINF "   Try $x: Getting commit list... (" . currtime() . ")"; 
		$response = $ua->request($request);
		last if ($response->is_success);
		LOGWARN "   API call try $x has failed. (" . currtime() . ") HTTP " . $response->code . " " . $response->message;
		usleep (100*1000);
	}
	
	if ($response->is_error) {
		$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_FETCHING_COMMIT_LIST'} . $response->code . " " . $response->message;
		&err;
		LOGCRIT $joutput{'error'};
		exit(1);
	}
	LOGOK "Commit list fetched.";
	LOGINF "Parsing commit list...";
	my $commits = JSON->new->allow_nonref->convert_blessed->decode($response->decoded_content());
	my $commit_date;
	my $commit_by;
	my $commit_message;
	my $commit_sha;
	
	foreach my $commit ( @$commits ) {
		$commit_date = $commit->{commit}->{author}->{date};
		$commit_by = $commit->{commit}->{author}->{name};
		$commit_message = $commit->{commit}->{message};
		$commit_sha = $commit->{sha};
		last;
	}
	if (!$commit_date) {
		$joutput{'error'} = $SL{'UPDATES.UPGRADE_ERROR_NO_COMMITS_FOUND'};
		&err;
		LOGCRIT $joutput{'error'};
		exit(1);
	}
	
	my $commit_new = 1 if ($commit_sha ne $latest_sha);
	LOGDEB "SHA's: commit_sha $commit_sha / latest_sha $latest_sha / commit_new $commit_new";
	
	LOGOK "Latest commit found:";
	LOGINF "   Message     : $commit_message";
	LOGINF "   Commit by   : $commit_by";
	LOGINF "   Commited at : $commit_date";
	LOGINF "   Commit key  : $commit_sha";
	LOGINF "   Commit is newer than installed" if ($commit_new);
	
	$joutput{'info'} = "<span style='color:green;'>" . $SL{'UPDATES.INFO_NEW_COMMIT_FOUND'} . "</span>" if ($commit_new);
	$joutput{'info'} = $SL{'UPDATES.INFO_NO_NEW_COMMIT_FOUND'}  if (!$commit_new);
	$joutput{'release_new'} = 1 if ($commit_new);
	$joutput{'release_version'} = $commit_sha;
	$joutput{'release_name'} = "$commit_message" if ($commit_new);
	$joutput{'release_name'} = "<span style='color:gray;'>$commit_message</span>" if (!$commit_new);
	$joutput{'release_body'} = $SL{'UPDATES.INFO_COMMITED_BY'} . " $commit_by";
	$joutput{'published_at'} = $commit_date;
	$joutput{'releasetype'} = "commit";
	
	
	if ($cron && $cfg->param('UPDATE.INSTALLTYPE') eq 'notify') {
		
		my @notifications = get_notifications( 'updates', 'lastnotifiedcommit');
		if ($notifications[0] && $notifications[0]->{commitsha} eq "$commit_sha") {
			LOGOK "Skipping notification because commit has already been notified.";
		} else {
			# Delete old helper notification
			delete_notifications('updates', 'lastnotifiedcommit');
			# Set a new helper notification with the new version
			my %notification = (
						PACKAGE => "updates",
						NAME => "lastnotifiedcommit",
						MESSAGE => "This helper notification keeps track of last notified commits",
						SEVERITY => 7,
						commitsha => "$commit_sha",
				);
			LoxBerry::Log::notify_ext( \%notification );
	
			my $message = "LoxBerry Updatecheck: New commit from $commit_by on $commit_date, message $commit_message.";
			notify('updates', 'check', $message);
			delete_notifications('updates', 'check', 1);
		}
	}
	
	# If an update was requested
	if ($cgi->param('update') || ( $cfg->param('UPDATE.INSTALLTYPE') eq 'install' && $cron && $commit_new )) {
		LOGEND "Installing new commit - see the update log for update status!";
		my $log = LoxBerry::Log->new(
			package => 'LoxBerry Update',
			name => 'update',
			logdir => "$lbslogdir/loxberryupdate",
			loglevel => 7,
			stderr => 1
		);
		$joutput{'logfile'} = $log->filename;
		my $logfilename = $log->filename;
		LOGSTART "Latest commit will be installed:";
		LOGINF "   Message     : $commit_message";
		LOGINF "   Commit by   : $commit_by";
		LOGINF "   Commited at : $commit_date";
		LOGINF "   Commit key  : $commit_sha";
		
		LOGINF "Checking if another update is running..."; 
		my $pids = `pidof loxberryupdate.pl`;
		# LOGINF "PIDOF LENGTH: " . length($pids) . "\n";
		if (length($pids) > 0) {
			$joutput{'info'} = $SL{'UPDATES.UPGRADE_ERROR_ANOTHER_UPDATE_RUNNING'};
			&err;
			LOGCRIT $joutput{'info'};
			exit(1);
		} 
		LOGOK "No other update running.";			


		$joutput{'info'} = $SL{'UPDATES.INFO_UPDATE_COMMIT_STARTED'};
		LOGOK $joutput{'info'};
		&err;
		LOGINF "Starting download procedure for $download_file...";
		my $filename = download($release_url, $download_file);
		if (!$filename) {
			LOGCRIT "Error downloading file.";
		} else {
			LOGOK "Download successfully stored in $filename.";
			LOGINF "Starting unzip procedure for $filename...";
			my $unzipdir = unzip($filename, $update_path);
			if (!defined $unzipdir) {
				LOGERR "Unzipping failed.";
				LOGINF "Deleting download file";
				unlink ($filename);
				LOGCRIT "Update failed because file cound not be unzipped.";
				exit(1);
			}
			LOGINF "Deleting zipfile after unzip was successful";
			unlink ($filename);
			LOGINF "Starting prepare update procedure...";
			my $updatedir = prepare_update($unzipdir);
			if (!$updatedir) {
				LOGCRIT "prepare update returned an error. Exiting.\n";
				exit(1);
			}
			LOGOK "Prepare update successful.";
			
			
			# This is the place where we can hand over to the real update
			
			#LOGINF "Run loxberryupdate in bachground ...";
			LOGINF "Forking loxberryupdate...";
			my $pid = fork();
			if (not defined $pid) {
				LOGCRIT "Cannot fork loxberryupdate.";
			} 
			if (not $pid) {	
				LOGINF "Executing LoxBerry Update forked...";
				# exec never returns
				# exec("$lbhomedir/sbin/loxberryupdate.pl", "updatedir=$updatedir", "release=$release_version", "$dryrun 1>&2");
				exec("$lbhomedir/sbin/loxberryupdate.pl updatedir=$updatedir release=config $dryrun logfilename=$logfilename cron=$cron sha=$commit_sha </dev/null >/dev/null 2>&1 &");
				exit(0);
			} 
			exit(0);
		}
	}
	my $jsntext = to_json(\%joutput);
	LOGINF "JSON: " . $jsntext . "\n";
	#print $cgi->header('application/json');
	print $jsntext;
	
}

############################################
# Downloads a file
# Parameters: URL, Filename where so store
# Returns filename of ok, undef if failed
############################################
sub download
{
	
	my ($url, $filename) = @_;
	LOGINF "   Download preparing. URL: $url Filename: $filename\n";
	
	# my $download_size;
	# my $rel_header;
	# for (my $x=1; $x<=5; $x++) {
		# LOGINF "   Try $x: Checking file size of download...";
		# $rel_header = GetFileSize($url);
		# $download_size = $rel_header->content_length;
		# LOGINF "   Returned file size: $download_size";
		# last if (defined $download_size && $download_size > 0);
		# usleep (100*1000);
	# }
	# return undef if (!defined $download_size || $download_size == 0); 
	# LOGINF "   Expected download size: $download_size";
	
	# LOGINF "    Header check passed.\n";
	
	my $ua = LWP::UserAgent->new;
	my $res;
	for (my $x=1; $x<=5; $x++) { 
			LOGINF "   Try $x: Download of release... (" . currtime() . ")";
			$res = $ua->mirror( $url, $filename );
			last if ($res->is_success);
			LOGWARN "   Download try $x has failed. (" . currtime() . ")";
			usleep (300*1000);
	}
	return undef if (!$res->is_success);
	# LOGOK "   Download successful. Comparing filesize...";
	# my $file_size = -s $filename;
	# if ($file_size != $download_size) { 
		# LOGCRIT "Filesize does not match";
		# return undef;
	# }
	LOGOK "Download saved successfully in $filename";
	return $filename;

}
#############################################################
# Checks the file size before the download
# Parameter is the download url
# Returns the $header object of the request
#############################################################
sub GetFileSize
{
    my ($url) = @_;
    my $ua = new LWP::UserAgent;
    $ua->agent("Mozilla/5.0");
    my $req = new HTTP::Request 'HEAD' => $url;
   #$req->header('Accept' => 'text/html');
    for (my $x=1; $x<=5; $x++) {
		my $res = $ua->request($req);
		if ($res->is_success && defined $res->headers) {
			my $headers = $res->headers;
			return $headers;
		} else {
		LOGINF "   GetFileSize check try $x failed: " . $res->code . " " . $res->message;
		usleep (100*1000);
		}
	}
    LOGCRIT "   Filesize could not be aquired.";
	return 0;
}

############################################################
# Unzips a file
# Parameters are the ZIP file and destination folder
# Returning:

#############################################################
sub unzip
{
	LOGINF "   Running unzip";
	my ($unzipfile, $unzipfolder) = @_;
	if (! -f $unzipfile) {
		LOGCRIT "   Zip file $unzipfile does not exist.";
		return undef;
	}
	
	if (-d $unzipfolder) {   
		LOGINF "   Cleaning up destination folder $unzipfolder...";
		delete_directory($unzipfolder);
	}
	
	if (-d $unzipfolder) {   
		LOGCRIT "   Could not clean up in $unzipfolder.";
		return undef;
	}
	
	my $bins = LoxBerry::System::get_binaries();
	LOGINF "   Extracting ZIP file $unzipfile to folder $unzipfolder...";
	system("$bins->{UNZIP} -q -a -d $unzipfolder $unzipfile");
	my $exitcode  = $? >> 8;
	my $signal_num  = $? & 127;
	my $dumped_core = $? & 128;

	if ($exitcode > 0) {
		LOGCRIT unziperror($exitcode);
		LOGINF "Cleaning up unzip folder after failed unzip...";
		delete_directory($unzipfile);
		# unlink ($unzipfile);
		return undef;
	}
	LOGOK "   Unzipping was successful.";
	return $unzipfolder;
}

sub unziperror
{
	my $errorcode = shift;
	my %err;
	$err{0} = 'Normal; no errors or warnings detected.';
	$err{1} = 'One or more warning errors were encountered, but processing completed successfully anyway.  This includes zipfiles where one or more files was skipped due to unsupported compression method or encryption with an unknown password.';
	$err{2} = 'A generic error in the zipfile format was detected.  Processing may have completed successfully anyway; some broken zipfiles created by other archivers have simple work-arounds.';
	$err{3} = 'A severe error in the zipfile format was detected.  Processing probably failed immediately.';
	$err{4} = 'Unzip was unable to allocate memory for one or more buffers during program initialization.';
	$err{5} = 'Unzip was unable to allocate memory or unable to obtain a tty to read the decryption password(s).';
	$err{6} = 'Unzip was unable to allocate memory during decompression to disk.';
	$err{7} = 'Unzip was unable to allocate memory during in-memory decompression.';
	$err{8} = '[currently not used]';
	$err{9} = 'The specified zipfiles were not found.';
	$err{10} = 'Invalid options were specified on the command line.';
	$err{11} = 'No matching files were found.';
	$err{50} = 'The disk is (or was) full during extraction.';
	$err{51} = 'The end of the ZIP archive was encountered prematurely.';
	$err{80} = 'The user aborted unzip prematurely with control-C (or similar)';
	$err{81} = 'Testing or extraction of one or more files failed due to unsupported compression methods or unsupported decryption.';
	$err{82} = 'No files were found due to bad decryption password(s).  (If even one file is successfully processed, however, the exit status is 1.)';
	
	if (defined $err{$errorcode}) {
		return "Unzip error: " . $err{$errorcode};
	} 
	return "Unzip error: Undefined zip error.";
}

sub delete_directory
{
	my $delfolder = shift;
	
	if (-d $delfolder) {   
		rmtree($delfolder, {error => \my $err});
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					LOGERR "     Delete folder: general error: $message";
				} else {
					LOGERR "     Delete folder: problem unlinking $file: $message";
				}
			}
		return undef;
		}
	}
	return 1;
}

sub prepare_update
{
	my $updatedir = shift;
	if (! -d $updatedir) {
		LOGCRIT "Prepare_update failed. Directory $updatedir does not exist.";
		return undef;
	}
	
	LOGINF "Seeking for unzipped sub-directory in $updatedir...";
	opendir( my $DIR, $updatedir );
	my $direntry;
	my $dircount;
	while ( $direntry = readdir $DIR ) {
		next unless -d $updatedir . '/' . $direntry;
		next if $direntry eq '.' or $direntry eq '..';
		$dircount++;
		last;
	}
	closedir $DIR;
	if ($dircount != 1) {
		LOGCRIT "Found unclear number of directories ($dircount) in update directory.";
		return undef;
	}
	
	# system("chown -R loxberry:loxberry $updatedir");
	# my $exitcode  = $? >> 8;
	# if ($exitcode != 0) {
	# LOGINF "Changing owner of updatedir $updatedir returned errors (errorcode: $exitcode). This may lead to further permission problems. Exiting.\n";
	# return undef;
	# }

	$updatedir = "$updatedir/$direntry";
	LOGOK "Update directory is $updatedir\n";
	
	LOGINF "LoxBerry Update programs are updated from the release to your LoxBerry...";
	if ($cgi->param('keepupdatefiles')) {
		LOGWARN "keepupdatefiles is set - no files are copied.";
	}
	
	if (-e "$updatedir/sbin/loxberryupdatecheck.pl" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/sbin/loxberryupdatecheck.pl", "$lbhomedir/sbin/loxberryupdatecheck.pl" or 
			do {
			LOGCRIT "Error copying loxberryupdatecheck to $lbhomedir/sbin/loxberryupdatecheck.pl: $!";
			return undef;
			};
	}
	if (! -x "$lbhomedir/sbin/loxberryupdatecheck.pl") {
		chmod 0774, "$lbhomedir/sbin/loxberryupdatecheck.pl";
	}
	
	if (-e "$updatedir/sbin/loxberryupdate.pl" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/sbin/loxberryupdate.pl", "$lbhomedir/sbin/loxberryupdate.pl" or
			do {
			LOGCRIT "Error copying loxberryupdate to $lbhomedir/sbin/loxberryupdate.pl: $!";
			return undef;
		};
	}
	if (! -e "$lbhomedir/sbin/loxberryupdate.pl") {
		LOGCRIT "Cannot find part two of update, $lbhomedir/sbin/loxberryupdate.pl - Quitting.";
		return undef;
	}
		
	if (-e "$updatedir/config/system/update-exclude.system" && !$cgi->param('keepupdatefiles')) {
		LOGINF "Copying new file exlude list from release to your LoxBerry";
		copy "$updatedir/config/system/update-exclude.system", "$lbhomedir/config/system/update-exclude.system";
	}
	if (! -e "$lbhomedir/config/system/update-exclude.system") {
		LOGCRIT "Missing local exclude list $lbhomedir/config/system/update-exclude.system - Quitting.";
		return undef;
	}
	if (! -x "$lbhomedir/sbin/loxberryupdate.pl") {
		LOGINF "Setting permissions for update program";
		chmod 0774, "$lbhomedir/sbin/loxberryupdate.pl";
	}
	if (! -x "$lbhomedir/sbin/loxberryupdate.pl") {
		LOGCRIT "Cannot set executable $lbhomedir/sbin/loxberryupdate.pl - Quitting.";
		exit(1);
	}
	
	LOGOK "Update checked and prepared successfully.";
	return $updatedir;
}

sub err
{
	if ($joutput{'error'}) {
		LOGERR $joutput{'error'};
		
	} elsif ($joutput{'info'}) {
		LOGINF $joutput{'info'};
	}
	if ($formatjson) {
		my $jsntext = to_json(\%joutput);
		LOGINF "JSON: " . $jsntext;
		print $jsntext;

	}
}



sub vers_tag
{
	my ($vers, $reverse) = @_;
	$vers = lc(LoxBerry::System::trim($vers));
	$vers = "v$vers" if (substr($vers, 0, 1) ne 'v' && ! $reverse);
	$vers = substr($vers, 1) if (substr($vers, 0, 1) eq 'v' && $reverse);
	
	return $vers;

}


# This routine is called at every end
END 
{
	if ($? != 0) {
		LOGCRIT "LoxBerry Updatecheck exited or terminated with an error. Errorcode: $?";
		if ($cron) {
			# Create an error notification
		notify('updates', 'check', "LoxBerry Updatecheck: " . $SL{'UPDATES.LBU_NOTIFY_CHECK_ERROR'}, 'Error');
		}
	}
	if ($log) {
		LOGEND;
	}
}
