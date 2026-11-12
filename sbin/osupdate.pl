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

my $version = "4.0.1.6";

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
	my %env = ( APT_LISTCHANGES_FRONTEND => 'none', DEBIAN_FRONTEND => 'noninteractive' );
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
