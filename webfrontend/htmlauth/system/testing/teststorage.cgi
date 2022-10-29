#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Storage;
use CGI;
use warnings;
use strict;

our $cgi = CGI->new;
my  $version = "0.1.1";


LoxBerry::Web::lbheader("Test Storage", "https://wiki.loxberry.de/");
print "<p>Hallo</p>";
print "<p>";
print "<form action=''>";
# my @storages = LoxBerry::Storage::get_storage(1);

# foreach my $storage (@storages) {
    # print "$storage->{GROUP} $storage->{TYPE} $storage->{NAME} $storage->{PATH} Writable:$storage->{WRITEABLE}<br>";
# }

print LoxBerry::Storage::get_storage_html(
	formid => 'mystorage', 
	# currentpath => '/opt/loxberry/system/storage/usb/9daec47a-01/test/',
	currentpath => '/schöne scheiße/',
	custom_folder => 1,
	#type_all => 1,
	readwriteonly => 1,
	# label => "Ziel auswählen",
);

print "</form>";

print <<EOF;
<script>
 \$(function() {
	console.log ("Own script started");
	// Log changes of the path by JavaScript

	\$("#mystorage").on("change", function() {
		console.log ("mystorage path changed to", \$("#mystorage").val());


	});
});

</script>


EOF




LoxBerry::Web::lbfooter();

exit;
