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

print $cgi->header('application/json;charset=utf-8');

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->max_redirect( 0 );

$R::useclouddns if (0);
$R::ip if (0);

my $hostport = "$R::ip";
$hostport .= ":$R::port" if ($R::port);

# Cloud DNS handling
if (is_enabled($R::useclouddns)) {
	if (! $R::clouddns) {
		$jout{error} = 1;
		$jout{success} = 0;
		$jout{status_line} = "Cloud DNS not set";
		print to_json(\%jout);
		exit;
	}
	
	my $cfg = new Config::Simple("$lbhomedir/config/system/general.cfg");
	my $cloudaddress = $cfg->param('BASE.CLOUDDNS');
	my $checkurl = "http://$cloudaddress/$R::clouddns";
	my $resp = $ua->head($checkurl);
	# print $resp->status_line;
	my $header = $resp->header('location');
	# Removes http://
	$header =~ s/http:\/\///;
	# Removes /
	$header =~ s/\///;
	$hostport = $header;
	$jout{isclouddns} = 1;
}

$jout{hostport} = $hostport;
	
if ($R::get_hostport) {
	print to_json(\%jout);
	exit;
}

my $urlnonadmin = "http://$R::user:$R::pass\@$hostport/dev/cfg/version";
my $urladmin = "http://$R::user:$R::pass\@$hostport/dev/cfg/ip";


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
