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
# Debian and PHP updates are installed by LoxBerry itself now: sbin/osupdate.pl,
# started every night from cron.daily. unattended-upgrades checks the
# packages one by one - on a LoxBerry with a backlog of 160 security updates
# it calculated for more than two hours and locked dpkg the whole time.
# osupdate.pl lets apt select the same packages in seconds.
# ---------------------------------------------------------------------------

# system/ is excluded from rsync, so these files are copied explicitly
LOGINF "Installing sudoers defaults (osupdate.pl entry)...";
copy_to_loxberry("/system/sudoers/lbdefaults");
LOGINF "Installing the nightly job for Debian/PHP updates...";
copy_to_loxberry("/system/cron/cron.daily/05-osupdate", "loxberry");

# ---------------------------------------------------------------------------
# Carry over the settings made for unattended-upgrades in the WebUI
# ---------------------------------------------------------------------------
my $generalobj = LoxBerry::System::General->new();
my $generalcfg = $generalobj->open();
if ( !$generalcfg ) {
	LOGERR "Could not open general.json - settings for Debian/PHP updates are not set.";
	$errors++;
} elsif ( !$generalcfg->{Osupdate} ) {
	my $interval = '7';
	if ( open( my $fh, '<', "$lbhomedir/system/unattended-upgrades/periodic.conf" ) ) {
		while ( <$fh> ) {
			$interval = $1 if ( /^\s*APT::Periodic::Unattended-Upgrade\s+"(\d+)"/ );
		}
		close($fh);
	}
	$interval = '7' if ( $interval !~ /^(0|1|7|30)$/ );

	# 4.0.1.2 set Automatic-Reboot, before only Automatic-Reboot-WithUsers was set
	my $reboot = 'false';
	my $rebootline;
	if ( open( my $fh, '<', "$lbhomedir/system/unattended-upgrades/unattended-upgrades.conf" ) ) {
		while ( <$fh> ) {
			$rebootline = $1 if ( /^\s*Unattended-Upgrade::Automatic-Reboot\s+"(\w+)"/ );
			$reboot = $1 if ( /^\s*Unattended-Upgrade::Automatic-Reboot-WithUsers\s+"(\w+)"/ );
		}
		close($fh);
	}
	$reboot = $rebootline if ( defined $rebootline );
	$reboot = 'false' if ( $reboot ne 'true' );

	$generalcfg->{Osupdate} = { Interval => $interval, Type => 'security', Reboot => $reboot };
	$generalobj->write();
	LOGOK "Settings for Debian/PHP updates: interval $interval days, security updates only, automatic reboot $reboot.";
} else {
	LOGINF "Settings for Debian/PHP updates already exist.";
}

# ---------------------------------------------------------------------------
# Remove unattended-upgrades. Only on DietPi based LoxBerrys - old Raspbian
# based installations stay as they are.
# ---------------------------------------------------------------------------
if ( ! -e '/boot/dietpi/.version' ) {
	LOGINF "This is not a DietPi based LoxBerry - unattended-upgrades is left unchanged.";
	exit($errors);
}

# 4.0.1.2 had enabled the apt-daily timers, DietPi masks them
LOGINF "Stopping and masking the apt-daily timers...";
execute( command => "systemctl stop apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service", log => $log );
execute( command => "systemctl disable apt-daily.timer apt-daily-upgrade.timer", log => $log );
execute( command => "systemctl mask apt-daily.timer apt-daily-upgrade.timer", log => $log );

foreach my $link ( '/etc/apt/apt.conf.d/50unattended-upgrades', '/etc/apt/apt.conf.d/99loxberry-periodic', '/etc/apt/apt.conf.d/02periodic' ) {
	next if ( ! -l $link || readlink($link) !~ /^\Q$lbhomedir\E\// );
	LOGINF "Removing $link";
	unlink $link or do { LOGERR "Could not remove $link: $!"; $errors++; };
}

my ($uexitcode) = execute( command => "dpkg-query -W -f='\${db:Status-Abbrev}' unattended-upgrades 2>/dev/null | grep -q '^ii'" );
if ( $uexitcode == 0 ) {
	LOGINF "Removing unattended-upgrades...";
	apt_remove("unattended-upgrades");
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
