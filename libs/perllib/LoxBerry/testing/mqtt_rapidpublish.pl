#!/usr/bin/perl

use warnings;
use strict;
use LoxBerry::IO;
use Net::MQTT::Simple;

my $mqttcred = LoxBerry::IO::mqtt_connectiondetails();
print "Broker Host:Port: " . $mqttcred->{brokerhost}.':'.$mqttcred->{brokerport} ."\n";


print "Rapid publish test\n";

my $basetopic = "test/";
my $content = 'aaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbccccccccccccccccccccccddddddddddddddddddd';

$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1; 
my $mqtt = Net::MQTT::Simple->new($mqttcred->{brokerhost}.':'.$mqttcred->{brokerport});
$mqtt->login($mqttcred->{brokeruser}, $mqttcred->{brokerpass});

for my $a ( 1..10 ) {
	print "Number $a\n";
	$mqtt->publish( $basetopic.$a, $content );
}

$mqtt->disconnect();
