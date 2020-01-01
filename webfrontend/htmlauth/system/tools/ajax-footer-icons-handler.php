<?php

header('Content-Type: application/json');

// Currently known types are: lbupdate, plugininstall
$lockfile_definitions = $_SERVER['LBHOMEDIR']."/config/system/lockfiles.default";
$which = array();

if (file_exists($lockfile_definitions))
{
	$lockfiles = file($lockfile_definitions);
	foreach ($lockfiles as $lockfilename) 
	{
		$lockfilename = trim($lockfilename, " \t\n\r\0\x0B");
		if (file_exists("/var/lock/".$lockfilename.".lock")) 
		{
			array_push($which, $lockfilename);
		} 
	}
}

// List what locks are set
if (!empty($which))
{
	$response['update_running'] = 1;
	$response['which'] = $which;
}
else
{
	$response['update_running'] = 0;
}

// reboot.required
if (file_exists($_SERVER['LBHOMEDIR']."/log/system_tmpfs/reboot.required")) 
{
	$response['reboot_required'] = 1;
} else {
	$response['reboot_required'] = 0;
}

// reboot.force. Do not send force if a lock is set.
if (empty($which) and file_exists($_SERVER['LBHOMEDIR']."/log/system_tmpfs/reboot.force")) 
{
	$response['reboot_force'] = 1;
	$response['reboot_force_reason'] = file_get_contents($_SERVER['LBHOMEDIR']."/log/system_tmpfs/reboot.force");
	
} else {
	$response['reboot_force'] = 0;
}

echo json_encode($response);

?>
