#!/usr/bin/perl

use LoxBerry::IO;
$LoxBerry::IO::DEBUG = 1;

# # Create a hash of values
my %par;
$par{'Test_LONG_PARAMETERS1'} = 'Hallo_1';
$par{'Test_LONG_PARAMETERS2'} = 'Hallo_2';
$par{'Test_LONG_PARAMETERS3'} = 'Hallo_3';
$par{'Test_LONG_PARAMETERS4'} = 'Hallo_4';
$par{'Test_LONG_PARAMETERS5'} = 'Hallo_5';
$par{'Test_LONG_PARAMETERS6'} = 'Hallo_6';
$par{'Test_LONG_PARAMETERS7'} = 'Hallo_7';
$par{'Test_LONG_PARAMETERS8'} = 'Hallo_8';
$par{'Test_LONG_PARAMETERS9'} = 'Hallo_9';
$par{'Test_LONG_PARAMETERS10'} = 'Hallo_10';


# $resp = LoxBerry::IO::mshttp_send(1, %par);
# if(! $resp) {
	# print STDERR "Call FAILED\n";
# } else {
	# print STDERR "Call successful\n";
# }

# my %response = LoxBerry::IO::mshttp_get(1, 'Test_Any', 'WZ volume');
# # print STDERR "Query returned $resp\n";
# foreach my $resp (keys %response) {
	# print STDERR "$resp value is " . %response{$resp} . "\n";

# }

## Test UDP
LoxBerry::IO::msudp_send(1, 10000, undef, %par);
