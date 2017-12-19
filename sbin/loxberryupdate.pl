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
#######################################################

use LoxBerry::System;
# use LoxBerry::Web;
use strict;
use warnings;
use experimental 'smartmatch';
use CGI;
use JSON;
use File::Path;
use version;
# use Sort::Versions;
use LWP::UserAgent;
require HTTP::Request;

my $updatedir;
my %joutput;
my $errskipped = 0;
my $formatjson;

my $cgi = CGI->new;

if ($cgi->param('updatedir')) {
	$updatedir = $cgi->param('updatedir');
}
if (!$updatedir) {
	$joutput{'error'} = "No updatedir sent.";
	&err;
	exit (1);
}
if (! -e "$updatedir/config/system/general.cfg") {
	$joutput{'error'} = "Update directory is invalid (cannot find general.cfg in correct path).";
	&err;
	exit (1);
}

if (!$lbhomedir) {
	$joutput{'error'} = "Cannot determine LBHOMEDIR.";
	&err;
	exit (1);
}

my $release = $cgi->param('release');
if (!$release) {
	$joutput{'error'} = "No release parameter given";
	&err;
	exit (1);
}
if ($release eq "config") {
	my $newcfg = new Config::Simple("$updatedir/config/system/general.cfg");
	$release = $newcfg->param('BASE.VERSION');
}
if (!$release) {
	$joutput{'error'} = "Cannot detect release version number.";
	&err;
	exit (1);
}

if (version::is_lax($release)) {
	$release = version->parse($release);
} else {
	$joutput{'error'} = "Cannot parse provided version $release. Is this a real version string? Exiting.";
	&err;
	exit(1);
}
my $currversion;

if (version::is_lax(LoxBerry::System::lbversion())) {
	$currversion = version->parse(LoxBerry::System::lbversion());
} else {
	$joutput{'error'} = "Cannot read current LoxBerry version $currversion. Is this a real version string? Exiting.";
	&err;
	exit(1);
}

# Change owner of the loxberryupdate dir to loxberry:loxberry
system("chown -R loxberry:loxberry $updatedir");
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
	print STDERR "Changing owner of updatedir $updatedir returned errors. This may lead to further permission problems. Exiting.\n";
	exit(1);
}

# Set up rsync command line

my $dryrun = $cgi->param('dryrun') ? "--dry-run" : "";

my @rsynccommand = (
	"rsync",
	"-v",
	"-v",
	"--checksum",
	"--archive", # equivalent to -rlptgoD
#	"--backup",
	"--backup-dir=/opt/loxberry_backup",
	"--keep-dirlinks",
	"--delete",
	"-F",
	"--exclude-from=$lbhomedir/config/system/update-exclude.system",
	"--exclude-from=$lbhomedir/config/system/update-exclude.userdefined",
	"--human-readable",
	"$dryrun",
	"$updatedir/",
	"$lbhomedir/",
);

undef $exitcode;
system(@rsynccommand);
$exitcode  = $? >> 8;
if ($exitcode != 0 ) {
	print STDERR rsyncerror($exitcode) . ". Despite errors loxberryupdate.pl will continue.\n";
	$errskipped++;
}

if ($dryrun ne "") {
	print STDERR "rsync was started with dryrun. Nothing was changed.\n\n";
}

print STDERR "Restoring permissions\n";
# Restoring permissions
system("$lbhomedir/sbin/resetpermissions.sh");
$exitcode  = $? >> 8;
if ($exitcode != 0 ) {
	print STDERR "Restoring permissions exited with errorcode $exitcode. Despite errors loxberryupdate.pl will continue.\n";
	$errskipped++;
}

