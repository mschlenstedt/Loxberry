#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use LoxBerry::System;
use LWP::UserAgent;
use JSON;
use URI::Escape;

# Version of this script
my $version = "2.0.2.1";

my %jout;

my $cgi = CGI->new;
$cgi->import_names('R');

# my %headers = map { $_ => $cgi->http($_) } $cgi->http();
# print STDERR "ajax-check-miniserver.cgi RECEIVING HEADERS:\n";
# for my $header ( keys %headers ) {
    # print STDERR "$header: $headers{$header}\n";
# }
# print STDERR "Received POSTDATA:\n";
# my @postdata = $cgi->param;
# for my $param ( @postdata ) {
    # print STDERR "$param: " . $cgi->param($param) . "\n";
# }

$R::user = uri_escape($R::user);
$R::pass = uri_escape($R::pass);


print $cgi->header('application/json;charset=utf-8');

my $ua = LWP::UserAgent->new;
$ua->timeout(5);
$ua->max_redirect( 0 );
$ua->ssl_opts( SSL_verify_mode => 0, verify_hostname => 0 );

$R::useclouddns if (0);
$R::ip if (0);
$R::get_hostport if(0);
$R::preferhttps if (0);

# Check if ip format is IPv6
my $ipaddress = $R::ip;
my $IPv6Format = 0;
if( index( $ipaddress, ':' ) != -1 ) {
	$IPv6Format = 1;
}
if ( $IPv6Format == 1 ) {
	$ipaddress = '['.$ipaddress.']';
}

my $hostport = $ipaddress;
$hostport .= ":$R::port" if ($R::port);

my $preferhttps = is_enabled($R::preferhttps);
my $sslhostport;

if ( $preferhttps ) {
	$R::porthttps = defined $R::porthttps ? $R::porthttps : 443;
	$sslhostport = $ipaddress;
	$sslhostport .= ":$R::porthttps";
}

# Cloud DNS handling
if (is_enabled($R::useclouddns)) {
	if (! $R::clouddns) {
		$jout{http}{error} = 1;
		$jout{http}{success} = 0;
		$jout{http}{status_line} = "Cloud DNS not set";
		print to_json(\%jout);
		exit;
	}
	
	require LoxBerry::System::General;
	my $jsonobj = LoxBerry::System::General->new();
	my $cfg = $jsonobj->open( readonly => 1 );
	my $cloudaddress = $cfg->{Base}->{Clouddnsuri};
	
	my $checkurl = "http://$cloudaddress?getip&snr=$R::clouddns&json=true";
	$ua->timeout(5);
	my $resp = $ua->get($checkurl);
	if ($resp && $resp->is_success) 
	{
  		# success
		my $respjson = decode_json($resp->content);
		$jout{http}{isclouddns} = 1;
		$hostport = $respjson->{IP} if (defined $respjson->{IP});
		$sslhostport = $respjson->{IPHTTPS} if (defined $respjson->{IPHTTPS});
		$jout{clouddns} = $respjson;
		if($preferhttps) {
			$jout{https}{isclouddns} = 1;
		}
	}
	else
	{
		# fail
		$jout{http}{error} = 1;
		$jout{http}{success} = 0;
		$jout{http}{status_line} = "Timeout when reading $checkurl";
		print to_json(\%jout);
		exit;
	}
	
}

my @url_nonadmin;
my @url_admin;
$url_nonadmin[0] = "http://$R::user:$R::pass\@$hostport/dev/cfg/version";
$url_admin[0] = "http://$R::user:$R::pass\@$hostport/dev/cfg/ip";
if( $preferhttps ) {
	$url_nonadmin[1] = "https://$R::user:$R::pass\@$sslhostport/dev/cfg/version";
	$url_admin[1] = "https://$R::user:$R::pass\@$sslhostport/dev/cfg/ip";
}

my $nonadmin;
my $admin;
require HTTP::Status;

check_admin( $url_admin[0], "http" );

