#!/usr/bin/perl
use utf8;
use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use LoxBerry::JSON;
use warnings;
use strict;

use Net::MQTT::Simple;
# use Hash::Flatten;
use File::Monitor;

# use Data::Dumper;

$SIG{INT} = sub { 
	LOGTITLE "MQTT Finder interrupted by Ctrl-C"; 
	LOGEND; 
	exit 1;
};

$SIG{TERM} = sub { 
	LOGTITLE "MQTT Finder requested to stop"; 
	LOGEND;
	exit 1;	
};

my $datafile = "/dev/shm/mqttfinder.json";
my $cfgfile = "$lbsconfigdir/general.json";
my $json;
my $cfg; 

my %sendhash;

my $nextconfigpoll = 0;
my $nextsavedatafile;
my $mqtt;

my $pollms = 50;
my $mqtt_data_received = 0;

my $log = LoxBerry::Log->new (
    package => 'MQTT',
	name => 'MQTT Finder',
	filename => "$lbslogdir/mqttfinder.log",
	append => 1,
	stdout => 1,
	loglevel => 7,
	addtime => 1
);

LOGSTART "MQTT Finder started";

# Create monitor to handle config file changes
my $monitor = File::Monitor->new();

read_config();
	
# Capture messages
while(1) {
	
	# Check mqtt connection and read config
	if(time>$nextconfigpoll) {
		if(!$mqtt->{socket}) {
			LOGWARN "No connection to MQTT broker $cfg->{Main}{brokeraddress} - Check host/port/user/pass and your connection.";
		} 
		# LOGINF("Read_config");
		read_config();
	}

	# Query MQTT socket
	eval {
		$mqtt->tick();
	};
	
	# If no data where received, sleep some time
	if( $mqtt_data_received == 0 ) {
		Time::HiRes::sleep( $pollms/1000 );
	} else {
		$mqtt_data_received = 0;
	}
	
	if( time>$nextsavedatafile ) {
		save_data();
		$nextsavedatafile = Time::HiRes::time()+1;
	}
	
	
}

sub received
{
	
	my ($topic, $message) = @_;
	
	utf8::encode($topic);
	LOGOK "MQTT received: $topic: $message";
	
	# Remember that we have currently have received data
	$mqtt_data_received = 1;
	
	$sendhash{$topic}{msg} = $message;
	$sendhash{$topic}{time} = Time::HiRes::time();
	
}

sub read_config
{
	my $configs_changed = 0;
	$nextconfigpoll = time+5;
	
	
	# # Watch config config
	$monitor->watch( $cfgfile );
	# $monitor->watch( $credfile );
	
	my @changes = $monitor->scan;
	
	
	if(!defined $cfg or @changes) {
		$configs_changed = 1;
	}
	
	if($configs_changed == 0) {
		return;
	}
	
	LOGOK "Reading config";
	
	# General.json Config file
	$json = LoxBerry::JSON->new();
	$cfg = $json->open(filename => $cfgfile, readonly => 1);
	
	if(!$cfg) {
		LOGCRIT "Could not read json configuration. Possibly not a valid json?";
		return;
	}

	# Setting default values
	if( !defined $cfg->{Mqtt}->{Brokerhost} and !defined $cfg->{Mqtt}->{Brokerport} ) { 
		LOGCRIT "general.json: Brokerhost or Brokerport not defined. MQTT Gateway too old?";
	}
	if(! defined $pollms ) {
		$pollms = 50; 
	}
	
	# Unsubscribe old topics
	if($mqtt) {
		eval {
			LOGINF "UNsubscribing #";
			$mqtt->unsubscribe('#');
		};
		if ($@) {
			LOGERR "Exception catched on unsubscribing old topics: $!";
		}
	}
	
	undef $mqtt;
	
	# Reconnect MQTT broker
	LOGINF "Connecting broker $cfg->{Mqtt}->{Brokerhost}:$cfg->{Mqtt}->{Brokerport}";
	eval {
		
		$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
		
		$mqtt = Net::MQTT::Simple->new($cfg->{Mqtt}->{brokerhost}.":".$cfg->{Mqtt}->{Brokerport});
		
		if($cfg->{Mqtt}->{Brokeruser} or $cfg->{Mqtt}->{Brokerpass}) {
			LOGINF "Login at broker";
			$mqtt->login($cfg->{Mqtt}->{Brokeruser}, $cfg->{Mqtt}->{Brokerpass});
		}
		
		LOGINF "Subscribing #";
		$mqtt->subscribe('#', \&received);
	};
	if ($@) {
		LOGERR "Exception catched on reconnecting and subscribing: $@";
	}
}


sub save_data
{
		
	# LOGINF "Relayed topics are saved on RAMDISK for UI";
	unlink $datafile;
	my $relayjsonobj = LoxBerry::JSON->new();
	my $relayjson = $relayjsonobj->open(filename => $datafile, lockexclusive => 1);

	
	$relayjson->{incoming} = \%sendhash;

	
	$relayjsonobj->write();
	undef $relayjsonobj;

	
}


END
{
	if($mqtt) {
		$mqtt->disconnect()
	}
	
	if($log) {
		LOGEND "MQTT Finder exited";
	}
}

