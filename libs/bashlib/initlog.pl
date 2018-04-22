#!/usr/bin/perl

use LoxBerry::Log;
use Getopt::Long;

my $log;

# Collecting options
GetOptions (
	'action:s' => \$action,
	'package:s' => \$package,
	'name:s' => \$name,
	'filename:s' => \$logfilename,
	'logdir:s' => \$logdir,
	'append:s' => \$append,
	'nofile:s' => \$nofile,
	'stderr:s' => \$stderr,
	'stdout:s' => \$stdout,
	'message:s' => \$message,
	'loglevel:s' => \$loglevel,
);

if (!$action) { 
	init();
	start();
	exit(0);
}

$action = lc($action);

if( $action eq "new" ) {
	# print STDERR "initlog.pl: init\n";
	init();
	my $currfilename = $log->close;
	my $currloglevel = $log->loglevel;
	print "\"$currfilename\" $currloglevel\n";
	exit(0);
} elsif ( $action eq "logstart" ) {
	# print STDERR "initlog.pl: init\n";
	init();
	# print STDERR "initlog.pl: start\n";
	start();
	exit(0);
} elsif ( $action eq "logend" ) {
	# print STDERR "initlog.pl: init\n";
	$append = 1;
	init();
	# print STDERR "initlog.pl: end\n";
	end();
	exit(0);
}

exit;

sub init
{

	$log = LoxBerry::Log->new ( 
		package => $package, 
		name => $name,
		filename => $logfilename,
		logdir => $logdir,
		append => $append,
		nofile => $nofile,
		stderr => $stderr,
		stdout => $stdout,
	);
	
	if (! $log) {
		print STDERR "Logfile not initialized.\n";
	}
	
	
	#my $currfilename = $log->close;
	my $currloglevel = $log->loglevel;
	print "\"$currfilename\" $currloglevel\n";
	
	}

sub start
{
	LOGSTART $message;
#	my $currfilename = $log->close;
#	my $currloglevel = $log->loglevel;
#	print "\"$currfilename\" $currloglevel\n";
}

sub end
{
	# print STDERR "End: Filename: " . $log->filename . "\n";
	LOGEND $message;
}
