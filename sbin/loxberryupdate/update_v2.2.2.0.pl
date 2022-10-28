#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

#
# Add Backup to general.json
# --> general.json is done by ~/sbin/createconfig
LOGINF "Adding Backup options to general.json";
#if (!$gcfg->{'Backup'}) {
#	$gcfg->{'Backup'}->{'Keep_archives'} = "1";
#	$gcfg->{'Backup'}->{'Storagepath'} = "";
#	$gcfg->{'Backup'}->{'Schedule'}->{'Active'} = "false";
#	$gcfg->{'Backup'}->{'Schedule'}->{'Repeat'} = "1";
#	$gcfgobj->write();
system ("touch $lbhomedir/system/cron/cron.d/lbclonesd");
	LOGOK "Backup parameters added to general.json successfully.";
#} else {
	#LOGOK "Backup parameters already in general.json -> skipping.";
#}

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
