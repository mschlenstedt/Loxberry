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


# Test UDP with cache
# $LoxBerry::IO::mem_sendall = 1;
# LoxBerry::IO::msudp_send_mem(4, 10000, "Test", %par);

# Test UDP without cache
my $msnr = 4;
my $port = 10000;
$LoxBerry::IO::mem_sendall = 1;
LoxBerry::IO::msudp_send($msnr, $port, "Test", %par);

my %ms = LoxBerry::System::get_miniservers();
print "\nMiniserver $ms{$msnr}{Name} ($msnr)\n";
print "IP: $ms{$msnr}{IPAddress} PORT: $port\n";