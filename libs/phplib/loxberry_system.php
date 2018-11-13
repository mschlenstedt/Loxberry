<?php
	# define Constants for LoxBerry directories
	if(getenv("LBHOMEDIR")) {
		define("LBHOMEDIR", getenv("LBHOMEDIR"));
	} else {
		$p = explode(':', get_include_path());
		for ($i=count($p)-1; $i >= 0; $i--) {
			if (substr($p[$i], -11) == 'libs/phplib'
				&& file_exists($p[$i] . '/loxberry_web.php')
				&& file_exists($p[$i] .'/../perllib/LoxBerry/Web.pm'))
			{
				DEFINE("LBHOMEDIR", substr($p[$i], 0, -11));
				break;
			}
		}
		if (!defined('LBHOMEDIR')) {
			error_log("LoxBerry System WARNING: Falling back to /opt/loxberry");
			define("LBHOMEDIR", '/opt/loxberry');
		}
	}

function canonical_path($path) {
	$ret = array();
	$s = substr($path,-1,1);
	if ($s == '.' || $s == '/')
		$path .= '/';
	foreach (preg_split('/\/+/', $path . '-', 0, PREG_SPLIT_NO_EMPTY) as $tok) {
		if ($tok == '.')
			continue;
		if ($tok == '..') {
			array_pop($ret);
			continue;
		}
		$ret[] = $tok;
	}
	return '/' . substr(implode('/', $ret), 0, -1);
}

function get_plugindir($use_abs) {
	$p = array();

	$s = getenv('SCRIPT_FILENAME');
	$t = (isset($argv)) ? $argv[0] : '';
	if ($s) {
		if (substr($s, 0, 1) != '/')
			$s = getcwd() . "/" . $s;
		$s = $use_abs ? realpath($s) : canonical_path($s);
	} else {
		$s = '/';
	}
	if ($t != '' && substr($t, 0, 1) != '/')
		$t = getcwd() . "/" . $t;
	if ($s != $t && $t != '') {
		$t = $use_abs ? realpath($t) : canonical_path($t);
	} else {
		$t = '/';
	}
	if ($s == '/' && $t == '/')
		return '';

	if ($s != '/')
		$p[] = $s;
	if ($t != '/' && $s != $t)
		$p[] = $t;

	$parents = array('templates' => 1, 'log' => 2, 'data' => 3, 'config' => 4, 'bin' => 5);
	foreach ($p as $t) {
		#error_log("Checking '$t' for '/plugins/' ...\n");
		$pc = explode('/', $t);
		for ($i=count($pc)-2; $i > 0; $i--) {
			if($pc[$i] != 'plugins')
				continue;
			if ($i >= 2 && $pc[$i-2] == 'webfrontend') {
				return $pc[$i+1];
			} else if (array_key_exists($pc[$i-1], $parents)) {
				return $pc[$i+1];
			} else if ($i >= 2 && $pc[$i-2] =='system' && $pc[$i-1] =='daemon'){
				return $pc[$i+1];
			}
		}
	}
	return ($use_abs) ? '' : get_plugindir(1);
}

	// lbhomedir
	$lbhomedir = LBHOMEDIR;
	$pluginname = get_plugindir(0);
	
	if ($pluginname != '') {
		define ("LBPPLUGINDIR", $pluginname);
		unset($pluginname);
		
		// Plugin Constants
		define ("LBPHTMLAUTHDIR", LBHOMEDIR . "/webfrontend/htmlauth/plugins/" . LBPPLUGINDIR);
		define ("LBPHTMLDIR", LBHOMEDIR . "/webfrontend/html/plugins/" . LBPPLUGINDIR);
		define ("LBPTEMPLATEDIR", LBHOMEDIR . "/templates/plugins/" . LBPPLUGINDIR);
		define ("LBPDATADIR", LBHOMEDIR . "/data/plugins/" . LBPPLUGINDIR);
		define ("LBPLOGDIR", LBHOMEDIR . "/log/plugins/" . LBPPLUGINDIR);
		define ("LBPCONFIGDIR", LBHOMEDIR . "/config/plugins/" . LBPPLUGINDIR);
		// define ("LBPSBINDIR", LBHOMEDIR . "/sbin/plugins/" . LBPPLUGINDIR);
		define ("LBPBINDIR", LBHOMEDIR . "/bin/plugins/" . LBPPLUGINDIR);

		// Plugin Variables
		$lbpplugindir = LBPPLUGINDIR;
		$lbphtmlauthdir = LBPHTMLAUTHDIR;
		$lbphtmldir = LBPHTMLDIR;
		$lbptemplatedir = LBPTEMPLATEDIR;
		$lbpdatadir = LBPDATADIR;
		$lbplogdir = LBPLOGDIR;
		$lbpconfigdir = LBPCONFIGDIR;
		// $lbpsbindir = LBPSBINDIR;
		$lbpbindir = LBPBINDIR;
	}

	// error_log("LoxBerry System Info: LBHOMEDIR: " . LBHOMEDIR);
	
	# Defining globals for SYSTEM directories
	define ("LBSHTMLAUTHDIR", LBHOMEDIR . "/webfrontend/htmlauth/system");
	define ("LBSHTMLDIR", LBHOMEDIR . "/webfrontend/html/system");
	define ("LBSTEMPLATEDIR", LBHOMEDIR . "/templates/system");
	define ("LBSDATADIR", LBHOMEDIR . "/data/system");
	define ("LBSLOGDIR", LBHOMEDIR . "/log/system");
	define ("LBSCONFIGDIR", LBHOMEDIR . "/config/system");
	define ("LBSSBINDIR", LBHOMEDIR . "/sbin");
	define ("LBSBINDIR", LBHOMEDIR . "/bin");

	# As globals in PHP cannot be concentrated in strings, we additionally define variables
	
	$lbshtmlauthdir = LBSHTMLAUTHDIR;
	$lbshtmldir = LBSHTMLDIR;
	$lbstemplatedir = LBSTEMPLATEDIR;
	$lbsdatadir = LBSDATADIR;
	$lbslogdir = LBSLOGDIR;
	$lbsconfigdir = LBSCONFIGDIR;
	$lbssbindir = LBSSBINDIR;
	$lbsbindir = LBSBINDIR;

	# Variables to store

	$cfg=NULL;
	$miniservers=NULL;
	$binaries=NULL;
	$pluginversion=NULL;
	$lbfriendlyname=NULL;
	$lbsysversion=NULL;
	$miniservercount=NULL;
	$plugins=NULL;
	$lblang=NULL;
	$cfgwasread=NULL;
	
	$reboot_required_file = "$lbhomedir/log/system_tmpfs/reboot.required";


