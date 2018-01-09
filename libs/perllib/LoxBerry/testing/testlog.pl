#!/usr/bin/perl


use LoxBerry::Log;

print "Hallo\n";

# my $log = LoxBerry::Log->new ( logdir => "$lbslogdir", name => 'test', package => 'Test', loglevel => 3);
my $log = LoxBerry::Log->new ( 
	filename => "$lbslogdir/test.log", 
	name => 'test', 
	package => 'Test', 
	loglevel => 7,
	stderr => 1,
);

print "Log object created.\n";
print "Filename is " . $log->filename . "\n";

LOGSTART "My test logging";

$log->ERR ("Das ist ein Fehler!");
LOGERR "Das ist auch ein Fehler!";
LOGDEB "Debug";
LOGINF "Info";
LOGOK "OK";
my $filename = $log->close;
system("ls / -l >> $filename");
$log->open;
LOGWARN "Warning";
LOGERR "Error";
LOGCRIT "Critical";
LOGALERT "Alert";
LOGEMERGE "Emergency";
LOGEND "Process finished";

my $log2 = LoxBerry::Log->new ( 
	filename => "$lbslogdir/test2.log", 
	name => 'test', 
	package => 'Test', 
	loglevel => 7,
	stderr => 1,
	addtime => 1,
);
$log2->LOGSTART ("Logfile 2 started");
$log2->ERR ("Das ist ein Fehler!");
$log2->LOGEND ("Logfile 2 finished");
