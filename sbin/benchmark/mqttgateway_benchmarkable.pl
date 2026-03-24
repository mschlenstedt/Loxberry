#!/usr/bin/perl

# Script version V3.0.0.4-BENCHMARKABLE
#
# Benchmarkable version of mqttgateway_optimized.pl
# Each of the 7 fixes can be toggled via $ENV{BENCH_*} flags:
#
#   BENCH_EARLY_FILTER   - FIX 1: Early filtering before JSON expansion
#   BENCH_CONN_POOL      - FIX 2: HTTP connection pooling
#   BENCH_MS_CACHE        - FIX 3: Miniserver config cache
#   BENCH_PRECOMPILED_RE  - FIX 4: Precompiled subscription regexes
#   BENCH_OWN_TOPIC_FILTER - FIX 5: Own gateway topic filter
#   BENCH_FLATTEN_SINGLETON - FIX 6: Reuse Hash::Flatten instance
#   BENCH_JSON_XS         - FIX 7: Prefer JSON::XS over JSON::PP
#
# Set flag to 1 to enable the optimization, unset/0 for original behavior.
# Additional instrumentation: HTTP counter, latency logging, benchmark/# subscription.

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
use Fcntl qw(:flock O_RDWR O_CREAT);

# FIX 7: JSON::XS bevorzugen (10-50x schneller als JSON::PP)
# BENCH_JSON_XS: on = use JSON::XS, off = force JSON::PP
BEGIN {
	if ($ENV{BENCH_JSON_XS}) {
		eval {
			require JSON::XS;
			JSON::XS->import('decode_json', 'encode_json');
		};
		if ($@) {
			require JSON;
			JSON->import('decode_json', 'encode_json');
		}
	} else {
		require JSON::PP;
		JSON::PP->import('decode_json', 'encode_json');
	}
}

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

# FIX 4: Vorkompilierte Subscription-Regexes
my @subscriptions_compiled;

# Subscription Filter Expressions
my @subscriptionfilters = ();
# FIX 4: Vorkompilierte Filter-Regexes
my @subscriptionfilters_compiled = ();

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

# FIX 5: Vorkompilierter Regex fuer eigene Gateway-Topics
my $gw_topic_regex;

# Local lookup cache
my $dns_nextupdatetime=0;
my %dns_loopupcache = ();

# Transformer scripts
my %trans_udpin;
my %trans_mqttin;
my $trans_monitor = File::Monitor->new();

# FIX 6: Hash::Flatten einmal instanziieren statt pro Nachricht
my $flatterer = Hash::Flatten->new({
	HashDelimiter => '_', 
	ArrayDelimiter => '_',
	OnRefScalar => 'warn',
	EscapeSequence => '#',
	OnRefGlob => '',
	OnRefScalar  => '',
	OnRefRef => '',
});

# FIX 2+3: Persistenter HTTP UserAgent und Miniserver-Cache
my $http_ua;
my %ms_cache;

# Initialisiere den persistenten UserAgent
sub init_http_ua {
	require LWP::UserAgent;
	$http_ua = LWP::UserAgent->new(
		timeout    => 1,
		keep_alive => 10,    # Connection pooling
	);
	$http_ua->ssl_opts( SSL_verify_mode => 0, verify_hostname => 0 );
}

# FIX 3: Miniserver-Config cachen
sub refresh_ms_cache {
	%ms_cache = LoxBerry::System::get_miniservers();
}

# FIX 3 helper: Return cached or fresh MS config
# BENCH_MS_CACHE: on = use cached %ms_cache, off = call get_miniservers() fresh
sub get_ms_config {
	my ($msnr) = @_;
	if ($ENV{BENCH_MS_CACHE}) {
		return $ms_cache{$msnr};
	} else {
		my %fresh = LoxBerry::System::get_miniservers();
		return $fresh{$msnr};
	}
}

