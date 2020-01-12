#!/usr/bin/perl

use LoxBerry::System;

my $entered_pin = $ARGV[1];

print "Checking pin '$entered_pin'...\n";
  
my $result = LoxBerry::System::check_securepin($entered_pin);
  
if ( !$result ) {
	print "SecurePIN OK";
} elsif ( $result == 1 ) {
	print "SecurePIN wrong";
} elsif ( $result == 2 ) {
	print "SecurePIN file could not be opened";
} elsif ( $result == 3 ) {
	print "SecurePIN currently is LOCKED";
} else {
	print "Undefined result $result";
}
print "\n";
