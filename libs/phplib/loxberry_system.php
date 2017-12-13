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

	$plugindir_array = explode("/", substr(getcwd(), strlen(LBHOMEDIR)));
	if (isset($plugindir_array[4])) {
		$pluginname = $plugindir_array[4];
	}
		
		
	# $pluginname = explode("/", substr(getcwd(), strlen(LBHOMEDIR)))[4];
	if (isset($pluginname)) {
		define ("LBPLUGINDIR", $pluginname);
		unset($pluginname);
		// Plugin Constants
		define ("LBHTMLAUTHDIR", LBHOMEDIR . "/webfrontend/htmlauth/plugins/" . LBPLUGINDIR);
		define ("LBHTMLDIR", LBHOMEDIR . "/webfrontend/html/plugins/" . LBPLUGINDIR);
		define ("LBTEMPLATEDIR", LBHOMEDIR . "/templates/plugins/" . LBPLUGINDIR);
		define ("LBDATADIR", LBHOMEDIR . "/data/plugins/" . LBPLUGINDIR);
		define ("LBLOGDIR", LBHOMEDIR . "/log/plugins/" . LBPLUGINDIR);
		define ("LBCONFIGDIR", LBHOMEDIR . "/config/plugins/" . LBPLUGINDIR);
		// Plugin Variables
		$LBPLUGINDIR = LBPLUGINDIR;
		$LBHTMLAUTHDIR = LBHTMLAUTHDIR;
		$LBHTMLDIR = LBHTMLDIR;
		$LBTEMPLATEDIR = LBTEMPLATEDIR;
		$LBDATADIR = LBDATADIR;
		$LBLOGDIR = LBLOGDIR;
		$LBCONFIGDIR = LBCONFIGDIR;
		error_log("LoxBerry System Info: LBPLUGINDIR: " . LBPLUGINDIR);
	}

	error_log("LoxBerry System Info: LBHOMEDIR: " . LBHOMEDIR);
	
	# Defining globals for SYSTEM directories
	define ("LBSHTMLAUTHDIR", LBHOMEDIR . "/webfrontend/htmlauth/system");
	define ("LBSHTMLDIR", LBHOMEDIR . "/webfrontend/html/system");
	define ("LBSTEMPLATEDIR", LBHOMEDIR . "/templates/system");
	define ("LBSDATADIR", LBHOMEDIR . "/data/system");
	define ("LBSLOGDIR", LBHOMEDIR . "/log/system");
	define ("LBSCONFIGDIR", LBHOMEDIR . "/config/system");

	# As globals in PHP cannot be concentrated in strings, we additionally define variables
	$LBHOMEDIR = LBHOMEDIR;
	
	$LBSHTMLAUTHDIR = LBSHTMLAUTHDIR;
	$LBSHTMLDIR = LBSHTMLDIR;
	$LBSTEMPLATEDIR = LBSTEMPLATEDIR;
	$LBSDATADIR = LBSDATADIR;
	$LBSLOGDIR = LBSLOGDIR;
	$LBSCONFIGDIR = LBSCONFIGDIR;

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

class LBSystem
{
	public static $LBSYSTEMVERSION = "0.31_05";
	
	####### Get Miniserver array #######
	public function get_miniservers() 
	{
		# If config file was read already, directly return the saved hash
		global $miniservers;
		if ($miniservers) {
			# print ("READ miniservers FROM MEMORY\n");
			return $miniservers;
		}
		LBSystem::read_generalcfg();
		return $miniservers;
	}

	####### Get Miniserver key by IP Address #######
	public function get_miniserver_by_ip($ip)
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
	public function get_miniserver_by_name($myname)
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
	public function get_binaries()
	{
		global $binaries;
		if ($binaries) {
			return $binaries;
		} 

		if (! $miniservers) {
				LBSystem::read_generalcfg();
				return $binaries;
		}
		return;
	}

	##################################################################################
	# Get Plugin Version
	# Returns plugin version from plugindatabase
	##################################################################################
	public function pluginversion()
	{
		global $pluginversion;
		global $LBPLUGINDIR;
		
		if ($pluginversion) {
			# print STDERR "Returning already fetched version\n";
			return $pluginversion;
		} 
		if (!$LBPLUGINDIR) {
			return NULL;
		}
				
		# Read Plugin database copied from plugininstall.pl
		$filestr = file(LBHOMEDIR . "/data/system/plugindatabase.dat", FILE_IGNORE_NEW_LINES);
		#$filestr = file_get_contents(LBHOMEDIR . "/data/system/plugindatabase.dat");
		if (! $filestr) {
				error_log("LoxBerry System ERROR: Could not read Plugin Database " . LBHOMEDIR . "/data/system/plugindatabase.dat");
				return;
		}
		
		foreach ($filestr as $line) {
			$linearr = explode('|', $line);
			if (count($linearr) >=6  && $linearr[5] == LBPLUGINDIR) {
				$pluginversion = $linearr[3];
				return $pluginversion;
			}
		}
	}

