#!/usr/bin/php
<?php
	if( @$argv[1] == 'skills' ) {
		echo "description=Calculates moving average, minimum, maximum and sum\n";
		echo "link=https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt/mqtt_gateway_udp_transformers/udp_transformer_moving_minmaxavg\n";
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

	require_once "loxberry_system.php";
	require_once "loxberry_json.php";
	
	
	// Read params
	$params = array();
	$inputParams = explode(" ", $data);
	foreach( $inputParams as $key => $param ) {
		@list( $option, $val ) = explode( ":", $param, 2);
		switch( $option ) {
			case "base":
				$base = strtolower($val);
				break;
			case "range":
				$range = $val;
				break;
			case "set":
				$newvalue = $val;
				break;
			case "get":
				$newvalue = null;
				break;
			default:
				$error = 1;
		}
	}

	$calc = new CALCULATIONS( $topic );
	if( isset($base) && isset($range) ) {
		error_log("ranging called");
		$calc->ranging( $range, $base );
	}
	if( !is_null($newvalue) ) {
		error_log("set called");
		$calc->set( $newvalue );
	}
	$calc->get();
	
	
	echo $topic."#".json_encode($calc->store->Result, JSON_UNESCAPED_UNICODE)."\n";
	echo $topic."_Settings#".json_encode($calc->store->Settings, JSON_UNESCAPED_UNICODE)."\n";
	


function filter_filename($name) {
    // remove illegal file system characters https://en.wikipedia.org/wiki/Filename#Reserved_characters_and_words
    $name = str_replace(array_merge(
        array_map('chr', range(0, 31)),
        array('<', '>', ':', '"', '/', '\\', '|', '?', '*', '.', "'")
    ), '', $name);
    // maximise filename length to 255 bytes http://serverfault.com/a/9548/44086
    return $name;
}


class CALCULATIONS
{
	
	private $datastorefolder = LBSBINDIR.'/mqtt/datastore';
	public $datastorefile;
	public $store;
	public $starttime;
	public $currenttime;
	public $range_time;
	public $range_count;
	
	public function __construct($topic)
	{
		if( empty($topic) ) {
			throw new Exception('Topic needs to be defined');
		}
		
		// Open datastore
		$this->datastorefile = $this->datastorefolder.'/moving_minmax_'.filter_filename($topic).'.json';
		if( !file_exists( $this->datastorefile ) ) {
			@mkdir( $this->datastorefolder );
			file_put_contents( $this->datastorefile, "{}" );
		}
		// $this->store = new LBJSON($this->datastorefile);
		$this->store = json_decode( file_get_contents( $this->datastorefile ) );
		

		$this->range_count = isset( $this->store->Settings->range_count ) ? $this->store->Settings->range_count : null;
		$this->range_time = isset( $this->store->Settings->range_time ) ? $this->store->Settings->range_time : null;
		$this->range_base = isset( $this->store->Settings->range_base ) ? $this->store->Settings->range_base : null;
	}

	public function __destruct () 
	{
		file_put_contents( $this->datastorefile, json_encode( $this->store, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE ) );
	}

	public function set( $value ) 
	{
		$newdataset = new StdClass();
		$newdataset->value = $value;
		$newdataset->timestamp = time();
		
		@error_log("set elements before: " . count($this->store->dataset));
		$this->store->dataset[] = $newdataset;
		@error_log("set elements after : " . count($this->store->dataset));
		
	}
	
	public function get() 
	{
		$outofrange=0;
		// Delete obsolete entries
		error_log("get elements before : " . count($this->store->dataset) . " Range count: " . $this->range_count);
		
		if( $this->range_base == 'count' ) {
			$count = count( $this->store->dataset );
			$elements_to_splice = $count - $this->range_count;
		}
		elseif ( $this->range_base == 'time' ) {
			$elements_to_splice = 0;
			foreach( $this->store->dataset as $index => $element ) {
				if( $element->timestamp < time()-$this->range_time ) {
					$elements_to_splice++;
				}
			}
			// Special handling: if the latest element is also out of time range, keep it anyway 
			if( $elements_to_splice == count( $this->store->dataset ) ) {
				$elements_to_splice--;
				$outofrange = 1;
			}
		}
		
		if( $elements_to_splice > 0) {
				array_splice( $this->store->dataset, 0, $elements_to_splice);
			}
		
		// Calculate values
		
		$avg = null;
		$max = null;
		$min = null;
		$sum = 0;
		$timesum = 0;
		$count = 0;
		$last_val = null;
		$last_timestamp = null;
		$first_timestamp = null;
		
		foreach( $this->store->dataset as $index => $element ) {
			error_log("Dataset Index $index: " . $element->value);
			$count++;
			if( $this->range_base == 'time' ) {
				if( $count > 1 ) {
					$timediff = $element->timestamp - $last_timestamp;
					$timesum += $last_val * $timediff;
				} 
				else {
					$first_timestamp = $element->timestamp;
				}
				$last_val = $element->value;
				$last_timestamp = $element->timestamp;
			}
			
			
			$sum += $element->value;
			$max = empty($max) || ($element->value > $max) ? $element->value : $max;
			$min = empty($min) || ($element->value < $min) ? $element->value : $min;
		}


		if( $this->range_base == 'count' ) {
			error_log('get calculate count average');
			$avg = $sum/$count;
		} 
		elseif ( $this->range_base == 'time' ) {
			$timesum += $last_val * (time()-$last_timestamp);
			$timediff = time()-$first_timestamp;
			error_log("avg Timediff: $timediff $timesum");
			$avg = $timediff != 0 ? $timesum/$timediff : $last_val;
		
		}

		$result = array( 
			"min" => $min,
			"max" => $max,
			"sum" => $sum,
			"avg" => $avg,
			"count" => $count,
			"outofrange" => $outofrange
		);
		
		$this->store->Result = $result;
			
	}
	
	public function ranging($range=null, $base='count') 
	{
	
		// Getter
		if($range == null) {
			if( $this->range_base == 'time' ) {
				return $this->range_time;
			}
			elseif ( $this->range_base == 'count' ) {
				return $this->range_count;
			}
			else {
				return null;
			}
		}
		
		// Setter

		if(!isset($this->store->Settings)) {
			$this->store->Settings = new StdClass();
		}

		if( $base == 'time' || $base == 'count' ) {
			$this->store->Settings->range_base = $base;
			$this->range_base = $base;
		} 
		else {
			throw new Exception('base $base is not known');
		}
		
		if($base == 'time') {
			$this->store->Settings->range_time = $this->parseTimeString( $range );
			$this->range_time = $this->store->Settings->range_time;
		} 
		elseif ( $base == 'count' ) {
			$this->store->Settings->range_count = $range;
			$this->range_count = $range;
		}
		
	}
	
	// Parses time string with abbreviations, and returns seconds
	private function parseTimeString( $time ) {
		
		if(empty($time)) { 
			return null; 
		}
		
		$time = trim($time);
		$timeval = (float)$time;
		if($timeval == 0) {
			$timeval = 1;
		}
		
		switch( substr($time, -1 ) ) {
			case 'm': 
				$calcbase = 60;
				break;
			case 'h':
				$calcbase = 60*60;
				break;
			case 'd':
				$calcbase = 60*60*24;
				break;
			case 'w':
				$calcbase = 60*60*24*7;
				break;
			case 'M':
				$calcbase = 60*60*24*7*30;
				break;
			case 'Y':
				$calcbase = 60*60*24*365;
				break;
			default:
				$calcbase = 1;
		}		
		
		return( $timeval * $calcbase );
	}	
	
}
