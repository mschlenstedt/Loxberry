<?php
if( php_sapi_name() !== 'cli' ) {
	header('Content-Type: text/html; charset=utf-8');
}

/* Executed on include */
require_once "loxberry_system.php";
require_once "loxberry_io.php";

$LBMSVERSION = "2.0.2.6";
$LBMSDEBUG = 0;

error_log("\e[1mLoxBerry XL Version $LBMSVERSION\e[0m");
// fwrite(STDERR, "\e[1mLoxBerry XL Version $LBMSVERSION\e[0m\n");


$ms = LBSystem::get_miniservers();

if (!is_array($ms))
{
    error_log("No Miniservers defined, so no Miniserver objects created.");
} else {
	// Init Miniserver objects
	foreach ($ms as $msno => $miniserver)
	{
		$objectname = "ms$msno";
		$$objectname = new miniserver($msno);
		error_log("Miniserver $msno ({$miniserver['Name']}) accessible by \e[92m\${$objectname}\e[0m");
	}
}

// Init MQTT
$mqttcreds = mqtt_connectiondetails();
if( !is_array($mqttcreds) ) 
{
	error_log("MQTT Gateway not installed");
} else {
	require_once "phpMQTT/phpMQTT.php";
	$mqtt = new lbmqtt($mqttcreds);
}

// Init XL class
$xl = new lbxl();	

	
// Init sun
$sun = new lbsun();


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
			error_log("MQTT ({$this->mqttcreds['brokerhost']}) accessible by \e[94m\$mqtt\e[0m");
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
	public $common_words = array();
	
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
		$this->common_words['de'] = array ( 'and' => 'und', 'or' => 'oder', 'from' => 'von', 'to' => 'bis' );
		
		
		/* English */
		$this->weekdays['en'] = array ( "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" );
		$this->months['en'] = array ( "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" );
		$this->minutes_numerus['en'] = array ( 0 => 'minutes', 1 => 'minute', 2 => 'minutes' );
		$this->hours_numerus['en'] = array ( 0 => 'hours', 1 => 'hour', 2 => 'hours' );
		$this->days_numerus['en'] = array ( 0 => 'days', 1 => 'day', 2 => 'days' );
		$this->months_numerus['en'] = array ( 0 => 'months', 1 => 'month', 2 => 'months' );
		$this->years_numerus['en'] = array ( 0 => 'years', 1 => 'year', 2 => 'years' );
		$this->common_words['en'] = array ( 'and' => 'and', 'or' => 'or', 'from' => 'from', 'to' => 'to' );
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
		return strftime( $format, self::_evaldate($epoch) );
	}
	
	public function hour($epoch = null) {
		return (int)self::_date( '%H', self::_evaldate($epoch) );
	}
	public function minute($epoch = null) {
		return (int)self::_date( '%M', self::_evaldate($epoch) );
	}
	public function minofday($epoch = null) {
		$epoch = self::_evaldate($epoch);
		$hour = self::hour($epoch);
		$min = self::minute($epoch);
		return (int)($hour*60+$min);
	}
		
	public function day($epoch = null) {
		return (int)self::_date( '%e', self::_evaldate($epoch) );
	}
	public function month($epoch = null) {
		return (int)self::_date( '%m', self::_evaldate($epoch) );
	}
	public function year($epoch = null) {
		return (int)self::_date( '%Y', self::_evaldate($epoch) );
	}
	public function dayofyear($epoch = null) {
		return (int)self::_date( '%j', self::_evaldate($epoch) );
	}
	public function weekday($epoch = null) {
		return (int)self::_date( '%u', self::_evaldate($epoch) );
	}
	public function week($epoch = null) {
		return (int)self::_date( '%V', self::_evaldate($epoch) );
	}
	public function date($epoch = null) {
		return self::_date( '%e.%m.', self::_evaldate($epoch) );
	}
	public function datetext($epoch = null) {
		return self::_date( '%e.', $epoch ) . ' ' . self::monthtext;
	}
	public function time($epoch = null) {
		return self::_date( '%H:%M', self::_evaldate($epoch) );
	}
	public function weekdaytext($epoch = null) {
		$weekday = self::weekday(self::_evaldate($epoch));
		$lang = LBSystem::lblanguage();
		return self::weekdays["$lang"][$weekday];
	}
	public function monthtext($epoch = null) {
		$month = self::month(self::_evaldate($epoch));
		$lang = LBSystem::lblanguage();
		return self::months["$lang"][$month];
	}
	
	public function dtdiff($time1, $time2) {
		$time1 = self::_evaldate($time1);
		$time2 = self::_evaldate($time2);
		$dt1 = new DateTime("@$time1");
		$dt2 = new DateTime("@$time2");
		return date_diff($dt1, $dt2);
	}
	
	public function toxmasdays($epoch = null) {
		return self::toxmasdt(self::_evaldate($epoch))::days;
	}
	public function toxmastext($epoch = null) {
		$lang = LBSystem::lblanguage();
		$dtdiff = self::toxmasdt(self::_evaldate($epoch));
		$textarr = array();
		
		if($dtdiff->m > 0) {
			array_push( $textarr, $dtdiff->m . ' ' . $this->_getnumerus("months_numerus", $dtdiff->m) );
		}
		if($dtdiff->d > 0) {
			array_push( $textarr, $dtdiff->d . ' ' . $this->_getnumerus("days_numerus", $dtdiff->d) );
		}
		if($dtdiff->h > 0) {
			array_push( $textarr, $dtdiff->h . ' ' . $this->_getnumerus("hours_numerus", $dtdiff->h) );
		}
		
		$text = implode( ', ', $textarr );
		$commapos = strrpos( $text, ', ');
		if( $commapos !== FALSE ) {
			$text = substr( $text, 0, $commapos ) . ' ' . $this->common_words[$lang]['and'] . ' ' . substr( $text, $commapos+2 );
		}
		return $text;
		
	}

	public function toxmasdt($epoch = null) {
		$epoch = $this->_evaldate($epoch);
		$dtnow = new DateTime("@$epoch");
		$dtxmas = DateTime::createFromFormat('m-d H:i', '12-24 0:00');
		$dtdiff = date_diff($dtnow, $dtxmas);
		return $dtdiff;
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
		return $this->$numerus[$lang][$key];
		
	}
	 	
	// Evaluates format of incoming time, and returns an epoch timestamp
	public function _evaldate($epoch = null) {
		if( $epoch == null or strtolower($epoch)=='now') {
			// if empty return current time
			return time();
		} elseif( $epoch == (int)$epoch ) {
			// if input is epoch, return epoch
			return $epoch;
		} else {
			// if input is d.m.y H:i convert to epoch
			$dt = DateTime::createFromFormat('d.m.Y H:i', $epoch);
			return $dt->getTimestamp();
		}
	}
}

