#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

# Correct missing BINARIES section in legacy general.cfg

LOGINF "Checking your general.cfg for missing binaries section...";
eval {
	use Config::Simple;
	my $generalcfg = new Config::Simple("$lbsconfigdir/general.cfg");
	if( $generalcfg->param("BINARIES.POWEROFF") eq "" ) {
		LOGINF "general.cfg binaries section missing - fixing...";
		require LoxBerry::System::General;
		my $jsonobj = LoxBerry::System::General->new();
		my $cfg = $jsonobj->open( readonly => 1 );
		$jsonobj->_json2cfg();
		LOGOK "general.cfg binaries section added.";
	} else {
		LOGOK "general.cfg binaries section is correct. Nothing to do.";
	}
};
if( $@ ) {
	LOGWARN "Could not read general.cfg - possibly not yet existing";
}




## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
# reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
