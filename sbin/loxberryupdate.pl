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
$release = version->parse($release);
my $currversion = version->parse(LoxBerry::System::lbversion());

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
	"--backup",
	"--backup-dir=/opt/loxberry_backup/",
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

if ($dryrun ne "") {
	print STDERR "rsync was started with dryrun. Nothing was changed.\n\n";
}

# Preparing Update scripts
my @updatelist;
my $updateprefix = 'update_';
opendir (DIR, "$lbhomedir/sbin/loxberryupdate");
while (my $file = readdir(DIR)) {
	next if (!begins_with($file, $updateprefix));
	my $lastdotpos = rindex($file, '.');
	my $nameversion = lc(substr($file, length($updateprefix), length($file)-$lastdotpos-length($updateprefix)+1));
	#print STDERR "$nameversion\n";
	push @updatelist, version->parse($nameversion);
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
		# Should we remember, if exec failed? I think no.
	} else {
		print STDERR "   Dry-run. Skipping $version script.\n";
	}
}

# We think that everything is up to date now.
# I don't know what to do if error occurred during update scripts, so we simply continue.

# We have to recreate the legacy templates.
system("su - loxberry -c '$lbshtmlauthdir/tools/generatelegacytemplates.pl' >/dev/null");

# Last but not least set the general.cfg to the new version.
if (! $cgi->param('dryrun') ) {
	print STDERR "Updating the version in general.cfg is currently disabled for testing.";
	#my  $syscfg = new Config::Simple("$lbsconfigdir/general.cfg");
	#$syscfg->param('BASE.VERION', $release);
	#$syscfg->save();
}	
	
print STDERR "\n<OK> Loxberry Update thinks that the update was successful. If not -> http://www.loxwiki.eu:80/x/YQR7AQ\n";
	
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
}
