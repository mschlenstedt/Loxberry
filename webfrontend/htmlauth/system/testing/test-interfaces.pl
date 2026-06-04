#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;

require "../tools/Interfaces.pm";

my $ifparser = Interfaces->new();

$ifparser->open("/etc/network/interfaces");
$ifparser->parse;
