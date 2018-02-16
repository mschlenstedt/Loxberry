#!/usr/bin/perl
use LoxBerry::Log;
use strict;
use warnings;

my $package = "test";
my $group = "testing";
my $message = "Testmessage";
#my $message = undef;


notify ( $package, $group, $message );



my $error = "This is an error message";

my %notification = (
            package => "Extended",                    # Mandatory
            name => "Test",                            # Mandatory        
            message => "error connecting to the Miniserver", # Mandatory
            severity => 3,
            fullerror => "Access is denied: " . $error,
            msnumber => 1,
            logfile => $lbplogdir
    );
my $status = LoxBerry::Log::notify_ext( \%notification );
 
 
# Error handling
if (! $status) {
    print STDERR "Error setting notification.";
}