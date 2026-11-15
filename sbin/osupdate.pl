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

# Installs Debian and PHP updates on DietPi based LoxBerrys.
#
# Started every night by system/cron/cron.daily/05-osupdate (cron=daily):
# installs the updates when the interval set in the WebUI is over and
# reboots afterwards if an update requires it and automatic reboot is
# enabled. Started manually (as root) it installs the updates at once and
# never reboots. dryrun=1 only shows what would be installed, type=all or
# type=security overrides the setting for a manual run.
#
# Settings: general.json, section Osupdate (Interval 0/1/7/30 days,
# Type security/all, Reboot true/false). Status for the WebUI:
# data/system/osupdate.json.
#
# Type "security" installs only new versions from the Debian security
# archive and from repositories without a security archive of their own
# (packages.sury.org for PHP, the Raspberry Pi repository, Raspbian).
# A temporary APT pin gives every other origin priority 50 - below the
# installed version (100) - so apt's resolver never picks them and solves
# everything in one pass. unattended-upgrades does the same selection
# package by package and needed more than two hours for a backlog of 160
# packages on a fast machine.
# Type "all" installs every available upgrade, like dietpi-update does.

use LoxBerry::System;
use LoxBerry::System::General;
use LoxBerry::Log;
use JSON;
use File::Temp qw(tempdir);
use POSIX qw(strftime);
use strict;
use warnings;

my $version = "4.0.1.7";

