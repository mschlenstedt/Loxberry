#!/usr/bin/perl

# Only load libs here you definetely need.
# If there's a lib you only need for a
# single function, please load it with 
# require ....; within the function.
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Log;
use CGI;
use JSON;

my $error;
my $response;
my $cgi = CGI->new;
my $q = $cgi->Vars;

my $log = LoxBerry::Log->new (
    name => 'AJAX Template',
	stderr => 1,
	loglevel => 7
);

LOGSTART "Request $q->{action}";

## Example: Restart a Service
if( $q->{action} eq "restartservice" ) {

	my ($exitcode) = execute( { command => "sudo systemctl restart MYSERVICE", log => $log } );
	$response = $exitcode;

}

## Example: Get several Process IDs and give it back as response
if( $q->{action} eq "serrvicestatus" ) {
	
	my $stat1 = `pgrep -f process1`;
	chomp ($stat1); # cut of linefeeds
	my $stat2 = `pgrep -f process2`;
	chomp ($stat2); # cut of linefeeds
	my $stat3 = `pgrep -f process3`;
	chomp ($stat3); # cut of linefeeds
	my %response = (
		process1 => $stat1,
		process2 => $stat2,
		process3 => $stat3,
	);
	chomp (%response);
	$response = encode_json( \%response );
}

## Example: Get the json Config and give it back as response
if( $q->{action} eq "getconfig" ) {
	my $configfile = "/path/to/config";
	if ( -e $configfile ) {
		$response = LoxBerry::System::read_file($configfile);
		if( !$response ) {
			$response = "{ }";
		}
	}
	else {
		$response = "{ }";
	}
}




#####################################
# Manage Response and error
#####################################

if( defined $response and !defined $error ) {
	print "Status: 200 OK\r\n";
	print "Content-type: application/json; charset=utf-8\r\n\r\n";
	print $response;
	LOGOK "Parameters ok - responding with HTTP 200";
}
elsif ( defined $error and $error ne "" ) {
	print "Status: 500 Internal Server Error\r\n";
	print "Content-type: application/json; charset=utf-8\r\n\r\n";
	print to_json( { error => $error } );
	LOGCRIT "$error - responding with HTTP 500";
}
else {
	print "Status: 501 Not implemented\r\n";
	print "Content-type: application/json; charset=utf-8\r\n\r\n";
	$error = "Action ".$q->{action}." unknown";
	LOGCRIT "Method not implemented - responding with HTTP 501";
	print to_json( { error => $error } );
}

END {
	LOGEND if($log);
}
