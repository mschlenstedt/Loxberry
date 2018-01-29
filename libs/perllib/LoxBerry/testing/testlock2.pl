#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Lock;


print "Now lock a test file... - this should fail\n";
$lockstatus = LoxBerry::Lock::lock(lockfile => 'test', wait => 5);
if ($lockstatus) {
	print "Could not lock - locked by $lockstatus\n";
} else {
	print "test is locked by me\n";
}

LoxBerry::Lock::unlock(lockfile => 'test');
