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

exit 0;
