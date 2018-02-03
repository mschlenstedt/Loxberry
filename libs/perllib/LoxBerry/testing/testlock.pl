#!/usr/bin/perl

use LoxBerry::System;
# use LoxBerry::Lock;


# my $lockstatus = LoxBerry::System::lock(lockfile => 'test', wait => 20);

# if ($lockstatus) {
	# print "Could not lock - locked by $lockstatus\n";
	# exit;
# } else {
	# print "File is locked by me\n";
# }

# print "Waiting 20 Secs.\n";
# sleep (2);

# print "Unlocking test...\n";
# LoxBerry::System::unlock(lockfile => 'test');
# print "Finished \n";

print "Locking lbupdate...\n";
undef $lockstatus;
$lockstatus = LoxBerry::System::lock(lockfile => 'lbupdate');
if ($lockstatus) {
	print "Could not lock - locked by $lockstatus\n";
} else {
	print "lbupdate is locked by me\n";
}
sleep 30;
LoxBerry::System::unlock(lockfile => 'lbupdate');
exit;



print "Now lock a test file... - this should fail\n";
$lockstatus = LoxBerry::System::lock(lockfile => 'test', wait => 5);
if ($lockstatus) {
	print "Could not lock - locked by $lockstatus\n";
} else {
	print "test is locked by me\n";
}

print "Unlock lbupdate...\n";
LoxBerry::System::unlock(lockfile => 'lbupdate');

print "Now lock a test file again... - this should work\n";
$lockstatus = LoxBerry::System::lock(lockfile => 'test', wait => 5);
if ($lockstatus) {
	print "Could not lock - locked by $lockstatus\n";
} else {
	print "test is locked by me\n";
}
LoxBerry::System::unlock(lockfile => 'test');

print "We 'forget' to unlock test - auto-cleanup should do. Byebye.\n";
