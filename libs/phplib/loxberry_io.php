<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

$mem_sendall_sec = 3600;
$mem_sendall = 0;
$udp_delimiter = '=';

$LBIOVERSION = "2.2.1.1";

// msudp_send
function msudp_send($msnr, $udpport, $prefix, $params)
{
	global $udpsocket;
	
	if(empty($udpport) || $udpport > 65535) {
		error_log("UDP port $udpport invalid or not defined\n");
		return 0;
	}
	
	$ms = LBSystem::get_miniservers();
	if (!isset($ms[$msnr])) {
		error_log("Miniserver $msnr not defined\n");
		return 0;
	}
	if (!empty($prefix)) {
		$prefix = "$prefix: ";
	} else {
		$prefix = "";
	}
	
	// Handle socket
	if (!isset($udpsocket)) {
		// check if this is IPv4 or IPv6 address, or unknown
		$is_v6 = is_enabled( $ms[$msnr]['IPv6Format'] );
		if( !$is_v6 ) {
			$is_v4 = filter_var( $ms[$msnr]['IPAddress'] );
		}
		// error_log("Is V6: $is_v6 Is V4: $is_v4");
		
		// Try IPv4
		if( !$is_v6 ) {
			$udpsocket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
			if( $udpsocket === FALSE ) {
				$ipv4_failed = socket_last_error($udpsocket);
				socket_clear_error($udpsocket); 
				if (!$is_v4) {
					$is_v6 = true;
				}
			}
		}
		if( $is_v6 ) {
			$udpsocket = socket_create(AF_INET6, SOCK_DGRAM, SOL_UDP);
			if( $udpsocket === FALSE ) {
				$ipv6_failed = socket_last_error($udpsocket);
				socket_clear_error($udpsocket); 
			}
		}
		
		if($udpsocket == NULL) {
			$error = "Could not create udp socket: ";
			if($ipv4_failed) {
				$error .= "IPv4: $ipv4_failed ";
			}
			if($ipv6_failed) {
				$error .= "IPv6: $ipv6_failed ";
			}
			error_log($error);
			return 0;
		}
	}
	
	// Handle sending a raw string
	if(!is_array($params)) {
		$message = substr($prefix.$params, 0, 250);
		$udpresp = _udp_send($udpsocket, $message, $ms[$msnr]['IPAddress'], $udpport);
		if(!empty($udpresp)) {
			return 0;
		} else {
			return "OK";
		}
	}
	// Handle sending multiple values
	$parinline = 0;
	$udperror = 0;
	$line = "";
	foreach ($params as $param => $value) {
		// echo "Param: $param Value $value\n";
		$parinline++;
		$oldline = $line;
		$line .= $param . $udp_delimiter . $value . ' ';
		// echo "Line: $line\n";
		$currlen = strlen($prefix) + strlen($line);
		if ($parinline == 1 && $currlen > 220) {
			// If this is the first parameter and it is to long - skip
			error_log("msudp_send: Line with one parameter is too long. Parameter $param Value $value skipped.");
			$line = $oldline;
			$udperror = 1;
			continue;
		}
		if ($currlen > 220) {
			// If we've reached the max length, send the old line
			$message = $prefix.$oldline;
			$udpresp = _udp_send($udpsocket, $message, $ms[$msnr]['IPAddress'], $udpport);
			if(!empty($udpresp)) {
				$udperror = 1;
			}
			$line = $param . $udp_delimiter . $value . ' ';
			$parinline = 1;
		}
	}

	// Send the rest if $line has items
	if (!empty($line)) {
		$message = $prefix.$line;
		$udpresp = _udp_send($udpsocket, $message, $ms[$msnr]['IPAddress'], $udpport);
		if(!empty($udpresp)) {
			$udperror = 1;
		}
	}
	
	// Return
	if($udperror != 0) {
		return Null;
	} else {
		return "OK";
	}
}

