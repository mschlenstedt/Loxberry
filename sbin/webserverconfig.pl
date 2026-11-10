#!/usr/bin/perl

# Copyright 2026 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ---------------------------------------------------------------------------
# Applies the web server settings of the WebUI (system/services.php) to Apache:
# HTTP port, HTTPS on/off and HTTPS port. Runs as root, started through
# sbin/serviceshelper.
#
#   webserverconfig.pl apply    <port> <sslenabled 0|1> <sslport>
#   webserverconfig.pl finalize <port> <sslenabled 0|1> <sslport>
#   webserverconfig.pl verify   <backupdir>      (internal, started detached)
#
# A change is done in two steps, so that the browser never loses LoxBerry:
#
#   apply     Apache gets the old AND the new ports: HTTP 80 -> 81 gives
#             <VirtualHost *:80 *:81>, HTTPS 443 -> 444 gives *:443 *:444,
#             HTTPS on enables the SSL VirtualHost on the new port, HTTPS off
#             keeps it until the change is finalized. The old address keeps
#             working, the new one starts working.
#   finalize  Called when the browser has arrived on the new address: Apache
#             gets exactly the target ports, the old ones are removed.
#
# Only the LoxBerry ports are touched: the ports of the LoxBerry VirtualHosts
# (000-default.conf, 001-default-ssl.conf) and the target ports. Other Listen
# lines in ports.conf (e.g. of plugins) stay.
#
# Apache is never left in a worse state: all files are saved to
# system/apache2/backup/ first, a failing configtest restores them at once.
# The reload runs detached (systemd-run) 2 seconds later, so the web request
# that started it gets its answer. Afterwards Apache is probed on every port; if it is down or
# a port that answered before (or a new one) does not answer, the previous
# config is restored.
#
# Exit codes: 0 ok, 1 error, 2 wrong parameters, 3 port in use
# Output: one line "OK ..." or "ERROR ..." for the WebUI.
# ---------------------------------------------------------------------------

use LoxBerry::System;
use LoxBerry::Log;
use File::Copy qw(move);
use File::Path qw(make_path remove_tree);
use POSIX qw(strftime);
use strict;
use warnings;

my $version = "4.0.1.5";

my $dir      = "$lbhomedir/system/apache2";
my $avail    = "$dir/sites-available";
my $enabled  = "$dir/sites-enabled";
my $portsconf = "$dir/ports.conf";
my $httpconf = "$avail/000-default.conf";
my $sslconf  = "$avail/001-default-ssl.conf";
my $sslsite  = "$enabled/001-default-ssl.conf";
my $backupbase = "$dir/backup";
my $keepbackups = 5;

my ($lbuid, $lbgid) = ( getpwnam('loxberry') )[2, 3];
my $logfile = "$lbslogdir/webserverconfig.log";
my $log = LoxBerry::Log->new(
	package => 'LoxBerry Services',
	name => 'Webserver',
	filename => $logfile,
	append => 1,
	loglevel => 7,
	stderr => 0,
	addtime => 1,
);
chown $lbuid, $lbgid, $logfile;

my $mode = $ARGV[0] // '';

if ( $mode eq 'verify' ) {
	exit verify( $ARGV[1] );
}
if ( $mode ne 'apply' && $mode ne 'finalize' ) {
	print "ERROR Usage: $0 apply|finalize <port> <sslenabled 0|1> <sslport>\n";
	exit 2;
}

my ( $port, $ssl, $sslport ) = @ARGV[ 1 .. 3 ];
if ( !valid_port($port) || !defined $ssl || $ssl !~ /^[01]$/ || !valid_port($sslport) || $port == $sslport ) {
	print "ERROR Wrong parameters\n";
	exit 2;
}

LOGSTART "Web server: $mode (HTTP $port, HTTPS " . ( $ssl ? "on" : "off" ) . ", HTTPS port $sslport)";
LOGINF "Version of this script: $version";

