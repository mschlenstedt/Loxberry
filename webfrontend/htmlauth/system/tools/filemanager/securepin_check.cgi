#!/usr/bin/perl
use strict;
use warnings;
use LoxBerry::System;
use JSON;
use CGI;

my $cgi = CGI->new;
my $checkres = LoxBerry::System::check_securepin($cgi->param("secpin"));

my %resp;
$resp{error} = int($checkres // 0);

print $cgi->header(-type => 'application/json', -charset => 'utf-8');
print encode_json(\%resp);