print STDERR "Searching ans preparing update scripts\n";
# Preparing Update scripts
my @updatelist;
my $updateprefix = 'update_';
opendir (DIR, "$lbhomedir/sbin/loxberryupdate");
while (my $file = readdir(DIR)) {
	next if (!begins_with($file, $updateprefix));
	my $lastdotpos = rindex($file, '.');
	my $nameversion = lc(substr($file, length($updateprefix), length($file)-$lastdotpos-length($updateprefix)+1));
	#print STDERR "$nameversion\n";
	if (version::is_lax($nameversion)) {
		push @updatelist, version->parse($nameversion);
	} else {
		print STDERR "Ignoring $nameversion as this does not look like a version number.\n";
		$errskipped++;
		next;
	}
}
closedir DIR;
@updatelist = sort { version->parse($a) <=> version->parse($b) } @updatelist;

print STDERR "Running update scripts...\n";

foreach my $version (@updatelist)
{ 
	my $exitcode;
	print STDERR "Script version: " . $version . "\n";
	if ( $version <= $currversion ) {
		print STDERR "  Skipping. $version too old version.\n";
		next;
	}
	if ( $version > $release ) {
		print STDERR "  Skipping. $version too new version.\n";
		next;
	}
	
	if (!$cgi->param('dryrun')) {
		print STDERR "   Running update script for $version...\n";
		undef $exitcode; 
		$exitcode = exec_perl_script("$lbhomedir/sbin/loxberryupdate/update_$version.pl");
		$exitcode  = $? >> 8;
		if ($exitcode != 0 ) {
			print STDERR "Update-Script update_$version returned errorcode $exitcode. Despite errors loxberryupdate.pl will continue.\n";
			$errskipped++;
		}
		# Should we remember, if exec failed? I think no.
	} else {
		print STDERR "   Dry-run. Skipping $version script.\n";
	}
}

# We think that everything is up to date now.
# I don't know what to do if error occurred during update scripts, so we simply continue.

# We have to recreate the legacy templates.
print STDERR "Updating LoxBerry legacy templates...\n";
system("su - loxberry -c '$lbshtmlauthdir/tools/generatelegacytemplates.pl' >/dev/null");
$exitcode  = $? >> 8;
if ($exitcode != 0 ) {
	print STDERR "generatelegacytemplates returned errorcode $exitcode. Despite errors loxberryupdate.pl will continue.\n";
	$errskipped++;
}

# Last but not least set the general.cfg to the new version.
if (! $cgi->param('dryrun') ) {
	print STDERR "Updating the version in general.cfg is currently disabled for testing.\n";
	#my $syscfg = new Config::Simple("$lbsconfigdir/general.cfg") or do {
	#		print STDERR "Cannot open general.cfg. Error: " . $syscfg->error() . "\n"; 
	#		$errskipped++;
	#}
	#$syscfg->param('BASE.VERION', "$release");
	#$syscfg->save() or do {
	#		print STDERR "Cannot write to general.cfg. Error: " . $syscfg->error() . "\n"; 
	#		$errskipped++;
	#}
	}

# Finished. 
	
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
		print STDERR "   exec_perl_script: Filename is empty. Skipping.\n";	
		return;
	}
	print STDERR "Executing $filename\n";
	my @commandline;
	if ($user) {
		push @commandline, "su", "-", $user, "-c", "'$^X $filename'";
	} else {
		push @commandline, "$^X", $filename;
	}
	system(@commandline);
	my $exitcode  = $? >> 8;
	print STDERR "exec_perl_script $filename with user $user - errcode $exitcode\n";
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
		print STDERR "ERROR: " . $joutput{'error'} . "\n";
		
	} elsif ($joutput{'info'}) {
		print STDERR "INFO: " . $joutput{'info'} . "\n";
	}
	if ($formatjson == 1) {
		my $jsntext = to_json(\%joutput);
		print STDERR "JSON: " . $jsntext . "\n";
		print $jsntext;

	}
}

# This routine is called at every end
END 
{
	print STDERR "<INFO> LoxBerry Update skipped at least $errskipped warnings or errors. Check the log.\n" if ($errskipped > 0 );
	
	if ($? != 0) {
		print STDERR "<ERROR> LoxBerry Update exited with an error. Errorcode: $?\n";
		
	} else {
		print STDERR "\n<OK> Loxberry Update thinks that the update was successful. If not -> http://www.loxwiki.eu:80/x/YQR7AQ\n";
	}
}