// _udp_send (internal)
function _udp_send($udpsocket, $message, $ip, $udpport)
{
	// echo "Send message: $message\n";
	$udperror = Null;
	$udpsent = socket_sendto($udpsocket, $message, strlen($message), 0, $ip, $udpport);	
	if ($udpsent == NULL) {
		$udperror = "socket_sentto returned an error. ";
	}
	return $udperror;
}
// msudp_send_mem
function msudp_send_mem($msnr, $udpport, $prefix, $params)
{
	global $mem_sendall_sec;
	global $mem_sendall;
	
	$memfile = "/run/shm/msudp_mem_${msnr}_${udpport}.json";
	
	if(empty($udpport) || $udpport > 65535) {
		error_log("UDP port $udpport invalid or not defined\n");
		return 0;
	}
	
	if(file_exists($memfile)) {
		// echo "Read file\n";
		$jsonstr = file_get_contents($memfile);
		if(isset($jsonstr)) {
			$mem = json_decode($jsonstr, true);
		}
	}
	
	// Section is defined by the prefix
	if(empty($prefix)) {
		$prefixsection = "Params";
	} else {
		$prefixsection = $prefix;
	}
	// echo "Prefixsection: $prefixsection\n";
	
	if(empty($mem['Main']['timestamp'])) {
		// echo "Set new timestamp\n";
		$mem['Main']['timestamp'] = time();
	}
	if( $mem['Main']['timestamp'] < (time()-$mem_sendall_sec) ) {
		// echo "timestamp requires resending\n";
		$mem_sendall = 1;
	}
	
	if ( empty($mem['Main']['lastMSRebootCheck']) || $mem['Main']['lastMSRebootCheck'] < (time()-300)) {
		// Check if Miniserver was rebooted after 5 minutes
		$mem['Main']['lastMSRebootCheck'] = time();
		list($newtxp, $code) = mshttp_call($msnr, "/dev/lan/txp");
		// echo "newtxp: $newtxp Code: $code\n";
		if($code == "200" && ( !isset($mem['Main']['MSTXP']) || $newtxp < $mem['Main']['MSTXP']) ) {
			$mem_sendall = 1;
			$mem['Main']['MSTXP'] = $newtxp;
		}
	}
	//echo "mem_sendall: $mem_sendall\n";
	
	if( $mem_sendall <> 0 ) {
		$mem_main_tmp = $mem['Main'];
		$mem = Null;
		$mem['Main'] = $mem_main_tmp;
		$mem['Main']['timestamp'] = time();
		$mem_sendall = 0;
	}
	
	$newparams = array();
	
	foreach ($params as $param => $value) {
		if( !isset($mem[$prefixsection][$param]) || $mem[$prefixsection][$param] !== $value ) {
			// Param has changed
			// echo "Param changed: $param = $value\n";
			$newparams[$param] = $value;
		}
	}
	
	if(!empty($newparams)) {
		$udpres = msudp_send($msnr, $udpport, $prefix, $newparams);
		if ($udpres != null) {
			if(!isset($mem[$prefixsection])) {
				$mem[$prefixsection] = array();
			}
			$mem[$prefixsection] = array_merge($mem[$prefixsection], $newparams);
			// array_push($mem['Params'], $newparams);
			//echo "AFTER:\n";
			//echo var_dump($mem);
			$jsonstr = json_encode( $mem, JSON_PRETTY_PRINT, 20);
			file_put_contents($memfile, $jsonstr);
			chown($memfile, "loxberry");
			chgrp($memfile, "loxberry");
			
		}
	} else {
		$udpres = "cached";
	}
	
	return $udpres;
}

