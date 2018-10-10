#!/usr/bin/env php
<?php

require_once "loxberry_log.php";

$log = null;
$currfilename = null;
$currloglevel = null;

fwrite (STDERR, "initlog.php Commandline: " . implode(" ", $argv) . "\n");

# Collecting options
$longopts = array( "action:", 'package::', 'name::', 'filename::', 'logdir::', 'append::', 'nofile::', 'stderr::', 'stdout::', 'message::', 'loglevel::' );
$opt = getopt(null, $longopts);



// GetOptions (
	// 'action:s' => \$action,
	// 'package:s' => \$package,
	// 'name:s' => \$name,
	// 'filename:s' => \$logfilename,
	// 'logdir:s' => \$logdir,
	// 'append:s' => \$append,
	// 'nofile:s' => \$nofile,
	// 'stderr:s' => \$stderr,
	// 'stdout:s' => \$stdout,
	// 'message:s' => \$message,
	// 'loglevel:s' => \$loglevel,
// );

if (empty($opt["action"])) { 
	$opt["action"] = "logstart";
}

$opt["action"] = strtolower($opt["action"]);

if( $opt["action"] == "new" ) {
	fwrite( STDERR , "initlog.php: init\n");
	do_init();
	$currfilename = $log->close;
	$currloglevel = $log->loglevel;
	echo "\"$currfilename\" $currloglevel\n";
	exit(0);
} elseif ( $opt["action"] == "logstart" ) {
	fwrite (STDERR, "initlog.php: init\n");
	do_init();
	fwrite (STDERR, "initlog.php: start\n");
	do_logstart($opt["message"]);
	exit(0);
} elseif ( $opt["action"] == "logend" ) {
	fwrite(STDERR, "initlog.php: init\n");
	$opt["append"] = 1;
	do_init();
	fwrite(STDERR, "initlog.php: end\n");
	do_logend($opt["message"]);
	exit(0);
}

exit;

function do_init()
{
	global $log, $opt;
	
	fwrite(STDERR, "do_init()\n");
	
	$log = LBLog::newLog( $opt ); 
	
	if (!$log) {
		fwrite(STDERR, "Logfile not initialized.\n");
		exit(1);
	}
	
	$currfilename = $log->filename;
	$currloglevel = $log->loglevel;
	fwrite(STDERR, "Output to bash:  \"$currfilename\" $currloglevel\n");
	echo "\"$currfilename\" $currloglevel\n";
	
	}

function do_logstart($message = "")
{
	global $log;
	
	fwrite(STDERR, "do_logstart($message)\n");
	
	$log->LOGSTART($message);
#	my $currfilename = $log->close;
#	my $currloglevel = $log->loglevel;
#	print "\"$currfilename\" $currloglevel\n";
}

function do_logend($message = "")
{
	global $log;
	
	fwrite(STDERR, "do_logend($message)\n");
	
	
	# print STDERR "End: Filename: " . $log->filename . "\n";
	$log->LOGEND($message);
}