class lbsun {

	public $sc;
	public $sunTimes;

	// Init suncalc
	public function __construct() 
	{
		// Nothing to do here
	}

	public function gps($epoch, $lat = null, $lng = null) {
		$epoch = lbxl::_evaldate($epoch);
		require_once("suncalc/suncalc.php");
		
		$this->date = new DateTime("@$epoch");
		if( $lat != null) {
			$this->lat = $lat;
		}
		if( $lng != null) {
			$this->lng = $lng;
		}
		if( $this->lat == null or $this->lng == null ) {
			error_log( "You need to set GPS coordinates at least once" );
			exit(0);
		}
		
		$this->sc = new AurorasLive\SunCalc($this->date, $this->lat, $this->lng);
		$this->sunTimes = null;
		$this->sunPosition = null;
	}
	public function timeformat($format) {
		$this->format = $format;
	}
	
	// Sun times
	public function sunTimes($property, $format = null ) {
		if( !isset($this->sc) ) {
			error_log( "You first need to set your GPS coordinates with \$sun->gps" );
			return "No GPS";
		}
		if( !isset( $this->sunTimes ) ) {
			$this->sunTimes = $this->sc->getSunTimes(); 
		}
		
		$epoch = $this->sunTimes[$property]->format('U');
		return $this->_formattime( $epoch, $format );
	}

	// Sun position
	public function sunPosition($property) {
		if( !isset($this->sc) ) {
			error_log( "You first need to set your GPS coordinates with \$sun->gps" );
			return "No GPS";
		}
		if( !isset( $this->sunPosition ) ) {
			$this->sunPosition = $this->sc->getSunPosition($this->date); 
		}
		
		$posrad = $this->sunPosition->$property;
		$posgrad = rad2deg($posrad);
		if($property == 'azimuth') {
			$posgrad+=180;
		}
		return $posgrad;
		
	}

	private function _formattime($epoch, $format = null) {
		if( $format == null and isset( $this->format) ) {
			$format = $this->format;
		}
		switch($format) {
			case 'epoch':
				return $epoch;
			case 'time':
				return lbxl::time($epoch);
			default:
				return lbxl::minofday($epoch);
		}
	}
}

