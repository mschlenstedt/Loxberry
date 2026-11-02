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

# ---------------------------------------------------------------------------
# Repair the Apache VirtualHost ports
#
# update_v4.0.0.16.pl (shipped with 4.0.1.0 - 4.0.1.4) overwrote 000-default.conf
# and 001-default-ssl.conf with the templates (<VirtualHost *:80> / *:443).
# On a LoxBerry with its own web or SSL port, Apache kept listening on that port
# (ports.conf), but no VirtualHost matched it any more: every request ended in
# the main server and was answered with 403. update_v4.0.0.16.pl is fixed; this
# script repairs the systems it already broke. On all others it changes nothing.
# ---------------------------------------------------------------------------
$errors += apache_vhost_repair();

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
