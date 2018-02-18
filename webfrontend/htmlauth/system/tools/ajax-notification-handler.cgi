#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard/;
use Scalar::Util qw(looks_like_number);
use DBI;
use LoxBerry::Log;
use JSON;

# my $bins = LoxBerry::System::get_binaries();

my $cgi = CGI->new;
$cgi->import_names('R');

# print $cgi->header;


# Prevent 'only used once' warning
if (! $R::action) {
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "500 Method not supported",
	);
	exit;
}

my $action = $R::action;

print STDERR "--> ajax-notification-handler:\nAction: $action\n";

if ($action eq 'notify-deletekey') {notifydelete();}

else {
	print $cgi->header(-type => 'application/json;charset=utf-8', -status => "500 Action not supported");
	exit;
}

exit;

###################################################################
# Delete notify
###################################################################
sub notifydelete
{
	
	if (! $R::value) {
		print $cgi->header(-type => 'application/json;charset=utf-8',
							-status => "500 Key is missing");
		exit;
	}
	
	$R::value =~ s/[\/\\]//g;
	
	LoxBerry::Log::delete_notification_key($R::value);
	
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "200 OK");
	exit;
	
}
