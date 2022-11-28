#!/usr/bin/perl

use LoxBerry::LoxoneTemplateBuilder;

my $VI = LoxBerry::LoxoneTemplateBuilder->VirtualInUdp(
	Title => "Hallo",
	Address => "192.168.0.11",
	Port => "12345"
);

my $line1 = $VI->VirtualInUdpCmd (
	Title => "timeepoch",
	Check => '\i"timeepoch":\i\v',
	Analog => "false"
);

my $line2 = $VI->VirtualInUdpCmd (
	Title => "errors",
	Check => '\i"errors":\i\v',
	Analog => "true"
);

print $VI->output."\n";