my %args = map { split(/=/, $_, 2) } grep { /=/ } @ARGV;
my $cron = ($args{cron} // '') eq 'daily';
my $dryrun = $args{dryrun} ? 1 : 0;
# The interval counts from the start of a run, not its end: the start varies by
# up to 30 minutes (random delay in cron.daily/05-osupdate), a long run would
# otherwise push the next one past the tolerance and skip a day.
my $starttime = time();

my $statusfile = "$lbsdatadir/osupdate.json";
my $rebootflag = '/run/reboot-required';

# Packages that keep running in old code until the next reboot
my $rebootpackages = qr/^(linux-image-|raspberrypi-kernel|raspberrypi-bootloader|raspi-firmware|libc6|systemd|libsystemd0|dbus|libssl)/;

if ( $< != 0 ) {
	print STDERR "This script has to be run as root.\n";
	exit(1);
}

# Old Raspbian based LoxBerrys run Debian releases before Buster
if ( ! -e '/boot/dietpi/.version' ) {
	print STDERR "This is not a DietPi based LoxBerry - updates are not supported.\n";
	exit(0);
}

my $cfgobj = LoxBerry::System::General->new();
my $cfg = $cfgobj->open( readonly => 1 );
my $interval = $cfg->{Osupdate}->{Interval} // '7';
my $type = $cfg->{Osupdate}->{Type} // 'security';
my $autoreboot = ( $cfg->{Osupdate}->{Reboot} // 'false' ) eq 'true';
$type = $args{type} if ( !$cron && defined $args{type} );
$type = 'security' if ( $type ne 'all' );

my $status = {};
if ( open( my $fh, '<', $statusfile ) ) {
	$status = eval { decode_json( do { local $/; <$fh> } ) } // {};
	close($fh);
}
my ($lbuid, $lbgid) = ( getpwnam('loxberry') )[2, 3];

my $due = 1;
if ( $cron ) {
	# cron.daily/05-osupdate starts at a random time between 04:53 and 05:23 -
	# an hour of tolerance keeps that from skipping a day.
	$due = $interval =~ /^(1|7|30)$/ && time() - ( $status->{lastrun} // 0 ) >= $interval * 86400 - 3600;
	my $reboot = $autoreboot && -e $rebootflag;
	exit(0) if ( !$due && !$reboot );
}

# Same owner as the other LoxBerry logs, so that log_maint can clean up
my $logfile = "$lbslogdir/osupdate/" . strftime( "%Y%m%d_%H%M%S", localtime ) . "_osupdate.log";
my $log = LoxBerry::Log->new(
	package => 'LoxBerry Update',
	name => 'osupdate',
	filename => $logfile,
	loglevel => 7,
	stderr => 1,
	addtime => 1,
);
LOGSTART "LoxBerry Debian and PHP updates";
chown $lbuid, $lbgid, "$lbslogdir/osupdate", $logfile;
LOGINF "Version of this script: $version";
LOGINF "Selection: $type" . ( $dryrun ? ' (dry run)' : '' );

my $errors = 0;
if ( $due ) {
	my $lockstate = LoxBerry::System::lock( lockfile => 'osupdate', wait => 7200 );
	if ( $lockstate ) {
		LOGCRIT "Could not get the lock - $lockstate is still running.";
		notify( 'updates', 'osupdate', "Debian/PHP updates: could not start, $lockstate is still running.", 1 ) if ( $cron );
		exit(1);
	}
	$errors = run_update();
	LoxBerry::System::unlock( lockfile => 'osupdate' );
}

if ( $cron && $autoreboot && -e $rebootflag && !$dryrun ) {
	reboot_now();
}

LOGEND "Finished " . ( $errors ? "with errors" : "successfully" ) . ".";
exit( $errors ? 1 : 0 );


sub run_update
{
	my $errors = 0;
	my %env = ( APT_LISTCHANGES_FRONTEND => 'none', DEBIAN_FRONTEND => 'noninteractive', PATH => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' );
	@ENV{ keys %env } = values %env;
	my $aptopts = "-q -o DPkg::Lock::Timeout=1800 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold";

	if ( !$dryrun ) {
		execute( command => "dpkg --configure -a", log => $log );
	}
	my ($uexitcode) = execute( command => "apt-get $aptopts update", log => $log, intro => "Updating the package lists...", warn => "Some package lists could not be updated." );

	my $tmpdir = tempdir( CLEANUP => 1 );
	my $pinopts = "";
	if ( $type eq 'security' ) {
		mkdir("$tmpdir/preferences.d");
		$pinopts = "-o Dir::Etc::Preferences=$tmpdir/preferences -o Dir::Etc::PreferencesParts=$tmpdir/preferences.d";
		write_pinfile("$tmpdir/preferences") or do {
			LOGCRIT "Could not write the APT pin file: $!";
			save_status( 'error', 'pinfile', [] );
			return 1;
		};
	}

	my %before = installed_versions();
	my $php = php_state();
	php_protect($php) if ( !$dryrun );
	my ($exitcode, $output) = execute(
		command => "apt-get $aptopts $pinopts -y --with-new-pkgs " . ( $dryrun ? "-s " : "" ) . "upgrade 2>&1",
		log => $log,
		intro => "Installing the updates...",
	);
	LOGINF $_ foreach ( grep { /upgraded,|kept back|^E: / } split( /\n/, $output ) );
	if ( $exitcode != 0 ) {
		LOGERR "apt-get upgrade failed (exit code $exitcode).";
		$errors++;
	}
	return $errors if ( $dryrun );

	execute( command => "apt-get $aptopts -y autoremove --purge", log => $log, intro => "Removing packages that are no longer needed (e.g. old kernels)..." );
	$errors += php_restore($php);

	my %after = installed_versions();
	my @changed = sort grep { !defined $before{$_} || $before{$_} ne $after{$_} } keys %after;
	LOGOK scalar(@changed) . " packages updated or newly installed.";
	LOGINF "  $_: " . ( $before{$_} // '-' ) . " -> $after{$_}" foreach ( @changed );

	my @reboot = grep { /$rebootpackages/ } @changed;
	if ( @reboot ) {
		LOGWARN "A reboot is required: " . join( ' ', @reboot );
		if ( open( my $fh, '>', $rebootflag ) ) {
			print $fh "*** System restart required ***\n";
			close($fh);
		}
		if ( open( my $fh, '>>', "$rebootflag.pkgs" ) ) {
			print $fh "$_\n" foreach ( @reboot );
			close($fh);
		}
		reboot_required( "Debian/PHP updates: a reboot is required (" . join( ', ', @reboot ) . ")." ) if ( !$autoreboot );
	}

	save_status( $errors ? 'error' : 'ok', '', \@changed );
	notify( 'updates', 'osupdate', "Debian/PHP updates failed - see the log of LoxBerry Update / osupdate.", 1 ) if ( $errors && $cron );
	return $errors;
}

# Only this pin file counts for "security": a plugin pinning its own package
# with priority 1000 (e.g. "grafana 13.1.*") would otherwise get it upgraded
# from a third-party repository. Packages on hold stay untouched (dpkg).
sub write_pinfile
{
	my ($file) = @_;
	my @origins = (
		'release l=Debian-Security',
		'release o=deb.sury.org',
		'origin "archive.raspberrypi.com"',
		'origin "archive.raspberrypi.org"',
	);
	my ($oexitcode, $osid) = execute( command => ". /etc/os-release && echo \$ID" );
	chomp($osid);
	# Raspbian has no security archive of its own
	push( @origins, 'release o=Raspbian' ) if ( $osid eq 'raspbian' );

	open( my $fh, '>', $file ) or return 0;
	foreach my $origin ( @origins ) {
		print $fh "Package: *\nPin: $origin\nPin-Priority: 500\n\n";
	}
	print $fh "Package: *\nPin: release o=*\nPin-Priority: 50\n\n";
	# Repositories without an Origin field are not matched by o=*
	my ($iexitcode, $sites) = execute( command => "apt-get indextargets --format '\$(SITE)'" );
	my %hosts = map { m{^\w+://([^/:]+)} ? ( $1 => 1 ) : () } split( /\n/, $sites );
	print $fh "Package: *\nPin: origin \"$_\"\nPin-Priority: 50\n\n" foreach ( sort keys %hosts );
	close($fh) or return 0;
	LOGINF "Allowed origins: " . join( ', ', @origins );
	if ( open( my $pin, '<', $file ) ) {
		LOGDEB "APT pin file:\n" . do { local $/; <$pin> };
		close($pin);
	}
	return 1;
}

# ---------------------------------------------------------------------------
# PHP: keep the version that is active before the update.
# The PHP metapackages (php, php-cli, libapache2-mod-php, php-curl, ...; the
# Bullseye installer sets them up with "apt install php") depend on the newest
# PHP at packages.sury.org. Upgrading them installs e.g. PHP 8.4 as a new
# dependency; alternatives in auto mode then switch the command line to it
# (priority 84 beats 74), and the old version - now only automatically
# installed - would be purged by autoremove. LoxBerry and its plugins need the
# version that was set up. Same steps as the installer (install_*.sh):
# update-alternatives --set php, a2dismod php*, a2enmod phpX.Y.
# ---------------------------------------------------------------------------
sub php_state
{
	my ($quiet) = @_;
	my %state = ( alternatives => {}, modes => {}, apache => [], versions => [] );
	foreach ( `update-alternatives --get-selections 2>/dev/null` ) {
		my ($name, $mode, $value) = split;
		next if ( !defined $value || $name !~ /^(php|phar)/ );
		$state{alternatives}{$name} = $value;
		$state{modes}{$name} = $mode;
	}
	$state{apache} = [ sort map { m{/(php[\d.]+)\.load$} ? $1 : () } glob("/etc/apache2/mods-enabled/php*.load") ];
	my %versions = map { /(\d+\.\d+)$/ ? ( $1 => 1 ) : () } ( values %{ $state{alternatives} }, @{ $state{apache} } );
	$state{versions} = [ sort keys %versions ];
	if ( !$quiet ) {
		LOGINF "Active PHP: command line " . ( $state{alternatives}{php} // 'none' ) . " (" . ( $state{modes}{php} // '-' ) . "), Apache module " . ( join( ', ', @{ $state{apache} } ) || 'none' ) . ".";
	}
	return \%state;
}

# Packages of the active PHP versions are marked as manually installed, so
# that autoremove keeps them when a metapackage moves to a newer version.
sub php_protect
{
	my ($state) = @_;
	return if ( !@{ $state->{versions} } );
	my $re = join( '|', map { quotemeta } @{ $state->{versions} } );
	my @auto = grep { /^(php|libapache2-mod-php)($re)(-|:|$)/ } split( /\n/, `apt-mark showauto 2>/dev/null` );
	return if ( !@auto );
	LOGINF "Marking the active PHP packages as manually installed, so that autoremove keeps them...";
	execute( command => "apt-mark manual " . join( ' ', @auto ), log => $log, ignoreerrors => 1 );
}

sub php_restore
{
	my ($before) = @_;
	my $errors = 0;
	my $after = php_state(1);

	# Command line (php, php-cgi, phar, ...): set back and fix it (manual mode)
	foreach my $name ( sort keys %{ $before->{alternatives} } ) {
		my $old = $before->{alternatives}{$name};
		my $new = $after->{alternatives}{$name} // '';
		next if ( $old eq $new && ( $after->{modes}{$name} // '' ) eq 'manual' );
		if ( !-e $old ) {
			LOGERR "PHP alternative $name: $old does not exist anymore - left at " . ( $new || 'none' ) . ".";
			$errors++;
			next;
		}
		if ( $old ne $new ) {
			LOGWARN "PHP alternative $name was switched to $new by the update - setting it back to $old.";
		} else {
			LOGINF "PHP alternative $name: fixing $old (manual mode), so that updates cannot switch it.";
		}
		my ($aexitcode) = execute( command => "update-alternatives --set $name $old", log => $log );
		$errors++ if ( $aexitcode != 0 );
	}

	# Apache module
	my %old = map { $_ => 1 } @{ $before->{apache} };
	my %new = map { $_ => 1 } @{ $after->{apache} };
	my @enable = grep { !$new{$_} } sort keys %old;
	my @disable = grep { !$old{$_} } sort keys %new;
	if ( @{ $before->{apache} } && ( @enable || @disable ) ) {
		foreach my $mod ( @enable ) {
			my $so = '';
			if ( open( my $fh, '<', "/etc/apache2/mods-available/$mod.load" ) ) {
				( $so ) = map { /^\s*LoadModule\s+\S+\s+(\S+)/ ? $1 : () } <$fh>;
				close($fh);
			}
			if ( !$so || !-e $so ) {
				LOGERR "Apache module $mod is not available anymore - Apache PHP left at " . ( join( ', ', @{ $after->{apache} } ) || 'none' ) . ".";
				return $errors + 1;
			}
		}
		LOGWARN "Apache PHP module was switched to " . ( join( ', ', @{ $after->{apache} } ) || 'none' ) . " by the update - setting it back to " . join( ', ', @{ $before->{apache} } ) . ".";
		execute( command => "a2dismod -q -f $_", log => $log, ignoreerrors => 1 ) foreach ( @disable );
		execute( command => "a2enmod -q $_", log => $log, ignoreerrors => 1 ) foreach ( @enable );
		my ($cexitcode) = execute( command => "apache2ctl configtest 2>&1", log => $log );
		my ($rexitcode) = $cexitcode == 0 ? execute( command => "systemctl restart apache2", log => $log ) : ( 1 );
		my ($sexitcode) = execute( command => "systemctl is-active --quiet apache2" );
		if ( $cexitcode != 0 || $rexitcode != 0 || $sexitcode != 0 ) {
			# Apache has to come up in any case: back to the state after the upgrade
			LOGERR "Apache does not start with " . join( ', ', @{ $before->{apache} } ) . " - going back to " . ( join( ', ', @{ $after->{apache} } ) || 'none' ) . ".";
			execute( command => "a2dismod -q -f $_", log => $log, ignoreerrors => 1 ) foreach ( @enable );
			execute( command => "a2enmod -q $_", log => $log, ignoreerrors => 1 ) foreach ( @disable );
			execute( command => "systemctl restart apache2", log => $log, ignoreerrors => 1 );
			$errors++;
		} else {
			LOGOK "Apache runs with " . join( ', ', @{ $before->{apache} } ) . " again.";
		}
	}
	return $errors;
}

sub installed_versions
{
	my %versions;
	foreach ( `dpkg-query -W -f='\${db:Status-Abbrev} \${Package}:\${Architecture} \${Version}\\n' 2>/dev/null` ) {
		my ($state, $package, $pkgversion) = split;
		$versions{$package} = $pkgversion if ( $state =~ /^ii/ );
	}
	return %versions;
}

sub save_status
{
	my ($result, $message, $changed) = @_;
	$status->{lastrun} = $starttime;
	$status->{result} = $result;
	$status->{message} = $message;
	$status->{type} = $type;
	$status->{packages} = $changed;
	if ( open( my $fh, '>', $statusfile ) ) {
		print $fh JSON->new->pretty->canonical->encode($status);
		close($fh);
		chown $lbuid, $lbgid, $statusfile;
	} else {
		LOGERR "Could not write $statusfile: $!";
	}
}

sub reboot_now
{
	# Do not cut off a LoxBerry or plugin update that started meanwhile
	my $lockstate = LoxBerry::System::lock( wait => 3600 );
	if ( $lockstate ) {
		LOGWARN "Reboot postponed to the next night - $lockstate is running.";
		return;
	}
	LOGWARN "Rebooting now, as required by the installed updates.";
	notify( 'updates', 'osupdate', "Debian/PHP updates: LoxBerry was rebooted at night, as required by the installed updates." );
	LOGEND "Rebooting.";
	system( "/sbin/reboot" );
	exit(0);
}
