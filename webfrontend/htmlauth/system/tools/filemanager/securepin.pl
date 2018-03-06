#!/usr/bin/perl

# Script for setting a new Secure PIN

use LoxBerry::System;

my $pin = $ARGV[0];
#print "PIN is: $pin\n";

if ( LoxBerry::System::check_securepin($pin) ) {
	print STDERR "The entered securepin is wrong.\n";
	exit 1;
} else {
	print STDERR "You have entered the correct securepin. Continuing.\n";
	exit 0;
}
