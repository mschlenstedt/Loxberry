#!/usr/bin/perl
use CGI qw(:standard);
my $cgi = new CGI;
print redirect('/admin/system/index.cgi');
