#!/usr/bin/perl
use utf8;

use warnings;
use strict;

use LoxBerry::IO;
use LoxBerry::Log;
use LoxBerry::JSON;
use LoxBerry::MQTTGateway::IO;

use IO::Socket;
use Net::MQTT::Simple;

use Time::HiRes;
use Scalar::Util qw(looks_like_number);
use Hash::Flatten;

use File::Monitor;
use File::Find::Rule;

use Proc::CPUUsage;
use LoxBerry::PIDController;

use Data::Dumper;


$SIG{INT} = sub { 
	LOGTITLE "MQTT Gateway interrupted by Ctrl-C"; 
	LOGEND(); 
	exit 1;
};

$SIG{TERM} = sub { 
	LOGTITLE "MQTT Gateway requested to stop"; 
	LOGEND();
	exit 1;	
};

# general.json data
my $generaljsonfile = "$lbsconfigdir/general.json";
my $generaljsonobj;
my $generaljson;

# mqtt.json data
my $cfgfile = "$lbsconfigdir/mqttgateway.json";
my $json;
my $cfg;

# Temporary data files
my $datafile = "/dev/shm/mqttgateway_topics.json";
my $extplugindatafile = "/dev/shm/mqttgateway_extplugindata.json";
my $transformerdatafile = "/dev/shm/mqttgateway_transformers.json";

my $pollms;
my $nextconfigpoll;
my $mqtt;

# Plugin directories to load config files
my %plugindirs;
my $plugincount;

# Subscriptions
my @subscriptions;
my @subscriptions_toms;

# Subscription Filter Expressions
my @subscriptionfilters = ();

# Conversions
my %conversions;

# Reset After Send Topics
my %resetAfterSend;

# Do Not Forward Topics
my %doNotForward;

# Hash to store all submitted topics
my %relayed_topics_udp;
my %relayed_topics_http;
my %health_state;
my $nextrelayedstatepoll = 0;

# UDP
my $udpinsock;
my $udpmsg;
my $udpremhost;
my $udpMAXLEN = 10240;

# Store if data were received in the last cycle ("Fast Response Mode")
my $fast_response_mode = 1; # General mode enabled or disabled
my $do_fast_response; # Flag per loop
my $mqtt_data_received = 0;
my $udp_data_received = 0;
		
# Own MQTT Gateway topic
my $gw_topicbase;

# Local lookup cache
my $dns_nextupdatetime=0;
my %dns_loopupcache = ();

# Transformer scripts
my %trans_udpin;
my %trans_mqttin;
my $trans_monitor = File::Monitor->new();

print "Configfile: $generaljsonfile\n";
while (! -e $generaljsonfile) {
	print "ERROR: Cannot find config file $generaljsonfile\n";
	sleep(5);
	$health_state{configfile}{message} = "Cannot find config file $generaljsonfile";
	$health_state{configfile}{error} = 1;
	$health_state{configfile}{count} += 1;
}

$health_state{configfile}{message} = "Configfile present";
$health_state{configfile}{error} = 0;
$health_state{configfile}{count} = 0;

my $log = LoxBerry::Log->new (
    package => 'MQTT',
	name => 'MQTT Gateway',
	filename => "$lbstmpfslogdir/mqttgateway.log",
	append => 1,
	stdout => 1,
	loglevel => 7,
	addtime => 1
);

LOGSTART "MQTT Gateway started";

LOGINF "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.";
LOGINF "If you use UDP Monitor, you have to take actions that changes are pushed.";
LoxBerry::IO::msudp_send(1, 6666, "MQTT", "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.");

my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();

# Create monitor to handle config file changes
my $monitor = File::Monitor->new();

my $cpu = Proc::CPUUsage->new();
my $cpu_max;
my $PIDController;
my ($pollmsstarttime, $pollmsendtime, $pollmsloopcount);

read_config();
create_in_socket();


	
# Capture messages
while(1) {
	$pollmsstarttime = Time::HiRes::time;
	$pollmsloopcount++;
	if(time>$nextconfigpoll) {
		if(!$mqtt->{socket}) {
			LOGWARN "No connection to MQTT broker $generaljson->{Mqtt}{Brokerhost} - Check host/port/user/pass and your connection.";
			$health_state{broker}{message} = "No connection to MQTT broker $generaljson->{Mqtt}{Brokerhost} - Check host/port/user/pass and your connection.";
			$health_state{broker}{error} = 1;
			$health_state{broker}{count} += 1;
		} else {
			$health_state{broker}{message} = "Connected and subscribed to broker";
			$health_state{broker}{error} = 0;
			$health_state{broker}{count} = 0;
		}
		
		read_config();
		if(!$udpinsock) {
			create_in_socket();
		}
	}
	eval {
		$mqtt->tick();
	};
	
	# UDP Receive data from UDP socket
	eval {
		$udpinsock->recv($udpmsg, $udpMAXLEN);
	};
	if($udpmsg) {
		udpin();
	} 
	
	## Save relayed_topics_http and relayed_topics_udp
	## and send a ping to Miniserver
	if (time > $nextrelayedstatepoll) {
		save_relayed_states();
		eval_pollms();
		$nextrelayedstatepoll = time+60;
		$mqtt->retain($gw_topicbase . "keepaliveepoch", time);
		# Every 4 hours clear the DNS lookup cache
		if( $dns_nextupdatetime < time ) {
			undef %dns_loopupcache;
			$dns_nextupdatetime = time()+14400;
		}
	}
	
	$pollmsendtime = Time::HiRes::time;
	$do_fast_response = ($mqtt_data_received || $udp_data_received ) && $fast_response_mode ? 1 : 0;
	if ( $pollmsendtime < ($pollmsstarttime+$pollms/1000) and !$do_fast_response) {
		Time::HiRes::sleep(  $pollmsstarttime - $pollmsendtime + $pollms/1000 );
	}
	else {
		$mqtt_data_received = 0;
		$udp_data_received = 0;
	}
}

