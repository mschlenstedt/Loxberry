<?php

/* Executed on include */
require_once "loxberry_system.php";
require_once "loxberry_io.php";
require_once "phpMQTT/phpMQTT.php";

$LBMSVERSION = "2.0.2.3";
$LBMSDEBUG = 0;

error_log("LoxBerry XL Version $LBMSVERSION");



$ms = LBSystem::get_miniservers();

if (!is_array($ms))
{
    error_log("No Miniservers defined, so no Miniserver objects created.");
} else {

	// Auto-create Miniserver objects
	foreach ($ms as $msno => $miniserver)
	{
		$objectname = "ms$msno";
		$$objectname = new miniserver($msno);
		error_log("Miniserver $msno ({$miniserver['Name']}) accessible by \${$objectname}");
	}
}

$mqttcreds = mqtt_connectiondetails();
if( !is_array($mqttcreds) ) 
{
	error_log("MQTT Gateway not installed");
} else {
	$mqtt = new lbmqtt($mqttcreds);
}

$xl = new lbxl();	
	



function clean($inputval) {
	return (float) $inputval;
}

//////////////////////
/* Class miniserver */
//////////////////////
class miniserver
{
	private $msno;
	
	public function __construct($msnumber)
	{
		$this->msno = $msnumber;
	}
	
	// Method overload
	public function __call($name, $args) {
        if(isset($args[0])) {
			$value = $args[0];
			$this->_log("__call: Name '$name', arg '$value'");
			return $this->mshttp_send( $name, $value );
			
		} else {
			$this->_log("__call: Name '$name'");
			return $this->mshttp_get( $name );
		}
	}	
	
	public function get($name) {
		return $this->__get($name);
	}
	
	public function set($name, $value) {
		return $this->__set($name, $value);
	}
		
	// Property overload 
    public function __set($name, $value) { 
        $this->_log("__set: Name '$name', value '$value'");
		return $this->__call( $name, array( $value ) );
    } 
      
    // Function definition 
    public function __get($name) { 
        $this->_log("__get: Name '$name'");
        return $this->__call( $name, array() );
    } 
	
	private function mshttp_send($input, $value) {
        $this->_log("mshttp_send: Input '$input', value '$value'");
		$resp = mshttp_send( $this->msno, $input, $value );
		if($resp == null) {
			error_log("MS{$this->msno}: Error sending value $value to $input");
			return false;
		} else {
			$this->_log("Response: $resp");
		}
		return true;
	}
	private function mshttp_get($input) {
        $this->_log("mshttp_get: Input '$input'");
		$resp = mshttp_get( $this->msno, $input );

		if($resp == null) {
			error_log("MS{$this->msno}: Error getting value from input $input");
			return false;
		} else {
			$this->_log("Response: $resp");
		}
		return $resp;
	}

	private function _log($text) {
		global $LBMSDEBUG;
		if ( $LBMSDEBUG == 1 ) {
			error_log("MS{$this->msno} $text");
		}
	}
		
}

//////////////////////
/* Class lbmqtt     */
//////////////////////
class lbmqtt
{
	private $topicvalues = array();
	
	public function __construct($mqttcreds)
	{
		$this->mqttcreds = $mqttcreds;
		$this->_client_id = uniqid(gethostname()."_LoxBerry_XL");
		$this->_mqttconn = $this->_connect();
	}

	private function _connect()
	{
		$this->mqtt = new Bluerhinos\phpMQTT($this->mqttcreds['brokerhost'],  $this->mqttcreds['brokerport'],$this->_client_id);
		if( $this->mqtt->connect(true, NULL, $this->mqttcreds['brokeruser'], $this->mqttcreds['brokerpass'] ) ) {
			error_log("MQTT ({$this->mqttcreds['brokerhost']}) accessible by \$mqtt");
		}
	}
	
	private function _send($topic, $content, $retain=false) 
	{
		$this->mqtt->publish( $topic, $content, 0, $retain);
	}
	public function set($topic, $content, $retain=false) 
	{
		$this->_send($topic, $content, 0, $retain);
	}
	public function publish($topic, $content) 
	{
		$this->_send($topic, $content, 0, false);
	}
	public function retain($topic, $content) 
	{
		$this->_send($topic, $content, 0, true);
	}
	
	public function get($topic) {
		// $topics[$topic] = array("qos" => 0, "function" => '_procmsg');
		$topics[$topic] = array("qos" => 0, "function" => array( $this, '_procmsg') );
		$this->mqtt->subscribe( $topics, 0 );
		
		$time = microtime(1);
		unset($this->topicvalues[$topic]);
		while($this->mqtt->proc(0) and microtime(1) < ($time+1) ) {
			if( isset($this->topicvalues[$topic]) ) {
				break;
			}
		}
		if( isset($this->topicvalues[$topic]) ) {
			return $this->topicvalues[$topic];
		} else {
			return null;
		}
	}
	
