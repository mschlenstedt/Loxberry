#!/usr/bin/perl

use LoxBerry::Log;
use Getopt::Long;

# Collecting options
GetOptions (
	'package=s' => \$package,
	'name=s' => \$name,
	'filename=s' => \$logfilename,
	'logdir=s' => \$logdir,
	'append' => \$append,
	'nofile' => \$nofile,
	'stderr' => \$stderr,
	'message=s' => \$message,
	'loglevel=s' => \$loglevel,
);

my $log = LoxBerry::Log->new ( 
	package => $package, 
	name => $name,
	filename => $logfilename,
	logdir => $logdir,
	append => $append,
	nofile => $nofile,
	stderr => $stderr,
);

LOGSTART $message;
my $currfilename = $log->close;
my $currfilename = $log->loglevel;
print "\"$filename\" $currloglevel";

exit;
