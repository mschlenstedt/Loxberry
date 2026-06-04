#!/usr/bin/perl


use LoxBerry::Log;

print "Hallo\n";

LOGSTART "My test logging";

LOGERR "Das ist auch ein Fehler!";
LOGDEB "Debug";
LOGINF "Info";
LOGOK "OK";

print "Finished.\n";