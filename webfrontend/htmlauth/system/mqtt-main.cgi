#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;

print "Content-Type: text/html; charset=utf-8\n\n";

my $lb_header = "$lbstemplatedir/temporary-header.html";
my $lb_footer = "$lbstemplatedir/temporary-footer.html";
my $lb_body = "$lbstemplatedir/mqtt-main.html";

print LoxBerry::System::read_file($lb_header);
print LoxBerry::System::read_file($lb_body);
print LoxBerry::System::read_file($lb_footer);
