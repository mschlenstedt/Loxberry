#!/usr/bin/perl
use HTTP::Daemon;
use HTTP::Status;
use LoxBerry::System;
use JSON;
 
my $port = lbwebserverport();

# DEBUG
#my $port = 81;

my $d;

while (!$d) {

$d = HTTP::Daemon->new(
	LocalPort => $port,
	);
	if(!$d) {
		print STDERR "Waiting for port $port...\n";
		sleep 2;
	}
}

my $logfile = shift;

while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if($r->method eq 'GET' && $r->uri->path eq "/lastlines") {
			lastlines($c);
		} elsif ($r->method eq 'GET' && $r->uri->path eq "/logfile") {
        	$c->send_file_response("$logfile");
		} elsif ($r->method eq 'GET' && $r->uri->path eq "/system/scripts/jquery/jquery-1.12.4.min.js") {
        	$c->send_file_response("$lbshtmldir/scripts/jquery/jquery-1.12.4.min.js");
    	} elsif ($r->method eq 'GET' && $r->uri->path eq "/updatereboot-anim-large.gif") {
			$c->send_file_response("$lbshtmldir/images/updatereboot-anim-large.gif");
		} elsif ($r->method eq 'GET' && $r->uri->path eq "/admin/system/tools/power-handler.php") {
			$c->send_file_response("$lbstemplatedir/reboot_updaterunning_ph.html");
		} else {
			$c->send_file_response("$lbstemplatedir/reboot_updaterunning.html");
    	}
    }
    $c->close;
    undef($c);
}

sub lastlines
{
	my $c = shift;
	
	# DEBUG
	# $logfile = "/opt/loxberry/log/system_tmpfs/apache2/error.log";
		
	open my $fh, "<", $logfile;
	seek($fh, -700, 2);
	
	chomp(my @lines = <$fh>);
	close $fh;
	shift @lines;
	while (scalar @lines > 10) {
		shift @lines;
	}
	
	my $json->{"entries"} = \@lines;
	my $content = to_json($json);
	# print STDERR $content;
	
	my @header = ( 'Content-Type', 'application/json' );
	my $res = HTTP::Response->new( "200", "OK", \@header, $content );
	$c->send_response($res);

}
