#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir);
use Fcntl qw(:flock);

BEGIN {
	$ENV{LBHOMEDIR} ||= '/tmp/loxberry_pm_test_home';
}

# LoxBerry/ lives beside t/ under libs/perllib/
use lib File::Spec->catdir( $FindBin::Bin, '..' );
use LoxBerry::JSON;

my $dir = tempdir( CLEANUP => 1 );

sub slurp {
	my $f = shift;
	open my $fh, '<', $f or return undef;
	local $/;
	return <$fh>;
}

#
# Round-trip: create, read back, update, shrink (no trailing garbage)
#
{
	my $f = File::Spec->catfile( $dir, 'roundtrip.json' );

	my $j1 = LoxBerry::JSON->new;
	my $o1 = $j1->open( filename => $f );
	$o1->{hello} = 'welt';
	$o1->{zahl}  = 42;
	ok( $j1->write(), 'write() creates and writes a new file' );

	my $o2 = LoxBerry::JSON->new->open( filename => $f, readonly => 1 );
	is( $o2->{hello}, 'welt', 'value read back after create' );
	is( $o2->{zahl},  42,     'second value read back' );

	my $j3 = LoxBerry::JSON->new;
	my $o3 = $j3->open( filename => $f );
	$o3->{zahl} = 99;
	$j3->write();
	is( LoxBerry::JSON->new->open( filename => $f, readonly => 1 )->{zahl},
		99, 'existing value updated' );

	# Write strictly less content than before -> must not leave old bytes behind.
	my $j4 = LoxBerry::JSON->new;
	my $o4 = $j4->open( filename => $f );
	delete $o4->{hello};
	delete $o4->{zahl};
	$o4->{x} = 1;
	$j4->write();
	my $o5 = LoxBerry::JSON->new->open( filename => $f, readonly => 1 );
	ok( !exists $o5->{hello}, 'shrunk file: stale key gone (truncated correctly)' );
	is( $o5->{x}, 1, 'shrunk file: new content intact' );
}

#
# writeonclose and lockexclusive branches still work
#
{
	my $f = File::Spec->catfile( $dir, 'branches.json' );
	{
		my $j = LoxBerry::JSON->new;
		my $o = $j->open( filename => $f, writeonclose => 1 );
		$o->{woc} = 'ja';
	}
	is( LoxBerry::JSON->new->open( filename => $f, readonly => 1 )->{woc},
		'ja', 'writeonclose flushes on destroy' );

	{
		# Scope the exclusive handle so its LOCK_EX is released before we read
		# the file back below (a blocking readonly open in the same process would
		# otherwise deadlock against our own still-held exclusive lock).
		my $j = LoxBerry::JSON->new;
		my $o = $j->open( filename => $f, lockexclusive => 1 );
		$o->{lx} = 7;
		ok( $j->write(), 'lockexclusive branch writes' );
	}
	is( LoxBerry::JSON->new->open( filename => $f, readonly => 1 )->{lx},
		7, 'lockexclusive value read back' );
}

#
# Core regression: a competing writer holds the lock.
# write() must (a) NOT hang, and (b) NOT empty the file.
# Guarded by alarm() so a reintroduced infinite loop fails the test loudly
# instead of hanging the suite.
#
{
	my $f = File::Spec->catfile( $dir, 'contended.json' );

	# Seed a known payload through the module itself.
	my $seed = LoxBerry::JSON->new;
	my $so   = $seed->open( filename => $f );
	$so->{keep} = 'MUST SURVIVE';
	$seed->write();
	my $before = slurp($f);
	cmp_ok( length($before), '>', 0, 'seed file has content' );

	# Open first (the non-exclusive open lock is released on return), THEN a
	# separate handle grabs LOCK_EX, THEN we try to write.
	my $j = LoxBerry::JSON->new;
	my $o = $j->open( filename => $f, locktimeout => 1 );
	$o->{added} = 'x';

	open my $guard, '+<', $f or die "guard open: $!";
	ok( flock( $guard, LOCK_EX ), 'competing process holds the exclusive lock' );

	my $returned;
	my $hung = 0;
	eval {
		local $SIG{ALRM} = sub { die "TIMEOUT\n" };
		alarm 15;
		$returned = $j->write();
		alarm 0;
		1;
	} or do {
		alarm 0;
		$hung = 1 if $@ eq "TIMEOUT\n";
	};

	ok( !$hung, 'write() does not hang when the lock is held (no infinite loop)' );
	ok( !$returned, 'write() reports failure instead of claiming success' );

	my $after = slurp($f);
	cmp_ok( length($after), '>', 0, 'file is NOT truncated to 0 bytes on lock failure' );
	is( $after, $before, 'file content is left completely intact' );

	flock( $guard, LOCK_UN );
	close $guard;
}

done_testing();
