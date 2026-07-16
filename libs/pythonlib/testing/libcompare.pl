#!/usr/bin/perl
#
# libcompare.pl - Perl (master) side of the Perl <-> Python library parity test.
#
# Emits one line per test case in the form:
#     @@<testname>@@<single-line-json>
#
# The companion Python emitter (libcompare.py) produces the identical set of
# testnames from the ported Python libs; libcompare_run.py runs both and
# compares the JSON per test case.
#
# Only the functions ported to Python in the "Fundament" step are tested, and
# only deterministic (pure) or general.json-derived ones, so both sides yield
# identical output on a given host.

use strict;
use warnings;

BEGIN {
	my $home = $ENV{LBHOMEDIR} || '/opt/loxberry';
	unshift @INC, "$home/libs/perllib";
}

use LoxBerry::System;
use LoxBerry::Web;
use JSON;

my $J = JSON->new->canonical(1)->allow_nonref(1);
my $HOME = $ENV{LBHOMEDIR} || '/opt/loxberry';

sub emit {
	my ($name, $data) = @_;
	print "\@\@$name\@\@" . $J->encode($data) . "\n";
}

# --- bytes_humanreadable ---
{
	my @cases = (
		[0, ''], [1, ''], [1023, ''], [1024, ''], [1025, ''],
		[1048576, ''], [1500000, ''], [1073741824, ''],
		[137, 'K'], [1536, 'K'], [123124, 'K'],
		[2, 'M'], [2, 'G'], [1, 'T'], [0, 'K'],
	);
	my @res = map { LoxBerry::System::bytes_humanreadable($_->[0], $_->[1]) } @cases;
	emit('bytes_humanreadable', \@res);
}

# --- is_enabled / is_disabled ---
{
	my @inputs = ('true', 'YES', ' on ', 'Enabled', '1', 'check', 'selected',
	              'false', '0', '', 'no', 'random');
	emit('is_enabled',  [ map { LoxBerry::System::is_enabled($_)  } @inputs ]);
	emit('is_disabled', [ map { LoxBerry::System::is_disabled($_) } @inputs ]);
}

# --- trim / ltrim / rtrim ---
{
	my @inputs = ("  hello  ", "\tx\n", "nospace", "   ", " a b ");
	emit('trim',  [ map { LoxBerry::System::trim($_)  } @inputs ]);
	emit('ltrim', [ map { LoxBerry::System::ltrim($_) } @inputs ]);
	emit('rtrim', [ map { LoxBerry::System::rtrim($_) } @inputs ]);
}

# --- vers_tag ---
{
	my @cases = ( ['1.2.3', 0], ['v1.2.3', 0], ['1.2.3', 1],
	              ['v1.2.3', 1], ['  V2.0  ', 0] );
	emit('vers_tag', [ map { LoxBerry::System::vers_tag($_->[0], $_->[1]) } @cases ]);
}

# --- plugin_version_compare ---
{
	my @pairs = (
		['1.2.3', '1.2.4'], ['1.2.3', '1.2.3'], ['1.2.4', '1.2.3'],
		['1.2.0', '1.2.0-beta'], ['1.2.0-beta', '1.2.0'],
		['1.2.0-alpha', '1.2.0-beta'], ['1.2.0-1', '1.2.0-2'],
		['4.0.0.14', '4.0.0.13'], ['4.0.0.2', '4.0.0.10'],
		['v4.0.0.1', '4.0.0.1'], ['1.0', '1.0.0'], ['abc', '1.0'],
	);
	emit('plugin_version_compare',
		[ map { LoxBerry::System::plugin_version_compare($_->[0], $_->[1]) } @pairs ]);
}

# --- plugin_version_has_prerelease ---
{
	my @inputs = ('1.2.0', '1.2.0-beta', '4.0.0.14', '', 'v2.0.0-rc.1');
	emit('plugin_version_has_prerelease',
		[ map { LoxBerry::System::plugin_version_has_prerelease($_) } @inputs ]);
}

# --- epoch2lox / lox2epoch (host timezone) ---
emit('epoch2lox_fixed', { value => LoxBerry::System::epoch2lox(1600000000) });
emit('lox2epoch_fixed', { value => LoxBerry::System::lox2epoch(400000000) });

# --- general.json-derived accessors ---
emit('systemloglevel',  { value => LoxBerry::System::systemloglevel() });
emit('lbversion',       { value => LoxBerry::System::lbversion() });
emit('lbfriendlyname',  { value => LoxBerry::System::lbfriendlyname() });
emit('lbwebserverport', { value => LoxBerry::System::lbwebserverport() });
emit('lblanguage',      { value => LoxBerry::System::lblanguage() });
emit('lbcountry',       { value => LoxBerry::System::lbcountry() });

{
	my %ms = LoxBerry::System::get_miniservers();
	emit('get_miniservers', \%ms);
}

# --- get_binaries ---
emit('get_binaries', LoxBerry::System::get_binaries());

# --- diskspaceinfo (single folder "/") ---
{
	my %di = LoxBerry::System::diskspaceinfo("/");
	emit('diskspaceinfo_root', \%di);
}

# --- get_plugins ---
{
	my @plugins = LoxBerry::System::get_plugins();
	emit('get_plugins', \@plugins);
}

# --- pluginversion / pluginloglevel of the first plugin (by folder) ---
{
	my @plugins = LoxBerry::System::get_plugins();
	my $folder = @plugins ? $plugins[0]->{PLUGINDB_FOLDER} : '';
	emit('pluginversion_named',  { folder => $folder, version  => LoxBerry::System::pluginversion($folder) });
	emit('pluginloglevel_named', { folder => $folder, loglevel => LoxBerry::System::pluginloglevel($folder) });
}

# --- check_securepin (invalid PIN, counter reset around the call) ---
{
	my $errfile = "$HOME/log/system_tmpfs/securepin.errors";
	unlink $errfile if (-e $errfile);
	my $r = LoxBerry::System::check_securepin("zzz_invalid_pin_zzz");
	emit('check_securepin_invalid', { result => defined $r ? $r+0 : undef });
	unlink $errfile if (-e $errfile);
}

# --- lock / unlock (dedicated test lockfile) ---
{
	LoxBerry::System::unlock(lockfile => 'libcompare_py_test');
	my $rlock   = LoxBerry::System::lock(lockfile => 'libcompare_py_test', wait => 0);
	my $runlock = LoxBerry::System::unlock(lockfile => 'libcompare_py_test');
	emit('lock_unlock', { lock => $rlock, unlock => $runlock });
}

# --- Web::iso_languages ---
{
	my @vals = LoxBerry::Web::iso_languages(0, 'values');
	emit('iso_languages_values', \@vals);
	my %labels = LoxBerry::Web::iso_languages(0, 'labels');
	emit('iso_languages_labels', \%labels);
	my @availvals = LoxBerry::Web::iso_languages(1, 'values');
	emit('iso_languages_values_avail', \@availvals);
}

exit 0;
