
use strict;
use Config::Simple;
use LoxBerry::Log;

# use IO::Select;

use base 'Exporter';

our @EXPORT = qw (
	mshttp_send
	mshttp_send_mem
	mshttp_get
	mshttp_call
	msudp_send
	msudp_send_mem
);



package LoxBerry::IO;
our $VERSION = "2.0.0.1";
our $DEBUG = 0;
our $mem_sendall = 0;
our $mem_sendall_sec = 3600;
our $udp_delimiter = "=";

my %udpsocket;

#################################################################################
# Create Out Socket
# Params: $socket, $port, $proto (tcp, udp), $remotehost
# Returns: $socket
#################################################################################

sub create_out_socket 
{
	
	require IO::Socket;
	require IO::Socket::IP;
	require IO::Socket::Timeout;


	
	my ($socket, $port, $proto, $remotehost) = @_;
	
	my %params = (
		PeerHost  => $remotehost,
		PeerPort  => $port,
		Proto     => $proto,
		Blocking  => 0
	);
	
	if ($proto eq 'tcp') {
		$params{'Type'} = SOCK_STREAM();
	} elsif ($proto eq 'udp') {
		# $params{'LocalAddr'} = 'localhost';
	}
	# if($socket) {
		# close($socket);
	# }
		
	$socket = IO::Socket::IP->new( %params );
	if(! $socket) {
		print STDERR "Couldn't connect to $remotehost:$port : $@\n";
		return undef;
	}
	# sleep (3);
	# if ($socket->connected) {
		# LOGOK "Created $proto out socket to $remotehost on port $port";
	# } else {
		# LOGWARN "WARNING: Socket to $remotehost on port $port seems to be offline - will retry";
	# }
	print STDERR "Setting timeouts for socket to $remotehost:$port\n";
	IO::Socket::Timeout->enable_timeouts_on($socket);
	$socket->read_timeout(2);
	$socket->write_timeout(2);
	return $socket;
}

#################################################################################
# Create In Socket
# Params: $socket, $port, $proto (tcp, udp)
# Returns: $socket
#################################################################################

sub create_in_socket 
{

	require IO::Socket;
	
	my ($socket, $port, $proto) = @_;
	
	my %params = (
		LocalHost  => '0.0.0.0',
		LocalPort  => $port,
		Type       => SOCK_STREAM(),
		Proto      => $proto,
		Listen     => 5,
		Reuse      => 1,
		Blocking   => 0
	);
	$socket = new IO::Socket::INET ( %params );
	if (! $socket) {
		LOGERR("Could not create $proto socket for port $port: $!");
		return undef;
	}
	# In some OS blocking mode must be expricitely disabled
	IO::Handle::blocking($socket, 0);
	LOGOK("server waiting for $proto client connection on port $port");
	return $socket;
}

#####################################################
# mshttp_send
# https://www.loxwiki.eu/x/RAE_Ag
#####################################################

sub mshttp_send
{
	my $msnr = shift;
	
	if (@_ % 2) {
		Carp::croak "mshttp_send: Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	require URI::Escape;
	
	my @params = @_;
	my %response;
	
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
		print STDERR "Param: $params[$pidx] is $params[$pidx+1]\n" if ($DEBUG);
		my ($respvalue, $respcode) = mshttp_call($msnr, "/dev/sps/io/" . URI::Escape::uri_escape($params[$pidx]) . "/" . URI::Escape::uri_escape($params[$pidx+1]));
		print STDERR "respvalue: $respvalue | respcode: $respcode\n" if ($DEBUG);
		if($respcode == 200) {
			$response{$params[$pidx]} = 1;
		} else {
			$response{$params[$pidx]} = undef;
		}
	}
	return %response if (@params > 2);
	return $response{$params[0]} if (@params == 2);
}