// Functions in class LBSystem
// 
class LBSystem
{
	public static $LBSYSTEMVERSION = "1.2.5.4";
	public static $lang=NULL;
	private static $SL=NULL;
		
	///////////////////////////////////////////////////////////////////
	// Detects the language from query, post or general.cfg
	///////////////////////////////////////////////////////////////////
	public static function lblanguage() 
	{
		global $lblang;
		if (isset(LBSystem::$lang)) { 
			// error_log("Language " . LBSystem::$lang . " is already set.");
			return LBSystem::$lang; }
		
		// error_log("Will detect language");
		if (isset($_GET["lang"])) {
			LBSystem::$lang = substr($_GET["lang"], 0, 2);
			// error_log("Language " . LBSystem::$lang . " detected from Query string");
			return LBSystem::$lang;
		}
		if (isset($_POST["lang"])) {
			LBSystem::$lang = substr($_GET["lang"], 0, 2);
			// error_log("Language " . LBSystem::$lang . " detected from post data");
			return LBSystem::$lang;
		}
		LBSystem::read_generalcfg();
		if (isset($lblang)) {
			LBSystem::$lang = $lblang;
			// error_log("Language " . LBSystem::$lang . " used from general.cfg");
			return LBSystem::$lang;
		}
		// Finally we default to en
		return "en";
	}

