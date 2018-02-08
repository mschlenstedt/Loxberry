#!/usr/bin/perl

use LoxBerry::System;

$LoxBerry::System::DEBUG=1;

print "My own pid is $$\n";

print "Check locks...\n";
undef $lockstatus;

#$lockstatus = LoxBerry::System::lock(wait => 10, lockfile => 'test');
$lockstatus = LoxBerry::System::lock(wait => 60);
#$lockstatus = LoxBerry::System::lock();
if ($lockstatus) {
	print "Could not lock - locked by $lockstatus\n";
} else {
	print "Nothing locked\n";
}
