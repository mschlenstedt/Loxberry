#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;
use LoxBerry::System::General;

init();

# --- Repetition of update_v4.0.0.15.pl ---
#
# The 4.0.0.15 release tag was moved after the first systems had already
# updated: the cloudflared installation and the is_raspberry.cfg fix were
# committed after the zipball those systems had downloaded. There
# update_v4.0.0.15.pl ran in its earlier form, and it can never run again - a
# script only runs while "installed version < script version", and those
# systems already are on 4.0.0.15. Every step is therefore repeated here.
# All of them are idempotent: each checks its target state first and does
# nothing when it is already reached.

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

# 6. The package itself.
if ( -x $cf_bin ) {
	LOGOK "cloudflared is already installed - nothing to do.";
} elsif ( -s $cf_key && -e $cf_list ) {
	LOGINF "Updating apt database...";
	apt_update();
	LOGINF "Installing cloudflared...";
	apt_install("cloudflared");
	if ( -x $cf_bin ) {
		LOGOK "cloudflared installed to $cf_bin.";
	} else {
		LOGERR "cloudflared could not be installed - $cf_bin does not exist. Remote Support will not work on this system.";
		$errors++;
	}
}

# 7. A binary from the times before the repository shadows the packaged one in
#    LoxBerry's own PATH. Remove it once the package is in place.
if ( -x $cf_bin && -e "$lbhomedir/bin/cloudflared" ) {
	LOGINF "Removing the obsolete downloaded daemon $lbhomedir/bin/cloudflared...";
	unlink ("$lbhomedir/bin/cloudflared");
}

# --- Retro-create is_raspberry.cfg on installed systems (backup widget false
#     "not a Raspberry" warning) ---
# The installer only wrote is_raspberry.cfg when DietPi named the model
# "Raspberry Pi ..."; current DietPi names it "RPi ...", so on many installs the
# flag is missing and features that rely on it (Backup widget, healthcheck)
# misbehave. The installer does not run on an already-installed system, so we
# create the flag here - detecting the Pi the same, multi-stage way: DietPi's
# numeric hardware model 0-9, else /proc/device-tree/model.
if ( ! -e "$lbsconfigdir/is_raspberry.cfg" ) {
	my $is_pi = 0;

	# Stage 1: DietPi hardware model (0-9 = Raspberry Pi). The .hw_model file
	# follows the boot mount, so both layouts are checked.
	foreach my $hwfile ( '/boot/dietpi/.hw_model', '/boot/firmware/dietpi/.hw_model' ) {
		next if ( ! -r $hwfile );
		if ( open( my $fh, '<', $hwfile ) ) {
			while ( my $line = <$fh> ) {
				if ( $line =~ /^G_HW_MODEL=(\d+)/ ) {
					$is_pi = 1 if ( $1 >= 0 && $1 <= 9 );
					last;
				}
			}
			close($fh);
		}
		last if ( $is_pi );
	}

	# Stage 2: device-tree model (mount-independent, present on every Pi).
	if ( !$is_pi && -r '/proc/device-tree/model' ) {
		my $model = '';
		if ( open( my $fh, '<:raw', '/proc/device-tree/model' ) ) {
			local $/;
			$model = <$fh>;
			close($fh);
			$model =~ s/\0//g;
		}
		$is_pi = 1 if ( defined $model && $model =~ /raspberry pi/i );
	}

	if ( $is_pi ) {
		LOGINF "Raspberry Pi detected but is_raspberry.cfg is missing - creating it.";
		if ( open( my $fh, '>', "$lbsconfigdir/is_raspberry.cfg" ) ) {
			print $fh "raspberry\n";
			close($fh);
			execute( command => "chown loxberry:loxberry $lbsconfigdir/is_raspberry.cfg", log => $log, ignoreerrors => 1 );
			execute( command => "chmod 600 $lbsconfigdir/is_raspberry.cfg",                log => $log, ignoreerrors => 1 );
			LOGOK "Created $lbsconfigdir/is_raspberry.cfg.";
		} else {
			LOGERR "Could not create $lbsconfigdir/is_raspberry.cfg: $!";
		}
	} else {
		LOGINF "Not a Raspberry Pi (or not detectable) - is_raspberry.cfg not created.";
	}
} else {
	LOGINF "is_raspberry.cfg already present - nothing to do.";
}

