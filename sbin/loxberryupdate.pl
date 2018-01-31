#!/usr/bin/perl

#######################################################
# Parameters
#	release		
#		{version} This is the destination version number, e.g. 0.3.2
#		config 	  Reads the version from the destination general.cfg
#
#	updatedir		
#		{path}   This is the location of the extracted update. Don't use a training slash. 
#
#	dryrun
#		1	do not update loxberryupdate*.pl, exlude-file, and let rsync run dry
#
#	logfilename
#		(empty)	$lbslogdir/loxberryupdate/{timestamp}.log is used
#		filename  filename is used
#######################################################

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use strict;
use warnings;
use CGI;
use JSON;
use File::Path;
use version;
# use Sort::Versions;
use LWP::UserAgent;
require HTTP::Request;

# Version of this script
my $scriptversion='1.0.0.1';

my $backupdir="/opt/backup.loxberry";
my $update_path = '/tmp/loxberryupdate';

# # Predeclare logging functions
# sub LOGOK { my ($s)=@_; print ERRORLOG "<OK>" . $s . "\n"; }
# sub LOGINF { my ($s)=@_;print ERRORLOG "<INFO>" . $s . "\n"; }
# sub LOGWARN { my ($s)=@_;print ERRORLOG "<WARNING>" . $s . "\n"; }
# sub LOGERR { my ($s)=@_;print ERRORLOG"<ERROR>" . $s . "\n"; }
# sub LOGCRIT { my ($s)=@_;print ERRORLOG "<FAIL>" . $s . "\n"; }


#my $logfile ="$lbslogdir/loxberryupdate/logfile.log";
#open ERRORLOG, '>>', $logfile;

my $updatedir;
my %joutput;
my $errskipped = 0;
my $formatjson;
my $logfilename;
my $cron;
my $sha;

my $cgi = CGI->new;

# Initialize logfile
if ($cgi->param('logfilename')) {
	$logfilename = $cgi->param('logfilename');
}
print STDERR "Logfilename from cgi: $logfilename\n";
my $log = LoxBerry::Log->new(
		package => 'LoxBerry Update',
		name => 'update',
		filename => $logfilename,
		logdir => "$lbslogdir/loxberryupdate",
		loglevel => 7,
		stderr => 1,
		append => 1,
		addtime => 1,
);

our %SL = LoxBerry::System::readlanguage();

LOGOK "Update handed over from LoxBerry Update Check to LoxBerry Update";
LOGWARN "New logfile was created as handover of logfilename did not work" if (!$logfilename);

my $curruser = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
LOGINF "Executing user of loxberryupdate is $curruser";

$logfilename = $log->filename;
print STDERR "loxberryupdate uses filename $logfilename\n";

if ($cgi->param('cron')) {
	$cron = $cgi->param('cron');
	LOGOK "This update was triggered automatically by schedule.";
} else {
	LOGOK "This update was manually triggered.";
}

if ($cron) {
	LOGINF "Locking lbupdate - delaying up to 10 minutes...";
	eval {
			my $lockstate = LoxBerry::System::lock( lockfile => 'lbupdate', wait => 600 );
		
		if ($lockstate) {
			LOGCRIT "Could not get lock for lbupdate. Skipping this update.";
			LOGINF "Locking error reason is: $lockstate";
			notify('updates', 'update', "LoxBerry Update: Could not get lock for lbupdate. Locking error reason: $lockstate. Update was prevented.", 'Error');
			exit (1);
		}
	};
} else {
	LOGINF "Locking lbupdate - return immediately if lock stat is not secure...";
	eval {
		my $lockstate = LoxBerry::System::lock( lockfile => 'lbupdate');
		if ($lockstate) {
			LOGCRIT "Could not get lock for lbupdate. Exiting.";
			LOGINF "Locking error reason is: $lockstate";
			notify('updates', 'update', "LoxBerry Update: Could not get lock for lbupdate. Locking error reason: $lockstate. Update was prevented.", 'Error');
			exit (1);
		}
	};
}

LOGOK "Lock successfully set.";

