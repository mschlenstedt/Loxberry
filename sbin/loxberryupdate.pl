#!/usr/bin/perl
use LoxBerry::System;
use strict;
use warnings;
use experimental 'smartmatch';
use CGI;
use JSON;
use File::Path;
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


# Set up rsync command line
my @rsynccommand = (
	"rsync",
	"-v",
#	"-v",
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
	"$updatedir",
	"$lbhomedir",
#	"/tmp/lb2",
);

# -o und -g verhindern
	
	
system(@rsynccommand);
 
exit;



sub err
{
	if ($joutput{'error'}) {
		print STDERR "ERROR: " . $joutput{'error'} . "\n";
	} elsif ($joutput{'info'}) {
		print STDERR "INFO: " . $joutput{'info'} . "\n";
	}
}
