#!/usr/bin/perl
use warnings;
use strict;
use JSON;

use LoxBerry::IO;

# You define a topic to send to
my $basetopic = "publishtest";

# Example dataset in a hash variable
my %data;
$data{temperature} = "24.5";
$data{humidity} = "65";
$data{lastupdated} = time;

# Get broker credentials from MQTT Gateway
my $mqttcred = LoxBerry::IO::mqtt_connectiondetails();
my $udpport = $mqttcred->{udpinport};
my $socket;
$socket = LoxBerry::IO::create_out_socket($socket, $udpport, 'udp', '127.0.0.1');

# See https://www.loxwiki.eu/display/LOXBERRY/MQTT+Gateway+-+HTTP-+und+UDP-Interface
my %udpsendpackage = (
	'topic' => $basetopic,
	'value' => encode_json( \%data),
	'retain' => 1
);

# We use the UDP JSON interface, and send the json data as jaon ;-)
$socket->send(encode_json(\%udpsendpackage));
print "Subscribe $basetopic/# in MQTT Gateway!\n";
