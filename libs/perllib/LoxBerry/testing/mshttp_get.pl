#!/usr/bin/perl

# Wiki: https://wiki.loxberry.de/entwickler/perl_develop_plugins_with_perl/perl_loxberry_sdk_dokumentation/perlmodul_loxberryio/loxberryiomshttp_get

use LoxBerry::IO;
$LoxBerry::IO::DEBUG = 1;

my $value = LoxBerry::IO::mshttp_get( 1, "Heizraumlicht" );
print "Value:    $value\n";

my $value = LoxBerry::IO::mshttp_get( 1, "SSUG-Netzteil-24V" );
print "Value:    $value\n";

my $value = LoxBerry::IO::mshttp_get( 1, "Betrieb Zeit seit Aufzeichnung" );
print "Value:    $value\n";
