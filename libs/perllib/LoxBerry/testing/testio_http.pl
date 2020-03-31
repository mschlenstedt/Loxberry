#!/usr/bin/perl

use LoxBerry::IO;
$LoxBerry::IO::DEBUG = 1;
$LoxBerry::System::DEBUG = 1;
$LoxBerry::IO::mem_sendall_sec = 3600;

use Data::Dumper;

# # Create a hash of values
my %par;
$par{'Test_LONG_PARAMETERS1'} = 'Hallo_1';
#$par{'Test_LONG_PARAMETERS2'} = 'Hallo_2';
#$par{'Test_LONG_PARAMETERS3'} = 'Hallo_3';
#$par{'Test_LONG_PARAMETERS4'} = 'Hallo_4';
#$par{'Test_LONG_PARAMETERS5'} = 'Hallo_5';
#$par{'Test_LONG_PARAMETERS6'} = 'Hallo_6';
#$par{'Test_LONG_PARAMETERS7'} = 'Hallo_7';
#$par{'Test_LONG_PARAMETERS8'} = 'Hallo_8';
#$par{'Test_LONG_PARAMETERS9'} = 'Hallo_99';
#$par{'Test_LONG_PARAMETERS10'} = 'Hallo_100';

$LoxBerry::IO::mem_sendall = 1;
$resp = LoxBerry::IO::mshttp_send_mem(4, %par);
if(! $resp) {
	print STDERR "Call FAILED\n";
} else {
	print STDERR "Call successful\n";
}


# my $response = LoxBerry::IO::mshttp_get(1, 'WZ volume');
# print Dumper($response);


# my %response = LoxBerry::IO::mshttp_get(1, 'Test_Any', 'WZ volume', 'Nothing');
# foreach my $resp (keys %response) {
	# print STDERR "$resp value is " . %response{$resp} . "\n";
# }

## Test mshttp_call

# my ($value, $code, $resp) = LoxBerry::IO::mshttp_call(2, '/dev/sps/io/Verbrauch Waschmaschine/all');
# print Dumper($value, $code, $resp);

# print " code: " . $resp->{Code};
# print " value: " . $resp->{value};
# print " output AQ9: " . $resp->{output}->{AQ9}->{value};
