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
my @names = $cgi->param;
foreach my $name (@names) {
	print STDERR "Parameter $name is " . $cgi->param($name) . "\n";
}

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

	if (substr($R::currentpath, -1) eq "/") {
		$R::currentpath = substr($R::currentpath, 0, -1);
	}
	
	print $cgi->header(-type => 'text/html;charset=utf-8',
					-status => "200 OK",
	);
	
	my $html = <<EOF;
	<div data-role="fieldcontain">
		<label for="$R::formid-select">Select storage</label>
		<select name="$R::formid-select" id="$R::formid-select" disabled>
			<option value="">Please wait...</option>
		</select>	
	</div>
	<div data-role="fieldcontain" id="$R::formid-foldercontain" style="display:none">
		<label for="$R::formid-folder">Subfolder</label>
		<input name="$R::formid-folder" id="$R::formid-folder" type="text" name="folder" disabled>
	</div>
	<input type="hidden" name="$R::formid" id="$R::formid" value="$R::currentpath">
	
<script>
\$(function() {
	console.log( "JS loaded" );
	var select = \$("#$R::formid-select");
	if ("$R::custom_folder" > 0) 
		\$("#$R::formid-foldercontain").fadeIn();
	
	\$.post ( '/admin/system/tools/ajax-storage-handler.cgi', 
					{ 	action: 'get-storage',
						
					})
	.done(function(stor) {
		console.log("AJAX done");
		var currentpath = "$R::currentpath";
		var option = \$('<option></option>').attr("value", "").text("Select...");
		select.empty().append(option);
		//var option = "<option value=''>Select...</option>";
		for (var i=0; i < stor.length; i++) {
			// console.log("Storage " + i, stor[i].NAME);
			option = \$('<option></option>').attr("value", stor[i].PATH).text(stor[i].NAME);
			// storhtml += "<option value=\"" + stor[i].PATH + "\">" + stor[i].NAME + "</option>";
			select.append(option);
			if(currentpath.startsWith(stor[i].PATH)) {
				select.val(stor[i].PATH);
				var foldertmp = currentpath.substr(stor[i].PATH.length);
				\$("#$R::formid-folder").val(foldertmp);
			}
				
		}
		//select.selectmenu();
		select.selectmenu('enable');
		select.selectmenu('refresh', true);
		\$("#$R::formid-folder").textinput({ disabled: false });
		
	})
	
	.always(function(data) {
		//if (typeof updatenavbar !== 'undefined' && \$.isFunction(updatenavbar)) {
		//	console.log("Done");
		//	updatenavbar();
		//}
	});
	
	select.change(function() {
		console.log("SELECT changed");
		\$("#$R::formid").val(select.val() + \$("#$R::formid-folder").val());
	});
	
	\$("#$R::formid-folder").blur(function() {
		console.log("FOLDER changed");
		var folder = \$("#$R::formid-folder").val();
		if (folder.charAt(0) != "/") {
			folder = "/" + folder;
			\$("#$R::formid-folder").val(folder);
		}
		if (folder.charAt(folder.length-1) == "/") {
			folder = folder.substr(0, (folder.length-1));
			\$("#$R::formid-folder").val(folder);
		}
		
		\$("#$R::formid").val(select.val() + folder);
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