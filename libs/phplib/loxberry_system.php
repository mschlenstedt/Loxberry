<?php
	
	# define Constants for LoxBerry directories
	if(getenv("LBHOMEDIR")) {
		define("LBHOMEDIR", getenv("LBHOMEDIR"));
	} 
	elseif (posix_getpwuid(posix_getpwnam('loxberry')['uid'])['dir']) {
			define("LBHOMEDIR", posix_getpwuid(posix_getpwnam('loxberry')['uid'])['dir']);
	}
	else {
		error_log("LoxBerry System WARNING: Falling back to /opt/loxberry");
		define("LBHOMEDIR", '/opt/loxberry');
	}

	// lbhomedir
	$lbhomedir = LBHOMEDIR;
	list($scriptPath) = get_included_files();
	$p = explode("/", substr($scriptPath, strlen(LBHOMEDIR)));
	
	// // Debugging
	// error_log("Path parts");
	// error_log("P1 = $p[1]");
	// error_log("P2 = $p[2]");
	// error_log("P3 = $p[3]");
	// error_log("P4 = $p[4]");
	// error_log("P5 = $p[5]");
	// error_log("P6 = $p[6]");
	
	if 		($p[1] == 'webfrontend' && $p[3] == 'plugins' && isset($p[4]) )  { $pluginname = $p[4]; }
	elseif 	($p[1] == 'templates' && $p[2] == 'plugins' && isset($p[3]) ) { $pluginname = $p[3]; }
	elseif	($p[1] == 'log' && $p[2] == 'plugins' && isset($p[3]) ) { $pluginname = $p[3]; }
	elseif	($p[1] == 'data' && $p[2] == 'plugins' && isset($p[3]) ) { $pluginname = $p[3]; }
	elseif	($p[1] == 'config' && $p[2] == 'plugins' && isset($p[3]) ) { $pluginname = $p[3]; }
	elseif	($p[1] == 'bin' && $p[2] == 'plugins' && isset($p[3]) ) { $pluginname = $p[3]; }
	elseif	($p[1] == 'system' && $p[2] == 'daemons' && $p[3] == 'plugins' && isset($p[4]) ) { $pluginname = $p[4]; }

	// error_log("Determined plugin name is $pluginname");
	
	if (isset($pluginname)) {
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
		
		// error_log("LoxBerry System Info: LBPPLUGINDIR: " . LBPPLUGINDIR);
	}

	// error_log("LoxBerry System Info: LBHOMEDIR: " . LBHOMEDIR);
	
	# Defining globals for SYSTEM directories
	define ("LBSHTMLAUTHDIR", LBHOMEDIR . "/webfrontend/htmlauth/system");
	define ("LBSHTMLDIR", LBHOMEDIR . "/webfrontend/html/system");
	define ("LBSTEMPLATEDIR", LBHOMEDIR . "/templates/system");
	define ("LBSDATADIR", LBHOMEDIR . "/data/system");
	define ("LBSLOGDIR", LBHOMEDIR . "/log/system");
	define ("LBSTMPFSLOGDIR", LBHOMEDIR . "/log/system_tmpfs");
	define ("LBSCONFIGDIR", LBHOMEDIR . "/config/system");
	define ("LBSSBINDIR", LBHOMEDIR . "/sbin");
	define ("LBSBINDIR", LBHOMEDIR . "/bin");

	# As globals in PHP cannot be concentrated in strings, we additionally define variables
	
	$lbshtmlauthdir = LBSHTMLAUTHDIR;
	$lbshtmldir = LBSHTMLDIR;
	$lbstemplatedir = LBSTEMPLATEDIR;
	$lbsdatadir = LBSDATADIR;
	$lbslogdir = LBSLOGDIR;
	$lbstmpfslogdir = LBSTMPFSLOGDIR;
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
	$plugindb_timestamp = 0;
	$plugindb_lastchecked = 0;
	$plugindb_timestamp_last = 0;

	
	$reboot_required_file = "$lbstmpfslogdir/reboot.required";
	define ("PLUGINDATABASE", "$lbsdatadir/plugindatabase.json");

