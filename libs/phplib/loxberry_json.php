<?php

class LBJSON 
{ 
	public $VERSION = "2.0.2.2";
	public $DEBUG = 0;

	public $slave;
	private $filename;
	private $original;
	
	public function __get($key) {
		return property_exists ( $this->slave ,  $key ) ? $this->slave->{$key} : null;
	}

	public function __construct($filename)
	{
		
		$this->filename = $filename;
		$slave = json_decode(file_get_contents($filename));
		$this->original = serialize($slave);
		$this->slave = $slave;
		
	}
	
	public function filename($filename = null) {
		if( !empty($filename) ) {
			$this->filename = $filename;
		}
		return $this->filename;
	}

	public function write() {
		
		// echo "Write file\n";
		if( serialize($this->slave) == $this->original ) {
			// echo "  Nothing changed.\n";
			return;
		} else {
			// echo "  Something changed.\n";
			$writeerror = file_put_contents($this->filename, json_encode($this->slave, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), LOCK_EX);
			if ($writeerror === FALSE) {
				error_log("loxberry_json: write: ERROR writing file " . $this->filename );
			}
		}
	}
}
