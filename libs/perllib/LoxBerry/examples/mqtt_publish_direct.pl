#!/usr/bin/perl
use warnings;
use strict;
use JSON;

use LoxBerry::IO;
use Net::MQTT::Simple;

# You define a topic to send to
my $basetopic = "publishtest";

# Example dataset in a hash variable
my %data;
$data{temperature} = "24.5";
$data{humidity} = "65";
$data{lastupdated} = time;

# Get broker credentials from MQTT Gateway
my $mqttcred = LoxBerry::IO::mqtt_connectiondetails();
$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1; 
my $mqtt = Net::MQTT::Simple->new($mqttcred->{brokerhost}.':'.$mqttcred->{brokerport});
$mqtt->login($mqttcred->{brokeruser}, $mqttcred->{brokerpass});
$mqtt->publish( $basetopic , encode_json( \%data) );
$mqtt->disconnect();

print "Subscribe $basetopic/# in MQTT Gateway!\n";
