#!/usr/bin/perl
use LoxBerry::IO;
use Data::Dumper;
use strict;
use warnings;

my $mqttcred = LoxBerry::IO::mqtt_connectiondetails();

# print Dumper($mqttcred);

print $mqttcred->{brokerhost}.':'.$mqttcred->{brokerport}."\n";
