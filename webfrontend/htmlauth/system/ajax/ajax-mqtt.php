<?php
require_once "loxberry_system.php";
// $cfgfile = "$lbpconfigdir/mqtt.json";
// $jsoncontent = file_get_contents($cfgfile);
// $json = json_decode($jsoncontent, True);
// $udpinport = $json['Main']['udpinport'];

/* CA cert download must run before JSON header */
$_ajax_early = !empty($_GET['ajax']) ? $_GET['ajax'] : (!empty($_POST['ajax']) ? $_POST['ajax'] : '');
if ($_ajax_early === 'mqtt_tls_ca_download') {
    $cafile = '/etc/mosquitto/tls/ca.crt';
    if (file_exists($cafile) && is_readable($cafile)) {
        header('Content-Type: application/x-x509-ca-cert');
        header('Content-Disposition: attachment; filename="mqtt_ca.crt"');
        readfile($cafile);
    } else {
        http_response_code(404);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'MQTT CA certificate not found']);
    }
    exit;
}

header('Content-Type: application/json; charset=UTF-8');

/* If started from the command line, wrap parameters to $_POST and $_GET */
if (!isset($_SERVER["HTTP_HOST"])) {
  parse_str($argv[1], $_POST);
}

$cfgfile = "mqttgateway.json";
$datafile = "/dev/shm/mqttgateway_topics.json";
$finderdatafile = "/dev/shm/mqttfinder.json";

$ajax = !empty( $_POST['ajax'] ) ? $_POST['ajax'] : "";
$ajax = empty($ajax) ? $_GET['ajax'] : $ajax;

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
	
	if( is_array($cfg->{'resetAfterSend'}) ) {
		$cfg->{'resetAfterSend'} = new stdClass();
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
	$gw_pid = trim(`pgrep mqttgateway.pl`);
	if (!$gw_pid) {
		// V2: use PID file written by mqtt_gateway.py on startup
		$v2_pidfile = '/dev/shm/mqtt_gateway.pid';
		if (file_exists($v2_pidfile)) {
			$v2_pid = trim(file_get_contents($v2_pidfile));
			if ($v2_pid && is_numeric($v2_pid) && file_exists("/proc/$v2_pid")) {
				$gw_pid = $v2_pid;
			}
		}
	}
	$pids['mqttgateway'] = $gw_pid ?: null;

	// Determine broker mode from general.json
	$generalcfg = json_decode(file_get_contents(LBSCONFIGDIR.'/general.json'), true);
	$uselocalbroker = isset($generalcfg['Mqtt']['Uselocalbroker']) ? $generalcfg['Mqtt']['Uselocalbroker'] : 'true';

	if (is_enabled($uselocalbroker)) {
		// Local Mosquitto
		$pids['mosquitto']    = trim(`pgrep mosquitto`) ?: null;
		$pids['mosq_custom']  = false;
	} else {
		// Custom broker — TCP reachability check
		$brokerhost = $generalcfg['Mqtt']['Brokerhost'] ?? 'localhost';
		$brokerport = (int)($generalcfg['Mqtt']['Brokerport'] ?? 1883);
		$fp = @fsockopen($brokerhost, $brokerport, $errno, $errstr, 3);
		if ($fp) {
			fclose($fp);
			$pids['mosq_reachable'] = true;
		} else {
			$pids['mosq_reachable'] = false;
		}
		$pids['mosquitto']   = null;
		$pids['mosq_custom'] = true;
		$pids['mosq_host']   = $brokerhost . ':' . $brokerport;
	}

	echo json_encode( array ('pids' => $pids ) );

}

elseif ( $ajax == 'mosquitto_purgedb' ) {
	// Purge Mosquitto DB
	exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=mosquitto_purgedb" );
}

