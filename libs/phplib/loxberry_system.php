<?php

namespace LoxBerry\System;

# define Constants for LoxBerry directories

if(getenv("LBHOMEDIR")) {
	define("LBHOMEDIR", getenv("LBHOMEDIR"));
} 
elseif (posix_getpwuid(posix_getpwnam('loxberry')['uid'])['dir']) {
		define("LBHOMEDIR", posix_getpwuid(posix_getpwnam('loxberry')['uid'])['dir']);
}
else {
	fwrite(STDERR, "LoxBerry System WARNING: Falling back to /opt/loxberry\n");
	define("LBHOMEDIR", '/opt/loxberry');
}

$pluginname = explode("/", substr(getcwd(), strlen(LBHOMEDIR)))[4];
define ("LBPLUGINDIR", $pluginname);
unset($pluginname);

fwrite(STDERR, "LoxBerry System Info: LBHOMEDIR: " . LBHOMEDIR . "\n");
fwrite(STDERR, "LoxBerry System Info: LBPLUGINDIR: " . LBPLUGINDIR . "\n");

# Defining globals
define ("LBCGIDIR", LBHOMEDIR . "/webfrontend/cgi/plugins/" . LBPLUGINDIR);
define ("LBHTMLDIR", LBHOMEDIR . "/webfrontend/html/plugins/" . LBPLUGINDIR);
define ("LBTEMPLATEDIR", LBHOMEDIR . "/templates/plugins/" . LBPLUGINDIR);
define ("LBDATADIR", LBHOMEDIR . "/data/plugins/" . LBPLUGINDIR);
define ("LBLOGDIR", LBHOMEDIR . "/log/plugins/" . LBPLUGINDIR);
define ("LBCONFIGDIR", LBHOMEDIR . "/config/plugins/" . LBPLUGINDIR);

# As globals in PHP cannot be concentrated in strings, we additionally define variables
$LBHOMEDIR = LBHOMEDIR;
$LBPLUGINDIR = LBPLUGINDIR;
$LBCGIDIR = LBCGIDIR;
$LBHTMLDIR = LBHTMLDIR;
$LBTEMPLATEDIR = LBTEMPLATEDIR;
$LBDATADIR = LBDATADIR;
$LBLOGDIR = LBLOGDIR;
$LBCONFIGDIR = LBCONFIGDIR;

# Variables to store

$cfg=NULL;
$miniservers=NULL;
$binaries=NULL;
$pluginversion=NULL;

####### Get Miniserver array #######
function get_miniservers() 
{
	# If config file was read already, directly return the saved hash
	global $miniservers;
	if ($miniservers) {
		# print ("READ miniservers FROM MEMORY\n");
		return $miniservers;
	}
	read_generalcfg();
	return $miniservers;
}

####### Get Miniserver key by IP Address #######
function get_miniserver_by_ip($ip)
{
	global $miniservers;
	$ip = trim(strtolower($ip));
	
	if (! $miniservers) {
		read_generalcfg();
	}
	
	foreach ($miniservers as $key => $ms) {
		if (strtolower($ms['IPAddress']) == $ip) {
			return $key;
		}
	}
	return;
}

####### Get Miniserver key by Name #######
function get_miniserver_by_name($myname)
{
	global $miniservers;
	$myname = trim(strtolower($myname));
	
	if (! $miniservers) {
		read_generalcfg();
	}
	
	foreach ($miniservers as $key => $ms) {
		if (strtolower($ms['Name']) == $myname) {
			return $key;
		}
	}
	return;
}

####### Get Binaries #######
function get_binaries()
{
	global $binaries;
	if ($binaries) {
		return $binaries;
	} 

	if (! $miniservers) {
			read_generalcfg();
			return $binaries;
	}
	return;
}

