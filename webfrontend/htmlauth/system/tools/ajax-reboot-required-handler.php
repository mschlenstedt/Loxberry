<?php
if (file_exists($_SERVER['LBHOMEDIR']."/log/system_tmpfs/reboot.required")) 
{
	echo '{"reboot_required": "1"}';
} else {
	echo '{"reboot_required": "0"}';
}
?>