if( $jout{http}{error} ) {
	check_nonadmin( $url_nonadmin[0], "http" );
}

if ( $preferhttps ) {
	check_admin( $url_admin[1], "https" );
	if( $jout{https}{error} ) {
		check_nonadmin( $url_nonadmin[1], "https" );
	}
}

print to_json(\%jout);

exit;

###########################
# Check admin url
###########################
sub check_admin
{
	my ($urladmin, $label) = @_;
	
	# Try an admin access
	for (my $x = 1; $x <= 3; $x++) {
		$ua->timeout( $x*3 );
		# $jout{$label}{checkurl} = $urladmin;
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
		# # Cloud redirect ?
		# if ( $resp->code == &HTTP::Status::RC_MOVED_PERMANENTLY or $resp->code == &HTTP::Status::RC_MOVED_TEMPORARILY or $resp->code == &HTTP::Status::RC_FOUND or $resp->code == &HTTP::Status::RC_SEE_OTHER or $resp->code == &HTTP::Status::RC_TEMPORARY_REDIRECT )
		# { 
			# require URI;
			# my $uri = URI->new($resp->header('location'));
			# my $redirect = $uri->scheme."://$R::user:$R::pass\@".$uri->host.":".$uri->port.$uri->path;
			# $resp = $ua->get($redirect);
			# if ($resp->content =~ m/<LL control="dev\/cfg\/ip" value=".*" Code="200"\/>/) 
			# {
				# $checkerror = 0;
			# }
			# else
			# {
				# $checkerror = 1;
			# }
		# }
		$jout{$label}{code} = $resp->code;
		$jout{$label}{message} = $resp->message;
		$jout{$label}{status_line} = $resp->status_line;

		if (! $resp->is_success || $checkerror eq 1) {
			$jout{$label}{error} = 1;
			$jout{$label}{success} = 0;
		} else {
			$jout{$label}{error} = 0;
			$jout{$label}{success} = 1;
			$jout{$label}{isadmin} = 1;
			last;
		}
	}
}

######################
# Check non-admin url
######################
sub check_nonadmin 
{
	my ($urlnoadmin, $label) = @_;

	# Try non-admin access
	for (my $x = 1; $x <= 3; $x++) {
		$ua->timeout( $x*3 );
		# $jout{$label}{checkurl} = $urlnoadmin;
		my $resp = $ua->get($urlnoadmin);
		my $checkerror;
		if ($resp->content =~ m/<LL control="dev\/cfg\/version" value=".*" Code="200"\/>/) 
		{
			$checkerror = 0;
		}
		else
		{
			$checkerror = 1;
		}
			# # Cloud redirect ?
		# if ( $resp->code == &HTTP::Status::RC_MOVED_PERMANENTLY or $resp->code == &HTTP::Status::RC_MOVED_TEMPORARILY or $resp->code == &HTTP::Status::RC_FOUND or $resp->code == &HTTP::Status::RC_SEE_OTHER or $resp->code == &HTTP::Status::RC_TEMPORARY_REDIRECT )
		# { 
			# require URI;
			# my $uri = URI->new($resp->header('location'));
			# my $redirect = $uri->scheme."://$R::user:$R::pass\@".$uri->host.":".$uri->port.$uri->path;
			# $resp = $ua->get($redirect);
			# if ($resp->content =~ m/<LL control="dev\/cfg\/version" value=".*" Code="200"\/>/) 
			# {
				# $checkerror = 0;
			# }
			# else
			# {
				# $checkerror = 1;
			# }
		# }
		$jout{$label}{code} = $resp->code;
		$jout{$label}{message} = $resp->message;
		$jout{$label}{status_line} = $resp->status_line;
			
		if (! $resp->is_success || $checkerror eq 1) {
			$jout{$label}{error} = 1;
			$jout{$label}{success} = 0;
		} else {
			$admin = 1;
			$jout{$label}{error} = 0;
			$jout{$label}{success} = 1;
			$jout{$label}{isadmin} = 0;
			last;
		}
	}
}

