#!/usr/bin/perl


use LoxBerry::System;

print "Setting first 'reboot.required':\n";

reboot_required("This is the first test message from testrebootrequired.pl - ignore it.");

print "Setting a second 'reboot.required':\n";

reboot_required("This is the second test message from testrebootrequired.pl - ignore it.");