// mshttp_call
function mshttp_call($msnr, $command) 
{
	$ms = LBSystem::get_miniservers();
	if (!isset($ms[$msnr])) {
		error_log("Miniserver $msnr not defined\n");
		return array (null, 601, null);
	}
	
	$FullURI = $ms[$msnr]['FullURI'];
	
	$url = $FullURI . $command;
	
	$ch = curl_init($url); 
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	curl_setopt($ch, CURLOPT_HEADER, false);
	curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
	curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
	$resp = curl_exec($ch);
	$curl_code = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
	curl_close($ch);
	
	if($curl_code != 200) {	
   // echo "Errors occured\n";
		error_log("mshttp_call: Error fetching $url: HTTP $curl_code");
		return array (null, 500, null);
	}
	
	preg_match ( '/value\=\"(.*?)\"/' , $resp, $matches );
	$value = $matches[1];
	preg_match ( '/Code\=\"(.*?)\"/' , $resp, $matches );
	$code = $matches[1];
			
	return array ($value, $code, $resp);
	
}

// mshttp_get
function mshttp_get($msnr, $inputs)
{
	$ms = LBSystem::get_miniservers();
	if (!isset($ms[$msnr])) {
		error_log("Miniserver $msnr not defined or configuration not finished\n");
		return;
	}
	
	if(!is_array($inputs)) {
		$inputs = array ( $inputs );
		$input_was_string = true;
	}
	
	foreach ($inputs as $input) {
		// echo "Querying param: $input\n";
		list($respvalue, $respcode, $rawdata) = mshttp_call($msnr, "/dev/sps/io/" . rawurlencode($input) . '/all'); 
		echo "Responseval: $respvalue Respcode: $respcode\n";
		if($respcode == 200) {
			// Workaround for analogue outputs always return 0
			$respvalue_filtered = filter_var( $respvalue, FILTER_SANITIZE_NUMBER_FLOAT, FILTER_FLAG_ALLOW_FRACTION );
			// echo "respvalue_filtered: $respvalue_filtered\n";
			if( $respvalue_filtered != "" && $respvalue_filtered == 0) {
				if( strpos( $rawdata, '<output name="' ) == FALSE ) {
					# Not found - we require to request the value without /all
					list($respvalue, $respcode, $rawdata) = mshttp_call($msnr, "/dev/sps/io/" . rawurlencode($input) ); 
				}
			}
			$response[$input] = $respvalue;
		} else {
			$response[$input] = null;
		}
	}
	
	if (isset($input_was_string)) {
		
		return array_values($response)[0];
	} else {
		return $response;
	}
}

// mshttp_send
function mshttp_send($msnr, $inputs, $value = null)
{
	
	$ms = LBSystem::get_miniservers();
	if (!isset($ms[$msnr])) {
		error_log("Miniserver $msnr not defined or configuration not finished\n");
		return;
	}
	
	if(!is_array($inputs)) {
		if($value === null) {
			error_log("mshttp_send: Input string provided, but value missing");
			return;
		}
		// echo "Input is flat\n";
		$inputs = [ $inputs => $value ];
		$input_was_string = true;
	}
	
	foreach ($inputs as $input => $val) {
		// echo "Sending param: $input = $val \n";
		list($respvalue, $respcode) = mshttp_call($msnr, '/dev/sps/io/' . rawurlencode($input) . '/' . rawurlencode($val)); 
		// echo "Responseval: $respvalue Respcode: $respcode\n";
		if($respcode == 200) {
			$response[$input] = $respvalue;
		} else {
			$response[$input] = null;
		}
	}
	
	if (isset($input_was_string)) {
		
		return array_values($response)[0];
	} else {
		return $response;
	}
}

