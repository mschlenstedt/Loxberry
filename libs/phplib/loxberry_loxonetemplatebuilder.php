<?php

class LoxoneTemplateBuilder 
{ 
	public $VERSION = "2.0.0.2";
	public $DEBUG = 0;

	function __construct( $params ) {
		
		if(!is_array($params)) {
			throw new Exception('params need to be an array (key / value)');
		}
		
		// Default values of class
		$this->PollingTime = 60;
		$this->CloseAfterSend = "true";
		
		// Parse parameters
		foreach ($params as $param => $val) {
			switch ($param) {
				case "CloseAfterSend": $this->$param = isset($val) && ( $val == false || $val === "false" ) ? "false" : "true"; break;
				default:  $this->$param = $val; 
			}
		}
		
		$this->IOcmd = array ( );
	}
	
	function addIOCmd ( $params ) {
		
		if(!is_array($params)) {
			return $this->IOcmd[$params-1];
		}
		$count = count($this->IOcmd);
		$this->IOcmd[$count] = new IOCmd( $params );
		return count($this->IOcmd);
	}

	function delete( int $lineno ) {
		$lineno = $lineno-1;
		$this->IOcmd[$lineno]->_deleted = true;
	}
	
	function output() {
		
		$crlf = "\r\n";
		$encflags = ENT_XML1|ENT_QUOTES;
		
		$id = 0;
		$o = '<?xml version="1.0" encoding="utf-8"?>'.$crlf;
		
		$class = get_class($this);
		
		if ($class == "VirtualInHttp") {
			$o .= '<VirtualInHttp ';
			$o .= 'Title="'.@htmlspecialchars($this->Title, $encflags).'" ';
			$o .= 'Comment="'.@htmlspecialchars($this->Comment, $encflags).'" ';
			$o .= 'Address="'.@htmlspecialchars($this->Address, $encflags).'" ';
			$o .= 'PollingTime="'.$this->PollingTime.'"';
			$o .= '>'.$crlf;
		} elseif ($class = "VirtualInUdp") {
			$o .= '<VirtualInUdp ';
			$o .= 'Title="'.@htmlspecialchars($this->Title, $encflags).'" ';
			$o .= 'Comment="'.@htmlspecialchars($this->Comment, $encflags).'" ';
			$o .= 'Address="'.@htmlspecialchars($this->Address, $encflags).'" ';
			$o .= 'Port="'.@htmlspecialchars($this->Port, $encflags).'" ';
			$o .= '>'.$crlf;
		} elseif ($class = "VirtualOut") {
			$o .= '<VirtualOut ';
			$o .= 'Title="'.@htmlspecialchars($this->Title, $encflags).'" ';
			$o .= 'Comment="'.@htmlspecialchars($this->Comment, $encflags).'" ';
			$o .= 'Address="'.@htmlspecialchars($this->Address, $encflags).'" ';
			$o .= 'CmdInit="'.@htmlspecialchars($this->CmdInit, $encflags).'" ';
			$o .= 'CloseAfterSend="'.$this->CloseAfterSend.'" ';
			$o .= 'CmdSep="'.@htmlspecialchars($this->CmdSep, $encflags).'" ';
			$o .= '>'.$crlf;
		}
		
		foreach( $this->IOcmd as $Cmd ) {
			$o .= $Cmd->getXmlOutput($id);
			$id++;
		}
		
		if ($class == "VirtualInHttp") {
			$o .= '</VirtualInHttp>'.$crlf;
		} elseif ($class = "VirtualInUdp") {
			$o .= '</VirtualInUdp>'.$crlf;
		} elseif ($class = "VirtualOut") {
			$o .= '</VirtualOut>'.$crlf;
		}
		
		return $o;
	}
}
		
class IOCmd 
{
	function __construct( array $params ) {
		
		$backtrace = debug_backtrace();
		$this->_type = $backtrace[2]['class'];
		
		// Default values of command
		$this->_deleted = false;
		$this->Signed = "true";
		$this->Analog = "true";
		$this->SourceValLow = "0";
		$this->DestValLow = "0";
		$this->SourceValHigh = "100";
		$this->DestValHigh = "100";
		$this->DefVal = "0";
		$this->MinVal = "-2147483647";
		$this->MaxVal = "2147483647";
		$this->CmdOnMethod = "GET";
		$this->CmdOffMethod = "GET";
		$this->Repeat = "0";
		$this->RepeatRate = "0";
		
		foreach ($params as $param => $val) {
			switch ($param) {
				case "Signed": 
				case "Analog": $this->$param = isset($val) && ( $val == false || $val === "false" ) ? "false" : "true"; break;
				default: $this->$param = $val;
			}
		}
	}

	function delete() {
		$this->_deleted = true;
	}
	