	public static function readlanguage($template = NULL, $genericlangfile = "language.ini", $syslang = FALSE)
	{
		if (!is_object($template) && is_string($template)) {
			$genericlangfile = $template;
			$template = NULL;
		}
		if ($syslang == true) {
			$genericlangfile = LBSTEMPLATEDIR . "/lang/language.ini";
		} else {
			$genericlangfile = LBPTEMPLATEDIR . "/lang/$genericlangfile";
		}
		
		$lang = LBSystem::lblanguage();
		$pos = strrpos($genericlangfile, ".");
		if ($pos === false) {
				error_log("readlanguage: Illegal option '$genericlangfile'. This should be in the form 'language.ini' without pathes.");
				return null;
		}
		
		$langfile_foreign = substr($genericlangfile, 0, $pos) . "_" . $lang . substr($genericlangfile, $pos);
		$langfile_en = substr($genericlangfile, 0, $pos) . "_en" . substr($genericlangfile, $pos);
		// error_log("readlanguage: $langfile_foreign enlangfile: $langfile_en");
		
		if ($syslang == false || ($syslang == True && !is_array(self::$SL))) { 

			if (file_exists($langfile_foreign)) {
				$currlang = LBSystem::read_language_file($langfile_foreign);
				LBSystem::parse_lang_file($currlang, $language);
			}
			else
			{
				$currlang = [];
			}
			if (file_exists($langfile_en)) {
				$enlang = LBSystem::read_language_file($langfile_en);
				LBSystem::parse_lang_file($enlang, $language);
			}
		
			if ($syslang) {
				self::$SL = $language;
			}
		} elseif ($syslang == True && is_array(self::$SL)) {
			// error_log("readlanguage: Re-use cached system language"); 
			$language = self::$SL;
		}
		
		if (is_object($template)) {
			$template->paramArray($language);
		}
	
		return $language;

	}
	
	private static function parse_lang_file($content, &$langhash)
{
	
	// In Perl, $content alread is an array!
	
	$section = 'default';

	foreach ($content as $line) {
		# Trim
		$line=trim($line);
		$firstletter = substr($line, 0, 1);
		// echo "Firstletter: $firstletter\n";
		# Comments
		if($firstletter == '' || $firstletter == '#' || $firstletter == '/' || $firstletter == ';') {
			continue;}
		# Sections
		if ($firstletter == '[') {
			$closebracket = strpos($line, ']', 1);
			if($closebracket == FALSE) {
				continue;
			}
			$section = substr($line, 1, $closebracket-1);
			// echo "\n[$section]\n";
			continue;
		}
		# Define variables
		list($param, $value) = explode('=', $line, 2);
		$param = rtrim($param);
		if (!empty($langhash["$section.$param"])) {
			continue;
		}
		$value = ltrim($value);
		$firsthyphen = substr($value, 0, 1);
		$lasthyphen = substr($value, -1, 1);
		if ($firsthyphen == '"' && $lasthyphen == '"') {
			$value = substr($value, 1, -1);
		}
		// echo "$param=$value\n";
		$langhash["$section.$param"] = $value;
	}
}


	
	
	public static function read_language_file($langfile)
	{
		$langarray = file($langfile, FILE_SKIP_EMPTY_LINES) or error_log("LoxBerry System ERROR: Could not read language file $langfile");
		if ($langarray == false) {
			error_log("Cannot read language $langfile");
		}
		return $langarray;
	}
	
	####### Get Miniserver array #######
	public static function get_miniservers() 
	{
		# If config file was read already, directly return the saved hash
		global $clouddnsaddress, $msClouddnsFetched;
		global $miniservers;
		
		if(!empty($msClouddnsFetched)) {
			return $miniservers;
		}
		
		if (empty($miniservers)) {
			LBSystem::read_generalcfg();
		}
		
		foreach ($miniservers as $msnr => $value) {
			# CloudDNS handling
			if ($miniservers[$msnr]['UseCloudDNS'] && $miniservers[$msnr]['CloudURL']) {
				LBSystem::set_clouddns($msnr, $clouddnsaddress);
			}
			if (! $miniservers[$msnr]['Port']) {
				$miniservers[$msnr]['Port'] = 80;
			}

			// Miniserver values consistency check
			// If a Miniserver entry is not plausible, the full Miniserver entry is deleted
			if(empty($miniservers[$msnr]['Name']) || empty($miniservers[$msnr]['IPAddress']) || empty($miniservers[$msnr]['Admin']) || empty($miniservers[$msnr]['Pass']) || empty($miniservers[$msnr]['Port'])) {
				unset($miniservers[$msnr]);
			}
		}
		$msClouddnsFetched = 1;
		return $miniservers;
	}

