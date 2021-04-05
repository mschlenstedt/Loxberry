#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use Data::Dumper;
$LoxBerry::JSON::DEBUG = 1;

my $filename = "$lbhomedir/libs/perllib/LoxBerry/testing/jsontestdata2.json";
print "Filename: $filename\n";
my $jsonobj = LoxBerry::JSON->new();
my $json = $jsonobj->open(filename => $filename, lockexclusive => 1, locktimeout => 60);

sleep 2;

$json->{Random} = int(rand(100));

print "PRETTY output:\n" . $jsonobj->encode( pretty => 1 ) . "\n";

print "NORMAL output:\n" . $jsonobj->encode() . "\n";

$jsonobj->write();
