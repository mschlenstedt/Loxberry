#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Web;
use CGI::Simple qw(-debug1);

my $q = CGI::Simple->new;
my $action = $q->param('action');
if( $action ) {
	ajax_actions();
	exit;
}




my $lb_body = "$lbstemplatedir/mqtt-main.html";

our $htmlhead = <<'EOF';
  <script src="/system/scripts/vue3/vue3.js"></script> 
EOF


LoxBerry::Web::lbheader();

print LoxBerry::System::read_file($lb_body);

LoxBerry::Web::lbfooter();


####################################################
## AJAX functions 
####################################################

sub ajax_actions 
{
	
	require JSON;
	
	my %response;
	$response{"error"} = 1;
	
	if( $action eq 'mosquitto_set' ) {
		`sudo $lbhomedir/sbin/mqtt-handler.pl action=mosquitto_set`;
		$response{error} = 0;
	}
	
	else {
		$response{error} = 1;
		$response{message} = "Unknown action $action";
	}



	# Create headers
	
	if( !$response{error} ) {
		print $q->header('application/json','200 OK');
	}
	
	else {
		print $q->header('application/json','500 Internal Server Error');
	}

	print JSON::to_json( \%response ) . "\n";

}