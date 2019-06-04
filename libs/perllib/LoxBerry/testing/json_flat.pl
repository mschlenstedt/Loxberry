#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use Data::Dumper;

my $filename = "$lbhomedir/libs/perllib/LoxBerry/testing/jsontestdata2.json";
my $jsonobj = LoxBerry::JSON->new();
my $data = $jsonobj->open(filename => $filename);
#print Dumper(\$data);
my $flat = $jsonobj->flatten();
print Data::Dumper::Dumper($flat);
$data->{SMTP}->{EMAIL} = "FENZI";
my $flat = $jsonobj->flatten();
print Data::Dumper::Dumper($flat);
#print Dumper(\$flat);

# With prefix CFG
my $flat = $jsonobj->flatten("CFG");
print Data::Dumper::Dumper($flat);
print "SMTP-Server: " . $flat->{"CFG.SMTP.SMTPSERVER"} . "\n";