// Functions in class LBSystem
// 
class LBSystem
{
	public static $LBSYSTEMVERSION = "2.0.0.3";
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
		if ($syslang == True and isset($genericlangfile) and $genericlangfile != "language.ini") {
			$genericlangfile = LBSTEMPLATEDIR . "/lang/$genericlangfile";
			$widgetlang = True;
		} elseif ($syslang == true) {
			$genericlangfile = LBSTEMPLATEDIR . "/lang/language.ini";
			$widgetlang = False;
		} else {
			$genericlangfile = LBPTEMPLATEDIR . "/lang/$genericlangfile";
			$widgetlang = False;
		}
		
		// error_log("readlanguage: genericlangfile $genericlangfile");
		$lang = LBSystem::lblanguage();
		$pos = strrpos($genericlangfile, ".");
		if ($pos === false) {
				error_log("readlanguage: Illegal option '$genericlangfile'. This should be in the form 'language.ini' without pathes.");
				return null;
		}
		
		$langfile_foreign = substr($genericlangfile, 0, $pos) . "_" . $lang . substr($genericlangfile, $pos);
		$langfile_en = substr($genericlangfile, 0, $pos) . "_en" . substr($genericlangfile, $pos);
		// error_log("readlanguage: $langfile_foreign enlangfile: $langfile_en");
		
