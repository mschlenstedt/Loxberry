#!/usr/bin/perl
use LoxBerry::Log;
use strict;
use warnings;

$LoxBerry::Log::DEBUG = 1;

my $package = "Squeezelite";
my $group = "ssds";

print "TEST: Check notification count\n";
my ($check_err, $check_ok, $check_sum) = get_notification_count( $package, $group);

print "We have $check_err errors and $check_ok infos, together $check_sum notifications.\n";

