#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use Data::Dumper;

$LoxBerry::JSON::DEBUG = 1;

print "---------------------------------------------\n";
print "#1 Test with non-existant file\n";
print "   Expected result: File with content {}\n";
unlink "/tmp/json_non-existant.json";
my $jsonobj = LoxBerry::JSON->new();
my $json = $jsonobj->open(filename => "/tmp/json_non-existant.json");
$json->{test} = "Funny";
$jsonobj->write();

print "---------------------------------------------\n";
print "#2 Test with empty file\n";
print "   Expected result: File with content {} ?\n";
unlink "/tmp/json_empty.json";
`touch /tmp/json_empty.json`;
my $jsonobj = LoxBerry::JSON->new();
my $json = $jsonobj->open(filename => "/tmp/json_empty.json");
$json->{test} = "Funny2";
$jsonobj->write();



