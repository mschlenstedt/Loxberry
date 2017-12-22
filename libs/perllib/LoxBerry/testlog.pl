#!/bin/perl

use LoxBerry::Log;

print "Hallo\n";

# my $log = LoxBerry::Log->new ( logdir => "$lbslogdir", name => 'test', package => 'Test', loglevel => 3);
my $log = LoxBerry::Log->new ( filename => "$lbslogdir/test.log", name => 'test', package => 'Test', loglevel => 3, append => 1);


LOGSTART "My test logging";

$log->ERR("Das ist ein Fehler!");
LOGERR "Das ist auch ein Fehler!";


LOGDEB "Debug";
LOGINF "Info";
LOGOK "OK";
LOGWARN "Warning";
LOGERR "Error";
LOGCRIT "Critical";
LOGALERT "Alert";
LOGEMERGE "Emergency";

LOGEND "Process finished";




# print "Filename is " . $log->filename . "\n";
