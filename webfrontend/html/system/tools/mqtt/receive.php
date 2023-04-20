<?php
	require_once "loxberry_system.php";
	require_once "loxberry_io.php";
	require_once "loxberry_log.php";
	
/*
   On copying the script:
   You may need to adjust the logging "filename" parameter if you 
   encounter errors of the loxberry_log API
*/

$params = [
		"package" => "MQTT",
		"name" => "Receiver",
		"filename" => LBSTMPFSLOGDIR."/mqtt_http_receiver.log",
		"append" => 1,
		"stdout" => 1,
		"addtime" => 1,
		"loglevel" => 7
		
	];
$log = LBLog::newLog ($params);
LOGSTART("HTTP Receiver Request");

$data = array ();

// Get data from input
LOGINF("Getting data from request");
$input = file_get_contents('php://input');
LOGDEB("$input");
LOGINF("Checking if content is a json");
$datajson = json_decode($input, true);
if(!empty($datajson)) {
	LOGOK("Data is json - can directly be used");
	$data['BODY'] = $datajson;
} else {
	LOGOK("Data is no json");
}

if( $argc > 1 ) {
	LOGINF("Call from command line. Converting commandline parameters to GET variables");
	// Convert commandline parameters to $_GET
	array_shift($argv);
	foreach ($argv as $arg) {
		LOGDEB("   Commandline argument: $arg");
		$e=explode("=",$arg);
		if(count($e)==2)
			$_GET[$e[0]]=$e[1];
		else   
			$_GET[$e[0]]=0;
	}
} 

if( isset($_SERVER['REMOTE_HOST']) ) {
	$topic = $_SERVER['REMOTE_HOST'];
	// Truncate FQDN to single hostname
	$dotpos = strpos($topic, ".");
	if( $dotpos != FALSE ) {
		$topic = substr( $topic, 0, $dotpos);
	}
} elseif ( isset($_SERVER['REMOTE_ADDR']) ) {
	$topic = $_SERVER['REMOTE_ADDR'];
} else {
	$topic = 'local';
}

$topic="rcvr/".$topic;

LOGOK("Used topic is '$topic'");
LOGTITLE("Message from $topic");

$data['REMOTEHOST'] = isset($_SERVER['REMOTE_HOST']) ? $_SERVER['REMOTE_HOST'] : "";
$data['REMOTEADDR'] = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : "";
$data['loxtime'] = epoch2lox();

// Loop get variables
LOGINF("Looping through GET variables");
$counter = 0;
foreach($_GET as $variable => $value) {
   LOGDEB("   Variable '$variable': '$value'");
   $data['GET'][$variable] = $value;
   $counter++;
}
LOGOK("GET: $counter variables added");

LOGINF("Looping through POST variables");
$counter = 0;
foreach($_POST as $variable => $value) {
   LOGDEB("   Variable '$variable': '$value'");
   // Check if variable content is a json
   $postjson = json_decode($value, true);
   if(!empty($postjson)) {
	   LOGINF("POST variable $variable used as json");
	   $data['POST'][$variable] = $postjson;
   }
   else {
	  $data['POST'][$variable] = $value;
   }
   $counter++;
}
LOGOK("POST: $counter variables added");

send_udp($topic, $data);

// Send HTTP response
http_response_code(200);

LOGEND();

	
function send_udp($topic, $data)
{
	
	LOGINF("Querying MQTT Gateway UDP port");
	
	$mqttcred = mqtt_connectiondetails();
	if( empty($mqttcred['udpinport']) ) {
		LOGCRIT("Could not read UDP IN port of MQTT Gateway. Check the UDP configuration in MQTT Gateway widget.");
		return;
	}
	$udpport = $mqttcred['udpinport'];
	LOGOK("MQTT Gateway UDP-Port is $udpport");
	
	LOGINF("Opening UDP socket to MQTT Gateway");
	$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
	if(!$sock) {
		LOGCRIT("Could not create UDP socket");
		return;
	}
	
	$send['topic'] = $topic;
	$send['value'] = json_encode($data, JSON_UNESCAPED_UNICODE);
	
	if( !defined('PUBLISH') ) {
		LOGOK("Data will be sent as RETAIN");
		$send['retain'] = true;
	} else {
		LOGOK("Data will sent as PUBLISH");
	}
	
	$sendjson = json_encode($send, JSON_UNESCAPED_UNICODE);
	$len = strlen($sendjson);

    $sent = socket_sendto($sock, $sendjson, $len, 0, '127.0.0.1', $udpport);
	if($sent < 0) {
		LOGCRIT("Nothing sent. Sending function returned $sent");
		return;
	}
	LOGOK("$sent bytes sent by UDP");
    socket_close($sock);
	
}
