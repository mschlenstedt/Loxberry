#!/usr/bin/perl

# Wiki: https://www.loxwiki.eu/display/LOXBERRY/LoxBerry%3A%3AIO%3A%3Amshttp_call

use LoxBerry::IO;
$LoxBerry::IO::DEBUG = 1;

my $value = LoxBerry::IO::mshttp_get( 1, "Heizraumlicht" );
print "Value:    $value\n";

my $value = LoxBerry::IO::mshttp_get( 1, "SSUG-Netzteil-24V" );
print "Value:    $value\n";

my $value = LoxBerry::IO::mshttp_get( 1, "Betrieb Zeit seit Aufzeichnung" );
print "Value:    $value\n";