sub udpin
{

	# udpin supports already a bunch of incoming formats and keywords, that must be processed in the correct order
	#
	# "save_relayed_states"  .... Save topics to ramdisk
	# "reconnect"			 .... Resets the caching timer
	# "timestamp;name;value" .... Loxone "syslog" message
	# "{ .... }" 			 .... Data as a json message
	# "publish transform my/topic data" .... calls the 'transform' transformer and publishes the result
	# "retain transform my/topic data" .... calls the 'transform' transformer and publishes the result with retain
	# "publish my/topic data".... Publish a message
	# "retain my/topic data" .... Publish a message with retain
	# "my/topic data"		 .... Legacy format of publish
	
	
	# Data to publish are stored in an array holding a hash
	# LOGDEB "UDP IN: Starting" if( $udpmsg ne 'save_relayed_states' );
	my @publish_arr;
	my($port, $ipaddr) = sockaddr_in($udpinsock->peername);
	
	# Remember that we have currently have received data
	$udp_data_received = 1;
	
	if( defined $dns_loopupcache{ $ipaddr } ) {
		$udpremhost = $dns_loopupcache{ $ipaddr };
	}
	else {
		my $dnsstarttime = Time::HiRes::time();
		$udpremhost = gethostbyaddr($ipaddr, AF_INET);
		LOGINF "Executing DNS reverse lookup";
		$dns_loopupcache{ $ipaddr } = $udpremhost;
		if( (Time::HiRes::time()-$dnsstarttime) > 0.05 ) {
			LOGWARN "DNS lookup time is high: " . int((Time::HiRes::time()-$dnsstarttime)*1000) . " msecs. Normally this is around 2-10 msecs.";
		}
	}
	
	# Skip log for relayed_state requests
	if( $udpmsg ne 'save_relayed_states' ) {
		LOGOK "UDP IN: $udpremhost (" .  inet_ntoa($ipaddr) . "): $udpmsg";
	}
	
	## Send to MQTT Broker
			
	my ($command, $udptopic, $udpmessage, $transformer);
	my $contjson;

	
	# Check for Loxone Logger message
	if ( $udpmsg =~ /(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2});(.*);(.*)/ ) {
		# LOGDEB "Regex matches: $1 - $2 - $3";
		my ($udpremhost_short) = split(/\./, $udpremhost);
		$command = 'retain';
		$udptopic = 'logger/' . $udpremhost_short . '/' . $2;
		$udpmessage = trim($3);
	} 
	else {
		# Check for json content
		eval {
				$contjson = from_json($udpmsg);
		};
		if($@) {
			# Not a json message
			$udpmsg = trim($udpmsg);
			($command, $transformer, $udptopic, $udpmessage) = split(/\ /, $udpmsg, 4);
		} 
		else {
			# json message
			$udptopic = $contjson->{topic};
			$udpmessage = $contjson->{value};
			$command = is_enabled($contjson->{retain}) ? "retain" : "publish";
			$transformer = defined $contjson->{transform} ? $contjson->{transform} : undef;
		}
	}
	
	if(lc($command) ne 'publish' and lc($command) ne 'retain' and lc($command) ne 'reconnect' and lc($command) ne 'save_relayed_states') {
		# Old syntax - move around the values. Old syntax does not support transformers.
		no warnings;
		$udpmessage = trim($transformer.' '.$udptopic.' '.$udpmessage);
		$udptopic = $command;
		$command = 'publish';
		$transformer = undef;
	}
	
	$command = lc($command);


	# Check if we need to run a transformation
	if( $transformer ) {
		LOGDEB "Checking if transformer requested";
		if (exists $trans_udpin{$transformer}) {
			LOGOK "Transformer $transformer found";
			
		} else {
			# Without a known transformer, we need to swap data
			$udpmessage = trim($udptopic.' '.$udpmessage);
			$udptopic = $transformer;
			undef $transformer;
		}
	}

	# Now, the input is converted to a hash and pushed to our send array
	my %dataHash = (
		command => $command,
		transformer => $transformer,
		udptopic => $udptopic,
		udpmessage => $udpmessage
	);
	
	push @publish_arr, \%dataHash;
	
	# Process transformer
	if( $transformer ) {
		@publish_arr = trans_process( \@publish_arr );
	}

	foreach ( @publish_arr ) {
		# LOGDEB "Process UDP DATA\n".Dumper($_);
		
		$command = $_->{command};
		$udptopic = $_->{udptopic};
		$udpmessage = $_->{udpmessage};
	
		my $udptopicPrint = $udptopic;
		if($udptopic) {
			utf8::decode($udptopic);
		}

		if($command eq 'publish') {
			LOGDEB "Publishing: '$udptopicPrint'='$udpmessage'";
			eval {
				$mqtt->publish($udptopic, $udpmessage);
			};
			if($@) {
				LOGERR "Catched exception on publishing to MQTT: $!";
			}
		} elsif($command eq 'retain') {
			LOGDEB "Publish (retain): '$udptopicPrint'='$udpmessage'";
			eval {
				$mqtt->retain($udptopic, $udpmessage);
				
				# This code may only work, when the topic is not subscribed anymore (as the gateway receives the publish itself)
				if(!$udpmessage) {
					LOGDEB "Delete $udptopic from memory because of empty message";
					delete $relayed_topics_http{$udptopic};
					delete $relayed_topics_udp{$udptopic};
				}
			};
			if($@) {
				LOGERR "Catched exception on publishing (retain) to MQTT: $!";
			}
		} elsif($command eq 'reconnect') {
			LOGOK "Forcing reconnection and retransmission to Miniserver";
			$nextconfigpoll = 0;
			undef %plugindirs;
			$LoxBerry::MQTTGateway::IO::mem_sendall = 1;
			foreach( keys %relayed_topics_http ) {
				delete $relayed_topics_http{$_}{toMS};
			}
			delete $health_state{stats}{httpresp};
			
			
		} elsif($command eq 'save_relayed_states') {
			# LOGOK "Save relayed states triggered by udp request";
			
			## How to answer the client with the data?
			# if( defined $port ) {
				# use IO::Socket::INET;
				# my $udpoutsock = new IO::Socket::INET(
					# PeerAddr => '127.0.0.1',
					# PeerPort => $port,
					# Proto => 'udp', Timeout => 1);
				# print $udpoutsock encode_json( ( http => \%relayed_topics_http ) );
				# $udpoutsock->close();
			# }
	
			save_relayed_states();
		} else {
			LOGERR "Unknown incoming UDP command";
		}
	}
		
	# $udpinsock->send("CONFIRM: $udpmsg ");

}


