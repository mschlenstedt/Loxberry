#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;
use File::Temp qw(tempdir);

init();

# ---------------------------------------------------------------------------
# Security updates for Debian AND PHP (PHP2Shell, CVE-2026-109618/-109619).
#
# Until now no security update reached a LoxBerry automatically:
#  - DietPi masks the apt-daily timers, so unattended-upgrades never ran.
#  - The Origins-Pattern used codename=${distro_codename}, but the security
#    suite is called ${distro_codename}-security - it never matched.
#  - PHP comes from packages.sury.org, which was not an allowed origin.
#  - 20auto-upgrades (Debian package) is read after 02periodic and
#    overruled the interval set in the LoxBerry WebUI.
#  - Installations from the bookworm installer use a sury key that expired
#    on 2026-02-04, some have lost the sury source completely.
#
# Only DietPi based LoxBerrys are changed. Old Raspbian based installations
# run Debian releases before Buster - neither sury nor this configuration
# fits there.
# ---------------------------------------------------------------------------

if ( ! -e '/boot/dietpi/.version' ) {
	LOGINF "This is not a DietPi based LoxBerry - security update configuration is left unchanged.";
	exit($errors);
}

my ($oexitcode, $codename) = execute( command => ". /etc/os-release && echo \$VERSION_CODENAME" );
chomp($codename);
if ( !$codename ) {
	LOGERR "Could not determine the Debian codename - security update configuration is left unchanged.";
	$errors++;
	exit($errors);
}
LOGINF "DietPi based LoxBerry on Debian $codename.";

# ---------------------------------------------------------------------------
# PHP2Shell mitigation, effective without any package upgrade.
# system/ is excluded from rsync, so the ini file is copied explicitly.
# ---------------------------------------------------------------------------
LOGINF "Disabling session.upload_progress for Apache PHP (PHP2Shell mitigation)...";
copy_to_loxberry('/system/php/loxberry-apache.ini');

# ---------------------------------------------------------------------------
# Exactly one sury source with the current keyring
# ---------------------------------------------------------------------------
my $suryok = 0;
my ($rexitcode) = execute( command => "curl -fsS -o /dev/null https://packages.sury.org/php/dists/$codename/InRelease" );
if ( $rexitcode != 0 ) {
	LOGWARN "packages.sury.org offers no PHP packages for $codename (or is not reachable) - PHP source is left unchanged.";
} else {
	LOGINF "Refreshing the keyring of packages.sury.org...";
	my $tmpdir = tempdir( CLEANUP => 1 );
	my ($kexitcode) = execute( command => "curl -fsSL -o $tmpdir/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb", log => $log );
	if ( $kexitcode == 0 ) {
		apt_install("$tmpdir/debsuryorg-archive-keyring.deb");
		$suryok = 1 if ( -e '/usr/share/keyrings/debsuryorg-archive-keyring.gpg' );
	}
	if ( !$suryok ) {
		LOGERR "Could not install the keyring of packages.sury.org - PHP source is left unchanged.";
		$errors++;
	}
}

if ( $suryok ) {
	# Two entries for the same URI with different Signed-By make apt fail completely
	foreach my $file ( glob('/etc/apt/sources.list.d/*') ) {
		next if ( $file eq '/etc/apt/sources.list.d/sury-php.sources' );
		my ($gexitcode) = execute( command => "grep -qs 'packages.sury.org/php' $file" );
		next if ( $gexitcode != 0 );
		my ($cexitcode, $content) = execute( command => "grep -v '^\\s*#' $file" );
		LOGINF "Removing old sury source $file: $content";
		unlink $file or do { LOGERR "Could not remove $file: $!"; $errors++; };
	}
	my ($lexitcode) = execute( command => "grep -qs '^[^#]*packages.sury.org/php' /etc/apt/sources.list" );
	LOGWARN "/etc/apt/sources.list contains packages.sury.org as well - please remove it there." if ( $lexitcode == 0 );

	if ( open( my $fh, '>', '/etc/apt/sources.list.d/sury-php.sources' ) ) {
		print $fh "Types: deb deb-src\n";
		print $fh "URIs: https://packages.sury.org/php\n";
		print $fh "Suites: $codename\n";
		print $fh "Components: main\n";
		print $fh "Signed-By: /usr/share/keyrings/debsuryorg-archive-keyring.gpg\n";
		close($fh);
		LOGOK "PHP source of packages.sury.org set for $codename.";
	} else {
		LOGERR "Could not write sury-php.sources: $!";
		$errors++;
	}
}

apt_update();

