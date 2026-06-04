#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Version of this script
$version = "0.0.2";

##########################################################################
#
# Modules
#
##########################################################################

require LWP::UserAgent;
use CGI::Carp qw(fatalsToBrowser);
use Socket;
use IO::Socket;

##########################################################################
#
# Main
#
##########################################################################

sub scanoverssdp {
# Scan MiniServers over ssdp

my $IP             = "239.255.255.250";
my $PORT           = 1900;
my $TIMEOUT        = 3;
 
my $request_header = <<"__REQUEST_HEADER__";
M-SEARCH * HTTP/1.1
Host:$IP:$PORT
Man:"ssdp:discover"
ST: urn:schemas-upnp-org:device:HVAC_System:1
MX:3
 
__REQUEST_HEADER__
  
$request_header =~ s/\r//g;
$request_header =~ s/\n/\r\n/g;
 
my $proto = getprotobyname('udp');
socket(S, AF_INET, SOCK_DGRAM, $proto) || die "socket(S): $!\n";
setsockopt(S, SOL_SOCKET, SO_BROADCAST, 1) || die "setsockopt(S): $!\n";
my $that = sockaddr_in($PORT, inet_aton($IP));
 
send(S, $request_header, 0, $that) || die "send(S): $!\n";
 
my $rin = '';
my $rout = '';
my $miniserverip = '';
my $miniserverport = '';
my $miniservname = '';
vec($rin, fileno(S), 1) = 1;
while( select($rout = $rin, undef, undef, $TIMEOUT) ) {
    recv(S, $response_header, 4096, 0) || die "recv(S): $!\n";
    if ($response_header =~ /Loxone/) {
    	($miniserverip) = $response_header =~ m/http:\/\/(.*)\//;
    	($miniserverport) = $miniserverip =~ m/:([0-9]{1,5})/;
    	if ($miniserverport == "") { $miniserverport = 80; }
    	($miniserverip) =~ s/:[0-9]{1,5}//;
    	($miniservername) = $response_header =~ m/Miniserver (.*) UPnP/;
    }
}
 
close(S);


# Print last found ip address
print "Content-type: text/html; charset=iso-8859-15\n\n";
print "{\"Name\" : \"$miniservername\",\n\"IP\" : \"$miniserverip\",\n\"Port\" : \"$miniserverport\"}\n";

}

sub scanoverudpbc {

$ssock = IO::Socket::INET->new(PeerPort => 7070, PeerAddr => "255.255.255.255", Broadcast => 1, Proto => 'udp') or die "send socket: $!";

$ssock->send("\x00");
$lsock = IO::Socket::INET->new(LocalPort => 7071, Proto => 'udp', Broadcast => 1, Reuse => 1) or die "socket: $@";
$lsock->autoflush;

$lsock->recv($resp, 4096);

my ($MSName, $IP, $Port, $IPv6) = ($resp =~ m/LoxLIVE: (.*) ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}):([0-9]{1,5}).*IPv6:([:0-9a-fA-F]*),/);

print "Content-type: text/html; charset=iso-8859-15\n\n";
print "{\"Name\" : \"$MSName\",\n\"IP\" : \"$IP\",\n\"Port\" : \"$Port\",\n\"IPv6\" : \"$IPv6\"}\n";

}

#scanoverssdp();
scanoverudpbc();
exit;
