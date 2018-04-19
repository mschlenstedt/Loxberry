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

if( $action eq "new" ) {
	init();
	my $currfilename = $log->close;
	my $currloglevel = $log->loglevel;
	print "\"$currfilename\" $currloglevel\n";
	exit(0);
} elsif ( $action eq "logstart" ) {
	init();
	start();
	exit(0);
} elsif ( $action eq "logend" ) {
	init();
	end();
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
	my $currfilename = $log->close;
	my $currloglevel = $log->loglevel;
	print "\"$currfilename\" $currloglevel\n";
}

sub end
{
	LOGEND $message;
}
