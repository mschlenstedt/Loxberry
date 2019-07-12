#!/usr/bin/perl
use HTTP::Daemon;
use HTTP::Status;
use LoxBerry::System;
 
my $d = HTTP::Daemon->new(
	LocalPort => 80,
	) || die;

my $logfile = shift;

while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if ($r->method eq 'GET' && $r->uri->path eq "/logfile") {
            $c->send_file_response("$lbslogdir/loxberryupdate/$logfile");
        } else {
            $c->send_file_response("$lbstemplatedir/reboot_updaterunning.html");
        }
    }
    $c->close;
    undef($c);
}
