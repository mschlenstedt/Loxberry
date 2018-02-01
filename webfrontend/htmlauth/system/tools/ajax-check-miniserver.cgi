#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use LoxBerry::System;
use LWP::UserAgent;
use JSON;

my %jout;
my $cgi = CGI->new;
$cgi->import_names('R');

print $cgi->header('application/json');

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

my $urlnonadmin = "http://$R::user:$R::pass\@$R::ip\:$R::port/dev/cfg/version";
my $urladmin = "http://$R::user:$R::pass\@$R::ip\:$R::port/dev/cfg/ip";

my $nonadmin;
my $admin;

# Try an admin access
for (my $x = 1; $x <= 3; $x++) {
	my $resp = $ua->get($urladmin);
	$jout{code} = $resp->code;
	$jout{message} = $resp->message;
	$jout{status_line} = $resp->status_line;
		
	if (! $resp->is_success) {
		$jout{error} = 1;
		$jout{success} = 0;
	} else {
		$jout{error} = 0;
		$jout{success} = 1;
		$jout{isadmin} = 1;
		last;
	}
}

# Try an non-admin access
if ($jout{error}) {
	for (my $x = 1; $x <= 3; $x++) {
		my $resp = $ua->get($urlnonadmin);
		$jout{code} = $resp->code;
		$jout{message} = $resp->message;
		$jout{status_line} = $resp->status_line;
			
		if (! $resp->is_success) {
			$jout{error} = 1;
			$jout{success} = 0;
		} else {
			$admin = 1;
			$jout{error} = 0;
			$jout{success} = 1;
			$jout{isnonadmin} = 1;
			last;
		}
	}
}

print to_json(\%jout);

exit;
