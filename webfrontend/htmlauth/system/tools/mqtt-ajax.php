<?php
// require_once "loxberry_system.php";
// $cfgfile = "$lbpconfigdir/mqtt.json";
// $jsoncontent = file_get_contents($cfgfile); 
// $json = json_decode($jsoncontent, True); 
// $udpinport = $json['Main']['udpinport'];

header('Content-Type: application/json; charset=UTF-8');

$cfgfile = "mqttgateway.json";
$datafile = "/dev/shm/mqttgateway_topics.json";
$ajax = !empty( $_POST['ajax'] ) ? $_POST['ajax'] : "";

if( $ajax == 'relayed_topics' ) {
	if( !empty($_POST['udpinport'] ) ) {
		$address = "udp://127.0.0.1:".$_POST['udpinport'];
		$socket = fsockopen($address);
		fwrite($socket, 'save_relayed_states' );
		
		// How to get a response via udp?
		// stream_set_blocking($socket, 0);
		// echo fread($socket, 10);
		fclose($socket);
	}
	
	if( file_exists( $datafile ) ) {
		readfile( $datafile );
	}
} 
elseif ( $ajax == 'retain' ) {
		
		if ( !empty($_POST['udpinport']) and $_POST['udpinport'] != "0") {
			$address = "udp://127.0.0.1:".$_POST['udpinport'];
			$socket = fsockopen($address);
			
			$dataToUDP = array(
				"topic" => $_POST['topic'],
				"retain" => true,
			);
			
			fwrite( $socket, json_encode($dataToUDP) );
			fclose( $socket );
		}
				
		if( file_exists( $datafile ) ) {
			readfile( $datafile );
		}
}
elseif ( $ajax == 'disablecache' ) {
	
	require_once "loxberry_system.php";
	$fullcfgfile = LBSCONFIGDIR.'/'.$cfgfile;
	$topic = $_POST['topic'];
	
	if( !file_exists( $fullcfgfile ) ) {
		error_log("File does not exist: " . $fullcfgfile);
	}
	$fp = fopen($fullcfgfile, "c");
	flock($fp, LOCK_EX);

	$cfg = json_decode( file_get_contents($fullcfgfile) );
	
	if( empty( $cfg ) ) {
		error_log( "JSON is empty");
		exit();
	}
	
	if( !is_enabled( $_POST['disablecache'] ) ) {
		unset($cfg->{'Noncached'}->{$topic});
	} else {
		$cfg->{'Noncached'}->{$topic} = "true";
	}
	
	file_put_contents( $fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_LINE_TERMINATORS|JSON_UNESCAPED_UNICODE) );
	flock($fp, LOCK_UN);
	fclose($fp);
	readfile( $fullcfgfile );
}	
elseif ( $ajax == 'resetAfterSend' ) {
	
	require_once "loxberry_system.php";
	$fullcfgfile = LBSCONFIGDIR.'/'.$cfgfile;
	$topic = $_POST['topic'];
	
	if( !file_exists( $fullcfgfile ) ) {
		error_log("File does not exist: " . $fullcfgfile);
	}
	$fp = fopen($fullcfgfile, "c");
	flock($fp, LOCK_EX);

	$cfg = json_decode( file_get_contents($fullcfgfile) );
	
	if( empty( $cfg ) ) {
		error_log( "JSON is empty");
		exit();
	}
	
	if( !is_enabled( $_POST['resetAfterSend'] ) ) {
		unset($cfg->{'resetAfterSend'}->{$topic});
	} else {
		$cfg->{'resetAfterSend'}->{$topic} = "true";
	}
	
	file_put_contents( $fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_LINE_TERMINATORS|JSON_UNESCAPED_UNICODE) );
	flock($fp, LOCK_UN);
	fclose($fp);
	readfile( $fullcfgfile );
}	
elseif ( $ajax == 'doNotForward' ) {
	
	require_once "loxberry_system.php";
	$fullcfgfile = LBSCONFIGDIR.'/'.$cfgfile;
	$topic = $_POST['topic'];
	
	if( !file_exists( $fullcfgfile ) ) {
		error_log("File does not exist: " . $fullcfgfile);
	}
	$fp = fopen($fullcfgfile, "c");
	flock($fp, LOCK_EX);

	$cfg = json_decode( file_get_contents($fullcfgfile) );
	
	if( empty( $cfg ) ) {
		error_log( "JSON is empty");
		exit();
	}
	
	if( !is_enabled( $_POST['doNotForward'] ) ) {
		unset($cfg->{'doNotForward'}->{$topic});
	} else {
		$cfg->{'doNotForward'}->{$topic} = "true";
	}
	
	file_put_contents( $fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_LINE_TERMINATORS|JSON_UNESCAPED_UNICODE) );
	flock($fp, LOCK_UN);
	fclose($fp);
	readfile( $fullcfgfile );
}	
elseif ( $ajax == 'getpids' ) {
	$pids['mqttgateway'] = trim(`pgrep mqttgateway.pl`) ;
	$pids['mosquitto'] = trim(`pgrep mosquitto`) ;
	
	$pids['mqttgateway'] = $pids['mqttgateway'] != 0 ? $pids['mqttgateway'] : null;
	$pids['mosquitto'] = $pids['mosquitto'] != 0 ? $pids['mosquitto'] : null;
	
	echo json_encode( array ('pids' => $pids ) );
	
}
elseif ( $ajax == 'mosquitto_purgedb' ) {
	// Purge Mosquitto DB
	exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=mosquitto_purgedb" );
}

elseif ( $ajax == 'restart_mosquitto' ) {

	# Restart Mosquitto
	exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=mosquitto_restart" );
}	

elseif( $ajax == "reconnect" ) {
	# Send Reconnect
	if (!empty($_POST['udpinport'])) {
		
		$msg = 'reconnect';
		$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
		socket_sendto($sock, $msg, strlen($msg), 0, 'localhost', $_POST['udpinport']);
		socket_close($sock);
	} else {
		error_log("MQTT index.cgi: Ajax reconnect FAILED\n");
	}
}

elseif( $ajax == 'publish_json' ) {
	# Publish by JSON
	require_once "loxberry_io.php";
	$mqttcred = mqtt_connectiondetails();
	$udpinport=$mqttcred['udpinport'];
	
	$pub_data = (object) array ( 
		'topic' => $_POST['topic'], 
		'value' => $_POST['value'], 
		'retain' => $_POST['retain'], 
		'transform' => $_POST['transform'] 
	);
	if( empty($_POST['transform']) ) {
		unset($pub_data->transform);
	}
	$pubdata_json = json_encode($pub_data);
	$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
	socket_sendto($sock, $pubdata_json, strlen($pubdata_json), 0, 'localhost', $udpinport);
	socket_close($sock);
	print $pubdata_json;
	exit(0);

}
	


