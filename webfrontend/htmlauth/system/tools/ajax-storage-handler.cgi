#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard/;
#use Scalar::Util qw(looks_like_number);
#use DBI;
#use LoxBerry::Log;
use LoxBerry::Storage;
use JSON;

my $cgi = CGI->new;

$LoxBerry::Storage::DEBUG = 1;

# DEBUG parameters from POST
# my @names = $cgi->param;
# foreach my $name (@names) {
	# print STDERR "Parameter $name is " . $cgi->param($name) . "\n";
# }

$cgi->import_names('R');

# Prevent 'only used once' warning
if (! $R::action) {
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "500 Method not supported",
	);
	exit;
}

my $action = $R::action;

print STDERR "--> ajax-storage-handler:\n   Action: $action\n" if ($LoxBerry::Storage::DEBUG);

if ($action eq 'init') {init_html();}
elsif ($action eq 'get-storage') {get_storage();}
# elsif ($action eq 'get_notification_count') {getnotificationcount();}
# elsif ($action eq 'get_notifications_html') {getnotificationshtml();}
# elsif ($action eq 'notifyext') {setnotifyext();}

# else {
	# print $cgi->header(-type => 'application/json;charset=utf-8', -status => "500 Action not supported");
	# exit;
# }

exit;

sub init_html 
{

	if (! $R::formid) {
		$R::formid = "storage" . int(rand(1000));
	}

	print $cgi->header(-type => 'text/html;charset=utf-8',
					-status => "200 OK",
	);
	
	my $html = <<EOF;
	<div data-role="fieldcontain">
	<label for="$R::formid-select">Select storage path</label>
	<select name="$R::formid-select" id="$R::formid-select" disabled>
		<option value="">Please wait...</option>
	</select>	
	</div>
	<input type="hidden" name="$R::formid" id="$R::formid" value="$R::currentpath">
	
<script>
\$(function() {
	console.log( "JS loaded" );
	\$.post ( '/admin/system/tools/ajax-storage-handler.cgi', 
					{ 	action: 'get-storage',
						
					})
	.done(function(stor) {
		console.log("AJAX done");
		var select = \$("#$R::formid-select");
		
		// console.log("Storage1", stor[1].NAME);
		var option = \$('<option></option>').attr("value", "").text("Select...");
		select.empty().append(option);
		//var option = "<option value=''>Select...</option>";
		for (var i=0; i < stor.length; i++) {
			// console.log("Storage " + i, stor[i].NAME);
			option = \$('<option></option>').attr("value", stor[i].PATH).text(stor[i].NAME);
			// storhtml += "<option value=\"" + stor[i].PATH + "\">" + stor[i].NAME + "</option>";
			select.append(option);
		}
		//select.selectmenu();
		select.selectmenu('enable');
		select.selectmenu('refresh', true);
		//\$('select').selectmenu('refresh', true);
	})
	
	.always(function(data) {
		//if (typeof updatenavbar !== 'undefined' && \$.isFunction(updatenavbar)) {
		//	console.log("Done");
		//	updatenavbar();
		//}
	});
	
	
	
	
});



</script>
EOF

	print $html;
	exit;
}


sub get_storage
{
	print $cgi->header(-type => 'application/json;charset=utf-8', -status => "200 OK");
	my @storage = LoxBerry::Storage::get_storage();
	print to_json(\@storage);
	exit;
}