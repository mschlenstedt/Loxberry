#!/usr/bin/perl
use LoxBerry::MQTT;
use Data::Dumper;
use strict;
use warnings;

my $mqttcred = LoxBerry::MQTT::connectiondetails();

# print Dumper($mqttcred);

print $mqttcred->{brokerhost}.':'.$mqttcred->{brokerport}."\n";
