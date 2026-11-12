#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# ---------------------------------------------------------------------------
# cron.daily starts every job at 04:23 at the same time. The LoxBerry update
# check (loxberryupdate_cron, when set to daily) and osupdate.pl started in the
# same second; the check found the osupdate lock and stopped with an error.
# Now the check waits for a running update and starts 0-15 minutes after the
# cron run (sbin/loxberryupdate_cron.sh, delivered by rsync), osupdate.pl
# 30-60 minutes after it. system/ is excluded from rsync, so the new
# cron.daily/05-osupdate is copied explicitly.
# ---------------------------------------------------------------------------
LOGINF "Installing the nightly job for Debian/PHP updates with a random delay...";
copy_to_loxberry("/system/cron/cron.daily/05-osupdate", "loxberry");
execute( command => "chmod 755 $lbhomedir/system/cron/cron.daily/05-osupdate", log => $log, ignoreerrors => 1 );
execute( command => "dos2unix $lbhomedir/system/cron/cron.daily/05-osupdate", log => $log, ignoreerrors => 1 );

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
