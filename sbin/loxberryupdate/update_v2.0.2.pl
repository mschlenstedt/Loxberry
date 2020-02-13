#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();


# Install mod_rewrite for Apache
LOGINF "We are migrating general.cfg to general.json ...";
LOGINF "Create backup of your general.cfg";
my ($exitcode, $output);
my $time = time;
($exitcode, $output) = execute( {
    command => "cp $lbsconfigdir/general.cfg $lbsconfigdir/general.backup_$time.cfg",
    log => $log
} );

LOGINF "Starting migration...";
($exitcode, $output) = execute( {
    command => "$lbhomedir/sbin/migrate_generalcfg.pl",
    log => $log
} );
LOGOK "Migration complete. The primary configuration of LoxBerry now is stored in general.json.";

# Install mod_rewrite for Apache
LOGINF "Deleting CloudDNS cache files to get rebuilt with https...";
unlink "$lbstmpfslogdir/clouddns_cache.json";


## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
# reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
