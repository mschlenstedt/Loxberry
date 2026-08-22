#!/usr/bin/perl
#
# libcompare.pl - Perl side of the Perl<->PHP library parity test.
#
# Emits one line per test case in the form:
#     @@<testname>@@<single-line-json>
#
# The companion PHP emitter (../../phplib/testing/libcompare.php) produces
# the identical set of testnames; libcompare_run.py runs both and compares
# the JSON per test case (with a few volatile keys ignored).
#
# The functions under test are the ones that were ported from the Perl
# master libs to the PHP libs:
#   System : bytes_humanreadable, systemloglevel, diskspaceinfo,
#            check_securepin, lock, unlock
#   Web    : iso_languages
#   Log    : get_notification_count, get_logs
#   IO     : mshttp_call2
#   Storage: get_netshares, get_netservers, get_usbstorage, get_storage
#
# Read-only where possible. check_securepin is called with a deliberately
# invalid PIN and the brute-force counter file is reset before/after so no
# lasting state remains. lock/unlock use a dedicated test lockfile name.

use strict;
use warnings;

BEGIN {
	my $home = $ENV{LBHOMEDIR} || '/opt/loxberry';
	unshift @INC, "$home/libs/perllib";
}

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use LoxBerry::IO;
use LoxBerry::Storage;
use JSON;

my $J = JSON->new->canonical(1)->allow_nonref(1);
my $HOME = $ENV{LBHOMEDIR} || '/opt/loxberry';
my $SECPIN_ERRFILE = "$HOME/log/system_tmpfs/securepin.errors";

sub emit {
	my ($name, $data) = @_;
	print "\@\@$name\@\@" . $J->encode($data) . "\n";
}

#############################################
# System::bytes_humanreadable
#############################################
{
	my @cases = (
		[0, ''], [1, ''], [1023, ''], [1024, ''], [1025, ''],
		[1048576, ''], [1500000, ''], [1073741824, ''],
		[137, 'K'], [1536, 'K'], [123124, 'K'],
		[2, 'M'], [2, 'G'], [1, 'T'], [0, 'K'],
	);
	my @res;
	foreach my $c (@cases) {
		push @res, LoxBerry::System::bytes_humanreadable($c->[0], $c->[1]);
	}
	emit('bytes_humanreadable', \@res);
}

#############################################
# System::systemloglevel
#############################################
emit('systemloglevel', { value => LoxBerry::System::systemloglevel() });

#############################################
# System::diskspaceinfo (single folder "/")
#############################################
{
	my %di = LoxBerry::System::diskspaceinfo("/");
	emit('diskspaceinfo_root', \%di);
}

#############################################
# Web::iso_languages
#############################################
{
	my @vals = LoxBerry::Web::iso_languages(0, 'values');
	emit('iso_languages_values', \@vals);
	my %labels = LoxBerry::Web::iso_languages(0, 'labels');
	emit('iso_languages_labels', \%labels);
	my @availvals = LoxBerry::Web::iso_languages(1, 'values');
	emit('iso_languages_values_avail', \@availvals);
}

#############################################
# Log::get_notification_count
#############################################
{
	my ($err, $ok, $sum) = LoxBerry::Log::get_notification_count();
	emit('get_notification_count', { count => [ defined $err ? $err+0 : undef,
	                                             defined $ok  ? $ok+0  : undef,
	                                             defined $sum ? $sum+0 : undef ] });
}

#############################################
# Log::get_logs (unfiltered)
#############################################
{
	my @logs = LoxBerry::Log::get_logs();
	emit('get_logs', \@logs);
}

#############################################
# IO::mshttp_call2 (Miniserver 1, harmless read command)
#############################################
{
	# Leading slash so FullURI (which may lack a trailing slash) + command
	# yields a well-formed URL on both sides (curl rejects a malformed one).
	my ($body, $ri) = LoxBerry::IO::mshttp_call2(1, "/jdev/cfg/version");
	emit('mshttp_call2_ms1', { responseinfo => $ri });
}

#############################################
# Storage::get_netservers / get_netshares / get_usbstorage / get_storage
#############################################
{
	my @servers = LoxBerry::Storage::get_netservers();
	emit('get_netservers', \@servers);

	my @shares = LoxBerry::Storage::get_netshares();
	emit('get_netshares', \@shares);

	my @usb = LoxBerry::Storage::get_usbstorage('');
	emit('get_usbstorage', \@usb);

	my @storage = LoxBerry::Storage::get_storage();
	emit('get_storage', \@storage);
}