# --- Apache access-control fix (issue #1555) ---
#
# webfrontend/htmlauth/.htaccess mixed old-style (Order/Allow, mod_access_compat)
# and new-style (Require valid-user) directives via "Satisfy Any" - a documented
# Apache 2.4 anti-pattern. In practice it caused intermittent AH01797 denials
# from mod_access_compat, hitting the Logmanager's own live-refresh ajax poll
# (and other background pollers) hardest, since every denial is itself logged
# to the file being watched - the polled file grows without bound while the
# Logmanager is left open. Verified live on a test system: after switching to
# plain Require/<RequireAny>, the denials stopped immediately.
#
# The same mixed pattern also existed in the vhost Directory blocks and in the
# shellinabox (web terminal) proxy config, so all three are replaced here.
# .htaccess itself needs no explicit copy - webfrontend/ is not excluded from
# the update rsync and arrives with the release as usual. system/ is excluded
# (update-exclude.system): shellinabox.conf is copied, the two VirtualHost
# files are edited in place by apache_vhost_repair() below.
#
# Until 4.0.1.4 this script copied the VirtualHost templates (<VirtualHost
# *:80> / *:443) over the installed files. On a LoxBerry with its own web or
# SSL port, Apache kept listening on that port, but no VirtualHost matched it
# any more - every request was answered with 403. apache_vhost_repair() keeps
# the ports Apache listens on, and restores the previous config if Apache
# answers worse than before.
$errors += apache_vhost_repair( shellinabox => 1 );

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);


# ===========================================================================
# BEGIN apache_vhost_repair - identical in update_v4.0.0.16.pl and
# update_v4.0.1.5.pl. Keep both copies in sync.
#
# Brings the LoxBerry VirtualHosts in line with the ports Apache really
# listens on, without ever leaving Apache in a worse state than before:
#
#  - The ports come from ports.conf, not from general.json: ports.conf is what
#    Apache uses. Listen lines inside <IfModule ssl_module|mod_ssl.c|
#    mod_gnutls.c> (or with protocol https) are HTTPS ports, all others HTTP.
#    A port change that was never confirmed in the WebUI leaves two HTTP
#    ports - the VirtualHost then gets both (<VirtualHost *:80 *:81>).
#  - 000-default.conf / 001-default-ssl.conf are edited in place, not
#    replaced: the old access control "Order allow,deny" + "Allow from all"
#    becomes "Require all granted" (#1555), the opening <VirtualHost ...> line
#    gets the ports. Own certificates and other changes stay.
#  - Leftovers of an unconfirmed port change (000-default_<port>.conf,
#    001-default-ssl_<port>.conf, see sbin/serviceshelper) are moved to the
#    backup.
#  - Before anything is changed, Apache is probed on every port (curl), and
#    all touched files are saved to system/apache2/backup/. After configtest
#    and reload the probe is repeated. If Apache is not active, or a port that
#    answered before does not answer any more, everything is restored.
#
# Returns the number of errors (0 or 1).
# ===========================================================================
use File::Copy qw(move);
use File::Path qw(make_path remove_tree);
use POSIX qw(strftime);

