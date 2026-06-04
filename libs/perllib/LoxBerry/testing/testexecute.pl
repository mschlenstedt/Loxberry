#!/usr/bin/perl


use LoxBerry::Log;

print "Hallo\n";

my $log = LoxBerry::Log->new ( 
	filename => "$lbslogdir/test.log", 
	name => 'test', 
	package => 'Test', 
	loglevel => 7,
	stderr => 1,
);

LOGSTART "My test logging";
LOGINF "Info";

# Single command
my $exitcode;
my $output;

# # Single call
# ($exitcode, $output) = execute( 'ls -l /opt/loxberry' );
# LOGINF "Returned exitcode $exitcode";

# # Hash parameters
# ($exitcode, $output) = execute( { command => 'ls -l /opt/loxberry' } );
# LOGINF "Returned exitcode $exitcode";

# # With log object
# ($exitcode, $output) = execute( { 
	# command => 'ls -l /opt/loxberry',
	# log => $log,
# } );

# # with ok != 0
# ($exitcode, $output) = execute( { 
	# command => 'ls -l /opt/loxberry',
	# log => $log,
	# okcode => 1
# } );

# with ok != 0
($exitcode, $output) = execute( { 
	command => 'ls -l /opt/loxberry',
	log => $log,
	okcode => 1,
	intro => "Executing ls...",
	ok => "ls successful",
	warn => "ls failed"
} );




LOGINF "Returned exitcode $exitcode";




LOGEND "Process finished";
