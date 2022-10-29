#!/usr/bin/perl

# Wiki: https://wiki.loxberry.de/entwickler/perl_develop_plugins_with_perl/perl_loxberry_sdk_dokumentation/perlmodul_loxberryio/loxberryiomshttp_call

use LoxBerry::IO;
$LoxBerry::IO::DEBUG = 1;

my ($value, $respcode, $data) = LoxBerry::IO::mshttp_call( 1, "/dev/sps/io/Heizraumlicht" );

print "Value:    $value\n";
print "Respcode: $respcode\n";
print "Data:     $data\n";
