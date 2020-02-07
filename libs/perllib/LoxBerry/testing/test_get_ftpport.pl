#!/usr/bin/perl

use LoxBerry::System;
$LoxBerry::System::DEBUG = 1;

%miniservers = LoxBerry::System::get_miniservers();


print "Miniserver list\n";
foreach my $ms (sort keys %miniservers) {
    print "Miniserver Nr. $ms has name  $miniservers{$ms}{Name}. IP is $miniservers{$ms}{IPAddress}, port $miniservers{$ms}{Port}\n";
    print "     PreferredUrlFull $miniservers{$ms}{FullURI}\n";
    print "     FTP Port: " . LoxBerry::System::get_ftpport($ms) . "\n";

}
