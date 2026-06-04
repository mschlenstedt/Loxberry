#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard/;
use LoxBerry::System;
			
my $version = "2.0.1.1"; # Version of this script

my $cgi = CGI->new;
$cgi->import_names('R');

# Prevent 'only used once' warning
$R::action if 0;
$R::suggestedName if 0;
$R::filename if 0;

my $action = $R::action;
my $suggestedName = $R::suggestedName;
my $filename = $R::filename;
my $errormsg;
my $response;

print STDERR "ajax-download-handler: Action: $action\n";

if ($action eq 'download-admin-credentials') { download_admin_credentials(); }

else   { 
	$errormsg = "Action not supported.";
}

exit;


## For admin and wizard widget
## Creates from input parameters a downloadable file with credentials
sub download_admin_credentials
{

	if(! $R::credentialstxt) {
		$errormsg = "No data for download submitted";
		exit;
	}
	
	if(! $suggestedName) {
		$suggestedName = LoxBerry::System::lbhostname()."_credentials.txt";
	}

	$response = $R::credentialstxt;

}


END {

	if($errormsg) {
		print $cgi->header(
			-type => 'text/plain',
			-charset => 'utf-8',
			-status => '500 Internal Server Error',
		);
		print $errormsg;
		exit 1;
	} 
	
	print $cgi->header(
		-status => '200 OK',
		-type => 'application/octet-stream',
		-charset => '',
		-attachment => $suggestedName,
		-Content_length => length($response),
	);
	
	print $response;
	exit 0;

	# PHP Code
	# header($_SERVER["SERVER_PROTOCOL"] . " 200 OK");
	# header("Cache-Control: public"); // needed for internet explorer
	# header("Content-Type: application/octet-stream");
	# header("Content-Transfer-Encoding: Binary");
	# header("Content-Length: ".strlen($xml));
	# header("Content-Disposition: attachment; filename=$xmlfilename");
	
}