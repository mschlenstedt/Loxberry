#!/usr/bin/perl

use LoxBerry::Storage;
use CGI;
use warnings;
use strict;

our $cgi = CGI->new;


my $html = LoxBerry::Storage::get_storage_html(formid => 'storage', currentpath => '/opt/loxberry/test');
print $html if ($html);


exit;
