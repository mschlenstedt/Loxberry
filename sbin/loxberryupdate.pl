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

# Set up rsync command line

my $dryrun = $cgi->param('dryrun') ? "--dry-run" : "";

my @rsynccommand = (
	"rsync",
	"-v",
#	"-v",
	"--checksum",
	"--archive", # equivalent to -rlptgoD
	"--backup",
	"--backup-dir=/opt/loxberry_backup",
	"--keep-dirlinks",
	"--delete",
	"-F",
	"--exclude-from=$lbhomedir/config/system/update_exclude.system",
	"--exclude-from=$lbhomedir/config/system/update_exclude.userdefined",
	"--human-readable",
	"$dryrun",
	"$updatedir/",
	"$lbhomedir/",
);

system(@rsynccommand);
my $exitcode  = $? >> 8;

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

foreach my $version (@updatelist)
{ 
	print STDERR "Version: " . $version . "\n";
	if ( $version <= $currversion ) {
		print STDERR "  Skipping. $version too old version.\n";
		next;
	}
	if ( $version > $release ) {
		print STDERR "  Skipping. $version too new version.\n";
		next;
	}
	
	if (!$cgi->param('dryrun')) {
		print STDERR "   Running update script $version...\n";
		exec_update_script("$lbhomedir/sbin/loxberryupdate/update_$version.pl");
	} else {
		print STDERR "   Dry-run. Skipping $version script.\n";
	}
	
}

sub exec_update_script
{
	my $filename = shift;
	if (!$filename) {
		print STDERR "   exec_update_script: Filename is empty. Skipping.\n";	
		return;
	}
	print STDERR "Executing $filename\n";
	system($^X, $filename);
	my $exitcode  = $? >> 8;
	print STDERR "exec_update_script errcode $exitcode\n";
	return $exitcode;
}

sub err
{
	if ($joutput{'error'}) {
		print STDERR "ERROR: " . $joutput{'error'} . "\n";
	} elsif ($joutput{'info'}) {
		print STDERR "INFO: " . $joutput{'info'} . "\n";
	}
}