# FIX 2: Schnellerer HTTP-Call mit gepoolter Verbindung
sub mshttp_call_fast {
	require Encode;
	require URI::Escape;

	my ($msnr, $command) = @_;

	my $ms_cfg = get_ms_config($msnr);
	if (! $ms_cfg) {
		print STDERR "Miniserver $msnr not found or configuration not finished\n";
		return (undef, 601, undef);
	}

	# Initialisiere UA falls noetig (sollte nicht passieren)
	init_http_ua() unless $http_ua;

	my $url = $ms_cfg->{FullURI} . $command;
	my $response = $http_ua->get($url);
	
	if ($response->is_error) {
		return (undef, $response->code, undef);
	}
	
	my $resp = Encode::encode_utf8($response->content);
	$resp =~ /value\=\"(.*?)\"/;
	my $value=$1;
	$resp =~ /Code\=\"(.*?)\"/;
	my $code=$1;
	
	return ($value, $code, $resp);
}

# FIX 2: Optimierter HTTP-Versand (ersetzt mshttp_send2 fuer das Gateway)
sub mshttp_send_fast {
	require URI::Escape;
	
	my $msnr = shift;
	
	if (@_ % 2) {
		Carp::croak "mshttp_send_fast: Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	my @params = @_;
	my %response;
	
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
		my ($respvalue, $respcode, $respraw) = mshttp_call_fast($msnr, "/dev/sps/io/" . URI::Escape::uri_escape($params[$pidx]) . "/" . URI::Escape::uri_escape($params[$pidx+1]));
		
		if(defined $respcode and $respcode == 200) {
			$response{$params[$pidx]}{success} = 1;
		}
		$response{$params[$pidx]}{code} = $respcode;
		$response{$params[$pidx]}{value} = $respvalue;
		$response{$params[$pidx]}{raw} = $respraw;
	}
	return \%response;
}

# FIX 2: Optimierter cached HTTP-Versand (ersetzt mshttp_send_mem2)
sub mshttp_send_mem_fast {
	my $msnr = shift;
	
	if (! $msnr) {
		print STDERR "Miniserver must be specified\n";
		return undef;
	}
	
	if (@_ % 2) {
		Carp::croak "mshttp_send_mem_fast: Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	my @params = @_;
	my @newparams;

	require LoxBerry::JSON;

	my $memfile = "/run/shm/mshttp_mem_${msnr}.json";
		
	# Open memory file
	my $memobj = LoxBerry::JSON->new();
	my $memhash = $memobj->open(filename => $memfile, writeonclose => 1);
		
	if(! defined $memhash->{Main}) {
		$memhash->{Main} = ();
	}
	if (! defined $memhash->{Main}->{timestamp}) {
		$memhash->{Main}->{timestamp} = time;
		$LoxBerry::MQTTGateway::IO::mem_sendall = 1;
	}	
	
	my $timestamp = $memhash->{Main}->{timestamp};
	
	if ($timestamp < (time-$LoxBerry::MQTTGateway::IO::mem_sendall_sec)) {
		$LoxBerry::MQTTGateway::IO::mem_sendall = 1;
		$memhash->{Main}->{timestamp} = time;
	}
		
	if (! $memhash->{Main}->{lastMSRebootCheck} or $memhash->{Main}->{lastMSRebootCheck} < (time-300)) {
		$memhash->{Main}->{lastMSRebootCheck} = time;
		my $lasttxp = $memhash->{Main}->{MSTXP};
		# FIX 2: Nutze schnellen HTTP-Call
		my ($newtxp, $code) = mshttp_call_fast($msnr, "/dev/lan/txp");
		if (defined $code and $code eq "200") {
			$memhash->{Main}->{MSTXP} = $newtxp;
			if(defined $lasttxp and $newtxp < $lasttxp) {
				$LoxBerry::MQTTGateway::IO::mem_sendall = 1;
			}
		}
	}

	if ($LoxBerry::MQTTGateway::IO::mem_sendall == 1) {
		for(keys %$memhash) {
			next if ($_ eq 'Main');
			delete $memhash->{$_};
		}
	}

	# Build new delta parameter list
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
		if ($memhash->{$params[$pidx]} ne $params[$pidx+1] or $LoxBerry::MQTTGateway::IO::mem_sendall == 1) {
			push(@newparams, $params[$pidx], $params[$pidx+1]);
			$memhash->{$params[$pidx]} = $params[$pidx+1];
		}	
	}
	
	$LoxBerry::MQTTGateway::IO::mem_sendall = 0;
	
	if (@newparams) {
		return mshttp_send_fast($msnr, @newparams);
	} else {
		return;
	}
}


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

