#!/usr/bin/perl
use HTTP::Daemon;
use HTTP::Status;
use LoxBerry::System;
 
my $port = 64995;

my $d;

my ($newport) = @ARGV;

if ($ARGV[0]) {
	$port = $ARGV[0];
}

while (!$d) {

	$d = HTTP::Daemon->new(
		LocalPort => $port,
		);
	if(!$d) {
		print STDERR "Waiting for port $port...\n";
		sleep 2;
	}
}

my $r;
while (my $c = $d->accept) {
    while ($r = $c->get_request) {
	# Reboot
        if($r->method eq 'GET' && $r->uri->path eq "/reboot") {
		my $content;
		my $reboot;
		if ( &checkpin() ) {
			$content = "Rebooting...";
			$reboot = 1;
		} else {
			$content = "Wrong SecurePIN.";
		}
		my $response = HTTP::Response->new( 200, 'OK');
		$response->header('Content-Type' => 'text/plain'),
		$response->content($content);
		$c->send_response($response);
		system ("sudo /sbin/reboot > /dev/null 2>&1") if $reboot;
	# Live Healthcheck
	} elsif ($r->method eq 'GET' && $r->uri->path eq "/live_healthcheck") {
			my $content = &healthcheck_live();
			my $response = HTTP::Response->new( 200, 'OK');
			$response->header('Content-Type' => 'text/plain'),
			$response->content("$content");
			$c->send_response($response);
	# Healthcheck Summary
	} elsif ($r->method eq 'GET' && $r->uri->path eq "/healthcheck") {
			my $content = &healthcheck_summary();
			my $response = HTTP::Response->new( 200, 'OK');
			$response->header('Content-Type' => 'application/json;charset=utf-8'),
			$response->content("$content");
			$c->send_response($response);
	# Overview
	} else {
			$c->send_file_response("$lbstemplatedir/emergencywebserver.html");
    	}
    }
    $c->close;
    undef($c);
}

#
# Subroutines
#
sub healthcheck_summary {
	my $cmd = "$lbhomedir/webfrontend/htmlauth/system/healthcheck.cgi action=summary";
	my $content = qx ( $cmd );
	$content =~ s/\n//g;
	$content =~ s/^.*(\{[.\s]*\}$)/$1/;
	return ($content);
}

sub healthcheck_live {
	my $cmd = "$lbhomedir/sbin/healthcheck.pl output=text nocolors=1";
	my $content = qx ( $cmd );
	return ($content);
}

sub checkpin {
	my $pin = $r->uri->query;
	$pin =~ s/securepin=(\d+).*/$1/;
	if ( LoxBerry::System::check_securepin($pin) ) {
		return (0);
	} else {
		return (1);
	}
}
