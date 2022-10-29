#!/usr/bin/perl

use LoxBerry::IO;
$LoxBerry::IO::DEBUG = 1;
$LoxBerry::System::DEBUG = 1;
$LoxBerry::IO::mem_sendall_sec = 3600;

my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();

if (! %miniservers) {
    print "No Miniservers defined in LoxBerry\n";
	exit(1); 
}

print "Number of defined Miniservers: " . keys(%miniservers). "\n\n";

foreach my $ms (sort keys %miniservers) {
    print "===== Miniserver $ms: $miniservers{$ms}{Name} =====\n";
	print "Miniserver User  : $miniservers{$ms}{Admin}\n";
	print "Transport        : $miniservers{$ms}{Transport}\n";
	print "IP address       : $miniservers{$ms}{IPAddress}\n";
	print "http port        : $miniservers{$ms}{Port}\n";
	print "https port       : $miniservers{$ms}{PortHttps}\n";
	print "Prefer https     : $miniservers{$ms}{PreferHttps}\n";
	print "\n";
	print "Use Cloud DNS    : $miniservers{$ms}{UseCloudDNS}\n";
	print "Cloud MAC address: $miniservers{$ms}{CloudURL}\n";
	print "\n";

	my (undef, undef, $respraw) = LoxBerry::IO::mshttp_call( $ms, "/jdev/sps/LoxAPPversion3" );

}



