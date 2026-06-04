#!/usr/bin/perl

use LoxBerry::System;
use Data::Dumper;
$LoxBerry::System::DEBUG = 1;

my %ms = LoxBerry::System::get_miniservers();

print Dumper(\%ms) . "\n";