	####### Get Miniserver key by IP Address #######
	public static function get_miniserver_by_ip($ip)
	{
		global $miniservers;
		$ip = trim(strtolower($ip));
		
		if (! $miniservers) {
			LBSystem::read_generalcfg();
		}
		
		foreach ($miniservers as $key => $ms) {
			if (strtolower($ms['IPAddress']) == $ip) {
				return $key;
			}
		}
		return;
	}

	####### Get Miniserver key by Name #######
	public static function get_miniserver_by_name($myname)
	{
		global $miniservers;
		$myname = trim(strtolower($myname));
		
		if (! $miniservers) {
			LBSystem::read_generalcfg();
		}
		
		foreach ($miniservers as $key => $ms) {
			if (strtolower($ms['Name']) == $myname) {
				return $key;
			}
		}
		return;
	}

	####### Get Binaries #######
	public static function get_binaries()
	{
		global $binaries;
		if ($binaries) {
			return $binaries;
		} 

		if (! isset($miniservers)) {
				LBSystem::read_generalcfg();
				return $binaries;
		}
		return;
	}

	##################################################################################
	# Get Plugin Version
	# Returns plugin version from plugindatabase
	##################################################################################
	public static function pluginversion($queryname = "")
	{
		global $pluginversion;
		global $lbpplugindir;
		
		if (isset($pluginversion) && $queryname == "") {
			# error_log("Returning already fetched version\n");
			return $pluginversion;
		} 
		
		
		$query = $queryname != "" ? $queryname : $lbpplugindir;
		
		$plugin = LBSystem::plugindata($query);
		
		if (isset($plugin['PLUGINDB_VERSION']) && $queryname == "") {
				$pluginversion = $plugin['PLUGINDB_VERSION'];
		}
		
		return isset($plugin['PLUGINDB_VERSION']) ? $plugin['PLUGINDB_VERSION'] : null;
	}

	##################################################################################
	# Get Plugin Loglevel
	# Returns plugin loglevel from plugindatabase
	##################################################################################
	public static function pluginloglevel($queryname = "")
	{
		global $lbpplugindir;
		
		$query = $queryname != "" ? $queryname : $lbpplugindir;
		
		$plugin = LBSystem::plugindata($query);
		
		if (isset($plugin['PLUGINDB_LOGLEVEL']) && $queryname == "") {
				$pluginversion = $plugin['PLUGINDB_LOGLEVEL'];
		}
		
		return isset($plugin['PLUGINDB_LOGLEVEL']) ? $plugin['PLUGINDB_LOGLEVEL'] : 0;
	}

	
	##################################################################################
	# Get Plugindata
	# Returns the data of the current or named plugin
	##################################################################################
	public static function plugindata($queryname = "")
	{
		global $pluginversion;
		global $lbpplugindir;
		
		$query = $queryname != "" ? $queryname : $lbpplugindir;
				
		$plugins = LBSystem::get_plugins();
		
		foreach($plugins as $plugin) {
			if ($queryname != "" && ( $plugin['PLUGINDB_NAME'] == $queryname || $plugin['PLUGINDB_FOLDER'] == $queryname) ) {
				return $plugin;
			}
			if ($queryname == "" && $plugin['PLUGINDB_FOLDER'] == $lbpplugindir) {
				$pluginversion = $plugin['PLUGINDB_VERSION'];
				return $plugin;
			}
		}
	}
	
