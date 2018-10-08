#!/usr/bin/perl


use LoxBerry::Log;

print "Hallo\n";

# my $log = LoxBerry::Log->new ( logdir => "$lbslogdir", name => 'test', package => 'Test', loglevel => 3);
my $log = LoxBerry::Log->new ( 
	#filename => "$lbslogdir/test.log", 
	logdir => '/tmp',
	name => 'test', 
	package => 'Test', 
	loglevel => 7,
	stderr => 1,
);

print "DB key is: " . $log->dbkey . "\n";
print "Filename is: " . $log->filename . "\n";
LOGSTART "Start des Logs";
LOGINF "Erste Session";

print "DB key is: " . $log->dbkey . "\n";

#LOGEND "Finished";

#print "DB key is: " . $log->dbkey . "\n";
my $old_dbkey = $log->dbkey;

undef $log;

print "Recreating log object\n";
my $log = LoxBerry::Log->new ( 
	dbkey => $old_dbkey,
	#loglevel => 6,
	#stderr => 1,
);

print "New log filename: " . $log->filename() . "\n";
print "DB key is: " . $log->dbkey . "\n";
print "Loglevel is: " . $log->loglevel . "\n";
LOGINF "Weiter gehts!";
LOGEND;
