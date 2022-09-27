
use strict;
use LoxBerry::Log;
use LoxBerry::IO;

# use IO::Select;

package LoxBerry::MQTTGateway::IO;
our $VERSION = "1.2.0.1";
our $DEBUG = 0;
our $mem_sendall = 0;
our $mem_sendall_sec = 3600;
our $udp_delimiter = "=";

my %udpsocket;

#####################################################
# mshttp_send
# https://wiki.loxberry.de/entwickler/perl_develop_plugins_with_perl/perl_loxberry_sdk_dokumentation/perlmodul_loxberryio/loxberryiomshttp_send
# THIS IS THE MQTT GATEWAY VARIANT
#####################################################

sub mshttp_send2
{
	# print STDERR "mqtt_mshttp_send2\n";
	my $msnr = shift;
	
	if (@_ % 2) {
		Carp::croak "mshttp_send: Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	require URI::Escape;
	
	my @params = @_;
	my %response;
	
	for (my $pidx = 0; $pidx < @params; $pidx+=2) {
		print STDERR "Param: $params[$pidx] is $params[$pidx+1]\n" if ($DEBUG);
		my ($respvalue, $respcode, $respraw) = LoxBerry::IO::mshttp_call($msnr, "/dev/sps/io/" . URI::Escape::uri_escape($params[$pidx]) . "/" . URI::Escape::uri_escape($params[$pidx+1]));
		print STDERR "respvalue: $respvalue | respcode: $respcode\n" if ($DEBUG);
		
		if($respcode == 200) {
			$response{$params[$pidx]}{success} = 1;
		}
		$response{$params[$pidx]}{code} = $respcode;
		$response{$params[$pidx]}{value} = $respvalue;
		$response{$params[$pidx]}{raw} = $respraw;
		
	}
	return \%response;
}

sub mshttp_send_mem2
{
	# print STDERR "mqtt_mshttp_send_mem2\n";
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
		my ($newtxp, $code) = LoxBerry::IO::mshttp_call($msnr, "/dev/lan/txp");
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
		return LoxBerry::MQTTGateway::IO::mshttp_send2($msnr, @newparams);
	} else {
		return;
	}
}

#####################################################
# Finally 1; ########################################
#####################################################
1;