# --- Current state: the ports of the LoxBerry VirtualHosts ---
my ( $listen_http, $listen_https ) = listen_ports($portsconf);
my @hc = vhost_ports($httpconf);
my @sc = vhost_ports($sslconf);
@hc = sort { $a <=> $b } keys %$listen_http  if ( !@hc );
@sc = sort { $a <=> $b } keys %$listen_https if ( !@sc );
my $sslon_c = ( -e $sslsite ) ? 1 : 0;
LOGINF "Current: HTTP @hc, HTTPS " . ( $sslon_c ? "on" : "off" ) . " (VirtualHost @sc)";

# --- Target state ---
my ( @h, @s, $sslon );
if ( $mode eq 'apply' ) {
	@h = uniq( @hc, $port );
	if ($ssl) {
		@s = uniq( ( $sslon_c ? @sc : () ), $sslport );
		$sslon = 1;
	} else {
		@s = @sc ? @sc : ($sslport);
		$sslon = $sslon_c;
	}
	# A new port must not collide with the other protocol or another program
	my %http_now  = map { $_ => 1 } @hc;
	my %https_now = $sslon_c ? ( map { $_ => 1 } @sc ) : ();
	my @check;
	push @check, [ $port, \%https_now ] if ( !$http_now{$port} );
	push @check, [ $sslport, \%http_now ] if ( $ssl && !$https_now{$sslport} );
	foreach my $c (@check) {
		my ( $p, $other ) = @$c;
		if ( $other->{$p} ) {
			LOGERR "Port $p is used by LoxBerry for the other protocol.";
			LOGEND "Aborted.";
			print "INUSE $p\n";
			exit 3;
		}
		my $user = port_user($p);
		if ( $user && $user ne 'apache2' ) {
			LOGERR "Port $p is in use by $user.";
			LOGEND "Aborted.";
			print "INUSE $p $user\n";
			exit 3;
		}
	}
} else {
	@h = ($port);
	@s = ($sslport);
	$sslon = $ssl;
}
LOGINF "Target:  HTTP @h, HTTPS " . ( $sslon ? "on" : "off" ) . " (VirtualHost @s)";

# --- Probe before (for the comparison after the reload) ---
my %probe_http  = map { $_ => 1 } @hc;
my %probe_https = $sslon_c ? ( map { $_ => 1 } @sc ) : ();
my $before = probe( \%probe_http, \%probe_https );
LOGINF "Apache before: " . probe_text($before);

# --- Backup ---
my $bdir = "$backupbase/" . strftime( "%Y%m%d_%H%M%S", localtime ) . "_webserverconfig_$mode";
make_path( "$bdir/sites-available", "$bdir/sites-enabled" );
foreach my $f ( $portsconf, $httpconf, $sslconf ) {
	next if ( !-e $f );
	( my $rel = $f ) =~ s/^\Q$dir\E\///;
	system( "cp", "-a", $f, "$bdir/$rel" );
	if ( $? != 0 ) {
		fail("Could not save $f to $bdir - nothing changed.");
	}
}
my @state_moved;
my @state_created;
my @state_removed;    # links removed: [ link, target ]

# --- ports.conf ---
my $pc = slurp($portsconf) // '';
( my $pcbase = $pc ) =~ s/\r\n/\n/g;
my $newpc = edit_ports( $pcbase, [ uniq( @hc, @h ) ], \@h, [ uniq( @sc, @s ) ], \@s );
if ( $newpc ne $pcbase ) {
	spew( $portsconf, $newpc ) or fail("Could not write $portsconf");
	LOGINF "ports.conf: HTTP Listen @h, HTTPS Listen @s";
}

# --- VirtualHosts ---
set_vhost( $httpconf, \@h );
set_vhost( $sslconf, \@s ) if ( -e $sslconf );

# --- Leftovers of the old port change mechanism (until 4.0.1.5) ---
foreach my $f ( glob("$enabled/000-default_*.conf"), glob("$enabled/001-default-ssl_*.conf"),
                glob("$avail/000-default_*.conf"),   glob("$avail/001-default-ssl_*.conf") ) {
	( my $rel = $f ) =~ s/^\Q$dir\E\///;
	if ( move( $f, "$bdir/$rel" ) ) {
		push @state_moved, [ $f, "$bdir/$rel" ];
		LOGINF "Leftover of an old port change moved to the backup: $rel";
	}
}
unlink("$lbhomedir/webfrontend/html/system/servicehelper.php");

