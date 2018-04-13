#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard/;
#use Scalar::Util qw(looks_like_number);
#use DBI;
#use LoxBerry::Log;
use JSON;

# my $bins = LoxBerry::System::get_binaries();

my $cgi = CGI->new;

# DEBUG parameters from POST
# my @names = $cgi->param;
# foreach my $name (@names) {
	# print STDERR "Parameter $name is " . $cgi->param($name) . "\n";
# }

$cgi->import_names('R');

# my %headers = map { $_ => $cgi->http($_) } $cgi->http();

# print STDERR $cgi->header('text/plain');
# print STDERR "Got the following headers:\n";
# for my $header ( keys %headers ) {
    # print STDERR "$header: $headers{$header}\n";
# }


# Prevent 'only used once' warning
if (! $R::action) {
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "500 Method not supported",
	);
	exit;
}

my $action = $R::action;

print STDERR "--> ajax-storage-handler:\n   Action: $action\n" if ($LoxBerry::Log::DEBUG);

# if ($action eq 'notify-deletekey') {notifydelete();}
# elsif ($action eq 'get_notifications') {getnotifications();}
# elsif ($action eq 'get_notification_count') {getnotificationcount();}
# elsif ($action eq 'get_notifications_html') {getnotificationshtml();}
# elsif ($action eq 'notifyext') {setnotifyext();}

# else {
	# print $cgi->header(-type => 'application/json;charset=utf-8', -status => "500 Action not supported");
	# exit;
# }

exit;
