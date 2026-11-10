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

// Check package install processes (#1584)
$commandlist = array(
	// Match exact process names, not arbitrary command-line arguments
	'pgrep -l -x ' . escapeshellarg('apt|apt-get|dpkg'),
	// Match the updater itself, optionally launched through Python. A process
	// name is cut to 15 characters, so this needs -f. The anchored pattern
	// excludes shell wrappers (including the sh that exec() starts) and
	// unattended-upgrade-shutdown
	'pgrep -a -f ' . escapeshellarg(
		'^(/usr/bin/python3([.][0-9]+)*[[:space:]]+)?'
		. '/usr/bin/unattended-upgrade([[:space:]]|$)'
	)
);

foreach($commandlist as $command) {
	$output = array();
	$exitcode = 0;
	exec($command, $output, $exitcode);
	if($exitcode === 0) {
		foreach($output as $process) {
			$which[] = $process;
		}
	} elseif($exitcode !== 1) {
		// pgrep exits with 1 if nothing matched - anything else is a failure
		error_log("Package process detection failed with exit code $exitcode: $command");
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
