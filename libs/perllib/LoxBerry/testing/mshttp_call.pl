#!/usr/bin/perl

# Wiki: https://www.loxwiki.eu/display/LOXBERRY/LoxBerry%3A%3AIO%3A%3Amshttp_call

use LoxBerry::IO;
$LoxBerry::IO::DEBUG = 1;

my ($value, $respcode, $data) = LoxBerry::IO::mshttp_call( 1, "/dev/sps/io/Heizraumlicht" );

print "Value:    $value\n";
print "Respcode: $respcode\n";
print "Data:     $data\n";