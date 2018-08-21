#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use LoxBerry::System;
use LWP::UserAgent;
use JSON;
use URI::Escape;

my %jout;
my $cgi = CGI->new;
$cgi->import_names('R');

$R::user = uri_escape($R::user);
$R::pass = uri_escape($R::pass);


print $cgi->header('application/json;charset=utf-8');

my $ua = LWP::UserAgent->new;
$ua->timeout(5);
$ua->max_redirect( 0 );

$R::useclouddns if (0);
$R::ip if (0);

my $hostport = "$R::ip" if ($R::ip);
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
	
	## Old CloudDNS implementation (pre Aug. 2018)
	# my $checkurl = "http://$cloudaddress/$R::clouddns";
	# my $resp = $ua->head($checkurl);
	# # print $resp->status_line;
	# my $header = $resp->header('location');
	# # Removes http://
	# $header =~ s/http:\/\///;
	# # Removes /
	# $header =~ s/\///;
	# $hostport = $header;

	## New CloudDNS implementation (Loxone changed the handling)
	my $checkurl = "http://$cloudaddress?getip&snr=$R::clouddns&json=true";
	my $resp = $ua->get($checkurl);
	my $respjson = decode_json($resp->content);
	$hostport = $respjson->{IP};
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
require HTTP::Status;

# Try an admin access
for (my $x = 1; $x <= 3; $x++) {
	my $resp = $ua->get($urladmin);
	my $checkerror;
	if ($resp->content =~ m/<LL control="dev\/cfg\/ip" value=".*" Code="200"\/>/) 
	{
		$checkerror = 0;
	}
	else
	{
		$checkerror = 1;
	}
	# Cloud redirect ?
	if ( $resp->code == &HTTP::Status::RC_MOVED_PERMANENTLY or $resp->code == &HTTP::Status::RC_MOVED_TEMPORARILY or $resp->code == &HTTP::Status::RC_FOUND or $resp->code == &HTTP::Status::RC_SEE_OTHER or $resp->code == &HTTP::Status::RC_TEMPORARY_REDIRECT )
	{ 
    	use URI;
    	my $uri = URI->new($resp->header('location'));
    	my $redirect = $uri->scheme."://$R::user:$R::pass\@".$uri->host.":".$uri->port.$uri->path;
    	$resp = $ua->get($redirect);
		if ($resp->content =~ m/<LL control="dev\/cfg\/ip" value=".*" Code="200"\/>/) 
		{
			$checkerror = 0;
		}
		else
		{
			$checkerror = 1;
		}
	}
	$jout{code} = $resp->code;
	$jout{message} = $resp->message;
	$jout{status_line} = $resp->status_line;

	if (! $resp->is_success || $checkerror eq 1) {
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
		my $checkerror;
		if ($resp->content =~ m/<LL control="dev\/cfg\/version" value=".*" Code="200"\/>/) 
		{
			$checkerror = 0;
		}
		else
		{
			$checkerror = 1;
		}
			# Cloud redirect ?
		if ( $resp->code == &HTTP::Status::RC_MOVED_PERMANENTLY or $resp->code == &HTTP::Status::RC_MOVED_TEMPORARILY or $resp->code == &HTTP::Status::RC_FOUND or $resp->code == &HTTP::Status::RC_SEE_OTHER or $resp->code == &HTTP::Status::RC_TEMPORARY_REDIRECT )
		{ 
	    	use URI;
	    	my $uri = URI->new($resp->header('location'));
	    	my $redirect = $uri->scheme."://$R::user:$R::pass\@".$uri->host.":".$uri->port.$uri->path;
	    	$resp = $ua->get($redirect);
   			if ($resp->content =~ m/<LL control="dev\/cfg\/version" value=".*" Code="200"\/>/) 
			{
				$checkerror = 0;
			}
			else
			{
				$checkerror = 1;
			}
		}
		$jout{code} = $resp->code;
		$jout{message} = $resp->message;
		$jout{status_line} = $resp->status_line;
			
		if (! $resp->is_success || $checkerror eq 1) {
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