# --- Sites ---
if ( !-l "$enabled/000-default.conf" && !-e "$enabled/000-default.conf" ) {
	symlink( "../sites-available/000-default.conf", "$enabled/000-default.conf" ) and push @state_created, "$enabled/000-default.conf";
	LOGINF "000-default.conf enabled again.";
}
if ( $sslon && !-e $sslsite ) {
	if ( !-e "$dir/mods-enabled/ssl.load" ) {
		LOGINF "Enabling Apache module ssl...";
		system("a2enmod -q ssl >/dev/null 2>&1");
	}
	unlink($sslsite) if ( -l $sslsite );
	symlink( "../sites-available/001-default-ssl.conf", $sslsite ) and push @state_created, $sslsite;
	LOGINF "HTTPS VirtualHost enabled.";
} elsif ( !$sslon && ( -e $sslsite || -l $sslsite ) ) {
	my $target = readlink($sslsite);
	if ( unlink($sslsite) ) {
		push @state_removed, [ $sslsite, $target ];
		LOGINF "HTTPS VirtualHost disabled.";
	}
}

# --- Configtest ---
my $out = qx { PATH="\$PATH:/usr/sbin:/usr/bin:/sbin:/bin" apache2ctl configtest 2>&1 };
if ( $? != 0 ) {
	$out =~ s/\s+/ /g;
	LOGERR "Apache configtest failed: $out";
	restore( $bdir, \@state_moved, \@state_created, \@state_removed );
	LOGEND "Previous config restored, Apache not touched.";
	print "ERROR Apache configtest failed: $out\n";
	exit 1;
}

# --- State for the detached verify run ---
my %expect_http  = map { $_ => 1 } @h;
my %expect_https = $sslon ? ( map { $_ => 1 } @s ) : ();
write_state( "$bdir/state", {
	mode => $mode,
	before => $before,
	http => join( ',', @h ),
	https => join( ',', $sslon ? @s : () ),
	moved => join( ';', map { "$_->[0]|$_->[1]" } @state_moved ),
	created => join( ';', @state_created ),
	removed => join( ';', map { "$_->[0]|$_->[1]" } @state_removed ),
	ssdp => ( $mode eq 'finalize' ) ? 1 : 0,
} );
prune_backups();

# --- Reload detached, so this web request gets its answer first ---
# systemd-run starts with an empty environment: hand over what the LoxBerry libs need
my $unit = "loxberry-webserverconfig-" . time();
my $perl5lib = $ENV{PERL5LIB} || "$lbhomedir/libs/perllib";
system( "systemd-run", "--quiet", "--no-block", "--collect", "--unit=$unit",
	"--setenv=LBHOMEDIR=$lbhomedir", "--setenv=PERL5LIB=$perl5lib",
	$0, "verify", $bdir );
if ( $? != 0 ) {
	LOGWARN "systemd-run failed - reloading in a forked process.";
	my $pid = fork();
	if ( defined $pid && $pid == 0 ) {
		POSIX::setsid();
		open( STDIN, '<', '/dev/null' ); open( STDOUT, '>', '/dev/null' ); open( STDERR, '>', '/dev/null' );
		exec( $0, "verify", $bdir );
	}
}
LOGOK "Config written and tested - Apache reloads in 2 seconds ($unit). Backup: $bdir";
print "OK $bdir\n";
exit 0;