elseif ( $ajax == 'restart_mosquitto' ) {
	exec("nohup sudo $lbhomedir/sbin/mqtt-handler.pl action=mosquitto_restart > /dev/null 2>&1 &");
	echo json_encode(array('status' => 'ok'));
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

elseif( $ajax == "clearcache" ) {
	# Clear the send-cache (V2 gateway). Replaces the old "reconnect" meaning,
	# which now resends all values instead of clearing the cache.
	if (!empty($_POST['udpinport'])) {
		$msg = 'clearcache';
		$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
		socket_sendto($sock, $msg, strlen($msg), 0, 'localhost', $_POST['udpinport']);
		socket_close($sock);
		echo json_encode(array('status' => 'ok'));
	} else {
		echo json_encode(array('status' => 'error', 'message' => 'udpinport missing'));
	}
}

elseif( $ajax == "resend_all" ) {
	# Resend ALL cached values to the Miniserver(s), ignoring the dedup cache.
	if (!empty($_POST['udpinport'])) {
		$msg = 'resend';
		$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
		socket_sendto($sock, $msg, strlen($msg), 0, 'localhost', $_POST['udpinport']);
		socket_close($sock);
		echo json_encode(array('status' => 'ok'));
	} else {
		echo json_encode(array('status' => 'error', 'message' => 'udpinport missing'));
	}
}

elseif( $ajax == "resend_one" ) {
	# Resend a single cached value (by virtual-input name) to its Miniserver(s).
	if (!empty($_POST['udpinport']) && !empty($_POST['vi'])) {
		$msg = 'resend ' . $_POST['vi'];
		$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
		socket_sendto($sock, $msg, strlen($msg), 0, 'localhost', $_POST['udpinport']);
		socket_close($sock);
		echo json_encode(array('status' => 'ok'));
	} else {
		echo json_encode(array('status' => 'error', 'message' => 'udpinport or vi missing'));
	}
}

elseif( $ajax == "mosquitto_set" ) {
	exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=mosquitto_set" );
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
	$sentbytes = socket_sendto($sock, $pubdata_json, strlen($pubdata_json), 0, 'localhost', $udpinport);
	socket_close($sock);
	if( $sentbytes != false ) {	
		print $pubdata_json;
	} else {
		print '{ "error" : "Socket no data sent" }';
	}
	exit(0);

}

elseif( $ajax == 'restartgateway' ) {
	exec("nohup sudo $lbhomedir/sbin/mqtt-handler.pl action=restartgateway > /dev/null 2>&1 &");
	echo json_encode(array('status' => 'ok'));
}

elseif( $ajax == 'stop_gateway' ) {
	exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=stopgateway" );
	echo json_encode(array('status' => 'ok'));
}

elseif( $ajax == 'stop_mosquitto' ) {
	exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=stopmosquitto" );
	echo json_encode(array('status' => 'ok'));
}

elseif( $ajax == 'getmqttfinderdata' ) {
	$fp = @fopen($finderdatafile, "r");
	if( $fp && flock($fp, LOCK_SH) ) {
		echo fread($fp, 5*1024*1024);
		fclose($fp);
	}
	else {
		header("HTTP/1.0 404 Not Found");
	}
}

elseif ( $_POST['ajax'] == 'get_subscriptions_v2' || $_GET['ajax'] == 'get_subscriptions_v2' ) {
    $cfgfile = 'mqttgateway.json';
    $fullcfgfile = LBSCONFIGDIR.'/'.$cfgfile;

    if (file_exists($fullcfgfile)) {
        $cfg = json_decode(file_get_contents($fullcfgfile), true);
        $subs = isset($cfg['subscriptions_v2']) ? $cfg['subscriptions_v2'] : array();
        header('Content-Type: application/json');
        echo json_encode(array('subscriptions_v2' => $subs));
    } else {
        header('Content-Type: application/json');
        echo json_encode(array('subscriptions_v2' => array()));
    }
}

elseif ( $_POST['ajax'] == 'save_subscriptions_v2' ) {
    $cfgfile = 'mqttgateway.json';
    $fullcfgfile = LBSCONFIGDIR.'/'.$cfgfile;

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || !isset($input['subscriptions_v2'])) {
        http_response_code(400);
        echo json_encode(array('error' => 'Missing subscriptions_v2 data'));
        exit;
    }

    $fp = fopen($fullcfgfile, "c");
    if (!$fp) {
        error_log("mqtt-ajax: Could not open $fullcfgfile");
        http_response_code(500);
        exit;
    }
    flock($fp, LOCK_EX);
    $cfg = json_decode(file_get_contents($fullcfgfile), true);
    if (!$cfg) $cfg = array();

    $cfg['subscriptions_v2'] = $input['subscriptions_v2'];

    file_put_contents($fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    flock($fp, LOCK_UN);
    fclose($fp);

    header('Content-Type: application/json');
    echo json_encode(array('status' => 'ok', 'count' => count($input['subscriptions_v2'])));
}

elseif ( $_POST['ajax'] == 'get_subscriptions' || $_GET['ajax'] == 'get_subscriptions' ) {
    $fullcfgfile = LBSCONFIGDIR.'/subscriptions.json';
    header('Content-Type: application/json');
    if (file_exists($fullcfgfile)) {
        $cfg = json_decode(file_get_contents($fullcfgfile), true);
        echo json_encode($cfg ?: array('Subscriptions' => array()));
    } else {
        echo json_encode(array('Subscriptions' => array()));
    }
}

elseif ( $_POST['ajax'] == 'save_subscriptions' || $_GET['ajax'] == 'save_subscriptions' ) {
    $fullcfgfile = LBSCONFIGDIR.'/subscriptions.json';
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || !isset($input['Subscriptions'])) {
        http_response_code(400);
        header('Content-Type: application/json');
        echo json_encode(array('error' => 'Missing Subscriptions data'));
        exit;
    }
    $written = file_put_contents($fullcfgfile, json_encode($input, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), LOCK_EX);
    if ($written === false) {
        http_response_code(500);
        exit;
    }
    header('Content-Type: application/json');
    echo json_encode(array('status' => 'ok', 'count' => count($input['Subscriptions'])));
}

