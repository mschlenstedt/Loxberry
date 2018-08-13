
use strict;
use LoxBerry::Log;
# use IO::Select;

package LoxBerry::IO;
our $VERSION = "1.2.4.1";
our $DEBUG = 0;

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
	my @params = @_;
	my %response;
	
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
		print STDERR "Param: $params[$pidx] is $params[$pidx+1]\n" if ($DEBUG);
		my ($respcode, $respvalue) = mshttp_call($msnr, "/dev/sps/io/" . $params[$pidx] . "/" . $params[$pidx+1]);
		if($respcode == 200) {
			$response{$params[$pidx]} = 1;
		} else {
			$response{$params[$pidx]} = undef;
		}
	}
	return %response if (@params > 2);
	return $response{$params[0]} if (@params == 2);
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
	
	for (my $pidx = 0; $pidx < @params; $pidx++) {
		print STDERR "Querying param: $params[$pidx]\n" if ($DEBUG);
		my ($respcode, $respvalue) = mshttp_call($msnr, "/dev/sps/io/" . $params[$pidx]); 
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
	require XML::Simple;
		
	my ($msnr, $command) = @_;
	
	my %ms = LoxBerry::System::get_miniservers();
	if (! %ms{$msnr}) {
		print STDERR "No Miniservers configured\n";
		return (601, undef);
	}
	my $mscred = $ms{$msnr}{Credentials};
	my $msip = $ms{$msnr}{IPAddress};
	my $msport = $ms{$msnr}{Port};
		
	my $virtinenc = URI::Escape::uri_escape( $command );
		
	my $url = "http://$mscred\@$msip\:$msport" . $command;
	# $url_nopass = "http://$miniserveradmin:*****\@$miniserverip\:$miniserverport/dev/sps/io/$player_label/$textenc";
	my $ua = LWP::UserAgent->new;
	$ua->timeout(1);
	my $response = $ua->get($url);
	# If the request completely fails
	if ($response->is_error) {
		print STDERR "mshttp_call: http\://$msip\:$msport" . $command . " FAILED - Error " . $response->status_line . "\n" if ($DEBUG);
		return ($response->code, undef);
	}
	my $xmlresp = XML::Simple::XMLin($response->content);
	print STDERR "Loxone Response: Code " . $xmlresp->{Code} . " Value " . $xmlresp->{value} . "\n" if ($DEBUG);
	return ($xmlresp->{Code}, $xmlresp->{value});
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
			$line = $prefix . $params[$pidx] . "=" . $params[$pidx+1] . " ";
			if (length($line) > 220) {
				print STDERR "msudp_send: Line with one parameter is too long. Parameter $params[$pidx] skipped.\n";
				next;
			}
		} else {
			$line = $line . $params[$pidx] . "=" . $params[$pidx+1] . " ";
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

#####################################################
# Finally 1; ########################################
#####################################################
1;