# ---------------------------------------------------------------------------
# Debug symbol packages (installed from packagesXX.txt) depend on the exact
# version of their package. unattended-upgrades never removes packages, so
# a single one of them blocks the upgrade of the whole PHP version.
# ---------------------------------------------------------------------------
my ($dexitcode, $dbgsym) = execute( command => "dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\\n' '*-dbgsym' 2>/dev/null" );
my @dbgsym = map { (split)[1] } grep { /^ii/ } split( /\n/, $dbgsym );
if ( @dbgsym ) {
	LOGINF "Removing debug symbol packages...";
	apt_remove(@dbgsym);
}

my ($uexitcode) = execute( command => "dpkg-query -W -f='\${db:Status-Abbrev}' unattended-upgrades 2>/dev/null | grep -q '^ii'" );
apt_install("unattended-upgrades") if ( $uexitcode != 0 );

# ---------------------------------------------------------------------------
# unattended-upgrades configuration. The checkbox in the WebUI only set
# Automatic-Reboot-WithUsers so far - its value now becomes Automatic-Reboot.
# ---------------------------------------------------------------------------
my $uuconf = "$lbhomedir/system/unattended-upgrades/unattended-upgrades.conf";
my $autoreboot = "false";
my ($wexitcode) = execute( command => "grep -qE '^\\s*Unattended-Upgrade::Automatic-Reboot-WithUsers\\s+\"true\"' $uuconf" );
$autoreboot = "true" if ( $wexitcode == 0 );

LOGINF "Installing unattended-upgrades configuration (Debian-Security and packages.sury.org)...";
copy_to_loxberry('/system/unattended-upgrades/unattended-upgrades.conf', 'loxberry');
execute( command => "sed -i 's/^Unattended-Upgrade::Automatic-Reboot \".*\";/Unattended-Upgrade::Automatic-Reboot \"$autoreboot\";/' $uuconf", log => $log );
LOGINF "Automatic reboot (at 02:00, if an update requires it): $autoreboot";
execute( command => "ln -sfn $uuconf /etc/apt/apt.conf.d/50unattended-upgrades", log => $log );

# 20auto-upgrades is managed by the unattended-upgrades package (debconf) and
# is read after 02periodic. The LoxBerry settings are linked as
# 99loxberry-periodic now, so they are read last and win.
LOGINF "Linking the LoxBerry update interval as 99loxberry-periodic...";
unlink '/etc/apt/apt.conf.d/02periodic' if ( -l '/etc/apt/apt.conf.d/02periodic' );
execute( command => "ln -sfn $lbhomedir/system/unattended-upgrades/periodic.conf /etc/apt/apt.conf.d/99loxberry-periodic", log => $log );
my ($pexitcode, $periodic) = execute( command => "apt-config dump | grep -E '^APT::Periodic::(Update-Package-Lists|Unattended-Upgrade) '" );
LOGINF "Effective setting: $_" foreach ( split( /\n/, $periodic ) );

# DietPi masks the apt-daily timers when it builds its images
LOGINF "Enabling the apt-daily timers...";
execute( command => "systemctl unmask apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer", log => $log );
my ($texitcode) = execute( command => "systemctl enable --now apt-daily.timer apt-daily-upgrade.timer", log => $log );
if ( $texitcode == 0 ) {
	LOGOK "apt-daily timers enabled.";
} else {
	LOGERR "Could not enable the apt-daily timers.";
	$errors++;
}

# ---------------------------------------------------------------------------
# Close PHP2Shell now instead of waiting for the next timer run. Upgrading
# libapache2-mod-php restarts Apache - an update started from the WebUI runs
# in Apache's cgroup and would be killed with it. So the upgrade runs in a
# unit of its own and this script does not wait for it. Afterwards
# unattended-upgrades installs the pending security updates (if enabled).
# ---------------------------------------------------------------------------
my ($qexitcode, $installed) = execute( command => "dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\\n' 'php*' 'libapache2-mod-php*' 2>/dev/null" );
my @phppackages = grep { !/-dbgsym$/ } map { (split)[1] } grep { /^ii/ } split( /\n/, $installed );
my $upgradecmd = "";
if ( @phppackages ) {
	$upgradecmd = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold install --only-upgrade " . join( ' ', @phppackages ) . "; ";
}
$upgradecmd .= "systemctl reload apache2; systemctl start --no-block apt-daily-upgrade.service";
my ($sexitcode) = execute( command => "systemd-run --unit=loxberry-securityupdate-" . time() . " --collect --no-block /bin/sh -c '$upgradecmd'", log => $log );
if ( $sexitcode == 0 ) {
	LOGOK "PHP upgrade started in the background (journalctl -u 'loxberry-securityupdate-*'), unattended-upgrades follows.";
} else {
	LOGERR "Could not start the PHP upgrade.";
	$errors++;
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
