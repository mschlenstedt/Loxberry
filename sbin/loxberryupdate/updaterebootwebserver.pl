#!/usr/bin/perl
use HTTP::Daemon;
use HTTP::Status;
use LoxBerry::System;
 
my $port = lbwebserverport();

my $d = HTTP::Daemon->new(
	LocalPort => $port,
	) || die;

my $logfile = shift;

while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if ($r->method eq 'GET' && $r->uri->path eq "/logfile") {
            $c->send_file_response("$logfile");
    	} elsif ($r->method eq 'GET' && $r->uri->path eq "/admin/system/tools/power-handler.php") {
		$c->send_file_response("$lbstemplatedir/reboot_updaterunning_ph.html");
        } else {
            $c->send_file_response("$lbstemplatedir/reboot_updaterunning.html");
        }
    }
    $c->close;
    undef($c);
}
