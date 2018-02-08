#!/usr/bin/perl
use LoxBerry::Log;
use strict;
use warnings;

print "\nTest Notification\n";
print "=================\n";
print "Documentation of notify for Perl: http://www.loxwiki.eu:80/x/eQd7AQ\n\n";
print "All tests are using package 'test' and groupname 'testing'\n\n";
print "Notification directory is: " . $LoxBerry::Log::notification_dir . "\n\n";

print "TEST: Setting two info, one error notification\n";

my $package = "test";
my $group = "testing";
my $message;

$message = "This is the first information notification";
notify ( $package, $group, $message);
sleep(1);
$message = "This is the second information notification";
notify ( $package, $group, $message);
sleep(1);
$message = "This is an error notification";
notify ( $package, $group, $message, 1);
print "Notifications created\n";
# exit(0);

print "TEST: Check notification count\n";
my ($check_err, $check_ok, $check_sum) = get_notification_count( $package, $group);

print "We have $check_err errors and $check_ok infos, together $check_sum notifications.\n";

print "TEST: Get all notifications of package test with content:\n";

my @notifications = get_notifications( $package); 
for my $notification (@notifications ) {
	 my ($contentraw, $contenthtml) = notification_content($notification->{KEY});
    if ( $notification->{SEVERITY} ) {
        print STDERR "     Error at $notification->{DATESTR} in group $notification->{NAME}:\n$contentraw\n";
    } else {
        print STDERR "     Info at $notification->{DATESTR} in group $notification->{NAME}:\n$contentraw\n";
    }
}

print "TEST: Delete all but least notification\n";
delete_notifications($package, undef, 1);
print "Re-request notifications (without content):\n";
@notifications = get_notifications($package); 
for my $notification (@notifications ) {
    if ( $notification->{SEVERITY} ) {
        print STDERR "     Error at $notification->{DATESTR} in group $notification->{NAME}.\n";
    } else {
        print STDERR "     Info at $notification->{DATESTR} in group $notification->{NAME}.\n";
    }
}

print "TEST: Delete all notifications of package test:\n";
delete_notifications($package);
print "TEST: Get notification count:\n";
($check_err, $check_ok, $check_sum) = get_notification_count( $package, $group);
print "We have $check_err errors and $check_ok infos, together $check_sum notifications.\n";

print "\nTESTS FINISHED.\n";
