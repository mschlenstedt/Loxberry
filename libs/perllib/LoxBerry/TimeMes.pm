# This module is for debugging of timings. 
# Do not use in production environment

use strict;
use Time::HiRes qw(time);

################################################################
package LoxBerry::TimeMes;
our $VERSION = "0.3.2.1";

our @timing;
our @timingstring;

### Exports ###
use base 'Exporter';
our @EXPORT = qw (

mes
mesout

);

# Functions
 

sub mes
{
	my ($string) = @_;
	push @timing, Time::HiRes::time();
	push @timingstring, $string;
}

sub mesout
{
	print STDERR "==============================================================\n";
	print STDERR " TIME MESUREMENT (currtime HiRes: " . Time::HiRes::time() . ")\n\n";
	for (my $key = 0; $key < scalar @timing; $key++) {
		my $formatedtime = sprintf("%5.1f", 1000*($timing[$key]-$timing[0]));
		my $formateddiff = 0;
		$formateddiff = sprintf("%5.1f", 1000*($timing[$key]-$timing[$key-1])) if ($key != 0);
		
		print STDERR " " . $formatedtime . "ms / " . $formateddiff . "ms : $timingstring[$key]\n";
	}
	print STDERR "==============================================================\n";
	
}



#####################################################
# Finally 1; ########################################
#####################################################
1;
