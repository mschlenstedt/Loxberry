#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Do very flexible http and https requests\n";
		echo "link=https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt/mqtt_gateway_udp_transformers/udp_transformer_http2mqtt\n";
		echo "input=json\n";
		echo "output=json\n";
		exit();
	}
	
	// Remove the script name from parameters
	array_shift($argv);
	// Join together all command line arguments
	$commandline = implode( ' ', $argv );	
	// Parse json into an array
	$dataset = json_decode( $commandline, 1 );
	// Get the first element of the array
	$topic = array_key_first($dataset);
	$data = $dataset[$topic];
	
	$curlOptArr = array();
	$curlHeaderArr = array();
	
	$paramArr = explode( ' ', $data );
	
	
	$paramsFinal = false;
	$postData = array();
	
	foreach( $paramArr as $key => $value ) {
		$transParamArr = explode( ":", $value, 2);
		$transParam = strtolower($transParamArr[0]);
		$transVal = $transParamArr[1];
		if( empty( $transParam ) || empty( $transVal ) ) {
			continue;
		}
		
		switch ( $transParam ) {
			case "content-type": 
				$curlHeaderArr[] = "Content-Type: $transVal"; 
				break;
			case "start":
				$start = $transVal;
				break;
			case "length":
				$length = $transVal;
				break;
			case "method": // Query method GET, POST, PUT
				$querytype = $transVal;
				break;
			case "timeout":
				$timeout = $transVal;
				break;
			default:
				$paramsFinal = true;
		}
		if( $paramsFinal == true ) {
			$postData[] = $value;
		}
	}
	
	$querytype = !empty( $querytype ) ? $querytype : "GET";
	$start = !empty( $start ) ? $start : 0;
	$length = !empty( $length ) ? $length : 2500;
	$timeout = !empty( $timeout ) ? $timeout : 5;

	$curlOptArr[CURLOPT_URL] = $paramArr[0];
	$curlOptArr[CURLOPT_TIMEOUT] = $timeout;
	$curlOptArr[CURLOPT_RETURNTRANSFER] = 1;
	$curlOptArr[CURLOPT_HTTPAUTH] = CURLAUTH_ANY;
	$curlOptArr[CURLOPT_HTTPHEADER] = $curlHeaderArr;
	$curlOptArr[CURLOPT_SSL_VERIFYPEER] = false;
	$curlOptArr[CURLOPT_SSL_VERIFYHOST] = false;

	$curlOptArr[CURLOPT_COOKIEJAR] = "/dev/shm/http2mqtt_curl_cookies.tmp";
	$curlOptArr[CURLOPT_COOKIEFILE] = "/dev/shm/http2mqtt_curl_cookies.tmp";
	
	if( strtolower($querytype) == "post" ) {
		$curlOptArr[CURLOPT_POST] = true;
		$curlOptArr[CURLOPT_POSTFIELDS] = implode( ' ', $postData );
	} elseif ( strtolower($querytype) == "put" ) {
		$curlOptArr[CURLOPT_CUSTOMREQUEST] = 'PUT';
		$curlHeaderArr[] = "Content-Length: " . strlen( implode( ' ', $postData ) ); 
		$curlOptArr[CURLOPT_POSTFIELDS] = implode( ' ', $postData );
	}

	$ch = curl_init();
	curl_setopt_array( $ch, $curlOptArr );
	
	$result=curl_exec ($ch);
	$status_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);   //get status code
	curl_close ($ch);
	
	$jsonstr = isJson($result);
	$result = !empty($jsonstr) ? $jsonstr : substr( $result, $start, $length );
	
	if( empty ($result) ) {
		unset($dataset[$topic]);
	}
	else {
		$dataset[$topic] = $result;
	}
	
	$dataset["$topic/_httpstatus"] = $status_code;
	// Output data as json
	echo json_encode( $dataset, JSON_UNESCAPED_UNICODE );
	
	// Thank you and good bye
	exit;

function isJson($string) {
	$string = trim($string);
	if($string[0] !== '[' && $string[0] !== '{') { 
        $string = substr($string, strpos($string, '('));
		$string = trim($string);
		$string = trim($string, ';');
		$string = trim($string,'()');
    }
	if($string[0] !== '[' && $string[0] !== '{') { 
		return false;
	}
	$jsonobj = json_decode($string);
	if( json_last_error() == JSON_ERROR_NONE ) {
		return json_encode( $jsonobj, JSON_UNESCAPED_UNICODE );
	}
	return false;
}