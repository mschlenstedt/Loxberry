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
use Time::Piece;

my $error;
my $response;
my $cgi = CGI->new;
my $q = $cgi->Vars;

my $log = LoxBerry::Log->new (
    	name => 'AJAX',
	package => 'Remote Support',
	logdir => $lbstmpfslogdir,
	stderr => 1
);

LOGSTART "Request $q->{action}";

## Get status and logfile
if( $q->{action} eq "status" ) {

	my $logfile = "";
	my $logstatus = "";
	my ($exitcode,$output) = LoxBerry::System::execute { command => "$lbssbindir/remoteconnect.pl status" };
	chomp ($output);
	my %response;
	#my $loxberryid = LoxBerry::System::read_file("$lbsconfigdir/loxberryid.cfg");
	if ($exitcode eq 0 && $output ne "ERROR") {
		%response = (
			'online' => 1,
			'remoteurl' => $output,
			#'id' => $loxberryid,
		);
	} else {
		%response = (
			'online' => 0,
			'remoteurl' => '',
			#'id' => $loxberryid,
		);
	}
	$response = to_json( \%response );
}

## Get the json Config and give it back as response
if( $q->{action} eq "getconfig" ) {
	my $configfile = "$lbsconfigdir/general.json";
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

## Save the json Config and give it back as response
if( $q->{action} eq "saveconfig" ) {
	my $configfile = "$lbsconfigdir/general.json";
	require LoxBerry::JSON;
	my $jsonobj = LoxBerry::JSON->new();
	my $cfg = $jsonobj->open(filename => $configfile);
	$cfg->{'Remote'}->{'Autoconnect'} = $q->{'autoconnect'};
	$jsonobj->write();
	$response = 1;
}

# Start Connection
if( $q->{action} eq "start" ) {
	my ($exitcode) = LoxBerry::System::execute { command => "$lbssbindir/remoteconnect.pl start" };
	if ($exitcode ne 0) {
		$response = 0;
	} else {
		$response = 1;
	}
}

# Stop Connection
if( $q->{action} eq "stop" ) {
	my ($exitcode) = LoxBerry::System::execute { command => "$lbssbindir/remoteconnect.pl stop" };
	if ($exitcode ne 0) {
		$response = 0;
	} else {
		$response = 1;
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
