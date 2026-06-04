<?php

/*
	This is the LoxBerry implementation of encrypted Miniserver communication, including token-based authentication.
	
	The scripts acts as a transparent gateway in combination with Apache.
	Apache traps unencrypted requests, this script forwards it to the Miniserver encrypted and token-based. 
	The output is returned to the calling plugin.
*/

require_once "loxberry_system.php";
require_once "loxberry_log.php";

// Create a logging object
$log = LBLog::newLog([ 
	"package" => "core", 
	"name" => "Secure Communication",
	"filename" => "$lbslogdir/commsecure.log",
	//"append" => 1,
]);

LOGSTART ("New secure request");

LOGINF ("Test");

// Parsing incoming request (needs to be finished when Apache config is created

$cmd = "$_SERVER[REQUEST_URI]";