sub mshttp_send_mem
{
	my $msnr = shift;
	
	if (! $msnr) {
		print STDERR "Miniserver must be specified\n";
		return undef;
	}
	
	if (@_ % 2) {
		Carp::croak "mshttp_send: Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	my @params = @_;
	my @newparams;
	my %response;

	require LoxBerry::JSON;

	my $memfile = "/run/shm/mshttp_mem_${msnr}.json";
	print STDERR "mshttp_send_mem: Memory file is $memfile\n" if ($DEBUG);
		
	# Open memory file
	my $memobj = LoxBerry::JSON->new();
	my $memhash = $memobj->open(filename => $memfile, writeonclose => 1);
		
	if(! defined $memhash->{Main}) {
		$memhash->{Main} = ();
	}
	if (! defined $memhash->{Main}->{timestamp}) {
		# print STDERR "Setting timestamp\n";
		$memhash->{Main}->{timestamp} = time;
		$mem_sendall = 1;
	}	
	
	my $timestamp = $memhash->{Main}->{timestamp};
	
	# Check if this call should be set to mem_sendall
	if ($timestamp < (time-$mem_sendall_sec)) {
		$mem_sendall = 1;
		$memhash->{Main}->{timestamp} = time;
	}
		
	if (! $memhash->{Main}->{lastMSRebootCheck} or $memhash->{Main}->{lastMSRebootCheck} < (time-300)) {
		# Try to check if MS was restarted (in only possible with MS Admin)
		$memhash->{Main}->{lastMSRebootCheck} = time;
		my $lasttxp = $memhash->{Main}->{MSTXP};
		my ($newtxp, $code) = mshttp_call($msnr, "/dev/lan/txp");
		if ($code eq "200") {
			print STDERR "Setting newtxp $newtxp\n" if($DEBUG);
			$memhash->{Main}->{MSTXP} = $newtxp;
			if($newtxp < $lasttxp) {
				print STDERR "Miniserver may have been rebooted. Flagging to clear cache.\n" if($DEBUG);
				$mem_sendall = 1;
			}
		}
	}

	if ($mem_sendall == 1) {
		print STDERR "Clearing cache (mem_sendall is set)\n" if($DEBUG);
		for(keys %$memhash) {
			next if ($_ eq 'Main');
			delete $memhash->{$_};
		}
	}

	# Build new delta parameter list
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
			
		if ($memhash->{$params[$pidx]} ne $params[$pidx+1] or $mem_sendall == 1) {
			push(@newparams, $params[$pidx], $params[$pidx+1]);
			$memhash->{$params[$pidx]} = $params[$pidx+1];
		}	
	}
	
	$mem_sendall = 0;
	
	if (@newparams) {
		return mshttp_send($msnr, @newparams);
	} else {
		return 1;
	}
}

#####################################################
# mshttp_get
# https://www.loxwiki.eu/x/UwE_Ag
#####################################################
sub mshttp_get
{
	my $msnr = shift;
	
	my @params = @_;
	my %response;
	
	require URI::Escape;
	
	for (my $pidx = 0; $pidx < @params; $pidx++) {
		print STDERR "Querying param: $params[$pidx]\n" if ($DEBUG);
		my ($respvalue, $respcode) = mshttp_call($msnr, "/dev/sps/io/" . URI::Escape::uri_escape($params[$pidx])); 
		if($respcode == 200) {
			$response{$params[$pidx]} = $respvalue;
		} else {
			$response{$params[$pidx]} = undef;
		}
	}
	return %response if (@params > 1);
	return $response{$params[0]} if (@params == 1);
}

