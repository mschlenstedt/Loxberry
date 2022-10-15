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
print "<form action=''>";
# my @storages = LoxBerry::Storage::get_storage(1);

# foreach my $storage (@storages) {
    # print "$storage->{GROUP} $storage->{TYPE} $storage->{NAME} $storage->{PATH} Writable:$storage->{WRITEABLE}<br>";
# }

print LoxBerry::Storage::get_storage_html(
	formid => 'mystorage', 
	currentpath => '/opt/loxberry/system/storage/usb/9daec47a-01/test/',
	# currentpath => '/schöne scheiße/',
	custom_folder => 1,
	#type_all => 1,
	readwriteonly => 1,
	# label => "Ziel auswählen",
);

print "</form>";

print '<a href="#" class="ui-btn" id="change_button">Change path</a>';





print <<EOF;
<script>

const testpaths = [
	"/opt/loxberry/system/storage/usb/9daec47a-01/test/",
	"/opt/loxberry/data/system/",
	"/tmp",
	"/opt/loxberry/system/storage/smb/homeserver/Video-Projekte_in_Arbeit/test"
];


 \$(function() {
	 
	
	 
	console.log ("Own script started");
	// Log changes of the path by JavaScript

	\$("#mystorage").on("change", function() {
		console.log ("mystorage path changed to", \$("#mystorage").val());


	});

	\$("#change_button").bind( "click", function(event, ui) {
		var usepath = testpaths[Math.floor(Math.random()*testpaths.length)+1];
		console.log("Next using path", usepath);
		refresh_storage_mystorage(usepath);
		console.log("mystorage path now uses", \$("#mystorage").val());
	});


});

</script>


EOF




LoxBerry::Web::lbfooter();

exit;