#############################################
# System::check_securepin (invalid PIN, counter reset around the call)
#############################################
{
	unlink $SECPIN_ERRFILE if (-e $SECPIN_ERRFILE);
	my $r = LoxBerry::System::check_securepin("zzz_invalid_pin_zzz");
	emit('check_securepin_invalid', { result => defined $r ? $r+0 : undef });
	unlink $SECPIN_ERRFILE if (-e $SECPIN_ERRFILE);
}

#############################################
# System::lock / unlock (dedicated test lockfile)
#############################################
{
	LoxBerry::System::unlock(lockfile => 'libcompare_test');
	my $rlock   = LoxBerry::System::lock(lockfile => 'libcompare_test', wait => 0);
	my $runlock = LoxBerry::System::unlock(lockfile => 'libcompare_test');
	emit('lock_unlock', { lock => $rlock, unlock => $runlock });
}

#############################################
# Auth (pure functions)
#############################################
{
	require LoxBerry::Auth;

	my $auth_key  = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
	my $auth_apiv = "{'snr': 'AB:CD:EF:01:02:03', 'version':'17.1.7.3', 'hasEventSlots':true, "
	              . "'isInTrust':false, 'local':true,'certTLD':'com'}";

	emit('auth_norm_alg', [ map { LoxBerry::Auth::_norm_alg($_) }
	                        ('SHA256', 'sha-256', 'SHA1', '', 'MD5') ]);

	my $auth_pw256 = LoxBerry::Auth::_pw_hash('Test1234', '41B0A8F1', 'SHA256');
	my $auth_pw1   = LoxBerry::Auth::_pw_hash('Test1234', '41B0A8F1', 'SHA1');
	emit('auth_hashes', {
		pw_sha256    => $auth_pw256,
		pw_sha1      => $auth_pw1,
		auth_sha256  => LoxBerry::Auth::_auth_hash('loxberry', $auth_pw256, $auth_key, 'SHA256'),
		auth_sha1    => LoxBerry::Auth::_auth_hash('loxberry', $auth_pw1, $auth_key, 'SHA1'),
		token_sha256 => LoxBerry::Auth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $auth_key, 'SHA256'),
		token_sha1   => LoxBerry::Auth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $auth_key, 'SHA1'),
	});

	emit('auth_parse_api_value', LoxBerry::Auth::_parse_api_value($auth_apiv));

	emit('auth_fw_supported', [ map { LoxBerry::Auth::_fw_supported($_) }
	                            ('17.1.7.3', '11.2.10.22', '11.2.10.21', '11.2.9.99', '12.0', '') ]);

	emit('auth_rights_granted', [
		LoxBerry::Auth::_rights_granted(1924, 0x100),
		LoxBerry::Auth::_rights_granted(1924, 0x04),
		LoxBerry::Auth::_rights_granted(4,    0x100),
		LoxBerry::Auth::_rights_granted(1924, 0x104),
	]);

	emit('auth_ll_codes', [
		LoxBerry::Auth::_ll_code('{"LL":{"value":{},"code":"401"}}'),
		LoxBerry::Auth::_ll_code('{"LL":{"value":"x","Code":"200"}}'),
		LoxBerry::Auth::_ll_code('<html>401</html>'),
		LoxBerry::Auth::_effective_code(200, '{"LL":{"value":{},"code":"401"}}'),
		LoxBerry::Auth::_effective_code(200, '{"LL":{"value":"x","Code":"200"}}'),
		LoxBerry::Auth::_effective_code(401, '<html>401</html>'),
	]);

	emit('auth_constants', {
		default_perm      => $LoxBerry::Auth::DEFAULT_PERM,
		refresh_threshold => $LoxBerry::Auth::REFRESH_THRESHOLD,
		min_firmware      => $LoxBerry::Auth::MIN_FIRMWARE,
		perm_app          => $LoxBerry::Auth::PERM_APP,
		perm_sysws        => $LoxBerry::Auth::PERM_SYSWS,
	});

	my %auth_ms = LoxBerry::System::get_miniservers();
	emit('auth_ms_baseurl', $auth_ms{1} ? LoxBerry::Auth::_ms_baseurl($auth_ms{1}) : undef);
	emit('auth_auth_method_ms1', LoxBerry::Auth::auth_method(1));
}

exit 0;
