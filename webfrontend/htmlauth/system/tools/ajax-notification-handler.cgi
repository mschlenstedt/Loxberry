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

print STDERR "--> ajax-notification-handler:\n   Action: $action\n" if ($LoxBerry::Log::DEBUG);

if ($action eq 'notify-deletekey') {notifydelete();}
elsif ($action eq 'get_notifications') {getnotifications();}
elsif ($action eq 'get_notification_count') {getnotificationcount();}
elsif ($action eq 'get_notifications_html') {getnotificationshtml();}
elsif ($action eq 'notifyext') {setnotifyext();}

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
	print '{"status": "OK"}';
	exit;
	
}

sub getnotifications 
{
	
	$R::package if (0);
	$R::name if (0);
	
	
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "200 OK");
					
	my @notifications = get_notifications($R::package, $R::name);
	
	print JSON->new->encode(\@notifications);
	
	exit;

}


sub getnotificationcount
{
	
	$R::package if (0);
	$R::name if (0);
	
	
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "200 OK");
					
	my @notification_count = get_notification_count($R::package, $R::name);
	
	print JSON->new->encode(\@notification_count);
	
	exit;

}


sub setnotifyext 
{
	
	$R::package if (0);
	$R::name if (0);
	
	
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "200 OK");
					
	$cgi->delete('action');
	
	my %params = $cgi->Vars;
	
	#$LoxBerry::Log::DEBUG = 1;
	LoxBerry::Log::notify_ext(\%params);
	
	print '{"status": "OK"}';
	
	exit;

}


sub getnotificationshtml
{
	
	$R::package if (0);
	$R::name if (0);
	$R::buttons if (0);
	$R::type if (0);
	
	
	my $html = LoxBerry::Log::get_notifications_html($R::package, $R::name, $R::type, $R::buttons);
	
	if (! $html) {
		print $cgi->header(-type => 'text/html;charset=utf-8',
							-status => "204 No notifications found");
		exit;
	}
	
	print $cgi->header(-type => 'text/html;charset=utf-8',
						-status => "200 OK");
	print $html;
	
	exit;

}