my %folderinfo = LoxBerry::System::diskspaceinfo($lbhomedir);
if ($folderinfo{available} < 102400) {
	$joutput{'error'} = "Available diskspace is below 100MB. Update is skipped.";
	&err;
	LOGCRIT $joutput{'error'};
	notify('updates', 'update', "LoxBerry Update: Free diskspace is below 100MB (available: $folderinfo{available}). Update was prevented.", 'Error');
	exit (1);
}


if ($cgi->param('sha')) {
	$sha = $cgi->param('sha');
	LOGINF "SHA $sha was sent. This is an update to latest commit.";
}

if ($cgi->param('updatedir')) {
	$updatedir = $cgi->param('updatedir');
}

if (!$updatedir) {
	$joutput{'error'} = "No updatedir sent.";
	&err;
	LOGCRIT $joutput{'error'};
	exit (1);
}
if (! -e "$updatedir/config/system/general.cfg.default" && ! -e "$updatedir/config/system/general.cfg") {
	$joutput{'error'} = "Update directory is invalid (cannot find general.cfg or general.cfg.default in correct path).";
	&err;
	LOGCRIT $joutput{'error'};
	exit (1);
}

if (!$lbhomedir) {
	$joutput{'error'} = "Cannot determine LBHOMEDIR.";
	&err;
	LOGCRIT $joutput{'error'};
	exit (1);
}

my $release = $cgi->param('release');
if (!$release) {
	$joutput{'error'} = "No release parameter given";
	&err;
	LOGCRIT $joutput{'error'};
	exit (1);
}

if ($release eq "config") {
	my $newcfg = new Config::Simple("$updatedir/config/system/general.cfg.default");
	$release = $newcfg->param('BASE.VERSION');
	LOGWARN "Version parameter 'config' was given, destination version is read from new general.cfg.default (version $release).";
}
if (!$release) {
	$joutput{'error'} = "Cannot detect release version number.";
	&err;
	LOGCRIT $joutput{'error'};
	exit (1);
}





if (version::is_lax($release)) {
	$release = version->parse($release);
} else {
	$joutput{'error'} = "Cannot parse provided destination version $release. Is this a real version string? Exiting.";
	&err;
	LOGCRIT $joutput{'error'};
	exit(1);
}
my $currversion;

if (version::is_lax(LoxBerry::System::lbversion())) {
	$currversion = version->parse(LoxBerry::System::lbversion());
} else {
	$joutput{'error'} = "Cannot read current LoxBerry version $currversion. Is this a real version string? Exiting.";
	&err;
	LOGCRIT $joutput{'error'};
	exit(1);
}

LOGINF "Changing the owner of the update files to loxberry:loxberry...";
$log->close;
# Change owner of the loxberryupdate dir to loxberry:loxberry
system("chown -R loxberry:loxberry $updatedir >>$logfilename");
my $exitcode  = $? >> 8;
$log->open;
if ($exitcode != 0) {
	LOGCRIT "Changing owner of updatedir $updatedir returned errors. This may lead to further permission problems. Exiting.";
	exit(1);
}
LOGOK "Changing owner was successful.";
# Set up rsync command line

my $dryrun = $cgi->param('dryrun') ? "--dry-run" : "";

my @rsynccommand = (
	"rsync",
	"-v",
	"-v",
	"--checksum",
	"--archive", # equivalent to -rlptgoD
#	"--backup",
	"--backup-dir=$backupdir",
	"--keep-dirlinks",
	"--delete",
	"-F",
	"--exclude-from=$lbhomedir/config/system/update-exclude.system",
	"--exclude-from=$lbhomedir/config/system/update-exclude.userdefined",
	"--human-readable",
	"--log-file=$logfilename",
	"$dryrun",
	"$updatedir/",
	"$lbhomedir/",
);

LOGINF "Running rsync command...";
undef $exitcode;
$log->close;
#system(@rsynccommand);
qx{@rsynccommand};
$exitcode  = $? >> 8;
$log->open;
if ($exitcode != 0 ) {
	LOGERR rsyncerror($exitcode) . ". Despite errors loxberryupdate.pl will continue.";
	$errskipped++;
} else {
	LOGOK "rsync finished successful.";
}

if ($dryrun ne "") {
	LOGWARN "rsync was started with dryrun. Nothing was changed.";
}