elseif ( $ajax == 'scan_miniservers' ) {
    // "Miniserver scannen": liest die virtuellen Eingänge aus der Programmdatei
    // der Miniserver. Liest nur - sendet nichts an den Miniserver und schreibt
    // keine Konfiguration. Ersetzt die frühere V1->V2-Migration.
    $cmd = 'timeout 240 python3 ' . escapeshellarg("$lbhomedir/bin/mqtt-scan-miniserver.py");
    $output = [];
    $rc = 0;
    exec($cmd . ' 2>/dev/null', $output, $rc);
    $result = json_decode(implode("\n", $output), true);
    if ( !is_array($result) ) {
        http_response_code(500);
        echo json_encode([ 'miniservers' => new stdClass(), 'error' => 'internal', 'detail' => "scan exited with code $rc" ]);
        exit;
    }

    // Topics aus der V1-Übersicht: auch Topics, die V1 weitergeleitet hat,
    // der Finder aber gerade nicht kennt
    $v1topics = [];
    $statusfile = '/dev/shm/mqttgateway_topics.json';
    if ( file_exists($statusfile) ) {
        $status = json_decode( file_get_contents($statusfile), true, 512, JSON_INVALID_UTF8_SUBSTITUTE );
        foreach ( [ 'http', 'udp' ] as $section ) {
            foreach ( $status[$section] ?? [] as $key => $content ) {
                $topic = $content['originaltopic'] ?? $key;
                if ( !isset($v1topics[$topic]) ) {
                    $v1topics[$topic] = (string)($content['message'] ?? '');
                }
            }
        }
    }
    $result['v1topics'] = (object)$v1topics;

    // V1-Einstellungen je Eingang, damit sie beim Übernehmen erhalten bleiben
    $v1flags = [ 'noncached' => [], 'resetaftersend' => [] ];
    $gwcfgfile = LBSCONFIGDIR . '/mqttgateway.json';
    if ( file_exists($gwcfgfile) ) {
        $gwcfg = json_decode( file_get_contents($gwcfgfile), true, 512, JSON_INVALID_UTF8_SUBSTITUTE );
        foreach ( [ 'noncached' => 'Noncached', 'resetaftersend' => 'resetAfterSend' ] as $flag => $cfgkey ) {
            foreach ( $gwcfg[$cfgkey] ?? [] as $vi => $value ) {
                if ( $value === 'true' || $value === true ) $v1flags[$flag][] = (string)$vi;
            }
        }
    }
    $result['v1flags'] = $v1flags;

    echo json_encode($result, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
}

elseif ( $ajax == 'get_status_v2' ) {
    $f = '/dev/shm/mqttgatwayv2_status.json';
    header('Content-Type: application/json');
    echo file_exists($f) ? file_get_contents($f) : '{}';
}

elseif ( $ajax == 'mqtt_tls_cert_create' ) {
	$result = shell_exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=mqtt_create_cert 2>/dev/null");
	echo $result ?: json_encode(['success' => false, 'error' => 'No response from handler']);
}

elseif ( $ajax == 'mqtt_tls_cert_revoke' ) {
	$result = shell_exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=mqtt_revoke_cert 2>/dev/null");
	echo $result ?: json_encode(['success' => false, 'error' => 'No response from handler']);
}

elseif ( $ajax == 'mqtt_tls_cert_status' ) {
	$result = shell_exec("sudo $lbhomedir/sbin/mqtt-handler.pl action=mqtt_cert_status 2>/dev/null");
	echo $result ?: json_encode(['exists' => false]);
}

elseif ( $ajax == 'mqtt_external_ca_upload' ) {
	if (!isset($_FILES['cafile']) || $_FILES['cafile']['error'] !== UPLOAD_ERR_OK) {
		$err_code = isset($_FILES['cafile']) ? $_FILES['cafile']['error'] : -1;
		echo json_encode(['success' => false, 'error' => "Upload error (code $err_code)"]);
		exit;
	}
	$content = file_get_contents($_FILES['cafile']['tmp_name']);
	if (strpos($content, '-----BEGIN CERTIFICATE-----') === false) {
		echo json_encode(['success' => false, 'error' => 'Invalid format — PEM certificate expected']);
		exit;
	}
	$dest = LBSCONFIGDIR . '/mqtt_external_ca.crt';
	if (move_uploaded_file($_FILES['cafile']['tmp_name'], $dest)) {
		echo json_encode(['success' => true]);
	} else {
		echo json_encode(['success' => false, 'error' => 'Could not save certificate']);
	}
}

elseif ( $ajax == 'mqtt_external_ca_delete' ) {
	$cafile = LBSCONFIGDIR . '/mqtt_external_ca.crt';
	if (file_exists($cafile)) {
		unlink($cafile);
	}
	echo json_encode(['success' => true]);
}

elseif ( $ajax == 'mqtt_external_ca_status' ) {
	$cafile = LBSCONFIGDIR . '/mqtt_external_ca.crt';
	if (file_exists($cafile) && is_readable($cafile)) {
		$content = file_get_contents($cafile);
		$subject = '';
		if (function_exists('openssl_x509_parse')) {
			$certinfo = openssl_x509_parse($content);
			if ($certinfo) {
				$subject = $certinfo['subject']['CN'] ?? ($certinfo['subject']['O'] ?? '');
			}
		}
		echo json_encode(['exists' => true, 'subject' => $subject]);
	} else {
		echo json_encode(['exists' => false]);
	}
}

// Unknown request
else {
	http_response_code(500);
	if( empty($ajax) ) {
		error_log("mqtt-ajax.php: ERRROR: ajax not set.");
	} else {
		error_log("mqtt-ajax.php: ERRROR: ajax=$ajax is unknown.");
	}
}
