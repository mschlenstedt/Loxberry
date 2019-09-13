#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

$LoxBerry::System::DEBUG = 1;

init();

if( -e $LoxBerry::System::PLUGINDATABASE ) {
	print "<WARN> Plugin database is already migrated. Skipping.";
} 

else {

	# Migrate plugindatabase.dat to plugindatabase.json
	my ($exitcode, $output) = LoxBerry::System::execute( 
		log => $log,
		intro => "Migrating plugindatabase to json file format",
		command => "perl $lbhomedir/sbin/loxberryupdate/migrate_plugindb_v2.pl",
		ok => "Plugin database migrated successfully.",
		error => "Migration returned an error."
	);

	if($exitcode == 0) {
		LOGINF "The old plugin database is kept for any issues as plugindatabase.dat";
		unlink "$lbsdatadir/plugindatabase.dat-";
		unlink "$lbsdatadir/plugindatabase.bkp";
	} else {
		$errors++;
		LOGWARN "Because of errors, the old files of plugindatabase are kept for further investigation.";
	}
}

## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
# reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
