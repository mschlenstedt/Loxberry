#!/usr/bin/perl

use LoxBerry::System;
use CGI;

my $cgi= CGI->new();

# print $cgi->header();
print "sbin/testenvironment.pl: \$lbhomedir: $lbhomedir<br>";
print 'sbin/testenvironment.pl: $ENV{\'LBHOMEDIR\'}: ' . $ENV{'LBHOMEDIR'} . "<br>"; 
my $output = qx{/opt/loxberry/sbin/testenvironment.sh};
print $output;

