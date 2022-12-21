#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Shelly RGB and WHITE control for RGB/W devices\n";
		echo "link=https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt/mqtt_gateway_udp_transformers/udp_transformer_shelly_rgbw_shipped\n";
		echo "input=text\n";
		echo "output=text\n";
		exit();
	}
	
	// ---- THIS CAN BE USED ALWAYS ----
	// Remove the script name from parameters
	array_shift($argv);
	// Join together all command line arguments
	$commandline = implode( ' ', $argv );	
	// Split topic and data by separator
	list( $topic, $data ) = explode( '#', $commandline, 2);
	// ----------------------------------
	
	list($command, $value_pct) = explode( ' ', $data);
	
	$data = array (	
		'effect' => 0,
		'turn' => 'on',
	);
	
	switch ($command) {
		// Color mode
		case 'white': 
			$white = round( $value_pct / 100 * 255 );
			$data['mode'] = "color";
			$data['gain'] = 100;
			$data['white'] = $white;
			break;

		case 'rgb':
			$rgb_pct = str_pad( $value_pct, 9, '0', STR_PAD_LEFT );
			$red = round( substr( $rgb_pct, -3, 3) / 100 * 255 );
			$green = round( substr( $rgb_pct, -6, 3) / 100 * 255 );
			$blue = round( substr( $rgb_pct, -9, 3) / 100 * 255 );
			$data['mode'] = "color";
			$data['gain'] = 100;
			$data['red'] = $red;
			$data['green'] = $green;
			$data['blue'] = $blue;
			break;

		case 'tunablew':
			$tunable = str_pad( $value_pct, 9, '0', STR_PAD_LEFT );
			$bright = substr( $tunable, -7, 3);
			$temp = substr( $tunable, -4, 4);
			// Normalize Lumitech 2700...6500 to Shelly 3000...6500
			$temp = round( 3000 + ( $temp-2700 ) * (6500-3000) / (6500-2700) );
			$data['mode'] = "white";
			$data['temp'] = $temp;
			$data['brightness'] = intval($bright);
			break;
		default:
			error_log('Transformer shelly_rgb&w: Wrong parameters (white or rgb missing)');
	}
	
	echo $topic."#".json_encode($data, JSON_UNESCAPED_UNICODE )."\n";
	