	##################################################################################
	# Get Plugins
	# Returns an array of all plugins without comments
	##################################################################################
	public static function get_plugins($withcomments = 0, $force = 0)
	{
		global $plugins;
		
		if (is_array($plugins)) {
			// error_log("Returning already fetched plugin array");
			return $plugins;
		} 
		$plugins = Array();
		# Read Plugin database copied from plugininstall.pl
		$filestr = file(LBHOMEDIR . "/data/system/plugindatabase.dat", FILE_IGNORE_NEW_LINES);
		#$filestr = file_get_contents(LBHOMEDIR . "/data/system/plugindatabase.dat");
		if (! $filestr) {
				error_log("LoxBerry System ERROR: Could not read Plugin Database " . LBSDATADIR . "plugindatabase.dat");
				return;
		}
		
		$plugincount=0;
		foreach ($filestr as $line) {
			$fields = explode('|', trim($line));
			if (substr($fields[0], 0, 1)=="#") {
				continue;
			}
			$plugincount++;
			$plugin = array (
				'PLUGINDB_NO' => $plugincount,
				'PLUGINDB_MD5_CHECKSUM' => $fields[0],
				'PLUGINDB_AUTHOR_NAME' => $fields[1],
				'PLUGINDB_AUTHOR_EMAIL' => $fields[2],
				'PLUGINDB_VERSION' => $fields[3],
				'PLUGINDB_NAME' => $fields[4],
				'PLUGINDB_FOLDER' => $fields[5],
				'PLUGINDB_TITLE' => $fields[6],
				'PLUGINDB_INTERFACE' => isset($fields[7]) ? $fields[7] : null,
				'PLUGINDB_AUTOUPDATE' => isset($fields[8]) ? $fields[8] : null,
				'PLUGINDB_RELEASECFG' => isset($fields[9]) ? $fields[9] : null,
				'PLUGINDB_PRERELEASECFG' => isset($fields[10]) ? $fields[10] : null,
				'PLUGINDB_LOGLEVEL' => isset($fields[11]) ? $fields[11] : null,
				'PLUGINDB_LOGLEVELS_ENABLED' => isset($fields[11]) && $fields[11] >= 0 ? 1 : 0,
				'PLUGINDB_ICONURI' => "/system/images/icons/$fields[5]/icon_64.png"
				);
				# On changes of the plugindatabase format, please change here
				# and in libs/perllib/LoxBerry/System.pm, sub get_plugins 
			array_push($plugins, $plugin);
		}
		return $plugins;
	}

	##################################################################################
	# Get System Version
	# Returns LoxBerry version
	##################################################################################
	public static function lbversion()
	{
		global $lbversion;
		
		if ($lbversion) {
			return $lbversion;
		} 
		LBSystem::read_generalcfg();
		return $lbversion;
	}

	#########################################################################
	# INTERNAL function read_generalcfg
	#########################################################################
	public static function read_generalcfg()
	{
		global $miniservers;
		global $miniservercount;
		global $cfg;
		global $binaries;
		global $lbversion;
		global $lbfriendlyname;
		global $lblang;
		global $cfgwasread;
		global $webserverport;
		global $clouddnsaddress;
		
	#	print ("READ miniservers FROM DISK\n");

		$cfg = parse_ini_file(LBHOMEDIR . "/config/system/general.cfg", True, INI_SCANNER_RAW) or error_log("LoxBerry System ERROR: Could not read general.cfg in " . LBHOMEDIR . "/config/system/");
		$cfgwasread = 1;
		// error_log("general.cfg Base: " . $cfg['BASE']['VERSION']);
		
		# Get CloudDNS and Timezones, System language
		$clouddnsaddress = $cfg['BASE']['CLOUDDNS'] or error_log("LoxBerry System Warning: BASE.CLOUDDNS not defined.");
		$lbtimezone	= $cfg['TIMESERVER']['ZONE'] or error_log("LoxBerry System Warning: TIMESERVER.ZONE not defined.");
		$lbversion = $cfg['BASE']['VERSION'] or error_log("LoxBerry System Warning: BASE.VERSION not defined.");
		$lbfriendlyname = isset($cfg['NETWORK']['FRIENDLYNAME']) ? $cfg['NETWORK']['FRIENDLYNAME'] : NULL;
		$webserverport = isset($cfg['WEBSERVER']['PORT']) ? $cfg['WEBSERVER']['PORT'] : NULL;
		$lblang = isset($cfg['BASE']['LANG']) ? $cfg['BASE']['LANG'] : NULL;
		// error_log("read_generalcfg: Language is $lblang");
		$binaries = $cfg['BINARIES'];
		
		# If no miniservers are defined, return NULL
		$miniservercount = $cfg['BASE']['MINISERVERS'];
		if (!$miniservercount || $miniservercount < 1) {
			return;
		}
		
		
		for ($msnr = 1; $msnr <= $miniservercount; $msnr++) {
			 
			$miniservers[$msnr]['Name'] = $cfg["MINISERVER$msnr"]['NAME'];
			$miniservers[$msnr]['IPAddress'] = $cfg["MINISERVER$msnr"]['IPADDRESS'];
			$miniservers[$msnr]['Admin'] = $cfg["MINISERVER$msnr"]['ADMIN'];
			$miniservers[$msnr]['Pass'] = $cfg["MINISERVER$msnr"]['PASS'];
			$miniservers[$msnr]['Credentials'] = $miniservers[$msnr]['Admin'] . ':' . $miniservers[$msnr]['Pass'];
			$miniservers[$msnr]['Note'] = $cfg["MINISERVER$msnr"]['NOTE'];
			$miniservers[$msnr]['Port'] = $cfg["MINISERVER$msnr"]['PORT'];
			$miniservers[$msnr]['UseCloudDNS'] = $cfg["MINISERVER$msnr"]['USECLOUDDNS'];
			$miniservers[$msnr]['CloudURLFTPPort'] = $cfg["MINISERVER$msnr"]['CLOUDURLFTPPORT'];
			$miniservers[$msnr]['CloudURL'] = $cfg["MINISERVER$msnr"]['CLOUDURL'];
			$miniservers[$msnr]['Admin_RAW'] = urldecode($miniservers[$msnr]['Admin']);
			$miniservers[$msnr]['Pass_RAW'] = urldecode($miniservers[$msnr]['Pass']);
			$miniservers[$msnr]['Credentials_RAW'] = $miniservers[$msnr]['Admin_RAW'] . ':' . $miniservers[$msnr]['Pass_RAW'];

			$miniservers[$msnr]['SecureGateway'] = isset($cfg["MINISERVER$msnr"]['SECUREGATEWAY']) && is_enabled($cfg["MINISERVER$msnr"]['SECUREGATEWAY']) ? 1 : 0;
			$miniservers[$msnr]['EncryptResponse'] = isset ($cfg["MINISERVER$msnr"]['ENCRYPTRESPONSE']) && is_enabled($cfg["MINISERVER$msnr"]['ENCRYPTRESPONSE']) ? 1 : 0;
		}
	}

