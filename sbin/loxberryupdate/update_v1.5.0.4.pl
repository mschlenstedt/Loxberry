#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

LOGINF "Replacing auto.smb with LoxBerry's modified auto.smb ...";
copy_to_loxberry("/system/autofs", "root");
if ( ! -l '/etc/auto.smb' ) {
	# Not a symlink
	execute ( command => 'mv -f /etc/auto.smb /etc/auto.smb.backup', log => $log );
}

if ( ! -e "$lbhomedir/system/autofs" ) {
	mkdir "$lbhomedir/system/autofs" or do { LOGERR "Could not create dir $lbhomedir/system/autofs"; $errors++; };
}
unlink "/etc/auto.smb";
symlink "$lbhomedir/system/autofs/auto.smb", "/etc/auto.smb" or do { LOGERR "Could not create symlink from /etc/auto.smb to $lbhomedir/system/autofs/auto.smb"; $errors++; };
execute ( command => "chmod 0755 $lbhomedir/system/autofs/auto.smb", log => $log );
execute ( command => "systemctl restart autofs", log => $log );

## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);


