#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Storage;
use CGI;
use warnings;
use strict;

our $cgi = CGI->new;
my  $version = "0.1.1";


LoxBerry::Web::lbheader("Test Storage", "http://www.loxwiki.eu:80");
print "<p>Hallo</p>";
print "<p>";
# my @storages = LoxBerry::Storage::get_storage(1);

# foreach my $storage (@storages) {
    # print "$storage->{GROUP} $storage->{TYPE} $storage->{NAME} $storage->{PATH} Writable:$storage->{WRITEABLE}<br>";
# }

print LoxBerry::Storage::get_storage_html(
	formid => 'mystorage', 
	currentpath => '/opt/loxberry/system/storage/usb/9daec47a-01/test/',
	custom_folder => 1,
);

LoxBerry::Web::lbfooter();

exit;
