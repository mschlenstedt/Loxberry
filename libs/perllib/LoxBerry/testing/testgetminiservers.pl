#!/usr/bin/perl

use LoxBerry::System;

my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();
  
if (! %miniservers) {
    exit(1); # Keine Miniserver vorhanden
}
 
print "Anzahl deiner Miniserver: " . keys(%miniservers) . "\n";
  
foreach my $ms (sort keys %miniservers) {
    print "Der Miniserver Nr. $ms heißt $miniservers{$ms}{Name} und hat die IP $miniservers{$ms}{IPAddress}.\n";
}

#delete @miniservers{1};
delete @miniservers{2};
delete @miniservers{3};
delete @miniservers{4};

print "After delete:\n";
print "Anzahl deiner Miniserver: " . keys(%miniservers) . "\n";

foreach my $ms (sort keys %miniservers) {
    print "Der Miniserver Nr. $ms heißt $miniservers{$ms}{Name} und hat die IP $miniservers{$ms}{IPAddress}.\n";
}

if (! %miniservers) {
	print "Keine Miniserver vorhanden.\n";
}

if( ! %miniservers{1}) {
	print "Miniserver 1 nicht vorhanden\n";
}