#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Storage;
use CGI;
use warnings;
use strict;

our $cgi = CGI->new;
my  $version = "0.1.2";


LoxBerry::Web::lbheader("Test Storage", "http://www.loxwiki.eu:80");
print "<p>Hallo</p>";
print "<p>";
my @storages = LoxBerry::Storage::get_storage(1);

foreach my $storage (@storages) {
    print "$storage->{GROUP} $storage->{TYPE} $storage->{NAME} $storage->{PATH} Writable:$storage->{WRITABLE}<br>";
}

LoxBerry::Web::lbfooter();
exit;