#####################################################
# Miniserver REST Call
# Param 1: Miniserver number
# Param 2: Full URL without hostname (e.g. '/dev/sps/io/...'
#####################################################
sub mshttp_call
{
	require LWP::UserAgent;
	# require XML::Simple;
	require Encode;
	
		
	my ($msnr, $command) = @_;
	
	my %ms = LoxBerry::System::get_miniservers();
	if (! %ms{$msnr}) {
		print STDERR "No Miniservers configured\n";
		return (undef, 601, undef);
	}
	my $mscred = $ms{$msnr}{Credentials};
	my $msip = $ms{$msnr}{IPAddress};
	my $msport = $ms{$msnr}{Port};
		
	#my $virtinenc = URI::Escape::uri_escape( $command );
		
	my $url = "http://$mscred\@$msip\:$msport" . $command;
	# $url_nopass = "http://$miniserveradmin:*****\@$miniserverip\:$miniserverport/dev/sps/io/$player_label/$textenc";
	my $ua = LWP::UserAgent->new;
	$ua->timeout(1);
	my $response = $ua->get($url);
	# If the request completely fails
	if ($response->is_error) {
		print STDERR "mshttp_call: http\://$msip\:$msport" . $command . " FAILED - Error " . $response->status_line . "\n" if ($DEBUG);
		return (undef, $response->code, undef);
	}
	#require Data::Dumper;
	# print STDERR Data::Dumper::Dumper ($response);
	
	my $xmlresp = Encode::encode_utf8($response->content);
		
	$xmlresp =~ /value\=\"(.*?)\"/;
	my $value=$1;
	$xmlresp =~ /Code\=\"(.*?)\"/;
	my $code=$1;
	
	print STDERR "mshttp_call: Response Code $code Value $value Full: $xmlresp\n" if($DEBUG);
	
	return ($value,  $code, $xmlresp);
	
}


#####################################################
# msudp_send
# https://www.loxwiki.eu/x/RgE_Ag
#####################################################

sub msudp_send
{
	my $msnr = shift;
	my $udpport = shift;
	my $prefix = shift;
	my @params = @_;
	
	my %ms = LoxBerry::System::get_miniservers();
	if (! $udpport or $udpport > 65535) {
		print STDERR "UDP port $udpport invalid or not defined\n";
		return undef;
	}
	if (! %ms{$msnr}) {
		print STDERR "Miniserver $msnr not defined\n";
		return undef;
	}
	if ($prefix) {
		$prefix = "$prefix: ";
	}
	
	if (@params > 1 and @params % 2) {
		Carp::croak "msudp_send: Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	if (! $udpsocket{$msnr}{$udpport}) {
		# Open UDP socket
		$udpsocket{$msnr}{$udpport} = create_out_socket($udpsocket{$msnr}{$udpport}, $udpport, 'udp', $ms{$msnr}{'IPAddress'});
		if (! $udpsocket{$msnr}{$udpport}) {
			return undef;
		}
	}
	
	my $line;
	my $parinline = 0;
	
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
		$parinline++;
		my $oldline = $line;
		if ($parinline == 1) {
			$line = $prefix . $params[$pidx] . $LoxBerry::IO::udp_delimiter . $params[$pidx+1] . " ";
			if (length($line) > 220) {
				print STDERR "msudp_send: Line with one parameter is too long. Parameter $params[$pidx] skipped.\n";
				next;
			}
		} else {
			$line = $line . $params[$pidx] . $LoxBerry::IO::udp_delimiter . $params[$pidx+1] . " ";
		}
		if (length($line) > 220) {
			print STDERR "msudp_send: Sending: $oldline\n" if ($DEBUG);
			$udpsocket{$msnr}{$udpport}->send($oldline);
			$parinline = 0;
			$line = "";
			redo;
		}
		
	}
	
	if($line ne "") {
		print STDERR "msudp_send: Sending: $line\n" if ($DEBUG);
		$udpsocket{$msnr}{$udpport}->send($line);
	}
	return 1;
}

