#!/usr/bin/perl
use LoxBerry::Log;

my $log = LoxBerry::Log->new ( 
	filename => "$lbslogdir/test.log", 
	name => 'test', 
	package => 'Test', 
	loglevel => 7,
	stderr => 1,
	nosession => 1,
	append => 1
);

LOGSTART "Test";

for( my $i = 1; $i <= 1000; $i++ ) {
	LOGERR "This is a test message number $i";
}

LOGEND;
