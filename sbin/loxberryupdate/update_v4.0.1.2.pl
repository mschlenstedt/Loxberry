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
# PHP2Shell (CVE-2026-109618/-109619): PHP comes from packages.sury.org.
#  - Installations from the bookworm installer use a sury key that expired
#    on 2026-02-04, some have lost the sury source completely.
#  - Debug symbol packages block every PHP upgrade.
# The PHP packages are upgraded right away. Regular Debian and PHP updates
# are installed by sbin/osupdate.pl (update_v4.0.1.3.pl).
#
# Only DietPi based LoxBerrys are changed. Old Raspbian based installations
# run Debian releases before Buster - sury does not fit there.
# ---------------------------------------------------------------------------

if ( ! -e '/boot/dietpi/.version' ) {
	LOGINF "This is not a DietPi based LoxBerry - PHP configuration is left unchanged.";
	exit($errors);
}

my ($oexitcode, $codename) = execute( command => ". /etc/os-release && echo \$VERSION_CODENAME" );
chomp($codename);
if ( !$codename ) {
	LOGERR "Could not determine the Debian codename - PHP configuration is left unchanged.";
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
# version of their package. apt-get upgrade never removes packages, so a
# single one of them holds back the upgrade of the whole PHP version.
# ---------------------------------------------------------------------------
my ($dexitcode, $dbgsym) = execute( command => "dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\\n' '*-dbgsym' 2>/dev/null" );
my @dbgsym = map { (split)[1] } grep { /^ii/ } split( /\n/, $dbgsym );
if ( @dbgsym ) {
	LOGINF "Removing debug symbol packages...";
	apt_remove(@dbgsym);
}

# ---------------------------------------------------------------------------
# Close PHP2Shell now instead of waiting for the next night. Upgrading
# libapache2-mod-php restarts Apache - an update started from the WebUI runs
# in Apache's cgroup and would be killed with it. So the upgrade runs in a
# unit of its own and this script does not wait for it.
# ---------------------------------------------------------------------------
my ($qexitcode, $installed) = execute( command => "dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\\n' 'php*' 'libapache2-mod-php*' 2>/dev/null" );
my @phppackages = grep { !/-dbgsym$/ } map { (split)[1] } grep { /^ii/ } split( /\n/, $installed );
if ( @phppackages ) {
	my $upgradecmd = "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold install --only-upgrade " . join( ' ', @phppackages ) . "; systemctl reload apache2";
	my ($sexitcode) = execute( command => "systemd-run --unit=loxberry-securityupdate-" . time() . " --collect --no-block /bin/sh -c '$upgradecmd'", log => $log );
	if ( $sexitcode == 0 ) {
		LOGOK "PHP upgrade started in the background (journalctl -u 'loxberry-securityupdate-*').";
	} else {
		LOGERR "Could not start the PHP upgrade.";
		$errors++;
	}
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
