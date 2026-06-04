#!/usr/bin/env php
<?php

require_once "loxberry_log.php";

$initlog_version = "2.0.0.1";

$INITLOG_DEBUG = 0;

$log = null;
$currfilename = null;
$currloglevel = null;

if($INITLOG_DEBUG) fwrite (STDERR, "initlog.php Commandline: " . implode(" ", $argv) . "\n");

# Collecting options
$longopts = array( 
			'action:', 
			'package::', 
			'name::', 
			'filename::', 
			'logdir::', 
			'append::', 
			'nofile::', 
			'stderr::', 
			'stdout::', 
			'message::', 
			'loglevel::',
			'logtitle::',
			'status::',
			'dbkey::',
			'attentionmessages::',
);
$opt = getopt(null, $longopts);

if (empty($opt["action"])) { 
	$opt["action"] = "logstart";
}

$opt["action"] = strtolower($opt["action"]);

switch($opt["action"]) {
	case "new":
		if($INITLOG_DEBUG) fwrite( STDERR , "initlog.php: action new\n");
		do_init();
		return_stdout();
		exit(0);
		break;
	case "logstart":
		if($INITLOG_DEBUG) fwrite( STDERR , "initlog.php: action logstart\n");
		do_init();
		do_logstart();
		return_stdout();
		exit(0);
		break;
	case "logend":
		if($INITLOG_DEBUG) fwrite( STDERR , "initlog.php: action logend\n");
		$opt["append"] = 1;
		do_init();
		do_logend();
		exit(0);
		break;
	default: 
		fwrite( STDERR , "initlog.php: action unknown (Action: " . $opt["action"] . "\n");
}

exit;

function do_init()
{
	global $log, $opt, $INITLOG_DEBUG;
	
	if($INITLOG_DEBUG) fwrite(STDERR, "do_init()\n");
	
	$log = LBLog::newLog( $opt ); 
	
	if (!$log) {
		fwrite(STDERR, "Logfile not initialized.\n");
		exit(1);
	}
}

function do_logstart()
{
	global $log, $opt, $INITLOG_DEBUG;
		
	if($INITLOG_DEBUG) fwrite(STDERR, "do_logstart()\n");
	
	$log->LOGSTART($opt["message"]);
#	my $currfilename = $log->close;
#	my $currloglevel = $log->loglevel;
#	print "\"$currfilename\" $currloglevel\n";
}

function do_logend()
{
	global $log, $opt, $INITLOG_DEBUG;
	
	if($INITLOG_DEBUG) fwrite(STDERR, "do_logend()\n");
	
	do_status();
	do_attentionmessages();
	
	if(!isset($opt["message"])) { 
		$opt["message"]="";
	}
	
	$log->LOGEND($opt["message"]);
}

function do_status()
{
	global $log, $opt, $INITLOG_DEBUG;
	
	if($INITLOG_DEBUG) fwrite(STDERR, "do_status()\n");
	
	if(isset($opt["status"])) {
			$log->STATUS($opt["status"]);
	}
}

function do_attentionmessages()
{
	global $log, $opt, $INITLOG_DEBUG;
	
	if($INITLOG_DEBUG) fwrite(STDERR, "do_attentionmessages()\n");
	
	if(isset($opt["attentionmessages"])) {
			$log->ATTENTIONMESSAGES($opt["attentionmessages"]);
	}
}

function return_stdout()
{
	global $log, $opt, $INITLOG_DEBUG;
	
	if($INITLOG_DEBUG) fwrite(STDERR, "return_stdout()\n");
	
	
	$currfilename = $log->filename;
	$currloglevel = $log->loglevel;
	if($INITLOG_DEBUG) fwrite(STDERR, "DEBUG: " . $log->dbkey . "\n");
	
	$currdbkey = $log->dbkey ? $log->dbkey : "";
	if($INITLOG_DEBUG) fwrite(STDERR, "Output to bash:  \"$currfilename\" $currloglevel $currdbkey\n");
	echo "\"$currfilename\" $currloglevel $currdbkey\n";
	
}