LOGSTART "MQTT Gateway started (OPTIMIZED)";

LOGINF "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.";
LOGINF "If you use UDP Monitor, you have to take actions that changes are pushed.";
LoxBerry::IO::msudp_send(1, 6666, "MQTT", "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.");

my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();

# FIX 2+3: HTTP-Agent und Cache initialisieren
init_http_ua();
refresh_ms_cache();

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
			LOGWARN "No connection to MQTT Server $generaljson->{Mqtt}{Brokerhost} - Check host/port/user/pass and your connection.";
			$health_state{broker}{message} = "No connection to MQTT Server $generaljson->{Mqtt}{Brokerhost} - Check host/port/user/pass and your connection.";
			$health_state{broker}{error} = 1;
			$health_state{broker}{count} += 1;
		} else {
			$health_state{broker}{message} = "Connected and subscribed to MQTT Server";
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
		LOGINF "Executing DNS reverse lookup";
		$udpremhost = gethostbyaddr($ipaddr, AF_INET);
		$udpremhost = inet_ntoa($ipaddr) if (!$udpremhost);
		
		$dns_loopupcache{ $ipaddr } = $udpremhost;
			
		if( (Time::HiRes::time()-$dnsstarttime) > 0.05 ) {
			LOGWARN "DNS reverse lookup took " . sprintf("%.1f", (Time::HiRes::time()-$dnsstarttime)*1000) . " ms";
		}
	}
	
	LOGDEB "UDP IN from $udpremhost: $udpmsg";
	
	## Parse incoming commands
	
	if( $udpmsg eq 'save_relayed_states' ) {
		# LOGDEB "Triggered save_relayed_states by UDP";
		save_relayed_states();
	}
	elsif( $udpmsg eq 'reconnect' ) {
		LOGOK "Triggered reconnect by UDP command";
		$LoxBerry::MQTTGateway::IO::mem_sendall = 1;
		$mqtt_data_received = 0;
		$udp_data_received = 0;
	}
	elsif ($udpmsg =~ /^(\d+);(.+);(.*)$/) {
		# Loxone syslog format: "timestamp;name;value"
		my $timestamp = $1;
		my $name = $2;
		my $value = $3;
		LOGDEB "  Loxone syslog message: $name = $value (ts: $timestamp)";
		
		my $topic = "$udpremhost/$name";
		$mqtt->publish($topic, $value);
	}
	elsif ($udpmsg =~ /^\s*[\{\[]/) {
		# JSON message
		eval {
			my $jsondata = decode_json($udpmsg);
			if (ref($jsondata) eq "HASH") {
				foreach my $key (keys %$jsondata) {
					push @publish_arr, { command => 'publish', udptopic => $key, udpmessage => $jsondata->{$key} };
				}
			}
		};
		if ($@) {
			LOGERR "UDP JSON parse error: $@";
		}
	}
	elsif ($udpmsg =~ /^(publish|retain)\s+(\S+)\s+(\S+)\s+(.*)$/s ) {
		# publish/retain with transformer
		my $command = $1;
		my $transformer_or_topic = $2;
		my $topic_or_data = $3;
		my $rest = $4;
		
		if (exists $trans_udpin{$transformer_or_topic}) {
			# With transformer
			my %data = (
				command => $command,
				transformer => $transformer_or_topic,
				udptopic => $topic_or_data,
				udpmessage => $rest
			);
			my @subresponse = trans_process([\%data]);
			push @publish_arr, @subresponse;
		} else {
			# Without transformer: "publish topic data" or "retain topic data"
			push @publish_arr, { command => $command, udptopic => $transformer_or_topic, udpmessage => "$topic_or_data $rest" };
		}
	}
	elsif ($udpmsg =~ /^(publish|retain)\s+(\S+)\s+(.*)$/s ) {
		push @publish_arr, { command => $1, udptopic => $2, udpmessage => $3 };
	}
	elsif ($udpmsg =~ /^(\S+)\s+(.*)$/s ) {
		# Legacy format: "topic data"
		push @publish_arr, { command => 'publish', udptopic => $1, udpmessage => $2 };
	}
	else {
		if ($udpmsg ne 'save_relayed_states') {
			LOGWARN "UDP IN: Unknown format: $udpmsg";
		}
	}
	
	# Process publish array
	foreach my $pubdata (@publish_arr) {
		if ($pubdata->{command} eq 'retain') {
			$mqtt->retain($pubdata->{udptopic}, $pubdata->{udpmessage});
		} else {
			$mqtt->publish($pubdata->{udptopic}, $pubdata->{udpmessage});
		}
	}
	
	$udpmsg = undef;
}

# Helper: Track overview data for filtered topics
sub _track_overview {
	my ($topic, $topic_underlined, $message) = @_;
	if( is_enabled($cfg->{Main}{use_http}) ) {
		$relayed_topics_http{$topic_underlined}{timestamp} = time;
		$relayed_topics_http{$topic_underlined}{message} = $message;
		$relayed_topics_http{$topic_underlined}{originaltopic} = $topic;
	}
	if( is_enabled($cfg->{Main}{use_udp}) ) {
		$relayed_topics_udp{$topic}{timestamp} = time;
		$relayed_topics_udp{$topic}{message} = $message;
		$relayed_topics_udp{$topic}{originaltopic} = $topic;
	}
}


sub received
{
	
	my ($topic, $message) = @_;
	my $is_json = 1;
	my %sendhash;
	my $contjson;
	
	utf8::encode($topic);
	
	# Remember that we have currently have received data
	$mqtt_data_received = 1;

	# Benchmark instrumentation: latency logging
	bench_log_latency($message);

	# ================================================================
	# FIX 1+5: EARLY FILTERING - vor der teuren JSON-Expansion pruefen
	# ================================================================
	
	# FIX 5: Eigene Gateway-Monitoring-Topics sofort ignorieren
	# BENCH_OWN_TOPIC_FILTER: on = filter own topics early, off = let them pass through
	if ($ENV{BENCH_OWN_TOPIC_FILTER}) {
		if (defined $gw_topic_regex and $topic =~ $gw_topic_regex) {
			LOGDEB "MQTT IN (gw-filtered): $topic: $message";
			my $topic_underlined = $topic;
			$topic_underlined =~ s/[\/%]/_/g;
			_track_overview($topic, $topic_underlined, $message);
			return;
		}
	}
	
	# FIX 1: Fuer Non-JSON-Topics: DoNotForward und Regex-Filter VOR
	# der JSON-Expansion pruefen.
	# BENCH_EARLY_FILTER: on = filter before JSON expansion, off = no early filtering
	my $raw_topic_underlined = $topic;
	$raw_topic_underlined =~ s/[\/%]/_/g;

	if ($ENV{BENCH_EARLY_FILTER}) {
		# Wenn das gesamte Topic auf DoNotForward steht, brauchen wir
		# gar nicht erst JSON-expandieren
		if (exists $cfg->{doNotForward}->{$raw_topic_underlined}) {
			LOGDEB "MQTT IN (dnf-filtered): $topic: $message";
			_track_overview($topic, $raw_topic_underlined, $message);
			return;
		}

		# FIX 1: Regex-Filter auf den raw topic pruefen
		foreach my $filter_re (@subscriptionfilters_compiled) {
			if ($raw_topic_underlined =~ $filter_re) {
				LOGDEB "MQTT IN (regex-filtered): $topic: $message";
				_track_overview($topic, $raw_topic_underlined, $message);
				return;
			}
		}
	}
	
	# ================================================================
	# Ab hier: Standard-Verarbeitung (wie Original, mit kleineren Fixes)
	# ================================================================
	LOGOK "MQTT IN: $topic: $message";
	
	if( is_enabled($cfg->{Main}{expand_json}) ) {
		# Check if message is a json
		eval {
			$contjson = decode_json($message);
		};
		if($@ or !ref($contjson) or ref($contjson) eq "JSON::PP::Boolean" or ref($contjson) eq "JSON::XS::Boolean") {
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
				
				# FIX 6: Wiederverwendung des Hash::Flatten-Objekts
				# BENCH_FLATTEN_SINGLETON: on = reuse singleton, off = new instance per call
				my $flat_hash = $ENV{BENCH_FLATTEN_SINGLETON}
					? $flatterer->flatten($contjson)
					: Hash::Flatten->new({OnRefScalar => 'warn'})->flatten($contjson);
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
				$sendhash{$sendtopic} = "1";
			} elsif ( $sendhash{$sendtopic} ne "" and is_disabled($sendhash{$sendtopic}) ) {
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

		# Skip doNotForward topics (nach JSON-Expansion pro Key)
		if (exists $cfg->{doNotForward}->{$sendtopic_underlined} ) {
			LOGDEB "   $sendtopic (incoming value $sendhash{$sendtopic}) skipped - do not forward enabled";
			if( is_enabled($cfg->{Main}{use_http}) ) {
				$relayed_topics_http{$sendtopic_underlined}{timestamp} = time;
				$relayed_topics_http{$sendtopic_underlined}{message} = $sendhash{$sendtopic};
				$relayed_topics_http{$sendtopic_underlined}{originaltopic} = $sendtopic;
			}
			if( is_enabled($cfg->{Main}{use_udp}) ) {
				$relayed_topics_udp{$sendtopic}{timestamp} = time;
				$relayed_topics_udp{$sendtopic}{message} = $sendhash{$sendtopic};
				$relayed_topics_udp{$sendtopic}{originaltopic} = $sendtopic;
			}
			next;
		}
		
		# Run Subscription Filter Expressions
		# BENCH_PRECOMPILED_RE: on = precompiled qr//, off = compile at runtime
		my $regexcounter = 0;
		my $regexmatch = 0;
		if ($ENV{BENCH_PRECOMPILED_RE}) {
			# FIX 4: Nutze vorkompilierte Regexes
			foreach my $filter_re (@subscriptionfilters_compiled) {
				$regexcounter++;
				if( $sendtopic_underlined =~ $filter_re ) {
					LOGDEB "   $sendtopic (incoming value $sendhash{$sendtopic}) skipped - Subscription Filter line $regexcounter";
					$regexmatch = 1;
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
		} else {
			# Original: compile regex at runtime from @subscriptionfilters
			foreach my $filter_str (@subscriptionfilters) {
				$regexcounter++;
				eval {
					if( $sendtopic_underlined =~ /$filter_str/ ) {
						LOGDEB "   $sendtopic (incoming value $sendhash{$sendtopic}) skipped - Subscription Filter line $regexcounter";
						$regexmatch = 1;
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
					}
				};
				last if $regexmatch;
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
	
	# FIX 4: Subscription-Regex matching
	# BENCH_PRECOMPILED_RE: on = precompiled qr//, off = compile at runtime
	if ($ENV{BENCH_PRECOMPILED_RE}) {
		foreach my $sub_re (@subscriptions_compiled) {
			if( $topic =~ $sub_re ) {
				@toMS = @{$subscriptions_toms[$idx]};
				LOGDEB "$subscriptions[$idx] matches $topic, send to MS " . join(",", @toMS);
				last;
			}
			$idx++;
		}
	} else {
		# Original: compile regex at runtime from @subscriptions
		foreach my $sub (@subscriptions) {
			my $regex = $sub;
			$regex =~ s/\+/[^\/]+/g;
			$regex =~ s/\\//g;
			if( $regex eq '#' ) {
				$regex = ".+";
			} elsif ( substr($regex, -1) eq '#' ) {
				$regex = substr($regex, 0, -2) . '.*';
			}
			my $matched = 0;
			eval {
				if( $topic =~ /$regex/ ) {
					$matched = 1;
				}
			};
			if ($matched) {
				@toMS = @{$subscriptions_toms[$idx]};
				LOGDEB "$sub matches $topic, send to MS " . join(",", @toMS);
				last;
			}
			$idx++;
		}
	}
	
	# toMS: Fallback to default MS if nothing found
	if( ! @toMS ) {
		@toMS = ( $cfg->{Main}->{msno} );
		LOGWARN "Incoming topic does not match any subscribed topic. This might be a bug";
		LOGWARN "Topic: $topic";
	}
	
	# Send via UDP
	if( is_enabled($cfg->{Main}{use_udp}) ) {
		
		foreach my $sendtopic (keys %sendhash) {
			$relayed_topics_udp{$sendtopic}{timestamp} = time;
			$relayed_topics_udp{$sendtopic}{message} = $sendhash{$sendtopic};
			$relayed_topics_udp{$sendtopic}{originaltopic} = $topic;
		}	
		
		my $udpresp;
		
		if( $cfg->{Main}{msno} and $cfg->{Main}{udpport} and $miniservers{$cfg->{Main}{msno}}) {
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
		# Parse topics to replace /% with _
		foreach my $sendtopic (keys %sendhash_cached) {
			my $newtopic = $sendtopic;
			$newtopic =~ s/[\/%]/_/g;
			$sendhash_cached{$newtopic} = delete $sendhash_cached{$sendtopic};
		}
		foreach my $sendtopic (keys %sendhash_noncached) {
			my $newtopic = $sendtopic;
			$newtopic =~ s/[\/%]/_/g;
			$sendhash_noncached{$newtopic} = delete $sendhash_noncached{$sendtopic};
		}
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

		if( $miniservers{$cfg->{Main}{msno}} ) {
			foreach ( @toMS ) {
				my $httpresp;
				# FIX 2: HTTP call sites
				# BENCH_CONN_POOL: on = fast pooled functions, off = original LoxBerry::MQTTGateway::IO
				if ($ENV{BENCH_CONN_POOL}) {
					$httpresp = mshttp_send_fast($_,  %sendhash_noncached);
					validate_http_response( $_, \%sendhash_noncached, $httpresp ) if $httpresp;
					$httpresp = mshttp_send_mem_fast($_,  %sendhash_cached);
					validate_http_response( $_, \%sendhash_cached, $httpresp ) if $httpresp;

					if ( scalar keys %sendhash_resetaftersend > 0 ) {
						LOGDEB "  HTTP: Sending reset-after-send values (delay ".$cfg->{Main}{resetaftersendms}." ms)";
						Time::HiRes::sleep($cfg->{Main}{resetaftersendms}/1000);
						$httpresp = mshttp_send_fast($_, %sendhash_resetaftersend);
					}
				} else {
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

				# Instrumentation: increment HTTP counter
				bench_increment_http_counter();
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
		
		$monitor->watch( $generaljsonfile );
		$monitor->watch( $cfgfile );
		
		$monitor->watch( "$lbstmpfslogdir/plugins_state.json", sub {
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
	
	if(!defined $cfg or @changes) {
		$configs_changed = 1;
		my @changed_files;
		for my $change ( @changes ) {
			push @changed_files, $change->name;
		}
		LOGINF "Changed configuration files: " .  join(',', @changed_files) if (@changed_files);
	}
	
	if($configs_changed == 0) {
		return;
	}
	
	LOGOK "Reading config changes";
	
	# Own topic
	$gw_topicbase = lbhostname() . "/mqttgateway/";
	LOGOK "MQTT Gateway topic base is $gw_topicbase";
	
	# FIX 5: Regex fuer eigene Topics kompilieren
	my $gw_escaped = quotemeta($gw_topicbase);
	$gw_topic_regex = qr/^${gw_escaped}(?:pollms|pollcpucurpct|pollcpumaxpct|pollpidvalpct|pollproccnt|keepaliveepoch|status)/;
	
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
		if(! defined $generaljson->{Mqtt}{Brokerhost}) { $generaljson->{Mqtt}{Brokerhost} = 'localhost'; }
		if(! defined $generaljson->{Mqtt}{Brokerport}) { $generaljson->{Mqtt}{Brokerport} = '1883'; }
		if(! defined $generaljson->{Mqtt}{Udpinport}) { $generaljson->{Mqtt}{Udpinport} = 11884; }
		
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
		
		# FIX 3: Miniserver-Cache aktualisieren bei Config-Reload
		%miniservers = LoxBerry::System::get_miniservers();
		refresh_ms_cache();
		
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
		LOGINF "Connecting MQTT Server ". $generaljson->{Mqtt}{Brokerhost}.":".$generaljson->{Mqtt}{Brokerport};
		eval {
			
			$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
			
			$mqtt = Net::MQTT::Simple->new($generaljson->{Mqtt}{Brokerhost}.":".$generaljson->{Mqtt}{Brokerport});
			
			if($generaljson->{Mqtt}{Brokeruser} or $generaljson->{Mqtt}{Brokerpass}) {
				LOGINF "Login at MQTT Server";
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
			
			# Add external plugin subscriptions
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

			# Benchmark: subscribe to benchmark topics for load generator
			push @subscriptions, "benchmark/#";
			
			# Ordering by topic level
			LOGINF "Ordering subscriptions by topic level";
			@subscriptions = sort { ($b=~tr/\///) <=> ($a=~tr/\///) } @subscriptions;
			
			# FIX 4: Subscription-Regexes vorkompilieren
			LOGINF "Pre-compiling subscription regexes";
			@subscriptions_compiled = ();
			foreach my $sub (@subscriptions) {
				my $regex = $sub;
				# + -> [^/]+
				$regex =~ s/\+/[^\/]+/g;
				# Unescape
				$regex =~ s/\\//g;
				# # handling
				if( $regex eq '#' ) {
					$regex = ".+";
				} elsif ( substr($regex, -1) eq '#' ) {
					$regex = substr($regex, 0, -2) . '.*';
				}
				push @subscriptions_compiled, qr/$regex/;
			}
			LOGOK "Pre-compiled " . scalar(@subscriptions_compiled) . " subscription regexes";
			
			LOGINF "Reading your config about what topics to send to what Miniserver";
			my @default_arr = ( $cfg->{Main}->{msno} );
			@subscriptions_toms = ();
			
			foreach my $sub ( @subscriptions ) {
				my $sub_set;
				foreach my $cfg_sub ( @{$cfg->{subscriptions}} ) {
					if( $sub eq $cfg_sub->{id} ) {
						if( scalar @{$cfg_sub->{toMS}} > 0 ) {
							push @subscriptions_toms, $cfg_sub->{toMS};
						} else {
							push @subscriptions_toms, \@default_arr;
						}
						$sub_set = 1;
						last;
					}
				}
				if( ! $sub_set ) {
					push @subscriptions_toms, \@default_arr;
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
		if ( join('', @{$cfg->{subscriptionfilters}}) ne join('', @subscriptionfilters) ) {
			
			@subscriptionfilters = ();
			# FIX 4: Filter-Regexes vorkompilieren
			@subscriptionfilters_compiled = ();
			
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
					push( @subscriptionfilters_compiled, $regex );
				}	
			}
			LOGOK "Pre-compiled " . scalar(@subscriptionfilters_compiled) . " filter regexes";
			
			# Apply filters to current data
			LOGINF "Subscription Expression Filters are applied to current data";
			foreach my $topic ( %relayed_topics_http ) {
				my $regexcounter = 0;
				my $regexmatch;
				foreach my $filter_re (@subscriptionfilters_compiled) {
					$regexcounter++;
					if( $topic =~ $filter_re ) {
						$regexmatch = 1;
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
			foreach my $topic ( %relayed_topics_udp ) {
				my $filtertopic = $topic;
				$filtertopic =~ tr/\//_/;
				my $regexcounter = 0;
				my $regexmatch;
				foreach my $filter_re (@subscriptionfilters_compiled) {
					$regexcounter++;
					if( $filtertopic =~ $filter_re ) {
						$regexmatch = 1;
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
		
		LOGINF "Adding plugin conversions";
		foreach my $pluginname ( keys %plugindirs ) {
			if( $plugindirs{$pluginname}{conversions} ) {
				push @temp_conversions_list, @{$plugindirs{$pluginname}{conversions}};
			}
		}
		
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
		LOGINF "Processing Reset After Send";
		undef %resetAfterSend;
		if (exists $cfg->{resetAfterSend} and ref($cfg->{resetAfterSend}) eq "HASH" ) {
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
	LOGDEB "Creating udp-in socket";
	$udpinsock = IO::Socket::INET->new(
		LocalPort => $generaljson->{Mqtt}{Udpinport}, 
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
			foreach( keys %{$relayed_topics_http{$sendtopic}{toMS}} ) {
				my $code = $relayed_topics_http{$sendtopic}{toMS}{$_}{code};
				$health_state{stats}{httpresp}{$code}++;
			}
		}
	}
	else {
		undef %relayed_topics_http;
	}
		
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
	
	unlink $transformerdatafile;
	my $transjsonobj = LoxBerry::JSON->new();
	my $transjson = $transjsonobj->open(filename => $transformerdatafile);
	$transjson->{udpin} = \%trans_udpin;
	$transjson->{mqttin} = \%trans_mqttin;
	$transjsonobj->write();
}

sub trans_process
{
	my $data_arr = $_[0];
	my $data = $data_arr->[0];
	
	my @subresponse;
	my $param;
	
	LOGINF "Calling transformer " . $data->{transformer};
	my $transformer = $data->{transformer};
	my $command = $data->{command};
	
	if( $trans_udpin{$transformer}{input} eq "text" ) {
		$param = quotemeta( $data->{udptopic} ) . '#' . quotemeta( $data->{udpmessage} );
	} elsif( $trans_udpin{$transformer}{input} eq "json" ) {
		my %datahash = ( $data->{udptopic} => $data->{udpmessage} );
		$param = quotemeta( encode_json( \%datahash ) );
	}
	
	my ($exitcode, $output);
	eval {
		my $execcall = quotemeta($trans_udpin{$transformer}{filename}).' '.$param;
		LOGDEB "Executing: " . $execcall;
		($exitcode, $output) = execute( $execcall );
	};
	
	if( $@ ) {
		LOGERR "Error running transformer: $@";
		LOGERR "Transformers are only supported starting with LoxBerry 2.0";
	}
	elsif( $trans_udpin{$transformer}{output} eq "text" ) {
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
		my $jsonout;
		eval {
			$jsonout = decode_json( $output );
			LOGDEB "Transformer JSON output:\n".$output;
			
			if ( ref($jsonout) eq "ARRAY" ) {
				foreach( @$jsonout ) {
					my @keys = keys %$_;
					my %data = ( 
						command => $command,
						transformer => $transformer,
						udptopic => $keys[0],
						udpmessage => $_->{$keys[0]} 
					);
					push @subresponse, \%data;
				}
			} else {
				foreach( sort keys %$jsonout ) {
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
	


# ================================================================
# Benchmark Instrumentation
# ================================================================

# Atomic increment of HTTP call counter
sub bench_increment_http_counter {
	my $counter_file = '/dev/shm/bench_http_counter';
	sysopen(my $fh, $counter_file, O_RDWR | O_CREAT) or return;
	flock($fh, LOCK_EX) or do { close $fh; return };
	my $count = <$fh> || 0;
	chomp $count;
	$count++;
	seek($fh, 0, 0);
	truncate($fh, 0);
	print $fh "$count\n";
	flock($fh, LOCK_UN);
	close $fh;
}

# Latency logging: if payload contains _bench_ts, log timing
sub bench_log_latency {
	my ($message) = @_;
	return unless defined $message;
	if ($message =~ /_bench_ts["\s:=]+(\d+\.?\d*)/) {
		my $bench_ts = $1;
		my $now = Time::HiRes::time();
		my $logfile = '/dev/shm/bench_latency.log';
		if (open(my $fh, '>>', $logfile)) {
			flock($fh, LOCK_EX);
			print $fh "$bench_ts,$now\n";
			flock($fh, LOCK_UN);
			close $fh;
		}
	}
}

END
{
	if($mqtt) {
		$mqtt->retain($gw_topicbase . "status", "Disconnected");
		$mqtt->disconnect()
	}
	
	eval {
		if( defined $cfg->{Main}{pollms} and $cfg->{Main}{pollms} != $pollms ) {
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
