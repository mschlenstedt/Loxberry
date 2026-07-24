<?php

require_once "loxberry_system.php";

// get_storage_html
function get_storage_html ($args)
{

	global $lbpdatadir;

	$STORAGEHANDLERURL = "http://localhost:" . lbwebserverport() . "/admin/system/ajax/ajax-storage-handler.cgi";	

	$args['action'] = 'init';
	
	// $fields = array(
		// 'action' => 'init',
	// );
	
	if (!isset($args['localdir']) && isset($lbpdatadir)) {
		$args['localdir'] = $lbpdatadir;
	}
	
	$options = array(
		'http' => array(
			'header'  => "Content-type: application/x-www-form-urlencoded; charset=utf-8\r\n",
			'method'  => 'POST',
			'content' => http_build_query($args)
			)
	);
	$context  = stream_context_create($options);
	$result = file_get_contents($STORAGEHANDLERURL, false, $context);
	if ($result === FALSE) {
		error_log("get_storage_html: Could not get storage html");
		return;
	}

	return $result;

}

// get_netshares
// Returns all mounted network shares as an array of assoc arrays.
// Parameters:
//   $readwriteonly  If true, only writable shares are returned.
//   $forcereload    If true, the internal cache is bypassed.
// Each entry contains the keys NETSHARE_NO, NETSHARE_SERVER, NETSHARE_TYPE,
// NETSHARE_SERVERPATH, NETSHARE_SHAREPATH, NETSHARE_SHARENAME, NETSHARE_STATE,
// NETSHARE_USED(_HR), NETSHARE_AVAILABLE(_HR), NETSHARE_SIZE(_HR),
// NETSHARE_USEDPERCENT. Returns NULL on error.
function get_netshares($readwriteonly = false, $forcereload = false)
{
	global $lbhomedir;
	static $netshares_cache = null;

	if ($netshares_cache !== null && !$forcereload) {
		return $netshares_cache;
	}

	$storagebase = $lbhomedir . "/system/storage";
	$sharetypes = @scandir($storagebase);
	if ($sharetypes === false) {
		error_log("get_netshares: Error opening storage folder $storagebase");
		return null;
	}

	$netshares = array();
	$netsharecount = 0;

	foreach ($sharetypes as $type) {
		if ($type === '.' || $type === '..' || $type === 'usb') { continue; }
		$typepath = "$storagebase/$type";
		if (!is_dir($typepath)) { continue; }
		$serverfolders = @scandir($typepath);
		if ($serverfolders === false) { continue; }

		foreach ($serverfolders as $server) {
			if ($server === '.' || $server === '..') { continue; }
			$serverpath = "$typepath/$server";
			if (!is_dir($serverpath)) { continue; }
			$sharefolders = @scandir($serverpath);
			if ($sharefolders === false) { continue; }

			foreach ($sharefolders as $share) {
				if ($share === '.' || $share === '..') { continue; }
				$sharepath = "$serverpath/$share";
				$state = "";

				// Check read/write state
				LBSystem::execute("ls " . escapeshellarg($sharepath), $ec_ls);
				if ($ec_ls == 0) { $state = "Readonly"; }
				LBSystem::execute("touch " . escapeshellarg("$sharepath/check_loxberry_rw_state.tmp"), $ec_touch);
				if ($ec_touch == 0) { $state = "Writable"; }
				LBSystem::execute("rm " . escapeshellarg("$sharepath/check_loxberry_rw_state.tmp"), $ec_rm);

				if (($readwriteonly && $state !== "Writable") || !$state) { continue; }

				$folderinfo = LBSystem::diskspaceinfo($sharepath);
				if (!is_array($folderinfo)) { $folderinfo = array(); }
				$f_used  = isset($folderinfo['used'])      ? $folderinfo['used']      : 0;
				$f_avail = isset($folderinfo['available']) ? $folderinfo['available'] : 0;
				$f_size  = isset($folderinfo['size'])      ? $folderinfo['size']      : 0;

				$netsharecount++;
				$netshares[] = array(
					'NETSHARE_NO'           => $netsharecount,
					'NETSHARE_SERVER'       => $server,
					'NETSHARE_TYPE'         => $type,
					'NETSHARE_SERVERPATH'   => $serverpath,
					'NETSHARE_SHAREPATH'    => $sharepath,
					'NETSHARE_SHARENAME'    => $share,
					'NETSHARE_STATE'        => $state,
					'NETSHARE_USED'         => $f_used,
					'NETSHARE_USED_HR'      => LBSystem::bytes_humanreadable($f_used, "k"),
					'NETSHARE_AVAILABLE'    => $f_avail,
					'NETSHARE_AVAILABLE_HR' => LBSystem::bytes_humanreadable($f_avail, "k"),
					'NETSHARE_SIZE'         => $f_size,
					'NETSHARE_SIZE_HR'      => LBSystem::bytes_humanreadable($f_size, "k"),
					'NETSHARE_USEDPERCENT'  => isset($folderinfo['usedpercent']) ? $folderinfo['usedpercent'] : null,
				);
			}
		}
	}

	$netshares_cache = $netshares;
	return $netshares;
}

