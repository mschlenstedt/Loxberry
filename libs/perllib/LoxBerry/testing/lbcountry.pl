#!/usr/bin/perl

use warnings;
use strict;
use LoxBerry::System;

if ( my $country = lbcountry() ) {
	print "Country: " . $country . "\n";
} else {
	print "Country not defined\n";
}