#!/usr/bin/perl
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
$release = version->declare($release);
my $currversion = version->declare(LoxBerry::System::lbversion());

#my ($lbmajor, $lbminor, $lbbuild, $lbdev) = split_version(LoxBerry::System::lbversion());
#my ($major, $minor, $build, $dev) = split_version($release);


# Set up rsync command line
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
#	"--dry-run",
	"$updatedir/",
	"$lbhomedir/",
);

system(@rsynccommand);
my $exitcode  = $? >> 8;


# Preparing Update scripts
my @updatelist;
my $updateprefix = 'update_';
opendir (DIR, "$lbhomedir/sbin/loxberryupdate");
while (my $file = readdir(DIR)) {
	next if (!begins_with($file, $updateprefix));
	my $lastdotpos = rindex($file, '.');
	my $nameversion = lc(substr($file, length($updateprefix), length($file)-$lastdotpos-length($updateprefix)+1));
	#print STDERR "$nameversion\n";
	push @updatelist, version->declare($nameversion);
}
closedir DIR;
# @updatelist = sort { lc($a) cmp lc($b) } @updatelist;
@updatelist = sort { version->parse($a) <=> version->parse($b) } @updatelist;
foreach my $version (@updatelist)
{ 
	print STDERR "Version: " . $version . "\n";
	if ( version->parse($version) <= version->parse($currversion) ) {
		print STDERR "  Skipping. To older version.\n";
		next;
	}
	if ( version->parse($version) > version->parse($release) ) {
		print STDERR "  Skipping. To new version.\n";
		next;
	}
	
	exec_update_script("$lbhomedir/sbin/loxberryupdate/update_$version.pl");
}




sub exec_update_script
{
my $filename = shift;
print STDERR "Executing $filename\n";
system($^X, $filename);
my $exitcode  = $? >> 8;
print STDERR "exec_update_script errcode $exitcode\n";
}




	
	
exit;


sub split_version 
{
	my ($fversion) = @_;
	if (!$fversion) {
		return undef;
	}
	
	# If first letter is a 'V', remove it
	my $firstletter = substr($fversion, 0, 1);
	if ($firstletter eq 'v' || $firstletter eq 'V') {
		$fversion = substr($fversion, 1);
	}
	my ($version, $dev) = split(/-/, $fversion);
	$dev = "" if (!$dev);
	my ($maj, $min, $build) = split(/\./, $version);
	
	if (defined $maj && defined $min && defined $build) {
		return ($maj, $min, $build, $dev);
	}
	return undef;
	
}


sub err
{
	if ($joutput{'error'}) {
		print STDERR "ERROR: " . $joutput{'error'} . "\n";
	} elsif ($joutput{'info'}) {
		print STDERR "INFO: " . $joutput{'info'} . "\n";
	}
}