	function getXmlOutput(int $xmlSetID = null) {
		
		if($this->_deleted) {
			return;
		}
		
		$encflags = ENT_XML1|ENT_QUOTES;
		
		$o = "";
		$crlf = "\r\n";
		if ($this->_type == "VirtualInHttp") {
			$o .= "\t".'<VirtualInHttpCmd ';
			$o .= 'Title="'.@htmlspecialchars($this->Title, $encflags).'" ';
			$o .= 'Comment="'.@htmlspecialchars ($this->Comment, $encflags).'" ';
			$o .= 'Check="'.@htmlspecialchars ($this->Check, $encflags).'" ';
			$o .= 'Signed="'.@$this->Signed.'" ';
			$o .= 'Analog="'.@$this->Analog.'" ';
			$o .= 'SourceValLow="'.@$this->SourceValLow.'" ';
			$o .= 'DestValLow="'.@$this->DestValLow.'" ';
			$o .= 'SourceValHigh="'.@$this->SourceValHigh.'" ';
			$o .= 'DestValHigh="'.@$this->DestValHigh.'" ';
			$o .= 'DefVal="'.@$this->DefVal.'" ';
			$o .= 'MinVal="'.@$this->MinVal.'" ';
			$o .= 'MaxVal="'.@$this->MaxVal.'"';
			$o .= '/>'.$crlf;	
		}
		
		elseif ($this->_type == "VirtualInUdpCmd") {
			$o .= "\t".'<VirtualInUdpCmd ';
			$o .= 'Title="'.@htmlspecialchars($this->Title, $encflags).'" ';
			$o .= 'Comment="'.@htmlspecialchars ($this->Comment, $encflags).'" ';
			$o .= 'Address="'.@htmlspecialchars ($this->Address, $encflags).'" ';
			$o .= 'Check="'.@htmlspecialchars ($this->Check, $encflags).'" ';
			$o .= 'Signed="'.@$this->Signed.'" ';
			$o .= 'Analog="'.@$this->Analog.'" ';
			$o .= 'SourceValLow="'.@$this->SourceValLow.'" ';
			$o .= 'DestValLow="'.@$this->DestValLow.'" ';
			$o .= 'SourceValHigh="'.@$this->SourceValHigh.'" ';
			$o .= 'DestValHigh="'.@$this->DestValHigh.'" ';
			$o .= 'DefVal="'.@$this->DefVal.'" ';
			$o .= 'MinVal="'.@$this->MinVal.'" ';
			$o .= 'MaxVal="'.@$this->MaxVal.'"';
			$o .= '/>'.$crlf;	
		}
		
		elseif ($this->_type == "VirtualOutCmd") {
			$o .= "\t".'<VirtualOutCmd ';
			
			if(isset($xmlSetID)) {
				$o .= 'ID="'.$xmlSetID.'" ';
			}
			$o .= 'Title="'.@htmlspecialchars($this->Title, $encflags).'" ';
			$o .= 'Comment="'.@htmlspecialchars ($this->Comment, $encflags).'" ';
			$o .= 'CmdOnMethod="'.@strtoupper($this->CmdOnMethod).'" ';
			$o .= 'CmdOn="'.@htmlspecialchars ($this->CmdOn, $encflags).'" ';
			$o .= 'CmdOnHTTP="'.@htmlspecialchars ($this->CmdOnHTTP, $encflags).'" ';
			$o .= 'CmdOnPost="'.@htmlspecialchars ($this->CmdOnPost, $encflags).'" ';
			$o .= 'CmdOffMethod="'.@strtoupper($this->CmdOffMethod).'" ';
			$o .= 'CmdOff="'.@htmlspecialchars ($this->CmdOff, $encflags).'" ';
			$o .= 'CmdOffHTTP="'.@htmlspecialchars ($this->CmdOffHTTP, $encflags).'" ';
			$o .= 'CmdOffPost="'.@htmlspecialchars ($this->CmdOffPost, $encflags).'" ';
			$o .= 'Analog="'.@$this->Analog.'" ';
			$o .= 'Repeat="'.@$this->Repeat.'" ';
			$o .= 'RepeatRate="'.@$this->RepeatRate.'"';
			$o .= '/>'.$crlf;	
		}
		
		else {
			throw new Exception($this->_type . " is an unknown IO type");
		}
		
		return($o);
	}

}

// Virtual HTTP Inputs
class VirtualInHttp extends LoxoneTemplateBuilder 
{
	function VirtualInHttpCmd( $params ) {
		return parent::addIOCmd( $params );
	}
}

// Virtual UDP Inputs
class VirtualInUdp extends LoxoneTemplateBuilder 
{
	function VirtualInUdpCmd( $params ) {
		return parent::addIOCmd( $params );
	}
}

// Virtual Outputs
class VirtualOut extends LoxoneTemplateBuilder 
{
	function VirtualOutCmd( $params ) {
		return parent::addIOCmd( $params );
	}
}