// get_netservers
// Returns all network share servers as an array of assoc arrays.
// Each entry contains NETSERVER_NO, NETSERVER_SERVER, NETSERVER_TYPE,
// NETSERVER_SERVERPATH and NETSERVER_USERNAME (for smb servers).
// Returns NULL on error.
function get_netservers()
{
	global $lbhomedir;

	$storagebase = $lbhomedir . "/system/storage";
	$sharetypes = @scandir($storagebase);
	if ($sharetypes === false) {
		error_log("get_netservers: Error opening storage folder $storagebase");
		return null;
	}

	$netservers = array();
	$netservercount = 0;

	foreach ($sharetypes as $type) {
		if ($type === '.' || $type === '..' || $type === 'usb') { continue; }
		$typepath = "$storagebase/$type";
		if (!is_dir($typepath)) { continue; }
		$serverfolders = @scandir($typepath);
		if ($serverfolders === false) { continue; }

		$serveruser = array();

		foreach ($serverfolders as $server) {
			if ($server === '.' || $server === '..') { continue; }
			$serverpath = "$typepath/$server";

			$netservercount++;
			$netserver = array(
				'NETSERVER_NO'         => $netservercount,
				'NETSERVER_SERVER'     => $server,
				'NETSERVER_TYPE'       => $type,
				'NETSERVER_SERVERPATH' => $serverpath,
			);

			if ($type === "smb" && !isset($serveruser[$server])) {
				$serveruser[$server] = "";
				$credfile = "$lbhomedir/system/samba/credentials/$server";
				if (file_exists($credfile)) {
					$cred = @parse_ini_file($credfile, true);
					if (is_array($cred)) {
						if (isset($cred['default']['username'])) {
							$serveruser[$server] = $cred['default']['username'];
						} elseif (isset($cred['username'])) {
							$serveruser[$server] = $cred['username'];
						}
					}
				}
			}
			$netserver['NETSERVER_USERNAME'] = isset($serveruser[$server]) ? $serveruser[$server] : "";
			$netservers[] = $netserver;
		}
	}

	return $netservers;
}

