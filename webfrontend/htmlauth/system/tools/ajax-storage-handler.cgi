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

	my %SL = LoxBerry::System::readlanguage(undef, undef, 1);

	if(! $R::label) {
		$R::label = $SL{'STORAGE.GET_STORAGE_HTML_LABEL'};
	}
	
	if (! $R::formid) {
		$R::formid = "storage" . int(rand(1000));
	}

	if (substr($R::currentpath, -1) eq "/") {
		$R::currentpath = substr($R::currentpath, 0, -1);
	}

	if (! $R::type_all && ! $R::type_usb && ! $R::type_net && ! $R::type_local && ! $R::type_custom) {
		$R::type_all = 1;
	}
	if ($R::type_all eq "1") {
		$R::type_usb = "1";
		$R::type_net = "1";
		$R::type_local = "1";
		$R::type_custom = "1";
	}

	print $cgi->header(-type => 'text/html',
					-status => "200 OK",
	);
	
	# print $cgi->header(-type => 'text/html;charset=utf-8',
					# -status => "200 OK",
	# );
	
	
	my $html = <<EOF;
	<div data-role="fieldcontain">
		<label for="$R::formid-select">$R::label</label>
		<select name="$R::formid-select" id="$R::formid-select" disabled>
			<option value="">$SL{'COMMON.MSG_PLEASEWAIT'}</option>
		</select>	
	</div>
	<div data-role="fieldcontain" id="$R::formid-foldercontain" style="display:none">
		<label for="$R::formid-folder">$SL{'STORAGE.GET_STORAGE_HTML_FOLDER'}</label>
		<input name="$R::formid-folder" id="$R::formid-folder" type="text" name="folder" disabled>
	</div>
	<input type="hidden" name="$R::formid" id="$R::formid" value="$R::currentpath">
	
<script>
/*
DEBUG
	type_all: $R::type_all
	type_usb: $R::type_usb
	type_net: $R::type_net
	type_local: $R::type_local
	type_custom: $R::type_custom

*/
var ${R::formid}_storage = [""];

\$(function() {
	console.log( "JS loaded" );
	
	// Init things to display
	
	
	
	var select = \$("#$R::formid-select");
	if ("$R::custom_folder" > 0) 
		\$("#$R::formid-foldercontain").fadeIn();
	
	\$.post ( '/admin/system/tools/ajax-storage-handler.cgi', 
					{ 	action: 'get-storage',
						readwriteonly: '$R::readwriteonly',
						localdir: '$R::localdir',
					})
	.done(function(stor) {
		console.log("AJAX done");
		var currentpath = "$R::currentpath";
		var option = \$('<option></option>').attr("value", "").text("$SL{'STORAGE.GET_STORAGE_HTML_SELECT'}");
		select.empty().append(option);
		
		for (var i=0; i < stor.length; i++) {
			// console.log("Storage " + i, stor[i].NAME);
			if (stor[i].GROUP == "net" && "$R::type_net" != "1") continue;
			if (stor[i].GROUP == "usb" && "$R::type_usb" != "1") continue;
			if (stor[i].GROUP == "local" && "$R::type_local" != "1") continue;
			${R::formid}_storage[i+1] = stor[i].PATH;
			option = \$('<option></option>').attr("value", i+1).text(stor[i].NAME);
			select.append(option);
			if(currentpath.startsWith(stor[i].PATH)) {
				select.val(i+1);
				var foldertmp = currentpath.substr(stor[i].PATH.length);
				\$("#$R::formid-folder").val(foldertmp);
			}
		}
		
		var type_custom = "$R::type_custom";
		if (currentpath != "" && select.val() == "") {
			type_custom = "1";
		}
		
		if (type_custom == "1") {
			option = \$('<option></option>').attr("value", "0").text("$SL{'STORAGE.GET_STORAGE_HTML_CUSTOMPATH'}");
			select.append(option);
			// console.log("Selected:", select.val());
			if(currentpath != "" && select.val() == "") {
				\$("#$R::formid-folder").val(currentpath);
				select.val("0");
				\$("#$R::formid-foldercontain").fadeIn();
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
		if(select.val() == "0")
			\$("#$R::formid-foldercontain").fadeIn();
		if(select.val() != "0" && "$R::custom_folder" != "1") {
			\$("#$R::formid-foldercontain").fadeOut();
			\$("#$R::formid-folder").val("");
		}
		if (select.val() != "") 
			\$("#$R::formid").val(${R::formid}_storage[select.val()] + \$("#$R::formid-folder").val());
		else 
			\$("#$R::formid").val("");
		
		
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
		
		\$("#$R::formid").val(${R::formid}_storage[select.val()] + folder);
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
	my @storage = LoxBerry::Storage::get_storage($R::readwriteonly, $R::localdir);
	print to_json(\@storage);
	exit;
}