	####################################################
	# set_clouddns
	# INTERNAL function to set CloudDNS IP and Port
	####################################################
	public static function set_clouddns($msnr, $clouddnsaddress)
	{
		global $binaries, $miniservers, $miniservercount;
		
		if (!$miniservercount || $miniservercount < 1) {
			return;
		}

		//$checkurl = "http://$clouddnsaddress/" . $miniservers[$msnr]['CloudURL']."/dev/cfg/ip";
		$checkurl = "http://".$clouddnsaddress."/?getip&snr=".$miniservers[$msnr]['CloudURL']."&json=true";
		$response = file_get_contents($checkurl);
		$ip_info = json_decode($response);
		$ip_info = explode(":",$ip_info->IP);
		$miniservers[$msnr]['IPAddress']=$ip_info[0];
		if (count($ip_info) == 2) {
			$miniservers[$msnr]['Port']=$ip_info[1];
		} else {
			$miniservers[$msnr]['Port']=80;
		}
		//$lastUrl = curl_getinfo($ch, CURLINFO_REDIRECT_URL );
	  //  (!parse_url($lastUrl,PHP_URL_PORT))?$miniservers[$msnr]['Port']=80:$miniservers[$msnr]['Port']=parse_url($lastUrl,PHP_URL_PORT);
	  //  (!parse_url($lastUrl,PHP_URL_HOST))?$miniservers[$msnr]['IPAddress']='127.0.0.1':$miniservers[$msnr]['IPAddress']=parse_url($lastUrl,PHP_URL_HOST);
	}

