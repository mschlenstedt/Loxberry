#!/usr/bin/perl

use LockFile::Simple;

my $lockmgr = LockFile::Simple->make(
	    -max => 20, 
		-delay => 1, 
		-stale => 1,
	);
 
 
print "Locking...\n";
 $lockmgr->lock("/var/lock/test");
print "Waiting...\n";
sleep (20);
print "Unlocking...\n";
$lockmgr->unlock("/var/lock/test");
print "Finished\n";
