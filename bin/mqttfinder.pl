#!/usr/bin/perl
use utf8;
use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use LoxBerry::JSON;
use IO::Socket::UNIX;
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
my $unixsocketpath = "/dev/shm/mqttfinder.sock";
my $json;
my $cfg; 

my %sendhash;

my $nextconfigpoll = 0;
my $nextsavedatafile = 0;
my $nextdatacleanup = 0;
my $mqtt;

my $pollms = 50;
my $datacleanup_olderthan_secs = 7*24*60*60;
my $datacleanup_interval_secs = 60*60;

# Debug
# my $datacleanup_olderthan_secs = 30;
# my $datacleanup_interval_secs = 10;

my $mqtt_data_received = 0;

my $log = LoxBerry::Log->new (
    package => 'MQTT',
	name => 'MQTT Finder',
	filename => "$lbstmpfslogdir/mqttfinder.log",
	append => 1,
	stdout => 1,
	loglevel => 7,
	addtime => 1
);

LOGSTART "MQTT Finder started";

# Create monitor to handle config file changes
my $monitor = File::Monitor->new();

# Open Unix socket
my $unixsock = open_unix_socket( $unixsocketpath );

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
		if(time>$nextdatacleanup) {
			data_cleanup();
		}
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
		
		if( my $connection = $unixsock->accept ) {
			my $line = <$connection>;
			chomp($line);
			LOGDEB "Unixsock: $line";
			process_unixsock($line);
		}
		
		
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
	
	$sendhash{$topic}{p} = $message;
	$sendhash{$topic}{t} = Time::HiRes::time();
	
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
		return;
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
	LOGINF "Connecting broker " . $cfg->{Mqtt}->{Brokerhost} . ":" . $cfg->{Mqtt}->{Brokerport};
	eval {
		
		$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
		
		$mqtt = Net::MQTT::Simple->new($cfg->{Mqtt}->{Brokerhost}.":".$cfg->{Mqtt}->{Brokerport});
		
		if($cfg->{Mqtt}->{Brokeruser} or $cfg->{Mqtt}->{Brokerpass}) {
			LOGINF "Login at broker with user $cfg->{Mqtt}->{Brokeruser}";
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

sub data_cleanup
{
	LOGOK "data_cleanup started: " . scalar(keys %sendhash) . " topics";
	my $deltime = time - $datacleanup_olderthan_secs;
	foreach( keys %sendhash ) {
		if( $sendhash{$_}->{t} < $deltime ) {
			delete $sendhash{$_};
		}
	}
	$nextdatacleanup = time + $datacleanup_interval_secs;
	LOGOK "data_cleanup finished: " . scalar(keys %sendhash) . " topics";
	
}



sub open_unix_socket {
	my $path = shift;
	
	unlink $path if -e $path;
	
	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM(),
		Local => $path,
		Listen => 1,
	);
	$socket->blocking(0);
	return $socket;
	
}

sub process_unixsock {
	my $line = shift;
	
	
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

