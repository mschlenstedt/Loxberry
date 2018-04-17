#!/usr/bin/perl

use LoxBerry::Log;
use Getopt::Long;

# Collecting options
GetOptions (
	'action' => \$action,
	'package=s' => \$package,
	'name=s' => \$name,
	'filename=s' => \$logfilename,
	'logdir=s' => \$logdir,
	'append' => \$append,
	'nofile' => \$nofile,
	'stderr' => \$stderr,
	'stdout' => \$stdout,
	'message=s' => \$message,
	'loglevel=s' => \$loglevel,
);

if (!$action) { 
	init();
	start();
	exit(0);
}

$action = lc($action);

if( $action eq "init" ) {
	init();
	my $currfilename = $log->close;
	my $currloglevel = $log->loglevel;
	print "\"$currfilename\" $currloglevel\n";
	exit(0);
} elsif ( $action eq "start" ) {
	start();
	exit(0);
} elsif ( $action eq "end" ) {
	start();
	exit(0);
}

exit;

sub init
{

	my $log = LoxBerry::Log->new ( 
		package => $package, 
		name => $name,
		filename => $logfilename,
		logdir => $logdir,
		append => $append,
		nofile => $nofile,
		stderr => $stderr,
		stdout => $stdout,
	);
	my $currfilename = $log->close;
	my $currloglevel = $log->loglevel;
	print "\"$currfilename\" $currloglevel\n";
	}

sub start
{
	LOGSTART $message;
	
}

sub end
{
	LOGEND $message;
}
