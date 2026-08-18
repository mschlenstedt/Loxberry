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

# --- Remote Support: install the Cloudflare Tunnel daemon (issue #1545) ---
#
# remoteconnect.pl used to download the cloudflared binary on demand; since the
# switch to Cloudflare's apt repository it expects the daemon to be installed
# as a package. Fresh installations get it from the installer (repository plus
# packages13.txt), but an upgraded LoxBerry has seen neither - there the binary
# is simply missing and Remote Connect fails to start. So the repository is
# added here and the package installed. The path also moved: the apt package
# installs to /usr/bin/cloudflared, not to /usr/local/bin - sbin/remoteconnect.pl
# now probes all known locations and comes in via the normal rsync.

my $cf_key   = "/usr/share/keyrings/cloudflare-main.gpg";
my $cf_list  = "/etc/apt/sources.list.d/cloudflared.list";
my $cf_repo  = "deb [signed-by=$cf_key] https://pkg.cloudflare.com/cloudflared any main";
my $cf_bin   = "/usr/bin/cloudflared";
my $logfilename = $log->filename();

# 4. The apt key. Downloaded to a temporary file first: a truncated key file
#    would break every later apt-get update on the whole system.
if ( -s $cf_key ) {
	LOGOK "Cloudflare apt key already installed.";
} else {
	LOGINF "Installing Cloudflare apt key...";
	execute( command => "mkdir -p --mode=0755 /usr/share/keyrings", log => $log );
	my $output = qx { curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 https://pkg.cloudflare.com/cloudflare-main.gpg -o $cf_key.tmp 2>&1 };
	my $exitcode = $? >> 8;
	if ( $exitcode != 0 || !-s "$cf_key.tmp" ) {
		LOGERR "Could not download the Cloudflare apt key - Error $exitcode";
		LOGDEB $output;
		unlink ("$cf_key.tmp");
		$errors++;
	} else {
		rename ("$cf_key.tmp", $cf_key);
		chmod (0644, $cf_key);
		LOGOK "Cloudflare apt key installed.";
	}
}

# 5. The sources list.
if ( -e $cf_list ) {
	LOGOK "Cloudflare apt repository already configured.";
} else {
	LOGINF "Adding Cloudflare apt repository...";
	if ( open (my $fh, '>', $cf_list) ) {
		print $fh "$cf_repo\n";
		close ($fh);
		chmod (0644, $cf_list);
		LOGOK "Cloudflare apt repository added.";
	} else {
		LOGERR "Could not write $cf_list: $!";
		$errors++;
	}
}

# 6. The package itself. The apt database is refreshed for the Cloudflare list
#    only (Dir::Etc::sourceparts="-"), so this does not turn into a full
#    apt-get update of every repository on the box.
if ( -x $cf_bin ) {
	LOGOK "cloudflared is already installed - nothing to do.";
} elsif ( -s $cf_key && -e $cf_list ) {
	LOGINF "Updating apt database for the Cloudflare repository...";
	my $export = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive";
	qx { $export /usr/bin/apt-get -y -o Dir::Etc::sourcelist="sources.list.d/cloudflared.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" --allow-releaseinfo-change update >> $logfilename 2>&1 };
	my $exitcode = $? >> 8;
	if ( $exitcode != 0 ) {
		LOGERR "Could not update the apt database for the Cloudflare repository - Error $exitcode";
		$errors++;
	}
	LOGINF "Installing cloudflared...";
	apt_install("cloudflared");

	# The Cloudflare repository announces its architectures as "386" and "arm",
	# which are no valid Debian architecture names - on i386 and armel apt finds
	# nothing. Those boxes get the binary straight from the GitHub release, the
	# way remoteconnect.pl did it before the switch to the repository.
	if ( !-x $cf_bin ) {
		my $arch = qx { dpkg --print-architecture };
		chomp ($arch);
		my %cf_release = (
			"amd64" => "cloudflared-linux-amd64",
			"arm64" => "cloudflared-linux-arm64",
			"armhf" => "cloudflared-linux-arm",
			"armel" => "cloudflared-linux-arm",
			"i386"  => "cloudflared-linux-386",
		);
		if ( $cf_release{$arch} ) {
			LOGWARN "cloudflared is not available as a package for architecture $arch - downloading the release binary...";
			my $output = qx { curl -fsSL --connect-timeout 10 --max-time 300 --retry 2 https://github.com/cloudflare/cloudflared/releases/latest/download/$cf_release{$arch} -o /usr/local/bin/cloudflared.tmp 2>&1 };
			my $exitcode = $? >> 8;
			if ( $exitcode != 0 || !-s "/usr/local/bin/cloudflared.tmp" ) {
				LOGERR "Could not download $cf_release{$arch} - Error $exitcode";
				LOGDEB $output;
				unlink ("/usr/local/bin/cloudflared.tmp");
				$errors++;
			} else {
				rename ("/usr/local/bin/cloudflared.tmp", "/usr/local/bin/cloudflared");
				chmod (0755, "/usr/local/bin/cloudflared");
				LOGOK "cloudflared installed to /usr/local/bin/cloudflared.";
			}
		} else {
			LOGERR "cloudflared could not be installed and no release binary is known for architecture $arch. Remote Support will not work on this system.";
			$errors++;
		}
	} else {
		LOGOK "cloudflared installed to $cf_bin.";
	}
}

# 7. A binary from the times before the repository shadows the packaged one in
#    LoxBerry's own PATH. Remove it once the package is in place.
if ( -x $cf_bin && -e "$lbhomedir/bin/cloudflared" ) {
	LOGINF "Removing the obsolete downloaded daemon $lbhomedir/bin/cloudflared...";
	unlink ("$lbhomedir/bin/cloudflared");
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
