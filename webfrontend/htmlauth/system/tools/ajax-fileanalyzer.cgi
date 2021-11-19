#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use JSON;
use CGI;

my $cgi = CGI->new;
$cgi->import_names('R');

# Prevent 'only used once' warning
$R::action if 0;

my $action = defined $R::action ? $R::action : "";

my %response;
$response{error} = -1;

if($action eq "getopenfiledata" ) {
	
	$response{filedata} = `$lbssbindir/files_analyzer.pl action=getopenfiledata`;
	$response{error} = 0;
	
}

elsif($action eq "getlargefiledata" ) {
	
	$response{filedata} = `$lbssbindir/files_analyzer.pl action=getlargefiledata`;
	$response{error} = 0;
	
}



else { 
	$response{error} = -1; 
	$response{message} = "<red>Action not supported.</red>"
}




# 
# SEND HEASER AND RESPONSE
#

END {

	if($response{error} == -1) {
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '500 Internal Server Error',
		);	
	} else {
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '200 OK',
		);	
	}

	print encode_json(\%response);

}