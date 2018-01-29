#!/usr/bin/perl

use LoxBerry::System;

print "Now lock a test file... - this should fail\n";
$lockstatus = LoxBerry::System::lock(lockfile => 'lbupdate');
if ($lockstatus) {
	print "Could not lock - locked by $lockstatus\n";
} else {
	print "test is locked by me\n";
}

LoxBerry::System::unlock(lockfile => 'test');