	##################################################################################
	# Get Plugins
	# Returns an array of all plugins without comments
	##################################################################################
	public function get_plugins($withcomments = 0, $force = 0)
	{
		global $plugins;
		
		if (is_array($plugins)) {
			error_log("Returning already fetched plugin array");
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
				'PLUGINDB_INTERFACE' => $fields[7],
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
	public function lbversion()
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
	function read_generalcfg()
	{
		global $miniservers;
		global $miniservercount;
		global $cfg;
		global $binaries;
		global $lbversion;
		global $lbfriendlyname;
		global $lblang;
		global $cfgwasread;
		
	#	print ("READ miniservers FROM DISK\n");

		$cfg = parse_ini_file(LBHOMEDIR . "/config/system/general.cfg", True, INI_SCANNER_TYPED) or error_log("LoxBerry System ERROR: Could not read general.cfg in " . LBHOMEDIR . "/config/system/");
		$cfgwasread = 1;
		# error_log("general.cfg Base: " . $cfg['BASE']['VERSION']);
		
		# Get CloudDNS and Timezones, System language
		$clouddnsaddress = $cfg['BASE']['CLOUDDNS'] or error_log("LoxBerry System Warning: BASE.CLOUDDNS not defined.");
		$lbtimezone	= $cfg['TIMESERVER']['ZONE'] or error_log("LoxBerry System Warning: TIMESERVER.ZONE not defined.");
		$lbversion = $cfg['BASE']['VERSION'] or error_log("LoxBerry System Warning: BASE.VERSION not defined.");
		$lbfriendlyname = $cfg['NETWORK']['FRIENDLYNAME'] or error_log("LoxBerry System Info: NETWORK.FRIENDLYNAME not defined.");
		$lblang = $cfg['BASE']['LANG'];
		error_log("read_generalcfg: Language is $lblang");
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
			
			$miniservers[$msnr]['Admin_RAW'] = urlencode($miniservers[$msnr]['Admin']);
			$miniservers[$msnr]['Pass_RAW'] = urlencode($miniservers[$msnr]['Pass']);
			$miniservers[$msnr]['Credentials_RAW'] = $miniservers[$msnr]['Admin_RAW'] . ':' . $miniservers[$msnr]['Pass_RAW'];

			######## TO IMPLEMENT
			
			# CloudDNS handling
			if ($miniservers[$msnr]['UseCloudDNS'] && $miniservers[$msnr]['CloudURL']) {
				set_clouddns($msnr);
			}
			
			if (! $miniservers[$msnr]['Port']) {
				$miniservers[$msnr][Port] = 80;
			}

		}
	}

	####################################################
	# set_clouddns
	# INTERNAL function to set CloudDNS IP and Port
	####################################################
	function set_clouddns($msnr)
	{
		global $binaries;
		global $miniservers;
		global $clouddnsaddress;
		
		if (!$miniservercount || $miniservercount < 1) {
			return;
		}
		# Grep IP Address from Cloud Service
		$commandline = "{$binaries['CURL']} -I http://$clouddnsaddress/{$miniservers[$msnr]['CloudURL']} --connect-timeout 5 -m 5 2>/dev/null | {$binaries['GREP']} Location | {$binaries['AWK']} -F/ '{print \$3}'";
		# print "clouddns commandline: $commandline\n";
		#$dns_info = `$binaries['CURL'] -I http://$clouddnsaddress/$miniservers[$msnr]['CloudURL'] --connect-timeout 5 -m 5 2>/dev/null | $binaries['GREP'] Location | $binaries['AWK'] -F/ '{print \$3}'`;
		$dns_info = shell_exec($commandline);
		fwrite (STDERR, "LoxBerry System Info: CloudDNS Info: " . $dns_info . "\n");
		$dns_info_pieces = explode(':', $dns_info);

		if ($dns_info_pieces[1]) {
			# miniservers[$msnr]['Port'] =~ s/^\s+|\s+$//g;
			preg_match( 's/^\s+|\s+$//g', $dns_info_pieces[1], $matches);
			$miniservers[$msnr]['Port'] = $matches[0];
		 } else {
		 $miniservers[$msnr]['Port'] = 80;
		}

		if ($dns_info_pieces[0]) {
		  # $miniservers{$msnr}{IPAddress} =~ s/^\s+|\s+$//g;
			preg_match( 's/^\s+|\s+$//g', $dns_info_pieces[0], $matches);
			$miniservers[$msnr]['IPAddress'] = $matches[0];
		} else {
		  $miniservers[$msnr]['IPAddress'] = "127.0.0.1";
		}
	}

	#####################################################
	# get_ftpport
	# Function to get FTP port  considering CloudDNS Port
	# Input: $msnr
	# Output: $port
	#####################################################
	public function get_ftpport($msnr = 1)
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
	public function get_localip()
	{
		$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
		socket_connect($sock, "8.8.8.8", 53);
		socket_getsockname($sock, $localip); // $name passed by reference
		socket_close($sock);
		return $localip;
	}

	#########################################################
	# is_systemcall - Determine if called from system widget
	#########################################################

	public function is_systemcall()
	{
		$mypath = getcwd();
		error_log("is_systemcall: mypath $mypath");
		# print STDERR "abs_path:  " . Cwd::abs_path($0) . "\n";
		# print STDERR "lbshtmlauthdir: " . $lbshtmlauthdir . "\n";
		# print STDERR "substr:    " . substr(Cwd::abs_path($0), 0, length($lbshtmlauthdir)) . "\n";
		
		if (substr($mypath, 0, strlen(LBSHTMLAUTHDIR)) === LBSHTMLAUTHDIR) { return 1; }
		if (substr($mypath, 0, strlen(LBHOMEDIR . "/sbin")) === LBHOMEDIR . "/sbin") { return 1; }
		if (substr($mypath, 0, strlen(LBHOMEDIR . "/bin")) === LBHOMEDIR . "/bin") { return 1; }
		return null;
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
	return undef;
}


####################################################
# is_disabled - tries to detect if a string says 'False'
####################################################
function is_disabled($text)
{ 
	$text = trim($text);
	$text = strtolower($text);
	
	$words = array("false", "no", "off", "disabled", "disable", "0");
	if (in_array($text, $words)) {
		return 1;
	}
	return undef;
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


?>
