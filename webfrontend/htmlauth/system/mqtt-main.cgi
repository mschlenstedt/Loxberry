#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Web;

my $lb_body = "$lbstemplatedir/mqtt-main.html";

our $htmlhead = <<'EOF';
  <script src="/system/scripts/vue3/vue3.js"></script> 
EOF


LoxBerry::Web::lbheader();

print LoxBerry::System::read_file($lb_body);

LoxBerry::Web::lbfooter();