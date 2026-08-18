#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# --- Mosquitto logfile: group loxberry needs write permission (660) ---
#
# log_maint.pl shrinks oversized logfiles with copytruncate: gzip --keep, then
# reopen the original with '>' to empty it. It runs as user loxberry, while the
# broker logfile belongs to mosquitto:loxberry. With mode 640 the group may read
# it but not write it, so that truncate failed with EACCES - and because the
# return value of open() was never checked, entirely without a trace. The result
# was an hourly loop that gzipped a file it could never shrink: CPU burnt on
# gzip --best, the archive rewritten, and the original growing without limit
# (24 MB on a test system after two weeks, in a tmpfs). Mode 660 lets log_maint
# do its job; the missing error check is fixed in sbin/log_maint.pl, which the
# normal rsync installs.

# 1. The service template. system/ is excluded from the update rsync
#    (update-exclude.system), so it must be copied explicitly. Note this file is
#    no longer wired into systemd - the active integration is the .service.d
#    drop-in written by mqtt-handler.pl (see step 2). It is kept in sync so the
#    template does not drift away from the drop-in it documents.
LOGINF "Installing mosquitto service template (system/ is excluded from rsync)...";
copy_to_loxberry('/system/systemd/mosquitto.service');
execute( command => "dos2unix $lbhomedir/system/systemd/mosquitto.service", log => $log, ignoreerrors => 1 );

# 2. Rewrite the systemd drop-in, which is what actually applies the mode.
#    "mosquitto_set" writes the drop-in (now with chmod 660 instead of 640),
#    fixes the config-dir permissions, refreshes the broker overload config and
#    runs daemon-reload + SIGHUP. sbin/ is rsync'd normally, so the new
#    mqtt-handler.pl is already in place at this point.
LOGINF "Rewriting mosquitto systemd drop-in (logfile mode 640 -> 660)...";
execute( command => "$lbhomedir/sbin/mqtt-handler.pl action=mosquitto_set", log => $log, ignoreerrors => 1 );

# 3. Apply the mode to the logfile that exists right now. The drop-in only runs
#    its ExecStartPre on the next broker start, so without this the fix would
#    lie dormant until the next reboot and log_maint would keep failing until
#    then. Doing it here makes the update effective immediately - no broker
#    restart needed, which keeps every MQTT client connected.
my $mosqlog = "$lbhomedir/log/system_tmpfs/mosquitto.log";
if ( -e $mosqlog ) {
	LOGINF "Setting $mosqlog to mosquitto:loxberry mode 660...";
	execute( command => "chgrp loxberry '$mosqlog'", log => $log, ignoreerrors => 1 );
	execute( command => "chmod 660 '$mosqlog'",      log => $log, ignoreerrors => 1 );
} else {
	LOGINF "$mosqlog does not exist - the drop-in will create it with the correct mode on the next broker start.";
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
