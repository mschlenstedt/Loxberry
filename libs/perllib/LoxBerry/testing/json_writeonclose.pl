#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use Data::Dumper;

$LoxBerry::JSON::DEBUG = 1;

my $testfile = "/tmp/json_non-existant.json";
unlink $testfile;

# Create testfile
open my $fh, '>', $testfile;
print $fh '{ "Main": { "test": true, "test2": false } }' . "\n";
close $fh;

changejson();


# Output file
print "File output:\n";
open my $fh, '<', $testfile;
while(<$fh>){
   print $_;
}
close($fh);



sub changejson
{
	my $jsonobj = LoxBerry::JSON->new();
	my $json = $jsonobj->open(filename => $testfile, exclusivelock => 1, writeonclose => 1);
	$json->{Main}->{epoch} = time();

}

END 
{
	print "End\n";
}