##################################################################################
# Get Plugin Version
# Returns plugin version from plugindatabase
##################################################################################
function pluginversion()
{
	global $pluginversion;
	if ($pluginversion) {
		# print STDERR "Returning already fetched version\n";
		return $pluginversion;
	} 
	
	# Read Plugin database copied from plugininstall.pl
	$filestr = file(LBHOMEDIR . "/data/system/plugindatabase.dat", FILE_IGNORE_NEW_LINES);
	#$filestr = file_get_contents(LBHOMEDIR . "/data/system/plugindatabase.dat");
	if (! $filestr) {
			fwrite(STDERR, "LoxBerry System ERROR: Could not read Plugin Database " . LBHOMEDIR . "/data/system/plugindatabase.dat \n");
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

function read_generalcfg()
{
 	global $miniservers;
	global $cfg;
	global $binaries;
	
#	print ("READ miniservers FROM DISK\n");

	$cfg = parse_ini_file(LBHOMEDIR . "/config/system/general.cfg", True, INI_SCANNER_TYPED) or fwrite(STDERR, "LoxBerry System ERROR: Could not read general.cfg in " . LBHOMEDIR . "/config/system/\n");
	
	# fwrite(STDERR, "general.cfg Base: " . $cfg['BASE']['VERSION'] . "\n");
	
	# If no miniservers are defined, return NULL
	$miniservercount = $cfg['BASE']['MINISERVERS'];
	if (!$miniservercount || $miniservercount < 1) {
		return;
	}
	# Get CloudDNS and Timezones
	$clouddnsaddress = $cfg['BASE']['CLOUDDNS'] or fwrite(STDERR, "LoxBerry System Warning: BASE.CLOUDDNS not defined.\n");
	$lbtimezone	= $cfg['TIMESERVER']['ZONE'] or fwrite(STDERR, "LoxBerry System Warning: TIMESERVER.ZONE not defined.\n");
	
	$binaries = $cfg['BINARIES'];
	
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
	
	# Grep IP Address from Cloud Service
	$commandline = "{$binaries['CURL']} -I http://$clouddnsaddress/{$miniservers[$msnr]['CloudURL']} --connect-timeout 5 -m 5 2>/dev/null | {$binaries['GREP']} Location | {$binaries['AWK']} -F/ '{print \$3}'";
	#$dns_info = `$binaries['CURL'] -I http://$clouddnsaddress/$miniservers[$msnr]['CloudURL'] --connect-timeout 5 -m 5 2>/dev/null | $binaries['GREP'] Location | $binaries['AWK'] -F/ '{print \$3}'`;
	$dns_info = `$commandline`;
	fwrite (STDERR, "LoxBerry System Info: CloudDNS Info: " . $dns_info . "\n");
	fwrite (STDERR, "LoxBerry System WARNING: CloudDNS NOT IMPLEMENTED!\n");
	$dns_info_pieces = explode(':', $dns_info);

	# Not implemented - need an example of above command
	
	# if ($dns_info_pieces[1]) {
		# $miniservers[$msnr]['Port'] =~ s/^\s+|\s+$//g;
	// } else {
	  // $miniservers{$msnr}{Port} = 80;
	// }

	// if ($dns_info_pieces[0]) {
	  // $miniservers{$msnr}{IPAddress} =~ s/^\s+|\s+$//g;
	// } else {
	  // $miniservers{$msnr}{IPAddress} = "127.0.0.1";
	// }
}

#####################################################
# get_ftpport
# Function to get FTP port  considering CloudDNS Port
# Input: $msnr
# Output: $port
#####################################################
function get_ftpport($msnr = 1)
{
	global $miniservers;
		
#	$msnr = ($msnr ? $msnr : 1);
	
	# If we have no MS list, read the config
	if (! $miniservers) {
		read_generalcfg();
	}
	
	# If CloudDNS is enabled, return the CloudDNS FTP port
	if ($miniservers[$msnr]['UseCloudDNS'] && $miniservers[$msnr]['CloudURLFTPPort']) {
		return $miniservers[$msnr]['CloudURLFTPPort'];
	}
	
	# If $miniservers does not have FTP set, read FTP from Miniserver and save it in FTPPort
	if (! $miniservers[$msnr]['FTPPort']) {
		# Get FTP Port from Miniserver
		$url = "http://{$miniservers[$msnr]['Credentials']}@{$miniservers[$msnr]['IPAddress']}:{$miniservers[$msnr]['Port']}/dev/cfg/ftp";
		$response = file_get_contents($url);
		
		if (! $response) {
			fwrite(STDERR, "Cannot query FTP port because Loxone Miniserver is not reachable.");
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
function get_localip()
{
	$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
	socket_connect($sock, "8.8.8.8", 53);
	socket_getsockname($sock, $localip); // $name passed by reference
	socket_close($sock);
	return $localip;
}

?>