sub apache_vhost_repair
{
	my %args = @_;
	# shellinabox => 1: also install conf-available/shellinabox.conf from the update
	# force_reload => 1: reload even if no VirtualHost file changed
	# cmd => { ... }: replace the commands below (tests)
	my %cmd = (
		configtest => 'PATH=/usr/sbin:/usr/bin:/sbin:/bin apache2ctl configtest 2>&1',
		reload     => 'systemctl reload-or-restart apache2.service 2>&1',
		isactive   => 'systemctl is-active --quiet apache2.service',
		%{ $args{cmd} || {} },
	);
	my $dir      = "$lbhomedir/system/apache2";
	my $avail    = "$dir/sites-available";
	my $enabled  = "$dir/sites-enabled";
	my $httpconf = "$avail/000-default.conf";
	my $sslconf  = "$avail/001-default-ssl.conf";
	my $shellconf = "$dir/conf-available/shellinabox.conf";

	LOGINF "Checking the Apache VirtualHost ports...";

	# --- Ports Apache listens on ---
	my ( $http, $https ) = apache_listen_ports("$dir/ports.conf");
	my $gcfg = LoxBerry::System::General->new()->open( readonly => 1 ) || {};
	my $cfgport    = $gcfg->{Webserver}->{Port}    // '';
	my $cfgsslport = $gcfg->{Webserver}->{Sslport} // '';
	if ( !%$http ) {
		my $p = ( $cfgport =~ /^\d+$/ && $cfgport > 0 && $cfgport < 65536 ) ? $cfgport : 80;
		LOGWARN "No HTTP Listen line found in ports.conf - using port $p.";
		$http->{$p} = '127.0.0.1';
	}
	if ( !%$https ) {
		my $p = ( $cfgsslport =~ /^\d+$/ && $cfgsslport > 0 && $cfgsslport < 65536 ) ? $cfgsslport : 443;
		LOGINF "No HTTPS Listen line found in ports.conf - using port $p for the SSL VirtualHost.";
		$https->{$p} = '127.0.0.1';
	}
	my @httpports  = sort { $a <=> $b } keys %$http;
	my @httpsports = sort { $a <=> $b } keys %$https;
	LOGINF "Apache listens for HTTP on port(s) @httpports, for HTTPS on port(s) @httpsports.";
	LOGWARN "Web server port in general.json ($cfgport) is not in ports.conf - Apache uses @httpports."
		if ( $cfgport ne '' && !exists $http->{$cfgport} );
	LOGWARN "SSL port in general.json ($cfgsslport) is not in ports.conf - Apache uses @httpsports."
		if ( $cfgsslport ne '' && !exists $https->{$cfgsslport} );

	# --- Probe before ---
	my $ssl_on = ( -e "$enabled/001-default-ssl.conf" ) ? 1 : 0;
	my %probehttps = $ssl_on ? %$https : ();
	my $before = apache_probe( \%cmd, $http, \%probehttps );
	LOGINF "Apache before: " . apache_probe_text($before);

	# --- Backup ---
	( my $scriptname = $0 ) =~ s/.*\///;
	$scriptname =~ s/\.pl$//;
	my $bdir = "$dir/backup/" . strftime( "%Y%m%d_%H%M%S", localtime ) . "_$scriptname";
	make_path("$bdir/sites-available", "$bdir/sites-enabled", "$bdir/conf-available");
	foreach my $f ( "$dir/ports.conf", $httpconf, $sslconf, $shellconf ) {
		next if ( !-e $f );
		( my $rel = $f ) =~ s/^\Q$dir\E\///;
		qx { cp -a "$f" "$bdir/$rel" 2>&1 };
		if ( $? != 0 ) {
			LOGERR "Could not save $f to $bdir - nothing is changed.";
			return 1;
		}
	}
	my @moved;     # [ from, to ] - moved back on restore
	my @created;   # links created - removed on restore
	my $changed = 0;

	# --- shellinabox.conf (update_v4.0.0.16.pl only) ---
	if ( $args{shellinabox} ) {
		my $old = apache_slurp($shellconf);
		copy_to_loxberry('/system/apache2/conf-available/shellinabox.conf');
		my $new = apache_slurp($shellconf);
		if ( defined $new && $new =~ /\r/ ) {
			$new =~ s/\r\n/\n/g;
			apache_spew( $shellconf, $new );
		}
		$changed++ if ( ( $old // '' ) ne ( $new // '' ) );
	}

	# --- VirtualHost files ---
	foreach my $v ( [ $httpconf, \@httpports ], [ $sslconf, \@httpsports ] ) {
		my ( $file, $ports ) = @$v;
		my $orig = apache_slurp($file);
		if ( !defined $orig ) {
			LOGWARN "$file not found - skipped.";
			next;
		}
		( my $base = $orig ) =~ s/\r\n/\n/g;
		my $new = $base;
		my $n = ( $new =~ s/^([ \t]*)Order[ \t]+allow,deny[ \t]*\n[ \t]*Allow[ \t]+from[ \t]+all[ \t]*\n/$1Require all granted\n/mgi );
		my $addr = join( ' ', map { "*:$_" } @$ports );
		if ( $new !~ s/^([ \t]*)<VirtualHost\b[^>]*>/$1<VirtualHost $addr>/mi ) {
			LOGWARN "No <VirtualHost> line in $file - port not set.";
		}
		next if ( $new eq $base );
		if ( !apache_spew( $file, $new ) ) {
			LOGERR "Could not write $file.";
			apache_restore( \%cmd, $bdir, \@moved, \@created, 0 );
			return 1;
		}
		$changed++;
		LOGINF "$file: <VirtualHost $addr>" . ( $n ? ", $n x Order/Allow replaced by Require" : "" );
	}

	# --- Leftovers of an unconfirmed port change ---
	foreach my $f ( glob("$enabled/000-default_*.conf"), glob("$enabled/001-default-ssl_*.conf"),
	                glob("$avail/000-default_*.conf"),   glob("$avail/001-default-ssl_*.conf") ) {
		( my $rel = $f ) =~ s/^\Q$dir\E\///;
		if ( move( $f, "$bdir/$rel" ) ) {
			push @moved, [ $f, "$bdir/$rel" ];
			$changed++;
			LOGINF "Leftover of a port change moved to the backup: $rel";
		} else {
			LOGWARN "Could not move leftover $f: $!";
		}
	}

	# --- LoxBerry VirtualHost must be enabled ---
	if ( !-l "$enabled/000-default.conf" && !-e "$enabled/000-default.conf" ) {
		if ( symlink( "../sites-available/000-default.conf", "$enabled/000-default.conf" ) ) {
			push @created, "$enabled/000-default.conf";
			$changed++;
			LOGINF "sites-enabled/000-default.conf was missing - enabled again.";
		}
	}

	if ( !$changed && !$args{force_reload} ) {
		remove_tree($bdir);
		LOGOK "Apache VirtualHosts are correct - nothing changed.";
		return 0;
	}

	# --- Configtest ---
	my $out = qx { $cmd{configtest} };
	if ( $? != 0 ) {
		LOGERR "Apache configtest failed - restoring the previous config. Output: $out";
		apache_restore( \%cmd, $bdir, \@moved, \@created, 0 );
		return 1;
	}

	# --- Reload and probe again ---
	LOGINF "Apache config OK - reloading...";
	qx { $cmd{reload} };
	my $after;
	for ( my $i = 0; $i < 15; $i++ ) {
		sleep 1;
		$after = apache_probe( \%cmd, $http, \%probehttps );
		last if ( !apache_regression( $before, $after ) && !grep { !apache_code_ok( $after->{$_} ) } grep { $_ ne 'active' } keys %$after );
	}
	LOGINF "Apache after: " . apache_probe_text($after);

	if ( apache_regression( $before, $after ) ) {
		LOGERR "Apache answers worse than before - restoring the previous config (backup: $bdir).";
		apache_restore( \%cmd, $bdir, \@moved, \@created, 1 );
		my $restored = apache_probe( \%cmd, $http, \%probehttps );
		LOGINF "Apache after restore: " . apache_probe_text($restored);
		return 1;
	}
	my @failed = grep { $_ ne 'active' && !apache_code_ok( $after->{$_} ) } sort keys %$after;
	if (@failed) {
		LOGERR "Apache does not answer correctly on " . join( ', ', @failed ) . " (did not before either). Backup: $bdir";
		return 1;
	}
	LOGOK "Apache VirtualHosts set and reloaded. Backup of the previous config: $bdir";
	return 0;
}

# Listen ports from ports.conf: ( { http port => probe address }, { https port => probe address } )
sub apache_listen_ports
{
	my ($file) = @_;
	my ( %http, %https, @stack );
	my $fh;
	open( $fh, '<', $file ) or return ( \%http, \%https );
	while ( my $line = <$fh> ) {
		$line =~ s/\r?\n$//;
		next if ( $line =~ /^\s*#/ );
		if ( $line =~ /^\s*<IfModule\s+!?\s*([^>\s]+)\s*>/i ) { push @stack, lc($1); next; }
		if ( $line =~ /^\s*<\/IfModule\s*>/i ) { pop @stack; next; }
		next if ( $line !~ /^\s*Listen\s+(\S+)(?:\s+(\S+))?/i );
		my ( $addr, $proto ) = ( $1, $2 );
		next if ( $addr !~ /^(?:(.*):)?(\d+)$/ );
		my ( $ip, $port ) = ( $1 // '', $2 );
		$ip = '127.0.0.1' if ( $ip eq '' || $ip eq '0.0.0.0' || $ip eq '*' );
		$ip = '[::1]'     if ( $ip eq '[::]' );
		my $is_ssl;
		if ( defined $proto ) {
			$is_ssl = ( lc($proto) eq 'https' );
		} else {
			$is_ssl = ( grep { /ssl|gnutls/ } @stack ) ? 1 : 0;
		}
		if ($is_ssl) { $https{$port} = $ip; } else { $http{$port} = $ip; }
	}
	close($fh);
	return ( \%http, \%https );
}

# { active => 0/1, "http:<port>" => code, "https:<port>" => code }
sub apache_probe
{
	my ( $cmd, $http, $https ) = @_;
	my %r;
	system( $cmd->{isactive} );
	$r{active} = ( $? == 0 ) ? 1 : 0;
	foreach my $p ( keys %$http ) {
		$r{"http:$p"} = apache_http_code("http://$http->{$p}:$p/");
	}
	foreach my $p ( keys %$https ) {
		$r{"https:$p"} = apache_http_code("https://$https->{$p}:$p/");
	}
	return \%r;
}

sub apache_http_code
{
	my ($url) = @_;
	my $code = qx { curl -s -k -o /dev/null -m 10 -w '%{http_code}' '$url' 2>/dev/null };
	$code = '000' if ( !defined $code || $code eq '' );
	return $code;
}

sub apache_code_ok
{
	my ($code) = @_;
	return ( defined $code && $code =~ /^(2\d\d|3\d\d|401)$/ ) ? 1 : 0;
}

# True if Apache is down, or a port that answered before does not any more
sub apache_regression
{
	my ( $before, $after ) = @_;
	return 1 if ( !$after->{active} );
	foreach my $k ( keys %$before ) {
		next if ( $k eq 'active' );
		return 1 if ( apache_code_ok( $before->{$k} ) && !apache_code_ok( $after->{$k} ) );
	}
	return 0;
}

sub apache_probe_text
{
	my ($r) = @_;
	return ( $r->{active} ? 'active' : 'NOT active' ) . join( '', map { ", $_ = $r->{$_}" } sort grep { $_ ne 'active' } keys %$r );
}

sub apache_restore
{
	my ( $cmd, $bdir, $moved, $created, $reload ) = @_;
	my $dir = "$lbhomedir/system/apache2";
	foreach my $rel ( 'ports.conf', 'sites-available/000-default.conf', 'sites-available/001-default-ssl.conf', 'conf-available/shellinabox.conf' ) {
		next if ( !-e "$bdir/$rel" );
		qx { cp -a "$bdir/$rel" "$dir/$rel" 2>&1 };
		LOGERR "Could not restore $dir/$rel from $bdir" if ( $? != 0 );
	}
	foreach my $m (@$moved) {
		move( $m->[1], $m->[0] ) or LOGERR "Could not move $m->[1] back to $m->[0]: $!";
	}
	foreach my $l (@$created) {
		unlink($l);
	}
	LOGINF "Previous Apache config restored from $bdir.";
	if ($reload) {
		qx { $cmd->{reload} };
		sleep 3;
	}
}

sub apache_slurp
{
	my ($file) = @_;
	my $fh;
	open( $fh, '<', $file ) or return undef;
	local $/;
	my $c = <$fh>;
	close($fh);
	return $c;
}

# Writes into the existing file, so owner and mode stay
sub apache_spew
{
	my ( $file, $content ) = @_;
	my $fh;
	open( $fh, '>', $file ) or return 0;
	print $fh $content;
	close($fh) or return 0;
	return 1;
}
# ===========================================================================
# END apache_vhost_repair
# ===========================================================================
