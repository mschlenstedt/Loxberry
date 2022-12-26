<?php
	require_once "loxberry_system.php";
	require_once "loxberry_log.php";
	
// Try to evaluate the plugin

$referrer_path = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_PATH);

if( $referrer_path != null ) {
	if( startsWith( $referrer_path, '/admin/system/' ) or startsWith( $referrer_path, '/system/' ) ) {
		$package = 'core';
		$log_filename = LBSTMPFSLOGDIR."/ajax-generic.log";
	}
	elseif( startsWith( $referrer_path, '/admin/plugins/' ) ) {
		list( , , $package ) = explode('/', $referrer_path, 4);
		$log_filename = LBHOMEDIR."/log/plugins/".$package."/ajax-generic.log";
	}
	elseif( 
		startsWith( $referrer_path, '/plugins/' ) ) {
		list( , $package ) = explode('/', $referrer_path, 3);
		$log_filename = LBHOMEDIR."/log/plugins/".$package."/ajax-generic.log";
	}
}
if( empty($package) ) {
	$package = 'core';
	$log_filename = LBSTMPFSLOGDIR."/ajax-generic.log";
}

$params = [
		"package" => $package,
		"name" => "Ajax-Generic",
		"filename" => $log_filename,
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
	LOGINF("HTTP Referrer: " . $referrer_path);
	# LOGDEB("_SERVER:" . print_r ($_SERVER, true) );
}

$errorstr = null;
$querytype = null;
$replace = false;

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

if( isset( $_GET['replace'] ) ) {
	$replace = true;
	$action = 'write';
}

if( empty($action) ) {
	$action = 'read';
}

LOGTITLE("$action request for $configfile");

LOGINF("Action is $action");
LOGINF("Replace is $replace");

// Read or write a specific section?
if( isset( $_GET['section'] ) ) {
	$section = $_GET['section'];
} else {
	$section = null;
}
if( $section ) {
	LOGINF("Using section $section");
}


if( $action == 'write' ) {

	// Get data from input
	if( $argc > 0) {
		LOGINF("Getting data from stdin (use a pipe to \"post\" data)");
		$input = file_get_contents('php://stdin');
	} else {
		LOGINF("Getting data from request");
		$input = file_get_contents('php://input');
	}
	LOGDEB("Request Input: $input");
	LOGINF("Checking if content is a json");
	$datajson = json_decode($input, false, 512, JSON_INVALID_UTF8_IGNORE | JSON_UNESCAPED_LINE_TERMINATORS | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
	if(!empty($datajson)) {
		$querytype = 'JSON';
		LOGOK("Request is json - can directly be used");
	} 
	else {
		$querytype = 'POST';
		LOGOK("Request is no json");
		$datajson = $_POST;
	}
}

// Open file and create exclusive lock
if( file_exists( $configfile ) ) {
	LOGINF("Opening file $configfile");
	$fp = fopen($configfile, 'r+');
	flock( $fp, LOCK_EX );
	$config = json_decode( file_get_contents( $configfile ), false, 512, JSON_INVALID_UTF8_IGNORE | JSON_UNESCAPED_LINE_TERMINATORS | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE );
}
else {
	LOGINF("File $configfile does not exist, fallback to empty config");
	$config = new stdClass();
}

// LOGDEB("Configfile content");
// LOGDEB(print_r( $config, true) );

if( $action == 'write' ) {
	
	// Section given
	if( $section ) {
		if( $replace != true ) {
			// Merge
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
			// Replace
			$config["$section"] = $datajson;
		}
	}
	
	
	// No section - full file
	else {
		if( $replace != true ) {
			// Merge
			$newconfig = array_replace_recursive($config, $datajson);
			if( $newconfig == null ) {
				LOGINF("Existing config was empty. Sent config gets new config.");
				$newconfig = $datajson;
			}
			$config = $newconfig;
		}
		else {
			// Replace
			$config = $datajson;
		}
	}
	
	// LOGDEB("Configfile after merge:");
	// LOGDEB(print_r( $config, true) );


	file_put_contents( $configfile, json_encode( $config , JSON_INVALID_UTF8_IGNORE | JSON_PRETTY_PRINT | JSON_UNESCAPED_LINE_TERMINATORS | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) );

	if( $fp ) {
		fclose($fp);
	}
	
	if( $configfile == LBSCONFIGDIR."/general.json" ) {
		LOGINF("This is a general.json update. Calling the legacy general.cfg update");
		$generalcfg_update = exec(LBHOMEDIR."/webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi action=recreate-generalcfg");
		if( $generalcfg_update == false ) {
			LOGWARN("recreate-generalcfg returned an error. The general.cfg possibly was not updated.");
		} else {
			LOGOK("recreate-generalcfg executed successfully.");
		}
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
	global $package;
	
	LOGDEB("checkPath $path");
	if( !isset( $path) ) {
		$errorstr = "file parameter missing. Exiting.";
		LOGERR($errorstr);
		return;
	}
	
	//Replace variables
	$path = str_replace( 
		[ '$lbhomedir', 'LBHOMEDIR', 'LBPCONFIG', '$lbsconfigdir', 'LBSCONFIG', 'LEGACY' ], 
		[ LBHOMEDIR,    LBHOMEDIR,   LBHOMEDIR.'/config/plugins', LBSCONFIGDIR, LBSCONFIGDIR, LBHOMEDIR.'/webfrontend/legacy' ],
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
	
	if( !startsWith( $realpath, getEnv('LBSCONFIG') ) and !startsWith( $realpath, getEnv('LBPCONFIG') ) and !startsWith( $realpath, getEnv('LBHOMEDIR').'/webfrontend/legacy' ) ) {
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