	#####################################################
	# get_ftpport
	# Function to get FTP port  considering CloudDNS Port
	# Input: $msnr
	# Output: $port
	#####################################################
	public static function get_ftpport($msnr = 1)
	{
		global $miniservers;
		global $miniservercount;
		
		# If we have no MS list, read the config
		if (!$miniservers) {
			LBSystem::read_generalcfg();
		}
		
		if ($miniservercount < 1) {
			return;
		}
		
		# If CloudDNS is enabled, return the CloudDNS FTP port
		if ($miniservers[$msnr]['UseCloudDNS'] && $miniservers[$msnr]['CloudURLFTPPort']) {
			return $miniservers[$msnr]['CloudURLFTPPort'];
		}
		
		# If $miniservers does not have FTP set, read FTP from Miniserver and save it in FTPPort
		if (! isset($miniservers[$msnr]['FTPPort'])) {
			# Get FTP Port from Miniserver
			$url = "http://{$miniservers[$msnr]['Credentials']}@{$miniservers[$msnr]['IPAddress']}:{$miniservers[$msnr]['Port']}/dev/cfg/ftp";
			$response = file_get_contents($url);
			
			if (! $response) {
				error_log("Cannot query FTP port because Loxone Miniserver is not reachable.");
				return;
			} 
			$xml = new \SimpleXMLElement($response);
			$port = $xml[0]['value'];
			$miniservers[$msnr]['FTPPort'] = $port;
		}
		return $miniservers[$msnr]['FTPPort'];
	}

	####################################################
	# get_localip - Get local ip address
	####################################################
	public static function get_localip()
	{
		$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
		socket_connect($sock, "8.8.8.8", 53);
		socket_getsockname($sock, $localip); // $name passed by reference
		socket_close($sock);
		return $localip;
	}

}

// END of class LBSystem


####################################################
# is_enabled - tries to detect if a string says 'True'
####################################################
function is_enabled($text)
{ 
	$text = trim($text);
	$text = strtolower($text);
	
	$words = array("true", "yes", "on", "enabled", "enable", "1", "check", "checked", "select", "selected");
	if (in_array($text, $words)) {
		return 1;
	}
	return NULL;
}


####################################################
# is_disabled - tries to detect if a string says 'False'
####################################################
function is_disabled($text)
{ 
	if (! isset($text)) {
		return 1;
	}
	$text = trim($text);
	$text = strtolower($text);
	
	$words = array("false", "no", "off", "disabled", "disable", "0");
	if (in_array($text, $words)) {
		return 1;
	}
	return NULL;
}

####################################################
# lbfriendlyname - Returns the friendly name
####################################################
function lbfriendlyname()
{
	global $cfgwasread;
	global $lbfriendlyname;
	
	if (! $cfgwasread) {
		LBSystem::read_generalcfg(); 
	}
	
	# print STDERR "LBSYSTEM lbfriendlyname $lbfriendlyname\n";
	return $lbfriendlyname;
	
}

####################################################
# lbhostname - Returns the network hostname
####################################################
function lbhostname()
{
	return gethostname();
}

####################################################
# lbwebserverport - Returns Apaches webserver port
####################################################
function lbwebserverport()
{
	global $cfgwasread;
	global $webserverport;
	
	if (! $cfgwasread) {
		LBSystem::read_generalcfg(); 
	}
	if (! $webserverport) {
		$webserverport = 80;
	}
	
	return $webserverport;
	
}

####################################################
# currtime - Returns current in different formats
####################################################
function currtime($format = 'hr')
{
	if (! $format || $format == 'hr') {
	$timestr = date('d.m.Y H:i:s', time());
	}
	elseif ($format == 'hrtime') {
	$timestr = date('H:i:s', time());
	}
	elseif ($format == 'hrtimehires') {
		list($usec, $sec) = explode(' ', microtime());
		$usec = substr($usec, 2, 3);
		$timestr = date('H:i:s', $sec) . '.' . $usec;
	}
	elseif ($format == 'file') {
		$timestr = date('Ymd_His', time());
	}
	elseif ($format == 'filehires') {
		list($usec, $sec) = explode(' ', microtime());
		$usec = substr($usec, 2, 3);
		$timestr = date('Ymd_His') . '_' . $usec;
	}
	elseif ($format == 'iso') {
		$timestr = date('"Y-m-d\TH:i:sO"', time());
	}
	return $timestr;
}

####################################################
# reboot_required - Sets the reboot required state
####################################################
function reboot_required($message = 'A reboot was requested')
{
	global $reboot_required_file;
	$fh = fopen($reboot_required_file, "a");
	if(!$fh) {
		error_log("Unable to open reboot_required file $reboot_required_file.");
		return(0);
	}
	fwrite($fh, $message);
	fclose($fh);
}
