#!/usr/bin/perl
use LoxBerry::Log;
use strict;
use warnings;

my $package = "test";
my $group = "testing";
my $message = "Testmessage";

notify ( $package, $group, $message );