LOGINF "Restoring permissions of $lbhomedir of your LoxBerry...";
$log->close;
# Restoring permissions
system("$lbhomedir/sbin/resetpermissions.sh 1>&2 >>$logfilename");
$exitcode  = $? >> 8;
$log->open;
if ($exitcode != 0 ) {
	LOGERR "Restoring permissions exited with errorcode $exitcode. Despite errors loxberryupdate.pl will continue.";
	$errskipped++;
} else {
	LOGOK "Restoring permissions was successful.";
}

LOGINF "Searching and preparing update scripts...";
# Preparing Update scripts
my @updatelist;
my $updateprefix = 'update_';
opendir (DIR, "$lbhomedir/sbin/loxberryupdate");
while (my $file = readdir(DIR)) {
	next if (!begins_with($file, $updateprefix));
	my $lastdotpos = rindex($file, '.');
	my $nameversion = lc(substr($file, length($updateprefix), length($file)-$lastdotpos-length($updateprefix)+1));
	#LOGINF "$nameversion\n";
	if (version::is_lax($nameversion)) {
		push @updatelist, version->parse($nameversion);
	} else {
		LOGWARN "Ignoring $nameversion as this does not look like a version number.";
		$errskipped++;
		next;
	}
}
closedir DIR;
@updatelist = sort { version->parse($a) <=> version->parse($b) } @updatelist;

LOGINF "Running update scripts...";

my $scripterrskipped=0;
foreach my $version (@updatelist)
{ 
	my $exitcode;
	LOGINF "   Script version: " . $version;
	if ( $version <= $currversion ) {
		LOGINF "      Skipping. $version too old version.";
		next;
	}
	if ( $version > $release ) {
		LOGINF "      Skipping. $version too new version.";
		next;
	}
	if (!$cgi->param('dryrun')) {
		LOGINF "      Running update script for $version...\n";
		undef $exitcode; 
		$exitcode = exec_perl_script("$lbhomedir/sbin/loxberryupdate/update_$version.pl release=$release logfilename=$logfilename cron=$cron updatedir=$updatedir");
		$exitcode  = $? >> 8;
		if ($exitcode != 0 ) {
			LOGERR "Update-Script update_$version returned errorcode $exitcode. Despite errors loxberryupdate.pl will continue.";
			$errskipped++;
			$scripterrskipped++;
		}
		# Should we remember, if exec failed? I think no.
	} else {
		LOGWARN "   Dry-run. Skipping $version script.\n";
	}
}

if ($scripterrskipped > 0) {
	LOGWARN "Update scripts were processed, but $scripterrskipped did return an error code. Please check these files and create an issue at GitHub including your log.";
} else {
	LOGOK "Update scripts executed successful.";
}

LOGINF "Migrating configuration settings from default config...";
system("su - loxberry -c '$lbsbindir/createconfig.pl' >/dev/null");
$exitcode  = $? >> 8;
if ($exitcode != 0 ) {
	LOGWARN "$lbsbindir/createconfig.pl returned errorcode $exitcode. Despite errors loxberryupdate.pl will continue.";
	$errskipped++;
} else {
	LOGOK "LoxBerry config settings updated successfully.";
}


# We think that everything is up to date now.
# I don't know what to do if error occurred during update scripts, so we simply continue.

LOGINF "Deleting template cache...";
delete_directory('/tmp/templatecache');

# We have to recreate the legacy templates.
LOGINF "Updating LoxBerry legacy templates...";
system("su - loxberry -c '$lbshtmlauthdir/tools/generatelegacytemplates.pl --force'  >/dev/null");
$exitcode  = $? >> 8;
if ($exitcode != 0 ) {
	LOGWARN "generatelegacytemplates returned errorcode $exitcode. Despite errors loxberryupdate.pl will continue.";
	$errskipped++;
} else {
	LOGOK "LoxBerry legacy template successfully updated.";
}



# We have to recreate the skels for system log folders in tmpfs
LOGINF "Updating Skels for Logfolders...";
system("$lbssbindir/createskelfolders.pl >/dev/null");
$exitcode  = $? >> 8;
if ($exitcode != 0 ) {
	LOGWARN "/createskelfolders.pl returned errorcode $exitcode. Despite errors loxberryupdate.pl will continue.";
	$errskipped++;
} else {
	LOGOK "Skels for Logfolders successfully updated.";
}