// mshttp_send_mem
function mshttp_send_mem($msnr, $params, $value = null)
{
	global $mem_sendall_sec;
	global $mem_sendall;
	
	$memfile = "/run/shm/mshttp_mem_${msnr}.json";
	
	if(file_exists($memfile)) {
		// echo "Read file\n";
		$jsonstr = file_get_contents($memfile);
		if(isset($jsonstr)) {
			$mem = json_decode($jsonstr, true);
		}
	}
	
	if(empty($mem['Main']['timestamp'])) {
		$mem['Main']['timestamp'] = time();
	}
	
	if( $mem['Main']['timestamp'] < (time()-$mem_sendall_sec) ) {
		$mem_sendall = 1;
	}
	
	if ( empty($mem['Main']['lastMSRebootCheck']) || $mem['Main']['lastMSRebootCheck'] < (time()-300)) {
		// Check if Miniserver was rebooted after 5 minutes
		$mem['Main']['lastMSRebootCheck'] = time();
		list($newtxp, $code) = mshttp_call($msnr, "/dev/lan/txp");
		// echo "newtxp: $newtxp Code: $code\n";
		if($code == "200" && ( !isset($mem['Main']['MSTXP']) || $newtxp < $mem['Main']['MSTXP']) ) {
			$mem_sendall = 1;
			$mem['Main']['MSTXP'] = $newtxp;
		}
	}
	//echo "mem_sendall: $mem_sendall\n";
	
	if( $mem_sendall <> 0 ) {
		$mem['Params'] = Null;
		$mem['Main']['timestamp'] = time();
		$mem_sendall = 0;
	}
	
	if(!is_array($params)) {
		if($value === null) {
			error_log("mshttp_send_mem: Input string provided, but value missing");
			return;
		}
		// echo "Input is flat\n";
		$params = [ $params => $value ];
		$input_was_string = true;
	}
	
	
	$newparams = array();
	
	foreach ($params as $param => $value) {
		if( !isset($mem['Params'][$param]) || $mem['Params'][$param] !== $value ) {
			// Param has changed
			// echo "Param changed: $param = $value\n";
			$newparams[$param] = $value;
		}
	}
	
	if(!empty($newparams)) {
		$httpres = mshttp_send($msnr, $newparams);
		if ($httpres != null) {
			if(!isset($mem['Params'])) {
				$mem['Params'] = array();
			}
			$mem['Params'] = array_merge($mem['Params'], $newparams);
			$jsonstr = json_encode( $mem, JSON_PRETTY_PRINT, 20);
			file_put_contents($memfile, $jsonstr);
			chown($memfile, "loxberry");
			chgrp($memfile, "loxberry");
		}
	}
	
	// We need to generate a response for all values if it came from ram
	foreach ($params as $param => $value) {
		if(isset($mem['Params'][$param])) {
			$httpres[$param] = $value;
		}
	}
	
	if (isset($input_was_string)) {
		return array_values($httpres)[0];
	} else {
		return $httpres;
	}
}


// ##################################################################################
// # MQTT functions                                                                 #
// ##################################################################################

// Read MQTT connection details and credentials from MQTT plugin
function mqtt_connectiondetails() {

	# Check if MQTT Gateway plugin is installed
	$mqttplugindata = LBSystem::plugindata("mqttgateway");
	$pluginfolder = $mqttplugindata['PLUGINDB_FOLDER'];
	if(empty($pluginfolder)) {
		return;
	}

	// $mqttconf;
    // $mqttcred;
	
		# Read connection details
		$mqttconf = json_decode(file_get_contents(LBHOMEDIR . "/config/plugins/" . $pluginfolder . "/mqtt.json" ));
		$mqttcred = json_decode(file_get_contents(LBHOMEDIR . "/config/plugins/" . $pluginfolder . "/cred.json" ));

	if( $mqttconf === FALSE || $mqttcred === FALSE ) {
		error_log("loxberry_io connectiondetails: Failed to read/parse connection details");
		return;
	}
	
	$cred = array ();
	
	@list($brokerhost, $brokerport) = explode(':', $mqttconf->{'Main'}->{'brokeraddress'}, 2);
	$brokerport = $brokerport ? $brokerport : 1883;
	$cred['brokeraddress'] = $brokerhost.":".$brokerport;
	$cred['brokerhost'] = $brokerhost;
	$cred['brokerport'] = $brokerport;
	$cred['brokeruser'] = $mqttcred->Credentials->brokeruser;
	$cred['brokerpass'] = $mqttcred->Credentials->brokerpass;
	$cred['udpinport'] = $mqttconf->Main->udpinport;
	return $cred;

}





?>