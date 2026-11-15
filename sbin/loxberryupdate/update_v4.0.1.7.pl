#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# ---------------------------------------------------------------------------
# Repair the PHP version
#
# The PHP metapackages (php, php-cli, libapache2-mod-php, php-curl, ...; the
# Bullseye installer sets them up with "apt install php") depend on the newest
# PHP at packages.sury.org. update_v4.0.1.2.pl (4.0.1.2 - 4.0.1.6) and
# osupdate.pl (4.0.1.3 - 4.0.1.6) upgraded them: PHP 8.4 came in as a new
# dependency and, with the alternatives in auto mode, became the command line
# PHP (priority 84 beats 74). Plugins running PHP scripts failed. The old
# version, now only automatically installed, can even have been purged by the
# nightly autoremove.
#
# The PHP version of this LoxBerry is the one Apache runs. Without an Apache
# PHP module it is 7.4, the version all installers set up. This script
#  - installs missing packages of that version (the same extensions as the
#    other installed PHP versions),
#  - marks them as manually installed, so that autoremove keeps them,
#  - sets up the LoxBerry ini links (as the installer does),
#  - sets the command line PHP to that version (update-alternatives --set),
#  - enables the Apache module of that version if it is not enabled.
# osupdate.pl keeps the active PHP version from now on.
# ---------------------------------------------------------------------------

my $defaultphp = '7.4';
# a2enmod, apache2ctl and update-alternatives live in sbin - not every caller has it in PATH
$ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

if ( ! -e '/boot/dietpi/.version' ) {
	LOGINF "This is not a DietPi based LoxBerry - PHP configuration is left unchanged.";
	exit($errors);
}

my @apache = php_apache_modules();
my $target;
if ( @apache == 1 ) {
	$target = $apache[0];
	LOGINF "Apache runs PHP $target - this is the PHP version of this LoxBerry.";
} else {
	$target = $defaultphp;
	LOGWARN "Apache PHP module: " . ( join( ', ', map { "php$_" } @apache ) || 'none' ) . " - using the LoxBerry default PHP $target.";
}

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------
my %installed = php_installed();
my @missing;
if ( !$installed{"php$target-cli"} || !$installed{"libapache2-mod-php$target"} ) {
	# Base packages ("apt install php") and the same extensions as the other
	# PHP versions (php8.4-curl -> php7.4-curl)
	my %wanted = map { ( "php$target-$_" => 1 ) } qw(cli common json opcache readline);
	$wanted{"libapache2-mod-php$target"} = 1;
	foreach my $pkg ( keys %installed ) {
		$wanted{"php$target-$2"} = 1 if ( $pkg =~ /^php(\d+\.\d+)-(\S+)$/ && $1 ne $target && $2 !~ /-dbgsym$/ );
	}
	@missing = sort grep { !$installed{$_} } keys %wanted;
}
if ( @missing ) {
	LOGINF "Packages of PHP $target not installed: @missing";
	apt_update();
	my @available = grep { php_available($_) } @missing;
	my @unavailable = grep { !php_available($_) } @missing;
	LOGINF "Not available, skipped: @unavailable" if ( @unavailable );
	if ( @available ) {
		LOGINF "Installing the missing packages of PHP $target...";
		apt_install(@available);
		%installed = php_installed();
	}
}
if ( !$installed{"php$target-cli"} ) {
	LOGCRIT "PHP $target is not installed and could not be installed - PHP configuration is left unchanged.";
	$errors++;
	exit($errors);
}

# Packages of this version are kept by autoremove
my $re = quotemeta($target);
my @auto = grep { /^(php|libapache2-mod-php)$re(-|:|$)/ } split( /\n/, `apt-mark showauto 2>/dev/null` );
if ( @auto ) {
	LOGINF "Marking the packages of PHP $target as manually installed, so that autoremove keeps them...";
	execute( command => "apt-mark manual " . join( ' ', @auto ), log => $log, ignoreerrors => 1 );
}

# ---------------------------------------------------------------------------
# LoxBerry ini links (as the installer sets them up)
# ---------------------------------------------------------------------------
my %links = (
	apache2 => [ '20-loxberry-apache.ini', 'loxberry-apache.ini' ],
	cgi     => [ '20-loxberry-apache.ini', 'loxberry-apache.ini' ],
	cli     => [ '20-loxberry-cli.ini',    'loxberry-cli.ini' ],
);
foreach my $sapi ( sort keys %links ) {
	my $dir = "/etc/php/$target/$sapi/conf.d";
	next if ( !-d "/etc/php/$target/$sapi" );
	my ( $name, $source ) = @{ $links{$sapi} };
	next if ( -l "$dir/$name" && -e "$dir/$name" );
	execute( command => "mkdir -p $dir", log => $log, ignoreerrors => 1 );
	unlink("$dir/$name") if ( -l "$dir/$name" );
	if ( symlink( "$lbhomedir/system/php/$source", "$dir/$name" ) ) {
		LOGOK "Created $dir/$name.";
	} else {
		LOGERR "Could not create $dir/$name: $!";
		$errors++;
	}
}

