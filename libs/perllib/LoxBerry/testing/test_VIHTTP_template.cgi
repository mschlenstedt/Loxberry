#!/usr/bin/perl

require "/opt/loxberry/bin/plugins/nukismartlock/libs/LoxBerry/LoxoneTemplateBuilder.pm";


my $VI = LoxBerry::LoxoneTemplateBuilder->VirtualInHttp(
	Title => "Hallo",
	Address => "http://loxberry:loxberry@loxberry-dev/admin/system/healthcheck.cgi",
);

my $line1 = $VI->VirtualInHttpCmd (
	Title => "timeepoch",
	Check => '"timeepoch":\v',
	Analog => "false"
);

my $line2 = $VI->VirtualInHttpCmd (
	Title => "errors",
	Check => '"errors":\v',
	Analog => "true"
);

print "Lines $line1 and $line2\n";
print $VI->output."\n";

print "Delete 1\n";
$VI->delete(1);
print $VI->output."\n";

