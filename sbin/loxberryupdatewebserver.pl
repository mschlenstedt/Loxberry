#!/usr/bin/perl
use HTTP::Daemon;
use HTTP::Status;
use LoxBerry::System;
 
my $d = HTTP::Daemon->new(
	LocalPort => 80,
	) || die;

while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if ($r->method eq 'GET') {
            $c->send_file_response("$lbstemplatedir/reboot_updaterunning.html");
        }
    }
    $c->close;
    undef($c);
}