# ===========================================================================
# verify: reload, probe, restore if worse
# ===========================================================================
sub verify
{
	my ($bdir) = @_;
	my $st = read_state("$bdir/state");
	if ( !$st ) {
		LOGSTART "Web server: verify";
		LOGERR "No state in $bdir";
		LOGEND "Aborted.";
		return 1;
	}
	LOGSTART "Web server: reload and check ($st->{mode})";
	# Give the web request that started the change time to deliver its answer
	sleep 2;
	my %http  = map { $_ => 1 } grep { length } split( /,/, $st->{http} );
	my %https = map { $_ => 1 } grep { length } split( /,/, $st->{https} );
	my $before = $st->{before};

	system("systemctl reload-or-restart apache2.service >/dev/null 2>&1");
	my $after;
	for ( my $i = 0; $i < 15; $i++ ) {
		sleep 1;
		$after = probe( \%http, \%https );
		last if ( !worse( $before, $after ) );
	}
	LOGINF "Apache after: " . probe_text($after);

	if ( worse( $before, $after ) ) {
		LOGERR "Apache answers worse than before - restoring the previous config from $bdir.";
		my @moved   = map { [ split( /\|/, $_, 2 ) ] } grep { length } split( /;/, $st->{moved} );
		my @created = grep { length } split( /;/, $st->{created} );
		my @removed = map { [ split( /\|/, $_, 2 ) ] } grep { length } split( /;/, $st->{removed} );
		restore( $bdir, \@moved, \@created, \@removed );
		system("systemctl reload-or-restart apache2.service >/dev/null 2>&1");
		sleep 3;
		system("systemctl is-active --quiet apache2.service");
		LOGINF "Apache after restore: " . ( $? == 0 ? "active" : "NOT active" );
		LOGEND "Change reverted.";
		return 1;
	}

	if ( $st->{ssdp} ) {
		system("systemctl is-enabled --quiet ssdpd.service 2>/dev/null");
		if ( $? == 0 ) {
			system("systemctl restart ssdpd.service >/dev/null 2>&1");
			LOGINF "ssdpd restarted (announces the new port).";
		}
	}
	LOGEND "Web server settings active.";
	return 0;
}

# Worse: Apache down, a port that answered before does not, or a new port does not answer
sub worse
{
	my ( $before, $after ) = @_;
	return 1 if ( !$after->{active} );
	foreach my $k ( keys %$after ) {
		next if ( $k eq 'active' );
		next if ( code_ok( $after->{$k} ) );
		return 1 if ( !exists $before->{$k} || code_ok( $before->{$k} ) );
	}
	return 0;
}

# ===========================================================================
# Helpers
# ===========================================================================
sub fail
{
	my ($msg) = @_;
	LOGERR $msg;
	LOGEND "Aborted.";
	print "ERROR $msg\n";
	exit 1;
}

sub valid_port
{
	my ($p) = @_;
	return ( defined $p && $p =~ /^\d+$/ && $p >= 1 && $p <= 65535 ) ? 1 : 0;
}

sub uniq
{
	my %seen;
	return sort { $a <=> $b } grep { !$seen{$_}++ } @_;
}

# Ports of the first <VirtualHost ...> line of a file
sub vhost_ports
{
	my ($file) = @_;
	my $c = slurp($file) // return ();
	return () if ( $c !~ /^[ \t]*<VirtualHost\b([^>]*)>/mi );
	my $addr = $1;
	my @p;
	while ( $addr =~ /:(\d+)\b/g ) { push @p, $1 if valid_port($1); }
	return uniq(@p);
}

sub set_vhost
{
	my ( $file, $ports ) = @_;
	my $c = slurp($file);
	return if ( !defined $c );
	( my $base = $c ) =~ s/\r\n/\n/g;
	my $new = $base;
	my $addr = join( ' ', map { "*:$_" } @$ports );
	if ( $new !~ s/^([ \t]*)<VirtualHost\b[^>]*>/$1<VirtualHost $addr>/mi ) {
		LOGWARN "No <VirtualHost> line in $file";
		return;
	}
	# Old access control (mod_access_compat), see #1555
	$new =~ s/^([ \t]*)Order[ \t]+allow,deny[ \t]*\n[ \t]*Allow[ \t]+from[ \t]+all[ \t]*\n/$1Require all granted\n/mgi;
	return if ( $new eq $base );
	spew( $file, $new ) or fail("Could not write $file");
	LOGINF "$file: <VirtualHost $addr>";
}

