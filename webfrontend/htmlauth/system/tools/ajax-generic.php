<?php
	require_once "loxberry_system.php";
	require_once "loxberry_log.php";
	
/*
   On copying the script:
   You may need to adjust the logging "filename" parameter if you 
   encounter errors of the loxberry_log API
*/

$params = [
		"package" => "system",
		"name" => "Ajax-Generic",
		"filename" => LBSTMPFSLOGDIR."/ajax-generic.log",
		"append" => 1,
		"stderr" => 1,
		"addtime" => 1,
		"loglevel" => 7
		
	];
$log = LBLog::newLog ($params);

// For testing: Convert command line parameters to GET parameters
if( $argc > 0 ) {
	LOGSTART("Commandline request");
	parse_str(implode('&', array_slice($argv, 1)), $_GET);
	LOGDEB("ENV:" . implode( ",", $_ENV) );
} 
else {
	LOGSTART("HTTP Request");
}

$errorstr = null;
$querytype = null;

// Reading config file from url
$configfile = checkPath($_GET['file']);

if( empty($configfile) ) {
	LOGCRIT("Cannot execute ajax-generic without or with wrong config file parameter");
	echo "$errorstr";
	exit(1);
}


// What should we do: read or write
if( isset( $_GET['read'] ) ) {
		$action = 'read';
}
elseif( isset( $_GET['write'] ) ) {
		$action = 'write';
}

if( empty($action) ) {
	$action = 'read';
}

LOGTITLE("$action request for $configfile");

LOGINF("Action is $action");

// Read or write a specific section?
if( isset( $_GET['section'] ) ) {
	$section = $_GET['section'];
} else {
	$section = null;
}
if( $section ) {
	LOGINF("Using section $section");
}

// $data = array ();


// Get data from input
LOGINF("Getting data from request");
$input = file_get_contents('php://input');
LOGDEB("Request Input: $input");
LOGINF("Checking if content is a json");
$datajson = json_decode($input, true);
if(!empty($datajson)) {
	$querytype = 'JSON';
	LOGOK("Request is json - can directly be used");
} 
else {
	$querytype = 'POST';
	LOGOK("Request is no json");
	$datajson = $_POST;
}

// Open file and create exclusive lock
if( file_exists( $configfile ) ) {
	LOGINF("Opening file $configfile");
	$fp = fopen($configfile, 'r+');
	flock( $fp, LOCK_EX );
	$config = json_decode( file_get_contents( $configfile ), true );
}
else {
	LOGINF("File $configfile does not exist, fallback to empty config");
	$config = array();
}

LOGDEB("Configfile content");
LOGDEB(print_r( $config, true) );


if( $action == 'write' ) {
	
	if( $section ) {
		$newconfig = array_replace_recursive($config["$section"], $datajson);
		if( $newconfig == null ) {
			LOGINF("Existing config was empty. Sent config gets new config.");
			$config["$section"] = $datajson;
		}
		else {
			LOGINF("Existing config merged with new config.");
			$config["$section"] = $newconfig;
		}
	}
	else {
		$newconfig = array_replace_recursive($config, $datajson);
		if( $newconfig == null ) {
			LOGINF("Existing config was empty. Sent config gets new config.");
			$newconfig = $datajson;
		}
		$config = $newconfig;
	}
	
	LOGDEB("Configfile after merge:");
	LOGDEB(print_r( $config, true) );


	file_put_contents( $configfile, json_encode( $config , JSON_INVALID_UTF8_IGNORE | JSON_PRETTY_PRINT | JSON_UNESCAPED_LINE_TERMINATORS | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) );

	if( $fp ) {
		fclose($fp);
	}
}

// Prepare response
if( $section ) {
	LOGINF("Responding with Section $section");
	$responsedata = $config["$section"];
}
else {
	LOGINF("Responding with full config");
	$responsedata = $config;
}

// Send HTTP response
if( $errorstr ) {
	http_response_code(500);
	$responsestr = json_encode( $errorstr, JSON_INVALID_UTF8_IGNORE | JSON_UNESCAPED_LINE_TERMINATORS | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE );
}
else {
	http_response_code(200);
	if( $responsedata == null ) {
		$responsestr = '{}';
	}
	else {
		$responsestr = json_encode($responsedata, JSON_INVALID_UTF8_IGNORE | JSON_UNESCAPED_LINE_TERMINATORS | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE );
	}
}
echo $responsestr;
LOGDEB("Response data:");
LOGDEB(print_r( $responsestr, true) );

LOGEND();

	
function checkPath( $path ) {
	global $errorstr;
	LOGDEB("checkPath $path");
	if( !isset( $path) ) {
		$errorstr = "file parameter missing. Exiting.";
		LOGERR($errorstr);
		return;
	}
	
	//Replace variables
	$path = str_replace( 
		[ '$lbhomedir', 'LBHOMEDIR', 'LBPCONFIG', '$lbsconfigdir', 'LBSCONFIG' ], 
		[ LBHOMEDIR,    LBHOMEDIR,   LBHOMEDIR.'/config/plugins', LBSCONFIGDIR, LBSCONFIGDIR ],
		$path
	);
	
	$pathparts = pathinfo($path);
	$realpath = realpath($pathparts['dirname']);
	
	LOGDEB("realpath $realpath");
	
	// Check if the path is in config/ directory
	if( $realpath == false ) {
		$errorstr = "file parameter possibly contains non-existing directory";
		LOGERR($errorstr);
		return;
	}
	
	if( !startsWith( $realpath, getEnv('LBSCONFIG') ) and !startsWith( $realpath, getEnv('LBPCONFIG' ) ) ) {
		$errorstr = "file parameter path is not in a config directory ($realpath)";
		LOGERR($errorstr);
		return;
	}

	$realpath = $realpath.'/'.$pathparts['basename'];

	return $realpath;
	
}
	
	
function startsWith( $haystack, $needle ) {
	$length = strlen( $needle );
	return substr( $haystack, 0, $length ) === $needle;
}