		if ($syslang == False || $widgetlang == True || ($syslang == True && !is_array(self::$SL))) { 

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
		
			if ($syslang && !$widgetlang) {
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
		global $miniservers, $cfgwasread;
		
		if(!empty($msClouddnsFetched)) {
			return $miniservers;
		}
		
		if (isset($cfgwasread)) {
			return $miniservers;
		}	
		
		LBSystem::read_generalcfg();
		
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
	# $withcomments is legacy and unused
	##################################################################################
	public static function get_plugins($withcomments = 0, $force = 0)
	{
		global $plugins, $plugindb_timestamp_last;
		
		if($force != 0) {
			$plugins = null;
		}
		
		if($plugindb_timestamp_last != LBSystem::plugindb_changed_time()) {
			// Changed
			$plugindb_timestamp_new = LBSystem::plugindb_changed_time();
			$plugins = null;
			// error_log("get_plugins: Plugindb timestamp has changed (old: $plugindb_timestamp_last new: $plugindb_timestamp_new)");
			$plugindb_timestamp_last = $plugindb_timestamp_new;
		}
		
		if (is_array($plugins)) {
			// error_log("Returning already fetched plugin array");
			return $plugins;
		} 
		// error_log("Reading plugindb");
			
		$plugins = Array();
		# Read Plugin database copied from plugininstall.pl
		#$filestr = file(PLUGINDATABASE, FILE_IGNORE_NEW_LINES);
		$plugindb = json_decode(file_get_contents(PLUGINDATABASE));
		if (! $plugindb) {
				error_log("LoxBerry System ERROR: Could not read Plugin Database " . PLUGINDATABASE);
				return;
		}
		
		$plugincount=0;
		foreach ($plugindb->plugins as $plugindata) {
			$plugincount++;
			$plugin = array (
				'PLUGINDB_NO' => $plugincount,
				'PLUGINDB_MD5_CHECKSUM' => $plugindata->md5,
				'PLUGINDB_AUTHOR_NAME' => $plugindata->author_name,
				'PLUGINDB_AUTHOR_EMAIL' => $plugindata->author_email,
				'PLUGINDB_VERSION' => $plugindata->version,
				'PLUGINDB_NAME' => $plugindata->name,
				'PLUGINDB_FOLDER' => $plugindata->folder,
				'PLUGINDB_TITLE' => $plugindata->title,
				'PLUGINDB_INTERFACE' => isset($plugindata->interface) ? $plugindata->interface : null,
				'PLUGINDB_AUTOUPDATE' => isset($plugindata->autoupdate) ? $plugindata->autoupdate : null,
				'PLUGINDB_RELEASECFG' => isset($plugindata->releasecfg) ? $plugindata->releasecfg : null,
				'PLUGINDB_PRERELEASECFG' => isset($plugindata->prereleasecfg) ? $plugindata->prereleasecfg : null,
				'PLUGINDB_LOGLEVEL' => isset($plugindata->loglevel) ? $plugindata->loglevel : null,
				'PLUGINDB_LOGLEVELS_ENABLED' => isset($plugindata->loglevels_enabled) && $plugindata->loglevels_enabled >= 0 ? 1 : 0,
				'PLUGINDB_ICONURI' => "/system/images/icons/$plugindata->name/icon_64.png"
				);
				# On changes of the plugindatabase format, please change here
				# and in libs/perllib/LoxBerry/System.pm, sub get_plugins 
			array_push($plugins, $plugin);
		}
		return $plugins;
	}

	##################################################################################
	# INTERNAL function plugindb_changed
	# Returns the timestamp of the plugindb. Only really checks every minute
	##################################################################################

public static function plugindb_changed_time()
{
	global $plugindb_timestamp, $plugindb_lastchecked;
	
	$plugindb_file = PLUGINDATABASE;
	
	# If it was never checked, it cannot have changed
	if ($plugindb_timestamp == 0 || ($plugindb_lastchecked+60) < time()) {
		clearstatcache(TRUE, PLUGINDATABASE);
		$plugindb_timestamp = filemtime(PLUGINDATABASE);
		$plugindb_lastchecked = time();
		// error_log("Updating plugindb timestamp variable to $plugindb_timestamp ($plugindb_file)");
	}
	return ($plugindb_timestamp);	

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
		
		if(isset($cfgwasread)) { return; }
	
		# print ("READ miniservers FROM DISK\n");
		
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
			 
			@$miniservers[$msnr]['Name'] = $cfg["MINISERVER$msnr"]['NAME'];
			@$miniservers[$msnr]['IPAddress'] = $cfg["MINISERVER$msnr"]['IPADDRESS'];
			@$miniservers[$msnr]['Admin'] = $cfg["MINISERVER$msnr"]['ADMIN'];
			@$miniservers[$msnr]['Pass'] = $cfg["MINISERVER$msnr"]['PASS'];
			@$miniservers[$msnr]['Credentials'] = $miniservers[$msnr]['Admin'] . ':' . $miniservers[$msnr]['Pass'];
			@$miniservers[$msnr]['Note'] = $cfg["MINISERVER$msnr"]['NOTE'];
			@$miniservers[$msnr]['Port'] = $cfg["MINISERVER$msnr"]['PORT'];
			@$miniservers[$msnr]['UseCloudDNS'] = $cfg["MINISERVER$msnr"]['USECLOUDDNS'];
			@$miniservers[$msnr]['CloudURLFTPPort'] = $cfg["MINISERVER$msnr"]['CLOUDURLFTPPORT'];
			@$miniservers[$msnr]['CloudURL'] = $cfg["MINISERVER$msnr"]['CLOUDURL'];
			@$miniservers[$msnr]['Admin_RAW'] = urldecode($miniservers[$msnr]['Admin']);
			@$miniservers[$msnr]['Pass_RAW'] = urldecode($miniservers[$msnr]['Pass']);
			@$miniservers[$msnr]['Credentials_RAW'] = $miniservers[$msnr]['Admin_RAW'] . ':' . $miniservers[$msnr]['Pass_RAW'];

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

		//error_log("set_clouddns(PHP)-->");

		// CloudDNS caching
		$memfile = "/run/shm/clouddns_cache.json";
		
		// Read cache file
		// error_log("set_clouddns: Parse json");
		
		$cachekey = $miniservers[$msnr]['CloudURL'];
		
		do {		
			
			if(!file_exists($memfile)) break;
						
			$jsonstr = file_get_contents($memfile); 
			if(empty($jsonstr)) break;
			
			$jsonobj = json_decode($jsonstr);
			if(empty($jsonobj)) {
				error_log("set_clouddns(PHP) Failed to DECODE json:" . json_last_error_msg ());
				break;
			}			
			$msobj = $jsonobj->$cachekey;
			
			if(
				isset($msobj->refresh_timestamp) &&
				$msobj->refresh_timestamp > time() &&
				isset($msobj->IPAddress)
			) {
				$miniservers[$msnr]['IPAddress'] = $msobj->IPAddress;
				if(!empty($msobj->Port)) {
					$miniservers[$msnr]['Port'] = $msobj->Port;
				} else {
					$miniservers[$msnr]['Port'] = 80;
				}
				//error_log("Reading data from cachefile $memfile: IP {$miniservers[$msnr]['IPAddress']} Port {$miniservers[$msnr]['Port']}");
				return;
			}
		} while(0);

		//$checkurl = "http://$clouddnsaddress/" . $miniservers[$msnr]['CloudURL']."/dev/cfg/ip";
		$checkurl = "http://".$clouddnsaddress."/?getip&snr=".$miniservers[$msnr]['CloudURL']."&json=true";
		$response = @file_get_contents($checkurl);
		$http_status_line = $http_response_header[0];
		preg_match('{HTTP\/\S*\s(\d{3})}', $http_status_line, $match);
		$http_status = $match[1];
		if ($http_status !== "200") {
			$miniservers[$msnr]['IPAddress'] = "0.0.0.0";
			$miniservers[$msnr]['Port'] = "0";
			error_log("CloudDNS: Could not fetch ip address for Miniserver $msnr: $http_status_line");
			return;
		}
		
		$ip_info = json_decode($response);
		$ip_info = explode(":",$ip_info->IP);
		$miniservers[$msnr]['IPAddress']=$ip_info[0];
		if (count($ip_info) == 2) {
			$miniservers[$msnr]['Port']=$ip_info[1];
		} else {
			$miniservers[$msnr]['Port']=80;
		}
	
		// Save cache information to json
		if (!empty($miniservers[$msnr]['IPAddress'])) {
			if(empty($jsonobj)) {
				$jsonobj = new stdClass();
			}
			if(empty($jsonobj->$cachekey)) {
				$jsonobj->$cachekey = new stdClass();
			}
			$msobj = $jsonobj->$cachekey;
			
			$msobj->IPAddress = $miniservers[$msnr]['IPAddress'];
			$msobj->Port = $miniservers[$msnr]['Port'];
			$msobj->refresh_timestamp = time() + 3600 + rand(1,3600);
			
			//error_log(print_r($jsonobj, true));
			$jsonstr = json_encode($jsonobj);
			if ($jsonstr == false) {
				error_log("set_clouddns(PHP) Failed to ENCODE json:" . json_last_error_msg ());
				return;
			}	
			file_put_contents($memfile, $jsonstr);
			chown($memfile , 'loxberry');
			chgrp($memfile , 'loxberry');
		}
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
	if(empty($text)) { 
		return NULL; 
	}
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
	if (empty($text)) {
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
	fwrite($fh, $message . "\n");
	fclose($fh);
}

######################################################
# Converts an Epoche (Unix Timestamp, seconds from 1.1.1970 00:00:00 UTC) to Loxone Epoche (seconds from 1.1.2009 00:00:00)
#####################################################
function epoch2lox($epoche=null)
{	
	if(empty($epoche)) {
		$epoche = time();
	}
	$offset = 1230764400; # 1.1.2009 00:00:00
	$tz_delta = tz_offset();
	$loxepoche = $epoche - $offset + $tz_delta - 3600;
	return ($loxepoche);
}

function lox2epoch($loxepoche=null)
{
	if (empty($loxepoche)) {
		# For compatibility reasons to epoch2lox - but makes no sense here...
		$epoche = time();
	} else {
		$offset = 1230764400; # 1.1.2009 00:00:00
		$tz_delta = tz_offset();
		$epoche = $loxepoche + $offset - $tz_delta + 3600;
	}
	return $epoche;
}

# INTERNAL FUNCTION
# Returns the delta of local time to UTC
function tz_offset() {
    $origin_tz = date_default_timezone_get();
    $origin_dtz = new DateTimeZone($origin_tz);
    $remote_dtz = new DateTimeZone('UTC');
    $origin_dt = new DateTime("now", $origin_dtz);
    $remote_dt = new DateTime("now", $remote_dtz);
    $offset = $origin_dtz->getOffset($origin_dt) - $remote_dtz->getOffset($remote_dt);
    return $offset;
}