sub received
{
	
	my ($topic, $message) = @_;
	my $is_json = 1;
	my %sendhash;
	my $contjson;
	
	utf8::encode($topic);
	LOGOK "MQTT received: $topic: $message";
	
	# Remember that we have currently have received data
	$mqtt_data_received = 1;
	
	if( is_enabled($cfg->{Main}{expand_json}) ) {
		# Check if message is a json
		eval {
			$contjson = from_json($message);
		};
		if($@ or !ref($contjson)) {
			# LOGDEB "  Not a valid json message";
			$is_json = 0;
			$sendhash{$topic} = $message;
		} else {
			LOGDEB "  Expanding json message";
			$is_json = 1;
			undef $@;
			eval {
				if( ref($contjson) eq "ARRAY" ) {
					my %tmphash = map { $_ => 1 } @$contjson;
					$contjson = \%tmphash;
					LOGDEB "Plain json array was converted to hash";
				}
				
				my $flatterer = new Hash::Flatten({
					HashDelimiter => '_', 
					ArrayDelimiter => '_',
					OnRefScalar => 'warn',
					#DisableEscapes => 'true',
					EscapeSequence => '#',
					OnRefGlob => '',
					OnRefScalar  => '',
					OnRefRef => '',
					# DisableEscapes => 1
				});
				my $flat_hash = $flatterer->flatten($contjson);
				for my $record ( keys %$flat_hash ) {
					my $val = $flat_hash->{$record};
					$sendhash{"$topic/$record"} = $val;
					LOGDEB "$topic/$record = $val";
				}
			};
			if($@) { 
				LOGERR "Error on JSON expansion: $!";
				$health_state{jsonexpansion}{message} = "There were errors expanding incoming JSON.";
				$health_state{jsonexpansion}{error} = 1;
				$health_state{jsonexpansion}{count} += 1;
			} 
		}
	}
	else {
		# JSON expansion is disabled
		$is_json = 0;
		$sendhash{$topic} = $message;
	}
	
	# Boolean conversion
	if( is_enabled($cfg->{Main}{convert_booleans}) ) {
		
		foreach my $sendtopic (keys %sendhash) {
			if( $sendhash{$sendtopic} ne "" and is_enabled($sendhash{$sendtopic}) ) {
				#LOGDEB "  Converting $message to 1";
				$sendhash{$sendtopic} = "1";
			} elsif ( $sendhash{$sendtopic} ne "" and is_disabled($sendhash{$sendtopic}) ) {
				#LOGDEB "  Converting $message to 0";
				$sendhash{$sendtopic} = "0";
			}
		}
	} 
	
	# User defined conversion
	if ( %conversions ) {
		foreach my $sendtopic (keys %sendhash) {
			if( defined $conversions{ trim($sendhash{$sendtopic}) } ) {
				$sendhash{$sendtopic} = $conversions{ trim($sendhash{$sendtopic}) };
			}
		}
	}
	
	# Split cached and non-cached data
	# Also "Reset after send" data imlicitely are non-cached
	my %sendhash_noncached;
	my %sendhash_cached;
	my %sendhash_resetaftersend;
	
	foreach my $sendtopic (keys %sendhash) {
		# Generate $sendtopic with / and % replaced by _
		# Not allowed in Loxone: /%
		my $sendtopic_underlined = $sendtopic;
		$sendtopic_underlined =~ s/[\/%]/_/g;

		# Skip doNotForward topics
		if (exists $cfg->{doNotForward}->{$sendtopic_underlined} ) {
			LOGDEB "   $sendtopic (incoming value $sendhash{$sendtopic}) skipped - do not forward enabled";
			if( is_enabled($cfg->{Main}{use_http}) ) {
				# Generate data for Incoming Overview
				$relayed_topics_http{$sendtopic_underlined}{timestamp} = time;
				$relayed_topics_http{$sendtopic_underlined}{message} = $sendhash{$sendtopic};
				$relayed_topics_http{$sendtopic_underlined}{originaltopic} = $sendtopic;
			}
			if( is_enabled($cfg->{Main}{use_udp}) ) {
				# Generate data for Incoming Overview
				$relayed_topics_udp{$sendtopic}{timestamp} = time;
				$relayed_topics_udp{$sendtopic}{message} = $sendhash{$sendtopic};
				$relayed_topics_udp{$sendtopic}{originaltopic} = $sendtopic;
			}
			next;
		}
		
		# Run Subscription Filter Expressions
		my $regexcounter = 0;
		my $regexmatch = 0;
		foreach( @subscriptionfilters ) {
			$regexcounter++;
			if( $sendtopic_underlined  =~ /$_/ ) {
				LOGDEB "   $sendtopic (incoming value $sendhash{$sendtopic}) skipped - Subscription Filter line $regexcounter";
				$regexmatch = 1;
				# Generate data for Incoming Overview
				if( is_enabled($cfg->{Main}{use_http}) ) {
					$relayed_topics_http{$sendtopic_underlined}{timestamp} = time;
					$relayed_topics_http{$sendtopic_underlined}{message} = $sendhash{$sendtopic};
					$relayed_topics_http{$sendtopic_underlined}{originaltopic} = $sendtopic;
					$relayed_topics_http{$sendtopic_underlined}{regexfilterline} = $regexcounter;
					delete $relayed_topics_http{$sendtopic_underlined}{toMS};
				}
				if( is_enabled($cfg->{Main}{use_udp}) ) {
					$relayed_topics_udp{$sendtopic}{timestamp} = time;
					$relayed_topics_udp{$sendtopic}{message} = $sendhash{$sendtopic};
					$relayed_topics_udp{$sendtopic}{originaltopic} = $sendtopic;
					$relayed_topics_udp{$sendtopic}{regexfilterline} = $regexcounter;
				}
				
				last;
			}
		}
		if( $regexmatch == 1 ) {
			next;
		}
		else {
			delete $relayed_topics_http{$sendtopic_underlined}{regexfilterline};
			delete $relayed_topics_udp{$sendtopic}{regexfilterline};
		}
		
		if (exists $cfg->{Noncached}->{$sendtopic_underlined} or exists $resetAfterSend{$sendtopic_underlined}) {
			LOGDEB "   $sendtopic is non-cached";
			$sendhash_noncached{$sendtopic} = $sendhash{$sendtopic};
			# Create a list of reset-after-send topics, with value 0
			if(exists $resetAfterSend{$sendtopic_underlined}) {
				$sendhash_resetaftersend{$sendtopic} = "0";
			}
		
		} else {
			LOGDEB "   $sendtopic is cached";
			$sendhash_cached{$sendtopic} = $sendhash{$sendtopic};
		}	
	}
	
	# Check if still any data need to be sent. Otherwise, processing is finished
	if( scalar keys %sendhash_cached == 0 and scalar keys %sendhash_noncached == 0 and scalar keys %sendhash_resetaftersend == 0 ) {
		LOGDEB "All data filtered - skipping further processing of this message";
		return;
	};
	
	# toMS: Evaluate what Miniservers to send to
	my @toMS = ();
	my $idx=0;
	
	# LOGDEB "Topic '$topic', " . scalar(@subscriptions) . " Subscriptions, " . scalar(@subscriptions_toms) . " toms elements";
	
	my $SUBMATCH_FIND = '\+'; 				# Quoted '+'
	my $SUBMATCH_REPLACE = '\[\^\/\]\+'; 		# Quoted '[^/]+'
		
	foreach ( @subscriptions ) {
		my $regex = $_; 
		# LOGDEB "$_ Regex 0: " . $regex;
		
		## Eval + in subscription
		$regex =~ s/$SUBMATCH_FIND/$SUBMATCH_REPLACE/g;
		# LOGDEB "$_ Regex 1: " . $regex;
		$regex =~ s/\\//g;								# Remove quotation
		# LOGDEB "$_ Regex 2: " . $regex;
		
		## Eval # in subscription
		if( $regex eq '#' ) {							# If subscription is only #, this is a "match-all"
			# LOGDEB "-->Regex is #: $regex";
			$regex = ".+";
		} elsif ( substr($regex, -1) eq '#' ) {			# If subscription ends with #, also fully accept the last hierarchy ( topic test is matched by test/# ) 
			$regex = substr($regex, 0, -2) . '.*';
		}
		# LOGDEB "$_ Regex to query: $regex";
		my $re = qr/$regex/;
		if( $topic =~ /$re/ ) {
			@toMS = @{$subscriptions_toms[$idx]};
			LOGDEB "$_ matches $topic, send to MS " . join(",", @toMS);
			last;
		}
		$idx++;
	}
	
	# toMS: Fallback to default MS if nothing found
	if( ! @toMS ) {
		@toMS = ( $cfg->{Main}->{msno} );
		LOGWARN "Incoming topic does not match any subscribed topic. This might be a bug";
		LOGWARN "Topic: $topic";
	}
	
	# Send via UDP
	if( is_enabled($cfg->{Main}{use_udp}) ) {
		
		#LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", $topic, $message);
		foreach my $sendtopic (keys %sendhash) {
			$relayed_topics_udp{$sendtopic}{timestamp} = time;
			$relayed_topics_udp{$sendtopic}{message} = $sendhash{$sendtopic};
			$relayed_topics_udp{$sendtopic}{originaltopic} = $topic;
		}	
		
		my $udpresp;
		
		if( $cfg->{Main}{msno} and $cfg->{Main}{udpport} and $miniservers{$cfg->{Main}{msno}}) {
			# Send uncached
			# LOGDEB "  UDP: Sending all uncached values";
			
			foreach( @toMS ) {
				LOGDEB "  UDP: Sending to MS $_";
				$udpresp = LoxBerry::IO::msudp_send($_, $cfg->{Main}{udpport}, "MQTT", %sendhash_noncached);
				if (!$udpresp) {
					$health_state{udpsend}{message} = "There were errors sending values via UDP to Miniserver $_ (via non-cached api).";
					$health_state{udpsend}{error} = 1;
					$health_state{udpsend}{count} += 1;
				}
				
				# Send 0 for Reset-after-send
				if ( scalar keys %sendhash_resetaftersend > 0 ) {
					LOGDEB "  UDP: Sending reset-after-send values (delay ".$cfg->{Main}{resetaftersendms}." ms)";
					Time::HiRes::sleep($cfg->{Main}{resetaftersendms}/1000);
					$udpresp = LoxBerry::IO::msudp_send($_, $cfg->{Main}{udpport}, "MQTT", %sendhash_resetaftersend);
				}
				
				# Send cached
				# LOGDEB "  UDP: Sending all other values";
				$udpresp = LoxBerry::IO::msudp_send_mem($_, $cfg->{Main}{udpport}, "MQTT", %sendhash_cached);
				if (!$udpresp) {
					$health_state{udpsend}{message} = "There were errors sending values via UDP to the Miniserver (via cached api).";
					$health_state{udpsend}{error} = 1;
					$health_state{udpsend}{count} += 1;
				}
			}
		} else {
			LOGERR "  UDP: Cannot send. No Miniserver defined, or UDP port missing";
		}
		
	}
	# Send via HTTP
	if( is_enabled($cfg->{Main}{use_http}) ) {
		# Parse topics to replace /% with _ (cached)
		foreach my $sendtopic (keys %sendhash_cached) {
			my $newtopic = $sendtopic;
			$newtopic =~ s/[\/%]/_/g;
			$sendhash_cached{$newtopic} = delete $sendhash_cached{$sendtopic};
		}
		# Parse topics to replace /% with _ (non-cached)
		foreach my $sendtopic (keys %sendhash_noncached) {
			my $newtopic = $sendtopic;
			$newtopic =~ s/[\/%]/_/g;
			$sendhash_noncached{$newtopic} = delete $sendhash_noncached{$sendtopic};
		}
		# Parse topics to replace /% with _ (reset-after-send)
		foreach my $sendtopic (keys %sendhash_resetaftersend) {
			my $newtopic = $sendtopic;
			$newtopic =~ s/[\/%]/_/g;
			$sendhash_resetaftersend{$newtopic} = delete $sendhash_resetaftersend{$sendtopic};
		}
		
		# Create overview data (cached)
		foreach my $sendtopic (keys %sendhash_cached) {
			$relayed_topics_http{$sendtopic}{timestamp} = time;
			$relayed_topics_http{$sendtopic}{message} = $sendhash_cached{$sendtopic};
			$relayed_topics_http{$sendtopic}{originaltopic} = $topic;
			LOGDEB "  HTTP: Preparing input $sendtopic (using cache): $sendhash_cached{$sendtopic}";
		}
		# Create overview data (non-cached)
		foreach my $sendtopic (keys %sendhash_noncached) {
			$relayed_topics_http{$sendtopic}{timestamp} = time;
			$relayed_topics_http{$sendtopic}{message} = $sendhash_noncached{$sendtopic};
			$relayed_topics_http{$sendtopic}{originaltopic} = $topic;
			LOGDEB "  HTTP: Preparing input $sendtopic (noncached): $sendhash_noncached{$sendtopic}";
		}

		#LOGDEB "  HTTP: Sending as $topic to MS No. " . $cfg->{Main}{msno};
		#LoxBerry::IO::mshttp_send_mem($cfg->{Main}{msno},  $topic, $message);
		
		if( $miniservers{$cfg->{Main}{msno}} ) {
			foreach ( @toMS ) {
				# LOGDEB "  HTTP: Sending all values";
				my $httpresp;
				$httpresp = LoxBerry::MQTTGateway::IO::mshttp_send2($_,  %sendhash_noncached);
				validate_http_response( $_, \%sendhash_noncached, $httpresp ) if $httpresp;
				$httpresp = LoxBerry::MQTTGateway::IO::mshttp_send_mem2($_,  %sendhash_cached);
				validate_http_response( $_, \%sendhash_cached, $httpresp ) if $httpresp;
				
				if ( scalar keys %sendhash_resetaftersend > 0 ) {
					LOGDEB "  HTTP: Sending reset-after-send values (delay ".$cfg->{Main}{resetaftersendms}." ms)";
					Time::HiRes::sleep($cfg->{Main}{resetaftersendms}/1000);
					$httpresp = LoxBerry::MQTTGateway::IO::mshttp_send2($_, %sendhash_resetaftersend);
				}
			}
		} else {
			LOGERR "  HTTP: Cannot send: No Miniserver defined";
		}
		
	}
}


