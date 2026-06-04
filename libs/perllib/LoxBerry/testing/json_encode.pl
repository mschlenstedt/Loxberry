#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use Data::Dumper;

my $filename = "$lbhomedir/libs/perllib/LoxBerry/testing/jsontestdata2.json";
my $jsonobj = LoxBerry::JSON->new();
$jsonobj->open(filename => $filename);


print "PRETTY output:\n" . $jsonobj->encode( pretty => 1 ) . "\n";

print "NORMAL output:\n" . $jsonobj->encode() . "\n";