LOGINF "LoxBerry's config version is updated from $currversion to $release";
LOGINF "Commit SHA is updated to $sha" if ($sha);
# Last but not least set the general.cfg to the new version.
if (! $cgi->param('dryrun') ) {
	my $syscfg;
	$syscfg = new Config::Simple("$lbsconfigdir/general.cfg") or 
		do {
			LOGERR "Cannot open general.cfg. Error: " . $syscfg->error() . "\n"; 
			$errskipped++;
			};
	$syscfg->param('BASE.VERSION', "$release");
	$syscfg->param('UPDATE.LATESTSHA', "$sha") if ($sha);
	$syscfg->save() or 
		do {
			LOGERR "Cannot write to general.cfg. Error: " . $syscfg->error() . "\n"; 
			$errskipped++;
			};
	}

# Finished. 
LOGINF "Cleaning up temporary download folder";
delete_directory($update_path);

LOGINF "All procesures finished.";
notify('updates', 'update', "LoxBerry Update: " . $SL{'UPDATES.LBU_NOTIFY_UPDATE_INSTALL_OK'} . " $release");
exit 0;


###################################################################################
# This runs a Perl script with the current Perl interpreter
# and returns the exit code
###################################################################################

sub exec_perl_script
{
	my $filename = shift;
	my $user = shift;
	
	if (!$filename) {
		LOGINF "   exec_perl_script: Filename is empty. Skipping.\n";	
		return;
	}
	LOGINF "Executing $filename\n";
	my @commandline;
	if ($user) {
		push @commandline, "su", "-", $user, "-c", "'$^X $filename'", "1>&2";
	} else {
		push @commandline, "$^X", $filename, "1>&2";
	}
	$log->close;
	qx(@commandline);
	my $exitcode  = $? >> 8;
	$log->open;
	LOGINF "exec_perl_script $filename with user $user - errcode $exitcode\n";
	return $exitcode;
}

sub rsyncerror
{
	my $errorcode = shift;
	my %err;

	$err{0} = "Success";
	$err{1} = "Syntax or usage error";
	$err{2} = "Protocol incompatibility";
	$err{3} = "Errors selecting input/output files, dirs";
	$err{4} = "Requested action not supported: an attempt was made to manipulate 64-bit files on a platform that cannot support them; or an option was specified that is supported by the client and not by the server.";
	$err{5} = "Error starting client-server protocol";
	$err{6} = "Daemon unable to append to log-file";
	$err{10} = "Error in socket I/O";
	$err{11} = "Error in file I/O";
	$err{12} = "Error in rsync protocol data stream";
	$err{13} = "Errors with program diagnostics";
	$err{14} = "Error in IPC code";
	$err{20} = "Received SIGUSR1 or SIGINT";
	$err{21} = "Some error returned by waitpid()";
	$err{22} = "Error allocating core memory buffers";
	$err{23} = "Partial transfer due to error";
	$err{24} = "Partial transfer due to vanished source files";
	$err{25} = "The --max-delete limit stopped deletions";
	$err{30} = "Timeout in data send/receive";
	$err{35} = "Timeout waiting for daemon connection";
	if (defined $err{$errorcode}) {
		return "Rsync error $errorcode: " . $err{$errorcode};
	} 
	return "Rsync error: Undefined rsync error.";

}

###################################################################################
# Prints an error in json
# Used for talking with jQuery
###################################################################################

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


sub delete_directory
{
	my ($delfolder) = @_;
	
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

# This routine is called at every end
END 
{
	LOGWARN "LoxBerry Update skipped at least $errskipped warnings or errors. Check the log." if ($errskipped > 0 );
	
	if ($? != 0) {
		LOGCRIT "LoxBerry Update exited or terminated with an error. Errorcode: $?";
		if ($cron) {
			notify('updates', 'update', "LoxBerry Update: " . $SL{'UPDATES.LBU_NOTIFY_UPDATE_INSTALL_ERROR'} . " $release", 'Error');
		}
		
	} else {
		LOGOK "Loxberry Update thinks that the UPDATE WAS SUCCESSFUL!";
	}
	# close ERR;
	LoxBerry::System::unlock( lockfile => 'lbupdate' );

}