# Listen ports from ports.conf: ( { http port => probe address }, { https port => probe address } )
sub listen_ports
{
	my ($file) = @_;
	my ( %http, %https, @stack );
	my $c = slurp($file) // return ( \%http, \%https );
	foreach my $line ( split( /\r?\n/, $c ) ) {
		next if ( $line =~ /^\s*#/ );
		if ( $line =~ /^\s*<IfModule\s+!?\s*([^>\s]+)\s*>/i ) { push @stack, lc($1); next; }
		if ( $line =~ /^\s*<\/IfModule\s*>/i ) { pop @stack; next; }
		next if ( $line !~ /^\s*Listen\s+(\S+)(?:\s+(\S+))?/i );
		my ( $addr, $proto ) = ( $1, $2 );
		next if ( $addr !~ /^(?:(.*):)?(\d+)$/ );
		my ( $ip, $p ) = ( $1 // '', $2 );
		my $is_ssl = defined $proto ? ( lc($proto) eq 'https' ) : ( ( grep { /ssl|gnutls/ } @stack ) ? 1 : 0 );
		if ($is_ssl) { $https{$p} = $ip; } else { $http{$p} = $ip; }
	}
	return ( \%http, \%https );
}

# Rewrites the LoxBerry Listen lines: removes managed ports that are not wanted
# any more, adds wanted ports that are missing. Other Listen lines stay.
sub edit_ports
{
	my ( $c, $managed_http, $want_http, $managed_https, $want_https ) = @_;
	my %mh = map { $_ => 1 } @$managed_http;
	my %wh = map { $_ => 1 } @$want_http;
	my %ms = map { $_ => 1 } @$managed_https;
	my %ws = map { $_ => 1 } @$want_https;
	my ( @out, @stack, %have_http, %have_https_block );
	my $first_http_idx;
	my @sslblocks;    # [ index of the </IfModule> line in @out, ports seen ]
	foreach my $line ( split( /\n/, $c, -1 ) ) {
		if ( $line =~ /^\s*<IfModule\s+!?\s*([^>\s]+)\s*>/i ) {
			push @stack, lc($1);
			push @out, $line;
			next;
		}
		if ( $line =~ /^\s*<\/IfModule\s*>/i ) {
			my $mod = pop @stack;
			if ( defined $mod && $mod =~ /ssl|gnutls/ ) {
				push @sslblocks, [ scalar(@out), { %have_https_block } ];
				%have_https_block = ();
			}
			push @out, $line;
			next;
		}
		if ( $line =~ /^\s*Listen\s+(\S+)(?:\s+(\S+))?/i ) {
			my ( $addr, $proto ) = ( $1, $2 );
			if ( $addr =~ /^(?:.*:)?(\d+)$/ ) {
				my $p = $1;
				my $is_ssl = defined $proto ? ( lc($proto) eq 'https' ) : ( ( grep { /ssl|gnutls/ } @stack ) ? 1 : 0 );
				if ($is_ssl) {
					next if ( $ms{$p} && !$ws{$p} );
					$have_https_block{$p} = 1;
				} else {
					$first_http_idx = scalar(@out) if ( !defined $first_http_idx && !@stack );
					next if ( $mh{$p} && !$wh{$p} );
					$have_http{$p} = 1;
				}
			}
		}
		push @out, $line;
	}
	my @inserts;    # [ index in @out, lines ]
	# Missing HTTPS ports: into every ssl/gnutls block
	if (@sslblocks) {
		foreach my $blk (@sslblocks) {
			my ( $idx, $seen ) = @$blk;
			my @add = map { "\tListen $_" } grep { !$seen->{$_} } sort { $a <=> $b } keys %ws;
			push @inserts, [ $idx, \@add ] if (@add);
		}
	} elsif (%ws) {
		push @inserts, [ scalar(@out), [ "", "<IfModule ssl_module>", ( map { "\tListen $_" } sort { $a <=> $b } keys %ws ), "</IfModule>", "" ] ];
	}
	# Missing HTTP ports: where the first top-level Listen line is (was), or at the top
	my @addh = map { "Listen $_" } grep { !$have_http{$_} } sort { $a <=> $b } keys %wh;
	push @inserts, [ $first_http_idx // 0, \@addh ] if (@addh);
	# From the end, so the indexes stay valid
	foreach my $ins ( sort { $b->[0] <=> $a->[0] } @inserts ) {
		splice( @out, $ins->[0], 0, @{ $ins->[1] } );
	}
	return join( "\n", @out );
}

# Program listening on a TCP port ('' = free)
sub port_user
{
	my ($p) = @_;
	my $out = qx { ss -Htlnp "sport = :$p" 2>/dev/null };
	return '' if ( !$out || $out !~ /\S/ );
	return $1 if ( $out =~ /users:\(\("([^"]+)"/ );
	return 'unknown';
}

# { active => 0/1, "http:<port>" => code, "https:<port>" => code }
sub probe
{
	my ( $http, $https ) = @_;
	my %r;
	system("systemctl is-active --quiet apache2.service");
	$r{active} = ( $? == 0 ) ? 1 : 0;
	foreach my $p ( keys %$http )  { $r{"http:$p"}  = http_code("http://127.0.0.1:$p/"); }
	foreach my $p ( keys %$https ) { $r{"https:$p"} = http_code("https://127.0.0.1:$p/"); }
	return \%r;
}

sub http_code
{
	my ($url) = @_;
	my $code = qx { curl -s -k -o /dev/null -m 10 -w '%{http_code}' '$url' 2>/dev/null };
	return ( defined $code && $code =~ /^\d{3}$/ ) ? $code : '000';
}

sub code_ok
{
	my ($code) = @_;
	return ( defined $code && $code =~ /^(2\d\d|3\d\d|401)$/ ) ? 1 : 0;
}

sub probe_text
{
	my ($r) = @_;
	return ( $r->{active} ? 'active' : 'NOT active' ) . join( '', map { ", $_ = $r->{$_}" } sort grep { $_ ne 'active' } keys %$r );
}

sub restore
{
	my ( $bdir, $moved, $created, $removed ) = @_;
	foreach my $rel ( 'ports.conf', 'sites-available/000-default.conf', 'sites-available/001-default-ssl.conf' ) {
		next if ( !-e "$bdir/$rel" );
		system( "cp", "-a", "$bdir/$rel", "$dir/$rel" );
		LOGERR "Could not restore $dir/$rel" if ( $? != 0 );
	}
	foreach my $m (@$moved) {
		move( $m->[1], $m->[0] ) or LOGERR "Could not move $m->[1] back: $!";
	}
	foreach my $l (@$created) {
		unlink($l);
	}
	foreach my $r (@$removed) {
		symlink( $r->[1], $r->[0] ) or LOGERR "Could not recreate link $r->[0]: $!";
	}
	LOGINF "Previous config restored from $bdir.";
}

# Keep the last $keepbackups backups of this script
sub prune_backups
{
	my @b = sort glob("$backupbase/*_webserverconfig_*");
	while ( @b > $keepbackups ) {
		my $old = shift @b;
		remove_tree($old);
	}
}

sub write_state
{
	my ( $file, $st ) = @_;
	my $fh;
	open( $fh, '>', $file ) or fail("Could not write $file");
	foreach my $k ( sort keys %$st ) {
		if ( ref $st->{$k} eq 'HASH' ) {
			foreach my $k2 ( sort keys %{ $st->{$k} } ) {
				print $fh "$k.$k2=$st->{$k}->{$k2}\n";
			}
		} else {
			print $fh "$k=$st->{$k}\n";
		}
	}
	close($fh);
}

sub read_state
{
	my ($file) = @_;
	my $c = slurp($file) // return undef;
	my %st = ( before => {}, http => '', https => '', moved => '', created => '', removed => '', ssdp => 0, mode => '' );
	foreach my $line ( split( /\n/, $c ) ) {
		next if ( $line !~ /^([^=]+)=(.*)$/ );
		my ( $k, $v ) = ( $1, $2 );
		if ( $k =~ /^before\.(.+)$/ ) { $st{before}->{$1} = $v; } else { $st{$k} = $v; }
	}
	return \%st;
}

sub slurp
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
sub spew
{
	my ( $file, $content ) = @_;
	my $fh;
	open( $fh, '>', $file ) or return 0;
	print $fh $content;
	close($fh) or return 0;
	return 1;
}