sub read_config
{
	my $configs_changed = 0;
	$nextconfigpoll = time+5;
	
	if(!defined $plugincount) {
		$configs_changed = 1;
		
		# Watch own config files
		$monitor->watch( $generaljsonfile );
		$monitor->watch( $cfgfile );
		
		# Monitor for plugin changes (installation/update/uninstall) with special treatment
		$monitor->watch( "$lbstmpfslogdir/plugins_state.json", sub {
			# It requires to re-read the plugin database
			LOGINF "Forcing re-read config because of plugin database change  (install/update/uninstall)";
			undef %plugindirs;
			undef $plugincount;
			$nextconfigpoll = 0;
		} );
		
		LOGDEB "Reading plugin configs";
		my @plugins = LoxBerry::System::get_plugins(undef, 1);
		$plugincount = scalar @plugins;
		undef %plugindirs;
		
		foreach my $plugin (@plugins) {
			next if (!$plugin->{PLUGINDB_FOLDER});
			my $ext_plugindir = "$lbhomedir/config/plugins/$plugin->{PLUGINDB_FOLDER}/";
			LOGDEB "Watching plugindir $ext_plugindir";
			$plugindirs{$plugin->{PLUGINDB_TITLE}}{configfolder} = $ext_plugindir;
			
			#push @plugindirs, $ext_plugindir;
			$monitor->watch( $ext_plugindir.'mqtt_subscriptions.cfg' );
			$monitor->watch( $ext_plugindir.'mqtt_conversions.cfg' );
			$monitor->watch( $ext_plugindir.'mqtt_resetaftersend.cfg' );
		}
	
		
		# Monitor transformer files
		$trans_monitor->watch( {
			name 		=> $lbsbindir.'/mqtt/transform',
			recurse 	=> 1,
			callback 	=> {
				change => sub { 
					LOGDEB "TRANSFORM FILE CHANGED";
					trans_reread_directories($lbsbindir.'/mqtt/transform'); }
			}
		} );
		trans_reread_directories($lbsbindir.'/mqtt/transform');
		$trans_monitor->scan;

	}
	
	my @changes = $monitor->scan;
	$trans_monitor->scan;
	
	## The change detection needs a further routine to detect changes in the Mqtt section of general.json
	## Otherwise, changes of other widgets will always force the gateway to re-read and re-subscribe.
	## TO BE FINISHED
	
	if(!defined $cfg or @changes) {
		$configs_changed = 1;
		my @changed_files;
		# Only for logfile
		for my $change ( @changes ) {
			push @changed_files, $change->name;
		}
		LOGINF "Changed configuration files: " .  join(',', @changed_files) if (@changed_files);
	}
	
	if($configs_changed == 0) {
		return;
	}
	
	LOGOK "Reading config changes";
	# $LoxBerry::JSON::DEBUG = 1;
	
	# Own topic
	$gw_topicbase = lbhostname() . "/mqttgateway/";
	LOGOK "MQTT Gateway topic base is $gw_topicbase";
	
	# General.json
	$generaljsonobj = LoxBerry::JSON->new();
	$generaljson = $generaljsonobj->open(filename => $generaljsonfile, readonly => 1);
	
	# Config file
	$json = LoxBerry::JSON->new();
	$cfg = $json->open(filename => $cfgfile, readonly => 1);
	
	if(!$generaljson) {
		LOGERR "Could not read $generaljsonfile configuration. Possibly not a valid json?";
		$health_state{configfile}{message} = "Could not read $generaljsonfile configuration. Possibly not a valid json?";
		$health_state{configfile}{error} = 1;
		$health_state{configfile}{count} += 1;
		return;
	} elsif (!$cfg) {
		LOGERR "Could not read $cfgfile configuration. Possibly not a valid json?";
		$health_state{configfile}{message} = "Could not read $cfgfile configuration. Possibly not a valid json?";
		$health_state{configfile}{error} = 1;
		$health_state{configfile}{count} += 1;
		return;

	} else {
	
	# Setting default values
		# Values from general.json
		if(! defined $generaljson->{Mqtt}{Brokerhost}) { $generaljson->{Mqtt}{Brokerhost} = 'localhost'; }
		if(! defined $generaljson->{Mqtt}{Brokerport}) { $generaljson->{Mqtt}{Brokerport} = '1883'; }
		if(! defined $generaljson->{Mqtt}{Udpinport}) { $generaljson->{Mqtt}{Udpinport} = 11884; }
		
		# Values from mqttgateway.json
		if(! defined $cfg->{Main}{msno}) { $cfg->{Main}{msno} = 1; }
		if(! defined $cfg->{Main}{udpport}) { $cfg->{Main}{udpport} = 11883; }
		if(! defined $cfg->{Main}{resetaftersendms} or $cfg->{Main}{resetaftersendms} < 1 ) { $cfg->{Main}{resetaftersendms} = 13; }
		if(! defined $pollms ) {
			$pollms = defined $cfg->{Main}{pollms} ? $cfg->{Main}{pollms} : 50; 
		}
		if(! defined $cpu_max ) {
			$cpu_max = defined $cfg->{Main}{cpuperf} ? $cfg->{Main}{cpuperf}/100 : 5/100; 
			LOGOK "Performance Profile: ".($cpu_max*100)."% CPU usage";
		} 
		else {
			if( defined $cfg->{Main}{cpuperf} and $cpu_max ne $cfg->{Main}{cpuperf}/100 ) {
				$cpu_max = $cfg->{Main}{cpuperf}/100;
				LOGOK "Performance Profile changed: ".($cpu_max*100)."% CPU usage";
			}
		}
		if(! defined $cfg->{subscriptionfilters} ) {
			$cfg->{subscriptionfilters} = \@subscriptionfilters;
		}
		
		LOGDEB "JSON Dump:";
		LOGDEB Dumper($cfg);

		LOGINF "MSNR: " . $cfg->{Main}{msno};
		LOGINF "UDPPort: " . $cfg->{Main}{udpport};
		
		# Unsubscribe old topics
		if($mqtt) {
			eval {
				$mqtt->retain($gw_topicbase . "status", "Disconnected");
				
				foreach my $topic (@subscriptions) {
					LOGINF "UNsubscribing $topic";
					$mqtt->unsubscribe($topic);
				}
			};
			if ($@) {
				LOGERR "Exception catched on unsubscribing old topics: $!";
			}
		}
		
		undef $mqtt;
		
		# Reconnect MQTT broker
		LOGINF "Connecting broker ". $generaljson->{Mqtt}{Brokerhost}.":".$generaljson->{Mqtt}{Brokerport};
		eval {
			
			$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
			
			$mqtt = Net::MQTT::Simple->new($generaljson->{Mqtt}{Brokerhost}.":".$generaljson->{Mqtt}{Brokerport});
			
			if($generaljson->{Mqtt}{Brokeruser} or $generaljson->{Mqtt}{Brokerpass}) {
				LOGINF "Login at broker";
				$mqtt->login($generaljson->{Mqtt}{Brokeruser}, $generaljson->{Mqtt}{Brokerpass});
			}
			
			LOGINF "Sending Last Will and Testament"; 
			$mqtt->last_will($gw_topicbase . "status", "Disconnected", 1);
		
			$mqtt->retain($gw_topicbase . "status", "Joining");
			
			@subscriptions = ();
			foreach my $sub_elem ( @{$cfg->{subscriptions}} ) {
				LOGDEB "Subscription " . $sub_elem->{id};
				push( @subscriptions,  $sub_elem->{id} );
			}
			read_extplugin_config();
			
			# Add external plugin subscriptions to subscription list
			foreach my $pluginname ( keys %plugindirs ) {
				if( $plugindirs{$pluginname}{subscriptions} ) {
					push @subscriptions, @{$plugindirs{$pluginname}{subscriptions}};
				}
			}
			
			# Make subscriptions unique
			LOGDEB "Uniquify subscriptions: Before " . scalar( @subscriptions ) . " subscriptions";
			my %subscriptions_unique = map { $_, 1 } @subscriptions;
			@subscriptions = sort keys %subscriptions_unique;
			undef %subscriptions_unique;
			LOGDEB "Uniquify subscriptions: Afterwards " . scalar( @subscriptions ) . " subscriptions";
			
			my @checked_subscriptions;
			LOGINF "Checking subscriptions for invalid entries";
			foreach my $topic (@subscriptions) {
				next if( !trim($topic) );
				my $msg = validate_subscription($topic);
				if($msg) {
					LOGWARN "Skipping subscription $topic ($msg)";
				} else {
					push @checked_subscriptions, $topic;
				}
			}
			@subscriptions = @checked_subscriptions;
						
			push @subscriptions, $gw_topicbase . "#";
			
			# Ordering is required for toMS based on number of topics
			LOGINF "Ordering subscriptions by topic level";
			@subscriptions = sort { ($b=~tr/\///) <=> ($a=~tr/\///) } @subscriptions;
			
			
			LOGINF "Reading your config about what topics to send to what Miniserver";
			# Fill up the subscriptions_toms array;
			my @default_arr = ( $cfg->{Main}->{msno} );
			@subscriptions_toms = ();
			
			foreach my $sub ( @subscriptions ) {
				my $sub_set;
				foreach my $cfg_sub ( @{$cfg->{subscriptions}} ) {
					if( $sub eq $cfg_sub->{id} ) {
						if( scalar @{$cfg_sub->{toMS}} > 0 ) {
							push @subscriptions_toms, $cfg_sub->{toMS};
							# LOGDEB "Read Subscription $sub: toMS: " . join( ",", @{$cfg_sub->{toMS}});
						} else {
							push @subscriptions_toms, \@default_arr;
							# LOGDEB "Subscription $sub: toMS: " . join( ",", @default_arr) . " (default)";
						}
						$sub_set = 1;
						last;
					}
				}
				if( ! $sub_set ) {
					push @subscriptions_toms, \@default_arr;
					# LOGDEB "No MS set - using " . $cfg->{Main}->{msno} . "(" . join(',', @{$default_arrref}) . ")";
				}
			}
			
			# Re-Subscribe new topics
			foreach my $topic (@subscriptions) {
				LOGINF "Subscribing $topic";
				$mqtt->subscribe($topic, \&received);
			}
		};
		if ($@) {
			LOGERR "Exception catched on reconnecting and subscribing: $@";
			$health_state{broker}{message} = "Exception catched on reconnecting and subscribing: $@";
			eval {
				$mqtt->retain($gw_topicbase . "status", "Disconnected");
			
			};
			$health_state{broker}{error} = 1;
			$health_state{broker}{count} += 1;
			
		} else {
			eval {
				$mqtt->retain($gw_topicbase . "status", "Connected");
			};
			$health_state{broker}{message} = "Connected and subscribed successfully";
			$health_state{broker}{error} = 0;
			$health_state{broker}{count} = 0;
			
		}
		
		# Subscription Filter Expressions
		# Compare current with loaded array
		
		if ( join('', @{$cfg->{subscriptionfilters}}) ne join('', @subscriptionfilters) ) {
			
			@subscriptionfilters = ();
			
			# Validate Expressions
			LOGINF "Reading Subscription Expression Filters";
			foreach( @{$cfg->{subscriptionfilters}} ) {
				if( !trim($_) ) {
					next;
				}
				my $regex = eval { qr/$_/ };
				if($@) {
					LOGWARN("Subscription Expression Filter '$_' is invalid - skipping");
				} else {
					LOGOK("Subscription Expression Filter '$_' is valid");
					push( @subscriptionfilters, $_ );
				}	
			}
			# Directly set current data as filtered
		
			LOGINF "Subscription Expression Filters are applied to current data";
			# Filter HTTP
			foreach my $topic ( %relayed_topics_http ) {
				my $regexcounter = 0;
				my $regexmatch;
				foreach( @subscriptionfilters ) {
					$regexcounter++;
					if( $topic  =~ /$_/ ) {
						$regexmatch = 1;
						# Generate data for Incoming Overview
						$relayed_topics_http{$topic}{regexfilterline} = $regexcounter;
						delete $relayed_topics_http{$topic}{toMS};
						last;
					}
					else {
						delete $relayed_topics_http{$topic}{regexfilterline};
					}
				}
				if( $regexmatch == 1 ) {
					next;
				}
			}
			# Filter UDP
			foreach my $topic ( %relayed_topics_udp ) {
				my $filtertopic = $topic;
				$filtertopic =~ tr/\//_/;
				my $regexcounter = 0;
				my $regexmatch;
				foreach( @subscriptionfilters ) {
					$regexcounter++;
					if( $filtertopic  =~ /$_/ ) {
						$regexmatch = 1;
						# Generate data for Incoming Overview
						$relayed_topics_udp{$topic}{regexfilterline} = $regexcounter;
						delete $relayed_topics_udp{$topic}{toMS};
						last;
					}
					else {
						delete $relayed_topics_udp{$topic}{regexfilterline};
					}
				}
				if( $regexmatch == 1 ) {
					next;
				}
			}
		}	
			
		# Conversions
		undef %conversions;
		my @temp_conversions_list;
	
		LOGOK "Processing conversions";
		
		LOGINF "Adding user defined conversions";
		push @temp_conversions_list, @{$cfg->{conversions}} if ($cfg->{conversions});
		
		# Add external plugin conversions to conversion list
		LOGINF "Adding plugin conversions";
		foreach my $pluginname ( keys %plugindirs ) {
			if( $plugindirs{$pluginname}{conversions} ) {
				push @temp_conversions_list, @{$plugindirs{$pluginname}{conversions}};
			}
		}
		
		# Parsing conversions
		foreach my $conversion (@temp_conversions_list) {
			my ($text, $value) = split('=', $conversion, 2);
			$text = trim($text);
			$value = trim($value);
			if($text eq "" or $value eq "") {
				LOGWARN "Ignoring conversion setting: $conversion (a part seems to be empty)";
				next;
			}
			if(!looks_like_number($value)) {
				LOGWARN "Conversion entry: Convert '$text' to '$value' - Conversion is used, but '$value' seems not to be a number";
			} else {
				LOGINF "Conversion entry: Convert '$text' to '$value'";
			}
			if(defined $conversions{$text}) {
				LOGWARN "Conversion entry: '$text=$value' overwrites '$text=$conversions{$text}' - You have a DUPLICATE";
			}
			$conversions{$text} = $value;
		}
		undef @temp_conversions_list;
		
		# Reset after send 
		# User defined settings
		LOGINF "Processing Reset After Send";
		undef %resetAfterSend;
		if (exists $cfg->{resetAfterSend}) {
			LOGINF "Adding user defined Reset After Send";
			foreach my $topic ( keys %{$cfg->{resetAfterSend}}) {
				if (LoxBerry::System::is_enabled($cfg->{resetAfterSend}->{$topic}) ) {
					$resetAfterSend{$topic} = 1;
					LOGDEB "ResetAfterSend: $topic";
				}
			}
		}
		LOGINF "Adding plugins Reset After Send";
		foreach my $pluginname ( keys %plugindirs ) {
			if( $plugindirs{$pluginname}{resetaftersend} ) {
				foreach my $topic ( @{$plugindirs{$pluginname}{resetaftersend}} ) {
					# %resetAfterSend = map { $_ => 1 } @{$plugindirs{$pluginname}{resetaftersend}};
					$resetAfterSend{$topic} = 1;
					LOGDEB "ResetAfterSend: $topic (Plugin $pluginname)";
				}
			}
		}
		
		# Do Not Forward
		LOGINF "Processing Do Not Forward";
		undef %doNotForward;
		if (exists $cfg->{doNotForward}) {
			LOGINF "Adding user defined Do Not Forward";
			foreach my $topic ( keys %{$cfg->{doNotForward}}) {
				if (LoxBerry::System::is_enabled($cfg->{doNotForward}->{$topic}) ) {
					$doNotForward{$topic} = 1;
					# Clear submit state
					delete $relayed_topics_udp{$topic}{toMS};
					delete $relayed_topics_http{$topic}{toMS};
					LOGDEB "doNotForward: $topic";
				}
			}
		}
		
		# Clean UDP socket
		create_in_socket();
	
	}
}


sub read_extplugin_config
{
	return if(!%plugindirs);
	
	foreach my $pluginname ( keys %plugindirs ) {
		my $content;
		@{$plugindirs{$pluginname}{subscriptions}} = () ;
		@{$plugindirs{$pluginname}{conversions}} = ();
		@{$plugindirs{$pluginname}{resetaftersend}} = ();
		$content = LoxBerry::System::read_file( $plugindirs{$pluginname}{configfolder}."mqtt_subscriptions.cfg" );
		if ($content) {
			$content =~ s/\r\n/\n/g;
			my @lines = split("\n", $content);
			@lines = grep { $_ ne '' } @lines;
			$plugindirs{$pluginname}{subscriptions} = \@lines;
		}
		$content = LoxBerry::System::read_file( $plugindirs{$pluginname}{configfolder}."mqtt_conversions.cfg" );
		if ($content) {
			$content =~ s/\r\n/\n/g;
			my @lines = split("\n", $content);
			@lines = grep { $_ ne '' } @lines;
			$plugindirs{$pluginname}{conversions} = \@lines;
		}
		$content = LoxBerry::System::read_file( $plugindirs{$pluginname}{configfolder}."mqtt_resetaftersend.cfg" );
		if ($content) {
			$content =~ s/\r\n/\n/g;
			my @lines = split("\n", $content);
			@lines = grep { $_ ne '' } @lines;
			$plugindirs{$pluginname}{resetaftersend} = \@lines;
		}
	}
	
	unlink $extplugindatafile;
	my $extplugindataobj = LoxBerry::JSON->new();
	my $extplugindata = $extplugindataobj->open(filename => $extplugindatafile);
	$extplugindata->{plugins}=\%plugindirs;
	$extplugindataobj->write();
	undef $extplugindataobj;
	
}



# Checks a subscription topic for validity to Standard (https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html)
# Returns a string with the error on error
# Returns undef if ok
sub validate_subscription
{
	my ($topic) = @_;
	
	if (!$topic) { 
		return "Topic empty"; }
	
	if ($topic eq "#") {
		return;
	}
	if ($topic eq "/") {
		return "/ without any topic level not allowed";
	}
	if(length($topic) > 65535) {
		return "Topic too long (max 65535 bytes";
	}
	
	my @parts = split /\//, $topic;
	for ( my $i = 0; $i < scalar @parts; $i++) {
		if ($parts[$i] eq '#' and $i eq (scalar @parts - 1)) {
			return;
		}
		if ($parts[$i] eq '+') {
			next;
		}
		if ( index($parts[$i], "+") != -1 ) {
			return "+ not allowed as string-part of a subtopic";
		}
		if ( index($parts[$i], "#") != -1 ) {
			return "# not allowed in the middle";
		}
	}
	return;
	
}

sub validate_http_response {

	my ($ms, $sendhash, $httpresp) = @_;
	
	foreach my $toMSVI ( keys %$sendhash ) {
		my $newcode = defined $httpresp->{$toMSVI}->{code} ? $httpresp->{$toMSVI}->{code} : 0;
		$relayed_topics_http{$toMSVI}{toMS}{"$ms"}{code} = $newcode;
		$relayed_topics_http{$toMSVI}{toMS}{"$ms"}{lastsent} = time;
	}
}

sub create_in_socket 
{

	undef $udpinsock;
	# sleep 1;
	# UDP in socket
	LOGDEB "Creating udp-in socket";
	$udpinsock = IO::Socket::INET->new(
		# LocalAddr => 'localhost', 
		LocalPort => $generaljson->{Mqtt}{Udpinport}, 
		# MultiHomed => 1,
		#Blocking => 0,
		Proto => 'udp') or 
	do {
		LOGERR "Could not create UDP IN socket: $@";
		$health_state{udpinsocket}{message} = "Could not create UDP IN socket: $@";
		$health_state{udpinsocket}{error} = 1;
		$health_state{udpinsocket}{count} += 1;
	};	
		
	if($udpinsock) {
		IO::Handle::blocking($udpinsock, 0);
		LOGOK "UDP-IN listening on port " . $generaljson->{Mqtt}{Udpinport};
		$health_state{udpinsocket}{message} = "UDP-IN socket connected";
		$health_state{udpinsocket}{error} = 0;
		$health_state{udpinsocket}{count} = 0;
	}
}

sub save_relayed_states
{
	#$nextrelayedstatepoll = time + 60;
	
	## Delete memory elements older than one day, and delete empty messages
	
	# Delete udp messages older 24 hours
	if( is_enabled( $cfg->{Main}->{use_udp} ) ) {
		foreach my $sendtopic (keys %relayed_topics_udp) {
			if(	$relayed_topics_udp{$sendtopic}{timestamp} < (time - 24*60*60) ) {
				delete $relayed_topics_udp{$sendtopic};
			}
			if( $relayed_topics_udp{$sendtopic}{message} eq "" ) {
				delete $relayed_topics_udp{$sendtopic};
			}
		}
	}
	else {
		undef %relayed_topics_udp;
	}
	
	# Delete http message
	if( is_enabled( $cfg->{Main}->{use_http} ) ) {
		delete $health_state{stats}{httpresp};
		foreach my $sendtopic (keys %relayed_topics_http) {
			if(	$relayed_topics_http{$sendtopic}{timestamp} < (time - 24*60*60) ) {
				delete $relayed_topics_http{$sendtopic};
				next;
			}
			if( $relayed_topics_http{$sendtopic}{message} eq "" ) {
				delete $relayed_topics_http{$sendtopic};
				next;
			}
			# Count resp status codes
			foreach( keys %{$relayed_topics_http{$sendtopic}{toMS}} ) {
				my $code = $relayed_topics_http{$sendtopic}{toMS}{$_}{code};
				$health_state{stats}{httpresp}{$code}++;
			}
		}
	}
	else {
		undef %relayed_topics_http;
	}
		
	# LOGINF "Relayed topics are saved on RAMDISK for UI";
	unlink $datafile;
	my $relayjsonobj = LoxBerry::JSON->new();
	my $relayjson = $relayjsonobj->open(filename => $datafile);

	$health_state{stats}{http_relayedcount} = keys %relayed_topics_http;
	$health_state{stats}{udp_relayedcount} = keys %relayed_topics_udp; 
	
	$relayjson->{udp} = \%relayed_topics_udp;
	$relayjson->{http} = \%relayed_topics_http;
	$relayjson->{Noncached} = $cfg->{Noncached};
	$relayjson->{resetAfterSend} = \%resetAfterSend;
	$relayjson->{doNotForward} = \%doNotForward;
	$relayjson->{health_state} = \%health_state;
# 	$relayjson->{transformers}{udpin} = \%trans_udpin;
#	$relayjson->{transformers}{mqttin} = \%trans_mqttin;

	$relayjson->{subscriptionfilters} = \@subscriptionfilters;
	
	$relayjsonobj->write();
	undef $relayjsonobj;
	
}

sub eval_pollms {
	my $usage = $cpu->usage();
	my $pollpidval;
	if( !$nextrelayedstatepoll ) {
		$PIDController = new LoxBerry::PIDController( P => 400, I => 0.001, D => 20 );
		$PIDController->setWindup(5);
		$PIDController->{setPoint} = $cpu_max*0.9;
		$pollpidval = 0;
	} 
	else {
		$PIDController->{setPoint} = $cpu_max*0.9;
		$pollpidval = $PIDController->update($usage);
		if( $pollpidval < 0 ) {
			$pollms -= $pollms*($pollpidval*0.01*5);
		} else {
			$pollms -= $pollms*($pollpidval*0.01);
		}
	}

	if( $pollms < 0.1 ) {
		$pollms = 0.1;
	} elsif( $pollms > 150 ) {
		$pollms = 150;
	}
	$mqtt->publish($gw_topicbase . "pollms", int($pollms*100+0.5)/100);
	$mqtt->publish($gw_topicbase . "pollcpucurpct", int($usage*1000+0.5)/10);
	$mqtt->publish($gw_topicbase . "pollcpumaxpct", int($PIDController->{setPoint}*1000)/10);
	$mqtt->publish($gw_topicbase . "pollpidvalpct", -1*int($pollpidval*10+0.5)/10);
	
	$mqtt->publish($gw_topicbase . "pollproccnt", int($pollmsloopcount/60+0.5));
	$pollmsloopcount = 0;
	
}
	


sub trans_reread_directories {
	LOGDEB "trans_reread_directories ";
	my ($trans_basepath) = shift;

	my @files = File::Find::Rule->file()
		->name( '*' )
		->nonempty
       	->in($trans_basepath.'/shipped/udpin', $trans_basepath.'/custom/udpin');
	
	undef %trans_udpin;
	undef %trans_mqttin;
	
	my $trans_basepath_len = length($trans_basepath)+1;
	
	foreach ( @files ) {
		my $trans_ext = '';
		my $trans_type = substr( $_, $trans_basepath_len, index( $_, '/', $trans_basepath_len ) - $trans_basepath_len );
		my $trans_name = lc( substr( $_, rindex( $_, '/')+1 ) );
		my $dot_pos = rindex( $trans_name, '.' );
		$trans_ext = substr ( $trans_name, $dot_pos+1) if $dot_pos != -1;
		$trans_name = substr( $trans_name, 0, $dot_pos) if $dot_pos != -1; 
		$trans_name =~ s/ /_/g;
		LOGDEB "Trans_Name $trans_name: $_";
		$trans_udpin{$trans_name}{filename} = $_;
		$trans_udpin{$trans_name}{extension} = $trans_ext;
		$trans_udpin{$trans_name}{type} = $trans_type;
		$trans_udpin{$trans_name}{is_perl} =  $trans_ext eq 'pl' or $trans_ext eq 'pm' ? 1 : 0;
		my $skills = trans_skills( $trans_udpin{$trans_name}{filename} );
		$trans_udpin{$trans_name}{input} = $skills->{input};
		$trans_udpin{$trans_name}{output} = $skills->{output};
		$trans_udpin{$trans_name}{description} = $skills->{description};
		$trans_udpin{$trans_name}{link} = $skills->{link};
		
	}
	
	# Create Transformers data file
	unlink $transformerdatafile;
	my $transjsonobj = LoxBerry::JSON->new();
	my $transjson = $transjsonobj->open(filename => $transformerdatafile);
	$transjson->{udpin} = \%trans_udpin;
	$transjson->{mqttin} = \%trans_mqttin;
	$transjsonobj->write();
	
}

sub trans_process
{
	
	# Data hash variables
		# command
		# transformer
		# udptopic
		# udpmessage
	
	my $data_arr = $_[0];
	my $data = $data_arr->[0];
	
	my @subresponse;
	my $param;
	
	LOGINF "Calling transformer " . $data->{transformer};
	my $transformer = $data->{transformer};
	my $command = $data->{command};
	
	# Manage INPUT
	#
	if( $trans_udpin{$transformer}{input} eq "text" ) {
		
		# Transformer text input
		$param = quotemeta( $data->{udptopic} ) . '#' . quotemeta( $data->{udpmessage} );
		
	} elsif( $trans_udpin{$transformer}{input} eq "json" ) {
		
		# Transformer json input
		my %datahash = ( $data->{udptopic} => $data->{udpmessage} );
		$param = quotemeta( encode_json( \%datahash ) );
		
	}
	
	# RUN transformer script
	#
	my ($exitcode, $output);
	eval {
		my $execcall = quotemeta($trans_udpin{$transformer}{filename}).' '.$param;
		LOGDEB "Executing: " . $execcall;
		($exitcode, $output) = execute( $execcall );
	};
	
	# Manage OUTPUT
	#
	if( $@ ) {
		LOGERR "Error running transformer: $@";
		LOGERR "Transformers are only supported starting with LoxBerry 2.0";
	}
	elsif( $trans_udpin{$transformer}{output} eq "text" ) {
		
		# Transformer text output
		LOGDEB "Transformer TEXT output:\n".$output;
		my @stdout = split("\n", $output);
		foreach ( @stdout ) {
			my ($topic, $value) = split("#", $_, 2);
			my %data = ( 
				command => $command,
				transformer => $transformer,
				udptopic => $topic,
				udpmessage => $value
			);
			push @subresponse, \%data;
		}
		
	} 
	elsif( $trans_udpin{$transformer}{output} eq "json" ) {
		
		# Transformer json output
		my $jsonout;
		eval {
			$jsonout = decode_json( $output );
			LOGDEB "Transformer JSON output:\n".$output;
			# LOGDEB "Transformer OUTPUT: \n". Data::Dumper::Dumper( $jsonout );
			
			if ( ref($jsonout) eq "ARRAY" ) {
				# LOGDEB "OUTPUT is ARRAY";
				foreach( @$jsonout ) {
					my @keys = keys %$_;
					# LOGDEB "   ". $keys[0] . ":" . $_->{$keys[0]};
					my %data = ( 
						command => $command,
						transformer => $transformer,
						udptopic => $keys[0],
						udpmessage => $_->{$keys[0]} 
					);
					push @subresponse, \%data;
				}
			} else {
				# LOGDEB "OUTPUT is OBJECTLIST";
				foreach( sort keys %$jsonout ) {
					# LOGDEB "   ". $_ . ":" . $jsonout->{$_};
					my %data = ( 
						command => $command,
						transformer => $transformer,
						udptopic => $_,
						udpmessage => $jsonout->{$_}
					);
					push @subresponse, \%data;
				}
			}
		};
	}
	
	return @subresponse;
	
}

sub trans_skills
{
	my ($filename) = @_;
	
	chmod 0774, $filename;
	
	my ($exitcode, $output) = execute( quotemeta($filename). " skills" );
	
	my %subresponse; 
	
	my @stdout = split("\n", $output);
	foreach ( @stdout ) {
		my ($param, $value) = split("=", $_);
		if( $param eq "description" ) {
			$subresponse{description} = trim($value);
			next;
		}
		if( $param eq "link" ) {
			$subresponse{link} = trim($value);
			next;
		}
		if( $param eq "input" ) {
			$subresponse{input} = trim($value);
			next;
		}
		if( $param eq "output" ) {
			$subresponse{output} = trim($value);
			next;
		}
	}
	if( $subresponse{input} ne "json" ) {
		$subresponse{input} = "text";
	}
	if( $subresponse{output} ne "json" ) {
		$subresponse{output} = "text";
	}
	
	return \%subresponse;
}
	


END
{
	if($mqtt) {
		$mqtt->retain($gw_topicbase . "status", "Disconnected");
		$mqtt->disconnect()
	}
	
	eval {
		if( defined $cfg->{Main}{pollms} and $cfg->{Main}{pollms} != $pollms ) {
			# Config file
			$json = LoxBerry::JSON->new();
			$cfg = $json->open(filename => $cfgfile );
			$cfg->{Main}{pollms} = $pollms;
			$json->write();
		}
	};
	
	if($log) {
		LOGEND "MQTT Gateway exited";
	}
}