# ---------------------------------------------------------------------------
# Command line PHP
# ---------------------------------------------------------------------------
my ( $mode, $value ) = ( '', '' );
foreach ( `update-alternatives --query php 2>/dev/null` ) {
	$mode = $1 if ( /^Status:\s*(\S+)/ );
	$value = $1 if ( /^Value:\s*(\S+)/ );
}
if ( $value eq "/usr/bin/php$target" && $mode eq 'manual' ) {
	LOGOK "Command line PHP is $target.";
} else {
	LOGWARN "Command line PHP is " . ( $value || 'not set' ) . " ($mode) - setting it to PHP $target.";
	my ($aexitcode) = execute( command => "update-alternatives --set php /usr/bin/php$target", log => $log );
	$errors++ if ( $aexitcode != 0 );
}

# ---------------------------------------------------------------------------
# Apache module
# ---------------------------------------------------------------------------
if ( @apache == 1 && $apache[0] eq $target ) {
	LOGOK "Apache PHP module is php$target.";
} else {
	$errors += php_apache_switch( $target, @apache );
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);


# ===========================================================================

sub php_apache_modules
{
	return sort map { m{/php(\d+\.\d+)\.load$} ? $1 : () } glob("/etc/apache2/mods-enabled/php*.load");
}

sub php_installed
{
	my %pkgs;
	foreach ( `dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\\n' 'php*' 'libapache2-mod-php*' 2>/dev/null` ) {
		my ( $state, $pkg ) = split;
		$pkgs{$pkg} = 1 if ( defined $pkg && $state =~ /^ii/ );
	}
	return %pkgs;
}

sub php_available
{
	my ($pkg) = @_;
	my $policy = `apt-cache policy $pkg 2>/dev/null`;
	return ( $policy =~ /Candidate:\s*(\S+)/ && $1 ne '(none)' ) ? 1 : 0;
}

