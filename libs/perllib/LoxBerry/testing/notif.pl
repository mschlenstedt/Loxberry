#!/usr/bin/perl
use LoxBerry::Log;
use strict;
use warnings;

$LoxBerry::Log::DEBUG = 1;

my $package = "NOTIFY";
my $group = "Test";
my $message = "äää ööö üüü ßßß";
#my $message = undef;


notify ( $package, $group, $message);



my $error = "This is an error message";

my %notification = (
            PACKAGE => "NOTIFY_EXT",                    # Mandatory
            NAME => "TestExt",                            # Mandatory        
            MESSAGE => "ÄÄÄ ÖÖÖ ÜÜÜ ßßß", # Mandatory
            SEVERITY => 3,
#            fullerror => "Access is denied: " . $error,
#            msnumber => 1,
#            logfile => $lbplogdir
    );
my $status = LoxBerry::Log::notify_ext( \%notification );
 
 
# # Error handling
# if (! $status) {
    # print STDERR "Error setting notification.";
# }

# LoxBerry::Log::get_notification_count("Extended", "Test");

# get_notifications("Extended", "Test");

# delete_notifications("Extended", "Test", 1);

# LoxBerry::Log::get_notification_count("Extended", "Test");