// get_usbstorage
// Returns all USB storage devices as an array of assoc arrays.
// Parameters:
//   $sizeunit       'h' = human readable, 'mb', 'gb'. Empty = kB.
//   $readwriteonly  If true, only writable devices are returned.
// Each entry contains USBSTORAGE_NO, USBSTORAGE_DEVICE, USBSTORAGE_BLOCKDEVICE,
// USBSTORAGE_TYPE, USBSTORAGE_STATE, USBSTORAGE_USED, USBSTORAGE_SIZE,
// USBSTORAGE_AVAILABLE, USBSTORAGE_CAPACITY, USBSTORAGE_USEDPERCENT,
// USBSTORAGE_DEVICEPATH. Returns NULL on error.
function get_usbstorage($sizeunit = '', $readwriteonly = false)
{
	global $lbhomedir;

	$sizeunit = strtolower($sizeunit);
	$usbbase = $lbhomedir . "/system/storage/usb";
	$usbdevices = @scandir($usbbase);
	if ($usbdevices === false) {
		error_log("get_usbstorage: Error opening storage folder $usbbase");
		return null;
	}

	$usbstorages = array();
	$usbstoragecount = 0;

	foreach ($usbdevices as $device) {
		if ($device === '.' || $device === '..') { continue; }
		$devicepath = "$usbbase/$device";

		$disk = LBSystem::diskspaceinfo($devicepath);
		if (!is_array($disk)) { $disk = array(); }
		$d_used        = isset($disk['used'])        ? $disk['used']        : 0;
		$d_size        = isset($disk['size'])        ? $disk['size']        : 0;
		$d_avail       = isset($disk['available'])   ? $disk['available']   : 0;
		$d_fs          = isset($disk['filesystem'])  ? $disk['filesystem']  : '';
		$d_usedpercent = isset($disk['usedpercent']) ? $disk['usedpercent'] : '';

		if ($sizeunit === "h") {
			$used = LBSystem::bytes_humanreadable($d_used, "k");
			$size = LBSystem::bytes_humanreadable($d_size, "k");
			$available = LBSystem::bytes_humanreadable($d_avail, "k");
		} elseif ($sizeunit === "mb") {
			$used = sprintf("%.1f", $d_used / 1024);
			$available = sprintf("%.1f", $d_avail / 1024);
			$size = sprintf("%.1f", $d_size / 1024);
		} elseif ($sizeunit === "gb") {
			$used = sprintf("%.1f", $d_used / 1024 / 1024);
			$available = sprintf("%.1f", $d_avail / 1024 / 1024);
			$size = sprintf("%.1f", $d_size / 1024 / 1024);
		} else {
			$used = $d_used;
			$available = $d_avail;
			$size = $d_size;
		}

		$type = "";
		if ($d_fs) {
			$typeout = LBSystem::execute("blkid -o udev " . escapeshellarg($d_fs) . " | grep ID_FS_TYPE | awk -F \"=\" '{ print \$2 }'");
			$type = isset($typeout[0]) ? trim($typeout[0]) : "";
		}

		$state = "";
		LBSystem::execute("ls " . escapeshellarg($devicepath), $ec_ls);
		if ($ec_ls == 0) { $state = "Readonly"; }
		LBSystem::execute("touch " . escapeshellarg("$devicepath/check_loxberry_rw_state.tmp"), $ec_touch);
		if ($ec_touch == 0) { $state = "Writable"; }
		LBSystem::execute("rm " . escapeshellarg("$devicepath/check_loxberry_rw_state.tmp"), $ec_rm);

		if (($readwriteonly && $state !== "Writable") || !$state) { continue; }

		$usbstoragecount++;
		$usbstorages[] = array(
			'USBSTORAGE_NO'          => $usbstoragecount,
			'USBSTORAGE_DEVICE'      => $device,
			'USBSTORAGE_BLOCKDEVICE' => $d_fs,
			'USBSTORAGE_TYPE'        => $type,
			'USBSTORAGE_STATE'       => $state,
			'USBSTORAGE_USED'        => $used,
			'USBSTORAGE_SIZE'        => $size,
			'USBSTORAGE_AVAILABLE'   => $available,
			'USBSTORAGE_CAPACITY'    => $d_usedpercent,
			'USBSTORAGE_USEDPERCENT' => $d_usedpercent,
			'USBSTORAGE_DEVICEPATH'  => $devicepath,
		);
	}

	return $usbstorages;
}

