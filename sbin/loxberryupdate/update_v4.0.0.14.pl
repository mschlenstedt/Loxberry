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

# --- Mosquitto: boot-ordering, tmpfs-log permissions, overload hardening ---
# system/ is excluded from rsync (update-exclude.system), so the systemd unit
# must be copied explicitly. The new unit adds After=/Requires=createtmpfs.service
# so the RAM-disk log folder exists before mosquitto opens its logfile (a boot
# race previously left mosquitto writing into a deleted inode - broker runs, log
# stops growing).
LOGINF "Deploying mosquitto systemd unit (boot-ordering, tmpfs log)...";
copy_to_loxberry('/system/systemd/mosquitto.service');
execute( command => "dos2unix $lbhomedir/system/systemd/mosquitto.service", log => $log, ignoreerrors => 1 );
# Ensure the LoxBerry unit is the ACTIVE one: /etc/systemd/system overrides the
# distro unit in /lib/systemd/system. On installs where this symlink is missing
# (never ran update_v3.0.0, or an apt upgrade of mosquitto removed it), the copied
# unit above would have no effect and the distro unit (no tmpfs ExecStartPre, no
# createtmpfs ordering) stays active. "ln -sfn" replaces a stale file or symlink.
execute( command => "ln -sfn $lbhomedir/system/systemd/mosquitto.service /etc/systemd/system/mosquitto.service", log => $log, ignoreerrors => 1 );
execute( command => "systemctl daemon-reload", log => $log, ignoreerrors => 1 );

# Repair the LoxBerry-managed mosquitto config dir: it needs the execute/traverse
# bit (755) so the conf.d symlink into it resolves.
LOGINF "Fixing permissions of config/system/mosquitto...";
execute( command => "chmod 755 $lbhomedir/config/system/mosquitto", log => $log, ignoreerrors => 1 );

# Rewrite the LoxBerry-managed mosquitto drop-in (adds overload hardening:
# max_queued_messages / max_inflight_messages / persistent_client_expiration /
# connection_messages) and restart the broker to apply the new unit + config.
LOGINF "Rewriting mosquitto drop-in config and restarting broker...";
execute( command => "$lbhomedir/sbin/mqtt-handler.pl action=mosquitto_set", log => $log, ignoreerrors => 1 );
execute( command => "systemctl restart mosquitto", log => $log, ignoreerrors => 1 );

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
