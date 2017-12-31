#!/usr/bin/perl
#use strict;
use CGI::Fast;
use Embed::Persistent; {
my $p = Embed::Persistent->new();
while (new CGI::Fast) {
my $filename = $ENV{SCRIPT_FILENAME};
my $package = $p->valid_package_name($filename);
my $mtime;
if ($p->cached($filename, $package, \$mtime)) {
eval {$package->handler;};
}
else {
$p->eval_file($ENV{SCRIPT_FILENAME});
}
}
}
