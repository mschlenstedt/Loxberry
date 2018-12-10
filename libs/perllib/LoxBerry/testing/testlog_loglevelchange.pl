#!/usr/bin/perl


use LoxBerry::Log;

print "Hallo\n";

# my $log = LoxBerry::Log->new ( logdir => "$lbslogdir", name => 'test', package => 'Test', loglevel => 3);
my $log = LoxBerry::Log->new ( 
	filename => "/opt/loxberry/log/plugins/lbbackup/test.log", 
	name => 'test', 
	package => 'lbbackup', 
	stderr => 1,
	addtime => 1,
);

while(1) {
	LOGINF "Hallo";
	sleep(10);
}
