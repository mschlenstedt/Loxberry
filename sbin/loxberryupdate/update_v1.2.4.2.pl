#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 

# Initialize logfile and parameters
my $logfilename;
if ($cgi->param('logfilename')) {
	$logfilename = $cgi->param('logfilename');
}
my $log = LoxBerry::Log->new(
		package => 'LoxBerry Update',
		name => 'update',
		filename => $logfilename,
		logdir => "$lbslogdir/loxberryupdate",
		loglevel => 7,
		stderr => 1,
		append => 1,
);
$logfilename = $log->filename;

if ($cgi->param('updatedir')) {
	$updatedir = $cgi->param('updatedir');
}
my $release = $cgi->param('release');

# Finished initializing
# Start program here
########################################################################

my $errors = 0;
LOGOK "Update script $0 started.";

# Move logdb to ramdisk
if (-e "$lbhomedir/data/system/logs_sqlite.dat") {
	my $dbsize = -s "$lbhomedir/data/system/logs_sqlite.dat";
	LOGINF "Current log database size is $dbsize bytes.";
	LOGINF "Deleting old log database entries...";
	eval {
		qx { echo "DELETE FROM logs_attr WHERE keyref NOT IN (SELECT logkey FROM logs);" | sqlite3 -batch $lbhomedir/data/system/logs_sqlite.dat };
	};
	LOGINF "Shrink log database...";
	$output = qx { echo "VACUUM;" | sqlite3 -batch $lbhomedir/data/system/logs_sqlite.dat };
	$dbsize = -s "$lbhomedir/data/system/logs_sqlite.dat";
	LOGINF "New log database size is $dbsize bytes.";
	if ($dbsize && $dbsize > 15728640) {
		LOGINF "Log database is too big and will be deleted and automatically recreated.";
		LOGWARN "LoxBerry Update History will not show logfiles of past updates.";
		unlink "$lbhomedir/data/system/logs_sqlite.dat";
	} else {
		LOGINF "Moving log database to ramdisk...";
		qx {cp -f $lbhomedir/data/system/logs_sqlite.dat $lbhomedir/log/system_tmpfs/};
		qx {chown loxberry:loxberry $lbhomedir/log/system_tmpfs/logs_sqlite.dat};
		qx {chmod +rw $lbhomedir/log/system_tmpfs/logs_sqlite.dat};
	}
}

# End of script
exit($errors);


sub delete_directory
{
	
	require File::Path;
	my $delfolder = shift;
	
	if (-d $delfolder) {   
		File::Path::rmtree($delfolder, {error => \my $err});
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


####################################################################
# Copy a file or dir from updatedir to lbhomedir including error handling
# Parameter:
#	file/dir starting from ~ 
#   (without /opt/loxberry, with leading /)
####################################################################
sub copy_to_loxberry
{
	my ($destparam) = @_;
		
	my $destfile = $lbhomedir . $destparam;
	my $srcfile = $updatedir . $destparam;
		
	if (! -e $srcfile) {
		LOGINF "$srcfile does not exist - This file might have been removed in a later LoxBerry verion. No problem.";
		return;
	}
	
	my $output = qx { cp -rf $srcfile $destfile 2>&1 };
	my $exitcode  = $? >> 8;

	if ($exitcode != 0) {
		LOGERR "Error copying $destparam - Error $exitcode";
		LOGINF "Message: $output";
		$errors++;
	} else {
		LOGOK "$destparam installed.";
	}
}

