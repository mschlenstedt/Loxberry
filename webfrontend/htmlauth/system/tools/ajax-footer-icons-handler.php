<?php
#Currently known types are: lbupdate, plugininstall
$lockfile_definitions = $_SERVER['LBHOMEDIR']."/config/system/lockfiles.default";
$at_least_one_running = 0;
if (file_exists($lockfile_definitions))
{
	$lockfiles = file($lockfile_definitions);
	$which = ', "which": [ ';
	foreach ($lockfiles as $lockfilename) 
	{
		$lockfilename = trim($lockfilename, " \t\n\r\0\x0B");
		if (file_exists("/var/lock/".$lockfilename.".lock")) 
		{
			$which .= '"'.$lockfilename.'",';
			$at_least_one_running = 1;
		} 
	}
	if ($at_least_one_running)
	{
		
		$which = rtrim($which,",").' ]'; 
	}
	else
	{
		$which = "";
	}
}

if (file_exists($_SERVER['LBHOMEDIR']."/log/system_tmpfs/reboot.required")) 
{
	$reboot_required='"reboot_required": "1",';
} else {
	$reboot_required='"reboot_required": "0",';
}

if ($at_least_one_running)
{
	echo '{'.$reboot_required.'"update_running": "1"'.$which.'}';
}
else
{
	echo '{'.$reboot_required.'"update_running": "0"}';
}
?>