# The PHP page answers with its XML when PHP runs, with its source when not
sub php_apache_ok
{
	return 0 if ( system("systemctl is-active --quiet apache2.service") != 0 );
	my $port = 80;
	if ( open( my $fh, '<', '/etc/apache2/ports.conf' ) ) {
		my $depth = 0;
		while ( my $line = <$fh> ) {
			next if ( $line =~ /^\s*#/ );
			$depth++ if ( $line =~ /^\s*<IfModule/i );
			$depth-- if ( $line =~ /^\s*<\/IfModule/i );
			if ( $depth == 0 && $line =~ /^\s*Listen\s+(?:\S*:)?(\d+)\s*$/i ) {
				$port = $1;
				last;
			}
		}
		close($fh);
	}
	my $body = `curl -s -m 10 http://127.0.0.1:$port/system/ssdpdesc.php 2>/dev/null`;
	$body = '' if ( !defined $body );
	my $ok = ( $body =~ /<root/ && $body !~ /<\?php/ ) ? 1 : 0;
	LOGDEB "PHP check on port $port: " . ( $ok ? "PHP runs" : "no PHP output (" . length($body) . " bytes: " . substr( $body =~ s/\s+/ /gr, 0, 80 ) . ")" );
	return $ok;
}

# Restart Apache in a unit of its own as soon as no update or plugin
# installation runs any more (LoxBerry locks), check PHP, go back if Apache
# does not come up with it. The result goes to the log of this update.
sub php_apache_restart_later
{
	my ( $target, @current ) = @_;
	my $job = '/run/loxberry-phpfix.pl';
	my $code = <<'EOF';
#!/usr/bin/perl
# Written by update_v4.0.1.7.pl: restart Apache after the LoxBerry update, so
# that it loads PHP. Removes itself.
use LoxBerry::System;
use POSIX qw(strftime);
$ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';
my ( $mod, $logfile, @current ) = @ARGV;
$logfile = '' if ( $logfile eq '-' );
sub logline {
	my ($line) = @_;
	print "$line\n";
	if ( $logfile && open( my $fh, '>>', $logfile ) ) {
		print $fh strftime( "%H:%M:%S", localtime ) . " $line\n";
		close($fh);
	}
}
sub php_ok {
	return 0 if ( system("systemctl is-active --quiet apache2.service") != 0 );
	my $port = 80;
	if ( open( my $fh, '<', '/etc/apache2/ports.conf' ) ) {
		my $depth = 0;
		while ( my $line = <$fh> ) {
			next if ( $line =~ /^\s*#/ );
			$depth++ if ( $line =~ /^\s*<IfModule/i );
			$depth-- if ( $line =~ /^\s*<\/IfModule/i );
			if ( $depth == 0 && $line =~ /^\s*Listen\s+(?:\S*:)?(\d+)\s*$/i ) { $port = $1; last; }
		}
		close($fh);
	}
	my $body = `curl -s -m 10 http://127.0.0.1:$port/system/ssdpdesc.php 2>/dev/null` // '';
	return ( $body =~ /<root/ && $body !~ /<\?php/ ) ? 1 : 0;
}
my $lockstate = LoxBerry::System::lock( lockfile => 'phpfix', wait => 7200 );
logline("<WARNING> Restarting Apache was postponed too long - $lockstate is still running.") if ( $lockstate );
system("systemctl restart apache2.service");
my $ok = 0;
for ( my $i = 0; $i < 15 && !$ok; $i++ ) { sleep(1); $ok = php_ok(); }
if ( $ok ) {
	logline("<OK> Apache restarted after the update - it runs PHP with module $mod.");
} else {
	logline("<ERROR> Apache does not run PHP after the restart - going back to " . ( join( ', ', map { "php$_" } @current ) || 'no PHP module' ) . ".");
	system("a2dismod -q -f $mod");
	system("a2enmod -q php$_") foreach ( @current );
	system("systemctl restart apache2.service");
}
LoxBerry::System::unlock( lockfile => 'phpfix' ) if ( !$lockstate );
unlink($0);
EOF
	my $fh;
	if ( !open( $fh, '>', $job ) || !print( $fh $code ) || !close($fh) ) {
		LOGERR "Could not write $job: $!";
		return 0;
	}
	chmod( 0700, $job );
	my $unit = "loxberry-phpfix-" . time();
	my $perl5lib = $ENV{PERL5LIB} || "$lbhomedir/libs/perllib";
	my ($sexitcode) = execute(
		command => "systemd-run --quiet --no-block --collect --unit=$unit --setenv=LBHOMEDIR=$lbhomedir --setenv=PERL5LIB=$perl5lib /usr/bin/perl $job php$target " . ( $main::logfilename || '-' ) . " @current",
		log => $log,
	);
	if ( $sexitcode != 0 ) {
		unlink($job);
		return 0;
	}
	LOGWARN "Apache loads PHP $target only on a restart - it is restarted as soon as this update is finished (journalctl -u '$unit').";
	return 1;
}

sub php_apache_switch
{
	my ( $target, @current ) = @_;
	my $mod = "php$target";
	if ( !-e "/etc/apache2/mods-available/$mod.load" && -e "/etc/apache2.orig/mods-available/$mod.load" ) {
		# /etc/apache2 is LoxBerry's system/apache2 - the installer copies the module files from the original
		execute( command => "cp /etc/apache2.orig/mods-available/$mod.load /etc/apache2.orig/mods-available/$mod.conf /etc/apache2/mods-available/", log => $log, ignoreerrors => 1 );
	}
	if ( !-e "/etc/apache2/mods-available/$mod.load" ) {
		LOGERR "Apache module $mod is not available - Apache PHP module left at " . ( join( ', ', map { "php$_" } @current ) || 'none' ) . ".";
		return 1;
	}

	my $okbefore = php_apache_ok();
	LOGINF "Apache PHP before the change: " . ( $okbefore ? "working" : "not working" ) . ".";
	LOGWARN "Apache PHP module is " . ( join( ', ', map { "php$_" } @current ) || 'none' ) . " - enabling $mod.";
	execute( command => "a2dismod -q -f php$_", log => $log, ignoreerrors => 1 ) foreach ( @current );
	execute( command => "a2enmod -q $mod", log => $log, ignoreerrors => 1 );

	my ($cexitcode) = execute( command => "apache2ctl configtest 2>&1", log => $log );
	my $okafter = 0;
	if ( $cexitcode == 0 ) {
		# A graceful reload does not cut off the request of an update started from the WebUI
		execute( command => "systemctl reload-or-restart apache2.service", log => $log, ignoreerrors => 1 );
		for ( my $i = 0; $i < 10; $i++ ) {
			sleep(1);
			$okafter = php_apache_ok();
			last if ( $okafter );
		}
		if ( !$okafter && system("systemctl is-active --quiet apache2.service") == 0 ) {
			# An Apache started without any PHP module loads one only on a restart
			# (tested: a reload is not enough). A restart from here would kill an
			# update started from the WebUI - it runs after the update.
			return 0 if ( php_apache_restart_later( $target, @current ) );
		}
	}
	if ( $okafter ) {
		LOGOK "Apache runs PHP $target.";
		return 0;
	}

	LOGERR "Apache does not run PHP $target - going back to " . ( join( ', ', map { "php$_" } @current ) || 'none' ) . ".";
	execute( command => "a2dismod -q -f $mod", log => $log, ignoreerrors => 1 );
	execute( command => "a2enmod -q php$_", log => $log, ignoreerrors => 1 ) foreach ( @current );
	execute( command => "systemctl reload-or-restart apache2.service", log => $log, ignoreerrors => 1 );
	sleep(2);
	if ( system("systemctl is-active --quiet apache2.service") != 0 ) {
		execute( command => "systemctl restart apache2.service", log => $log, ignoreerrors => 1 );
	}
	return 1;
}
