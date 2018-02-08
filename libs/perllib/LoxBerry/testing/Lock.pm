###########################################################
# DO NOT USE - LockFile::Simple does not work as expected.
###########################################################


use strict;
use LockFile::Simple;
use LoxBerry::System;
use Carp;


package LoxBerry::Lock;





#########################################################
# File locking features
# To keep LoxBerry consistent 
#########################################################
#
# lock
# Params: 	lockfile => 'lbupdate' (omit to only get status of important files)
#			wait => 120 (sec) (omit for immediate return)
# Return:
#	undef	lock is done, or nothing is locked
#	$name	On error, string with the locked file

sub lock 
{
	
	
	my %p = @_;	
	
	if ($p{wait} && $p{wait} < 5) {
		print STDERR "Setting wait to 5\n";
		$p{wait} = 5;
	}
	
	my $max = $p{wait} ? $p{wait}/5 : undef;
	
	
our $lockmgr = LockFile::Simple->make(
	   -max => 2, 
		-delay => 10, 
		-stale => 1,
		-autoclean => 1,
		-efunc => \&Carp::carp,
		-hold => 0,
		-wfunc => \&Carp::carp,
		-wmin => 60, 
		-format => '%f.lock'
	);
	
 
	#print STDERR "lock: file $p{lockfile} wait $p{wait}\n";
	
	# Read important lock files list
	my $importantlockfilesfile = "$LoxBerry::System::lbsconfigdir/lockfiles.default";
	my $openerr;
	open(my $fh, "<", $importantlockfilesfile) or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening important lock files file  $importantlockfilesfile";
		# &error;
		return "Error";
		}
	my @data = <$fh>;
	close $fh;
	
	# Check other lockfiles
	my $lockfilename;
	foreach my $lockfile (@data) {
		$lockfile = LoxBerry::System::trim($lockfile);
		$lockfilename = "/var/lock/$lockfile";
		print STDERR "Read: $lockfile ($lockfilename)\n";
		next if (! -e "$lockfilename.lock");
		next if ($p{lockfile} eq $lockfile); # At the moment, skip own file
		print STDERR "Lock test: Locking $lockfilename\n";
		if ($max) {
			return $lockfile if (! LockFile::Simple::lock("$lockfilename"));
			#$LockFile::Simple::lock("$lockfilename");
		}
		else {
			 return $lockfile if (! LockFile::Simple::trylock("$lockfilename"));
			 
			 #$LockFile::Simple::trylock("$lockfilename")
		}
		print STDERR "Lock test: Unlocking $lockfilename\n";
		LockFile::Simple::unlock("$lockfilename");
		
	}

	
	
	
	if ($p{lockfile}) {
		$lockfilename = "/var/lock/$p{lockfile}";
		print STDERR "tests ok - Locking $p{lockfile} ($lockfilename) ";
		if ($max) {
			print STDERR "with timer \n";
			return $p{lockfile} if (! LockFile::Simple::lock("$lockfilename"));
		} else {
			print STDERR "with immediate return \n";
			return $p{lockfile} if (! LockFile::Simple::trylock("$lockfilename"));
		}
	}
	return undef;
}

sub unlock
{

	my %p = @_;

our $lockmgr = LockFile::Simple->make(
	   -max => 2, 
		-delay => 2, 
		-stale => 1,
		-autoclean => 1,
		-efunc => \&Carp::carp,
		-hold => 0,
		-wfunc => \&Carp::carp,
		-wmin => 60, 
		-format => '%f.lock'
	);
	my $max = 2;
 
	print STDERR "unlock: file $p{lockfile}\n";
	my $lockfilename = "/var/lock/$p{lockfile}";
	# LockFile::Simple::unlock("$lockfilename");
	LockFile::Simple::unlock("/var/lock/$p{lockfile}");
	
}





#####################################################
# Finally 1; ########################################
#####################################################
1;