	public function _procmsg( $topic, $msg)
	{
	// error_log("Reveived $topic: $msg");	
	$this->topicvalues[$topic] = $msg;
	return $msg;
	}
	
}

//////////////////////
/* Class lbxl       */
//////////////////////
class lbxl
{
	public $weekdays = array();
	public $months = array();
	public $minutes_numerus = array();
	public $hours_numerus = array();
	public $days_numerus = array();
	public $months_numerus = array();
	public $years_numerus = array();
	
	public function __construct()
	{
		/* German */
		$this->weekdays['de'] = array ( "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag" );
		$this->months['de'] = array ( "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember" );
		$this->minutes_numerus['de'] = array ( 0 => 'Minuten', 1 => 'Minute', 2 => 'Minuten' );
		$this->hours_numerus['de'] = array ( 0 => 'Stunden', 1 => 'Stunde', 2 => 'Stunden' );
		$this->days_numerus['de'] = array ( 0 => 'Tage', 1 => 'Tag', 2 => 'Tage' );
		$this->months_numerus['de'] = array ( 0 => 'Monate', 1 => 'Monat', 2 => 'Monate' );
		$this->years_numerus['de'] = array ( 0 => 'Jahre', 1 => 'Jahr', 2 => 'Jahre' );
		
		/* English */
		$this->weekdays['en'] = array ( "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" );
		$this->months['en'] = array ( "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" );
		$this->minutes_numerus['en'] = array ( 0 => 'minutes', 1 => 'minute', 2 => 'minutes' );
		$this->hours_numerus['en'] = array ( 0 => 'hours', 1 => 'hour', 2 => 'hours' );
		$this->days_numerus['en'] = array ( 0 => 'days', 1 => 'day', 2 => 'days' );
		$this->months_numerus['en'] = array ( 0 => 'months', 1 => 'month', 2 => 'months' );
		$this->years_numerus['en'] = array ( 0 => 'years', 1 => 'year', 2 => 'years' );
		
	}
	
	
	
	
	
	public function __get($name) { 
        if( method_exists( $this, $name ) ) {
			return $this->$name();
		} else {
			throw new Exception("Constant $name does not exist");
		}
    } 
	
	private function _date($format, $epoch=null)
	{
		if( $epoch == null ) {
			$epoch = time();
		}
		return strftime( $format, $epoch );
	}
		
	
	public function hour($epoch = null) {
		return (int)$this->_date( '%H', $epoch );
	}
	public function minute($epoch = null) {
		return (int)$this->_date( '%M', $epoch );
	}
	public function day($epoch = null) {
		return (int)$this->_date( '%e', $epoch );
	}
	public function month($epoch = null) {
		return (int)$this->_date( '%m', $epoch );
	}
	public function year($epoch = null) {
		return (int)$this->_date( '%Y', $epoch );
	}
	public function dayofyear($epoch = null) {
		return (int)$this->_date( '%j', $epoch );
	}
	public function weekday($epoch = null) {
		return (int)$this->_date( '%u', $epoch );
	}
	public function week($epoch = null) {
		return (int)$this->_date( '%V', $epoch );
	}
	public function date($epoch = null) {
		return $this->_date( '%e.%m.', $epoch );
	}
	public function datetext($epoch = null) {
		return $this->_date( '%e.', $epoch ) . ' ' . $this->monthtext;
	}
	public function time($epoch = null) {
		return $this->_date( '%H:%M', $epoch );
	}
	public function weekdaytext($epoch = null) {
		$weekday = $this->weekday($epoch);
		$lang = LBSystem::lblanguage();
		return $this->weekdays["$lang"][$weekday];
	}
	public function monthtext($epoch = null) {
		$month = $this->month($epoch);
		$lang = LBSystem::lblanguage();
		return $this->months["$lang"][$month];
	}
	public function timediff($time1, $time2) {
		error_log("timediff: Not yet implemented");
	}
	
	
	public function daystoxmas($epoch = null) {
		if( $epoch == null ) {
			$epoch = time();
		}
		$xmas = mktime(0, 0, 0, 12, 24);
		$secs = $xmas - $epoch;
		$days = $secs/60/60/24;
		return (int)$days;
	}
	
	
	public function _getnumerus($numerus, $numvalue) {
		$lang = LBSystem::lblanguage();
		$numvalue = (int)$numvalue;
		$keys = array_keys( $this->$numerus[$lang] );
		foreach ( $keys as $key ) {
			if( $key >= $numvalue ) {
				break;
			}
		}
		echo "Final key: $key\n";
		return $this->$numerus[$lang][$key];
		
	}
		
}
