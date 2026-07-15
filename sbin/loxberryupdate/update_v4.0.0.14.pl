#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# Apache logs move back to the distro default /var/log/apache2.
# The stable LoxBerry path log/system_tmpfs/apache2 becomes a symlink to it.
# system/ is excluded from rsync (update-exclude.system), so the Apache
# config files must be copied/patched explicitly.

LOGINF "Restoring Debian default APACHE_LOG_DIR in Apache envvars...";
copy_to_loxberry('/system/apache2/envvars');
execute( command => "dos2unix $lbhomedir/system/apache2/envvars", log => $log, ignoreerrors => 1 );

LOGINF "Setting Apache LogLevel from crit to warn...";
execute( command => "sed -i 's/^LogLevel crit/LogLevel warn/' $lbhomedir/system/apache2/apache2.conf", log => $log );

LOGINF "Creating symlink $lbhomedir/log/system_tmpfs/apache2 -> /var/log/apache2...";
execute( command => "mkdir -p /var/log/apache2", log => $log );
if ( -d "$lbhomedir/log/system_tmpfs/apache2" and ! -l "$lbhomedir/log/system_tmpfs/apache2" ) {
	# Migrate leftovers from a former real directory (old APACHE_LOG_DIR redirect)
	execute( command => "mv $lbhomedir/log/system_tmpfs/apache2/* /var/log/apache2/", log => $log, ignoreerrors => 1 );
	execute( command => "rm -rf $lbhomedir/log/system_tmpfs/apache2", log => $log );
}
execute( command => "ln -sfn /var/log/apache2 $lbhomedir/log/system_tmpfs/apache2", log => $log );

LOGINF "Adding user loxberry to group adm (read access to Apache logs)...";
execute( command => "usermod -a -G adm loxberry", log => $log );

# envvars and LogLevel only take effect after a full Apache restart
reboot_required("LoxBerry Update: Apache configuration changed (log directory, LogLevel) - a reboot is required to apply.");

# --- Mosquitto: robust systemd drop-in + overload hardening ---
# The systemd integration (tmpfs logfile, createtmpfs boot-ordering) is a
# .service.d drop-in written by mqtt-handler.pl (ensure_mosquitto_dropin),
# NOT the old /etc/systemd/system/mosquitto.service symlink that shadowed the
# distro unit and was silently lost on mosquitto package upgrades - observed on
# both loxberrykeller and loxberrypoolboy, which had fallen back to the distro
# /lib unit (no tmpfs ExecStartPre, no createtmpfs ordering -> "deleted inode").
# A drop-in is never touched by dpkg and survives package upgrades.
#
# "mosquitto_set" does everything in one call: fixes config-dir perms (chmod 755),
# rewrites the broker drop-in config with the overload hardening
# (max_queued_messages / max_inflight_messages / persistent_client_expiration /
# connection_messages), writes the systemd drop-in, removes the stale unit
# override symlink and runs daemon-reload + SIGHUP. sbin/ is rsync'd normally, so
# the new mqtt-handler.pl (with ensure_mosquitto_dropin) is already in place here.
# The tmpfs logfile and queue limits take full effect on the reboot this update
# already requires (Apache section above) - no extra broker restart needed.
LOGINF "Applying robust mosquitto systemd drop-in + overload config...";
execute( command => "$lbhomedir/sbin/mqtt-handler.pl action=mosquitto_set", log => $log, ignoreerrors => 1 );

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
