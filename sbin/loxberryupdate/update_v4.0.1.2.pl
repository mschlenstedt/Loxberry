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
# PHP security update (PHP2Shell, CVE-2026-109618 / CVE-2026-109619).
#
# PHP 7.4 (default) and PHP 8.x come from packages.sury.org. Nothing updates
# them on its own: unattended-upgrades only allows Debian-Security, and DietPi
# disables the apt-daily timers anyway. So the packages are upgraded here.
#
# The key file the bookworm installer wrote (deb.sury.org-php.gpg) expired on
# 2026-02-04, so the keyring package is refreshed first. Some installations
# have lost the sury source - it is added again in that case.
# ---------------------------------------------------------------------------

LOGINF "Refreshing the keyring of packages.sury.org...";
my $tmpdir = tempdir( CLEANUP => 1 );
my ($kexitcode) = execute( command => "curl -fsSL -o $tmpdir/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb", log => $log );
if ( $kexitcode == 0 ) {
	apt_install("$tmpdir/debsuryorg-archive-keyring.deb");
} else {
	LOGERR "Could not download the keyring of packages.sury.org - PHP packages may not be upgradable.";
	$errors++;
}

my ($sexitcode) = execute( command => "grep -rqs 'packages.sury.org/php' /etc/apt/sources.list /etc/apt/sources.list.d/" );
if ( $sexitcode != 0 ) {
	LOGINF "PHP source of packages.sury.org is missing - adding it...";
	my ($cexitcode, $codename) = execute( command => ". /etc/os-release && echo \$VERSION_CODENAME" );
	chomp($codename);
	if ( $codename ) {
		open( my $fh, '>', '/etc/apt/sources.list.d/sury-php.sources' ) or do { LOGERR "Could not write sury-php.sources: $!"; $errors++; };
		if ( $fh ) {
			print $fh "Types: deb deb-src\n";
			print $fh "URIs: https://packages.sury.org/php\n";
			print $fh "Suites: $codename\n";
			print $fh "Components: main\n";
			print $fh "Signed-By: /usr/share/keyrings/debsuryorg-archive-keyring.gpg\n";
			close($fh);
			LOGOK "PHP source of packages.sury.org added for $codename.";
		}
	} else {
		LOGERR "Could not determine the Debian codename - PHP source not added.";
		$errors++;
	}
}

apt_update();

# Upgrade every installed PHP package. Debug symbol packages are not named -
# apt upgrades them along with their package, and one that is missing for an
# architecture would abort the whole install.
my ($qexitcode, $installed) = execute( command => "dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\\n' 'php*' 'libapache2-mod-php*' 2>/dev/null" );
my @phppackages;
foreach ( split( /\n/, $installed ) ) {
	my ($status, $package) = split;
	next if ( $status ne 'ii' or $package =~ /-dbgsym$/ );
	push( @phppackages, $package );
}

if ( @phppackages ) {
	LOGINF "Upgrading PHP packages...";
	apt_install( join( ' ', @phppackages ) );
	# Graceful reload loads the new PHP module. No restart - the update may run as child of apache.
	execute( command => "systemctl reload apache2", log => $log );
	my ($vexitcode, $versions) = execute( command => "dpkg-query -W -f='\${Package} \${Version}\\n' 'libapache2-mod-php*' 2>/dev/null" );
	LOGINF "Installed PHP Apache modules: $_" foreach ( grep { / \S/ } split( /\n/, $versions ) );
} else {
	LOGWARN "No installed PHP packages found - nothing to upgrade.";
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
