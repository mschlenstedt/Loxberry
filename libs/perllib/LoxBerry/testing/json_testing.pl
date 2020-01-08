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
$jsonobj->open(filename => "/tmp/json_non-existant.json");
$jsonobj->write();

print "---------------------------------------------\n";
print "#2 Test with empty file\n";
print "   Expected result: File with content {} ?\n";
unlink "/tmp/json_empty.json";
`touch /tmp/json_empty.json`;
my $jsonobj = LoxBerry::JSON->new();
$jsonobj->open(filename => "/tmp/json_empty.json");
$jsonobj->write();



