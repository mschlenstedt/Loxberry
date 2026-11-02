#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin;
use lib "$FindBin::Bin/../..";
use LoxBerry::Log;

my $dir = tempdir(CLEANUP => 1);
make_path("$dir/log/system_tmpfs");
# All log database writes go to a disposable database, not the live system.
local $LoxBerry::System::lbhomedir = $dir;
my $filename = "$dir/install.log";
open(my $fh, '>', $filename) or die $!;
print {$fh} "<INFO> Archive download completed.\n";
close $fh;

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };
my $log = LoxBerry::Log->new(
	package => 'Plugin Installation', name => 'Install',
	filename => $filename, loglevel => 7, append => 1,
);
is_deeply(\@warnings, [], 'appending to an unregistered log does not warn');
ok(!defined $log->{dbkey}, 'constructor leaves session creation to LOGSTART');
$log->LOGSTART('Plugin Installation');
ok($log->{dbkey}, 'LOGSTART creates the database session');
my $key = $log->{dbkey};
$log->LOGEND;

open($fh, '<', $filename) or die $!;
my $contents = do { local $/; <$fh> };
close $fh;
like($contents, qr/Archive download completed.*TASK STARTED.*TASK FINISHED/s,
	'download output and installer session are both retained');
is_deeply(\@warnings, [], 'complete log lifecycle does not warn');

my $appended = LoxBerry::Log->new(
	package => 'Plugin Installation', name => 'Install',
	filename => $filename, loglevel => 7, append => 1,
);
is($appended->{dbkey}, $key, 'existing log session is still found when appending');
$appended->LOGEND;

@warnings = ();
my $missing = { filename => "$dir/missing.log" };
is(LoxBerry::Log::log_db_query_id($log->{dbh}, $missing), undef,
	'ordinary missing session lookup returns undef');
like(join('', @warnings), qr/No database entry found/,
	'ordinary missing session lookup still warns');

@warnings = ();
my $broken_db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '',
	{ PrintError => 0, RaiseError => 0 }) or die $DBI::errstr;
is(LoxBerry::Log::log_db_query_id($broken_db, $missing, 1), undef,
	'database failure does not become a success');
ok(@warnings, 'database errors are still surfaced during append lookup');
$broken_db->disconnect;

my $root = "$FindBin::Bin/../../../..";
open(my $installer, '<', "$root/sbin/plugininstall.pl") or die $!;
my $source = do { local $/; <$installer> };
close $installer;
my ($replacement) = $source =~ /(\$aptpackages =~ s\/\(\^\|\\s\)php-.*?;)/;
ok($replacement, 'PHP package substitution found');
my $aptpackages = 'php-gettext php-curl notphp-foo php8.4-cli';
my $phpversion = '8.4';
eval $replacement;
die $@ if $@;
is($aptpackages, 'php8.4-gettext php8.4-curl notphp-foo php8.4-cli',
	'Perl capture syntax preserves PHP package rewriting');
unlike(join('', @warnings), qr/better written as/,
	'PHP package substitution no longer emits capture syntax warnings');

done_testing();