sub msudp_send_mem
{
	my $msnr = shift;
	my $udpport = shift;
	my $prefix = shift;
	my @params = @_;
	my @newparams;
	
	require LoxBerry::JSON;
		
	my $memfile = "/run/shm/msudp_mem_${msnr}_${udpport}.json";
	print STDERR "msudp_send_mem: Memory file is $memfile\n" if ($DEBUG);
	
	if (! $udpport or $udpport > 65535) {
		print STDERR "UDP port $udpport invalid or not defined\n";
		return undef;
	}
	if (! $msnr) {
		print STDERR "Miniserver must be specified\n";
		return undef;
	}
	
	# Open memory file
	my $memobj = LoxBerry::JSON->new();
	my $memhash = $memobj->open(filename => $memfile, writeonclose => 1);
	
	
	# Section is defined by the prefix
	my $prefixsection;
	if(!$prefix) {
		$prefixsection = "Params";
	} else {
		$prefixsection = $prefix;
	}

	if(! defined $memhash->{Main}) {
		$memhash->{Main} = ();
	}
	if (! defined $memhash->{Main}->{timestamp}) {
		# print STDERR "Setting timestamp\n";
		$memhash->{Main}->{timestamp} = time;
		$mem_sendall = 1;
	}
	
	my $timestamp = $memhash->{Main}->{timestamp};
	
	# Check if this call should be set to mem_sendall
	if ($timestamp < (time-$mem_sendall_sec)) {
		$mem_sendall = 1;
		$memhash->{Main}->{timestamp} = time;
	}
	
	if (! $memhash->{Main}->{lastMSRebootCheck} or $memhash->{Main}->{lastMSRebootCheck} < (time-300)) {
		# Try to check if MS was restarted (in only possible with MS Admin)
		$memhash->{Main}->{lastMSRebootCheck} = time;
		my $lasttxp = $memhash->{Main}->{MSTXP};
		my ($newtxp, $code) = mshttp_call($msnr, "/dev/lan/txp");
		if ($code eq "200") {
			print STDERR "Setting newtxp $newtxp\n" if($DEBUG);
			$memhash->{Main}->{MSTXP} = $newtxp;
			if($newtxp < $lasttxp) {
				print STDERR "Miniserver may have been rebooted. Flagging to clear cache.\n" if($DEBUG);
				$mem_sendall = 1;
			}
		}
	}

	if ($mem_sendall == 1) {
		print STDERR "Clearing cache (mem_sendall is set)\n" if($DEBUG);
		for(keys %$memhash) {
			next if ($_ eq 'Main');
			delete $memhash->{$_};
		}
	}
	
	# Build new delta parameter list
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
			
		if ($memhash->{$prefixsection}->{$params[$pidx]} ne $params[$pidx+1] or $mem_sendall == 1) {
			push(@newparams, $params[$pidx], $params[$pidx+1]);
			$memhash->{$prefixsection}->{$params[$pidx]} = $params[$pidx+1];
		}	
	}
	
	$mem_sendall = 0;
	
	if (@newparams) {
		return msudp_send($msnr, $udpport, $prefix, @newparams);
	} else {
		return 1;
	}
}

##################################################################################
# MQTT functions                                                                 #
##################################################################################


# Read MQTT connection details and credentials from MQTT plugin
sub mqtt_connectiondetails {

	# Check if MQTT Gateway plugin is installed
	my $mqttplugindata = LoxBerry::System::plugindata("mqttgateway");
	my $pluginfolder = $mqttplugindata->{PLUGINDB_FOLDER};
	return undef if(!$pluginfolder);

	my $mqttconf;
    my $mqttcred;
	
	require JSON;
	
	eval {	
		# Read connection details
		$mqttconf = JSON::decode_json(LoxBerry::System::read_file($LoxBerry::System::lbhomedir . "/config/plugins/" . $pluginfolder . "/mqtt.json" ));
		$mqttcred = JSON::decode_json(LoxBerry::System::read_file($LoxBerry::System::lbhomedir . "/config/plugins/" . $pluginfolder . "/cred.json" ));
	};
	if ($@) {
		print STDERR "LoxBerry::MQTT::connectiondetails: Failed to read/parse connection details: $@\n";
		return undef;
	}
	
	my %cred;
	
	my ($brokerhost, $brokerport) = split(':', $mqttconf->{Main}->{brokeraddress}, 2);
	$brokerport = $brokerport ? $brokerport : 1883;
	$cred{brokeraddress} = $brokerhost.":".$brokerport;
	$cred{brokerhost} = $brokerhost;
	$cred{brokerport} = $brokerport;
	$cred{brokeruser} = $mqttcred->{Credentials}->{brokeruser};
	$cred{brokerpass} = $mqttcred->{Credentials}->{brokerpass};
	$cred{udpinport} = $mqttconf->{Main}->{udpinport};

	return \%cred;

}

#####################################################
# Finally 1; ########################################
#####################################################
1;
