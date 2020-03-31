#!/usr/bin/perl

use warnings;
use strict;
use LoxBerry::System::General;

$LoxBerry::System::General::DEBUG = 1;

my $cfgobj = LoxBerry::System::General->new();
my $cfg = $cfgobj->open( writeonclose => 1 );

print "Method: $cfg->{Timeserver}->{Method} \n";
print "Timeserver: $cfg->{Timeserver}->{Timezone} \n";

$cfg->{Timeserver}->{TEST} = int(rand(100));
# $cfg->{Timeserver}->{TEST} = "10";

# $cfgobj->write();