// get_storage
// Returns a unified list of all available storages (network shares, USB
// devices and the local plugin data directory) as an array of assoc arrays.
// Parameters:
//   $readwriteonly  If true, only writable storages are returned.
//   $localdir       Overrides the local directory (default: plugin datadir).
// Each entry contains GROUP (net|usb|local), TYPE, PATH, WRITABLE, AVAILABLE,
// USED, SIZE, SIZE_GB, NAME plus group-specific fields.
function get_storage($readwriteonly = false, $localdir = null)
{
	global $lbpdatadir;

	$storages = array();

	// Network Shares
	$netshares = get_netshares($readwriteonly);
	if (is_array($netshares)) {
		foreach ($netshares as $netshare) {
			$size = isset($netshare['NETSHARE_SIZE']) ? $netshare['NETSHARE_SIZE'] : 0;
			$size_gb = (int)($size / 1024 / 1024 + 0.5);
			$storages[] = array(
				'GROUP'              => 'net',
				'TYPE'               => $netshare['NETSHARE_TYPE'],
				'PATH'               => $netshare['NETSHARE_SHAREPATH'],
				'WRITABLE'           => $netshare['NETSHARE_STATE'] === 'Writable' ? 1 : 0,
				'AVAILABLE'          => $netshare['NETSHARE_AVAILABLE'],
				'USED'               => $netshare['NETSHARE_USED'],
				'SIZE'               => $size,
				'SIZE_GB'            => $size_gb,
				'NAME'               => $netshare['NETSHARE_SERVER'] . '::' . $netshare['NETSHARE_SHARENAME'] . " (" . $size_gb . " GB)",
				'NETSHARE_SERVER'    => $netshare['NETSHARE_SERVER'],
				'NETSHARE_SHARENAME' => $netshare['NETSHARE_SHARENAME'],
			);
		}
	}

	// USB devices
	$usbdevices = get_usbstorage('', $readwriteonly);
	if (is_array($usbdevices)) {
		foreach ($usbdevices as $usbdevice) {
			$size = isset($usbdevice['USBSTORAGE_SIZE']) ? $usbdevice['USBSTORAGE_SIZE'] : 0;
			$size_gb = (int)($size / 1024 / 1024 + 0.5);
			$storages[] = array(
				'GROUP'                  => 'usb',
				'TYPE'                   => $usbdevice['USBSTORAGE_TYPE'],
				'PATH'                   => $usbdevice['USBSTORAGE_DEVICEPATH'],
				'WRITABLE'               => $usbdevice['USBSTORAGE_STATE'] === 'Writable' ? 1 : 0,
				'AVAILABLE'              => $usbdevice['USBSTORAGE_AVAILABLE'],
				'USED'                   => $usbdevice['USBSTORAGE_USED'],
				'SIZE'                   => $size,
				'SIZE_GB'                => $size_gb,
				'NAME'                   => "USB::" . $usbdevice['USBSTORAGE_DEVICE'] . " (" . $size_gb . " GB)",
				'USBSTORAGE_DEVICE'      => $usbdevice['USBSTORAGE_DEVICE'],
				'USBSTORAGE_BLOCKDEVICE' => $usbdevice['USBSTORAGE_BLOCKDEVICE'],
			);
		}
	}

	// Local Plugin data directory
	if ((isset($lbpdatadir) && $lbpdatadir) || $localdir) {
		$path = $localdir ? $localdir : $lbpdatadir;
		$disk = LBSystem::diskspaceinfo($path);
		if (!is_array($disk)) { $disk = array(); }
		$d_size = isset($disk['size']) ? $disk['size'] : 0;
		$size_gb = (int)($d_size / 1024 / 1024 + 0.5);
		$storages[] = array(
			'GROUP'     => 'local',
			'TYPE'      => 'local',
			'PATH'      => $path,
			'WRITABLE'  => 1,
			'AVAILABLE' => isset($disk['available']) ? $disk['available'] : null,
			'USED'      => isset($disk['used']) ? $disk['used'] : null,
			'SIZE'      => $d_size,
			'SIZE_GB'   => $size_gb,
			'NAME'      => 'Local Datadir (' . $size_gb . ' GB)',
		);
	}

	return $storages;
}
