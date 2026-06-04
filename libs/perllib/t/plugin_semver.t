#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

BEGIN {
	$ENV{LBHOMEDIR} ||= '/tmp/loxberry_pm_test_home';
}

# LoxBerry/ lives beside t/ under libs/perllib/
use lib File::Spec->catdir( $FindBin::Bin, '..' );
use LoxBerry::System qw(plugin_version_compare plugin_version_has_prerelease);

# Mirrors release vs prerelease pick in sbin/pluginsupdate.pl (sticky when installed is SemVer prerelease).
sub _pick_channel_like_pluginsupdate {
	my ($currentver_raw, $rel_verstr, $pre_verstr) = @_;

	my $rel_ok =
		defined($rel_verstr)
		&& defined( plugin_version_compare( $rel_verstr, $rel_verstr ) );
	my $pre_ok =
		defined($pre_verstr)
		&& defined( plugin_version_compare( $pre_verstr, $pre_verstr ) );

	my $cmp_rel =
		$rel_ok ? plugin_version_compare( $rel_verstr, $currentver_raw ) : undef;
	my $cmp_pre =
		$pre_ok ? plugin_version_compare( $pre_verstr, $currentver_raw ) : undef;

	my $rel_gt = ( defined($cmp_rel) && $cmp_rel == 1 );
	my $pre_gt = ( defined($cmp_pre) && $cmp_pre == 1 );

	return undef unless $rel_gt || $pre_gt;

	if ( $rel_gt && $pre_gt && plugin_version_has_prerelease($currentver_raw) ) {
		return 'prerelease';
	}
	if ( $rel_gt && $pre_gt ) {
		return 'release';
	}
	return 'release' if $rel_gt;
	return 'prerelease';
}

# shorthand for readable matrices
sub _cmp {
	plugin_version_compare( $_[0], $_[1] );
}

plan tests => 56;

is(
	plugin_version_compare( '1.4.1', '1.4.1-beta.3' ),
	1,
	'release newer than prerelease (same core)'
);
is(
	plugin_version_compare( '1.4.1-beta.3', '1.4.1' ),
	-1,
	'prerelease older than release'
);
is(
	plugin_version_compare( '1.4.1-beta.2', '1.4.1-beta.1' ),
	1,
	'prerelease dot ordering'
);
is(
	plugin_version_compare( '1.4.1-rc.1', '1.4.1-beta.2' ),
	1,
	'RC vs beta (identifier ASCII rule)'
);
is( plugin_version_compare( '1.4.1', '1.4.1' ), 0, 'equal release' );
is(
	plugin_version_compare( '1.4.1-alpha.1', '1.4.1-alpha.1' ),
	0,
	'equal prerelease'
);
is(
	plugin_version_compare( 'v1.4.1', '1.4.1' ),
	0,
	'optional v prefix normalized'
);
is(
	plugin_version_compare( '1.4.1+build.x', '1.4.1-beta' ),
	1,
	'build metadata ignored'
);

ok( plugin_version_has_prerelease('1.4.1-beta.1'), 'has_prerelease semver' );
ok( !plugin_version_has_prerelease('1.4.1'), 'stable has no prerelease' );
ok(
	!plugin_version_has_prerelease('1.2.3.4'),
	'quad not classic SemVer shape for flag'
);

is(
	plugin_version_compare( '1.0.0-alpha', '1.0.0-alpha.1' ),
	-1,
	'shorter prerelease identifiers lower precedence'
);
is(
	plugin_version_compare( '1.0.0-1', '1.0.0-2' ),
	-1,
	'numeric prerelease identifiers'
);

SKIP: {
	my $legacy_ok = defined( plugin_version_compare( 'v1.1', 'v1.1.1' ) );
	skip 'lax version.pm fallback unavailable in this perl', 1 if !$legacy_ok;
	is(
		plugin_version_compare( 'v1.1', 'v1.1.1' ),
		-1,
		'legacy lax: v1.1 < v1.1.1'
	);
}

ok(
	!defined( plugin_version_compare( '%%%invalid', '%%%bad' ) ),
	'mutually invalid => undef'
);

#
# pluginsupdate-style channel decision (sticky prerelease)
#

is(
	_pick_channel_like_pluginsupdate( '1.4.1-beta.1', '2.0.0',
		'1.5.0-beta.2' ),
	'prerelease',
	'pick: both newer + installed is prerelease -> sticky prerelease channel'
);

is(
	_pick_channel_like_pluginsupdate( '1.4.9', '2.0.0', '1.5.0-beta.1' ),
	'release',
	'pick: both newer + installed stable -> prefer release channel'
);

is(
	_pick_channel_like_pluginsupdate( '1.0.0', '1.0.1', undef ),
	'release',
	'pick: only release channel beats current'
);

is(
	_pick_channel_like_pluginsupdate( '1.0.0', undef, '1.0.1-beta.5' ),
	'prerelease',
	'pick: only prerelease channel beats current'
);

is(
	_pick_channel_like_pluginsupdate( '1.0.0', undef, '1.0.0-rc.88' ),
	undef,
	'pick: prerelease line still older than installed stable same X.Y.Z'
);

is(
	_pick_channel_like_pluginsupdate( '2.5.3', '1.99.99', '1.98.99-beta' ),
	undef,
	'pick: no bump when upstream behind current'
);

#
# Ordering edge cases exercised by pluginsupdate compare calls
#

is(
	plugin_version_compare( '1.9.99', '2.0.0-alpha' ),
	-1,
	'last 1.x below first 2.0 prerelease'
);

is(
	plugin_version_compare( '1.0.0-alpha.1', '1.0.0-alpha.beta' ),
	-1,
	'numeric prerelease id loses to alphabetic id (SemVer #11)'
);

is( plugin_version_compare( '10.0.0', '2.0.0' ), 1,
	'major numerically 10 > 2' );

foreach my $triple (
	[ '1.4.1',           '1.4.1-beta.3',  'stable vs pre same core' ],
	[ '1.0.0-rc.10',     '1.0.0-rc.11',   'incremental prereleases' ],
	[ '99.255.65535-rc', '99.255.65535',  'rc below same release triple' ]
	)
{
	my ( $lhs, $rhs, $descr ) = @$triple;

	my $ab = plugin_version_compare( $lhs, $rhs );
	my $ba = plugin_version_compare( $rhs, $lhs );
	SKIP: {
		skip "$descr incomparable either way", 1
			if !( defined($ab) && defined($ba) );
		is( $ba, -$ab, "antisymm: $descr" );
	}
}

#
# Stage 1: dense compare matrix (pure SemVer + lax edge spot checks)
#

is(
	_cmp( '1.4.11', '1.4.12' ),
	-1,
	'matrix compare: PATCH within same MINOR'
);
is(
	_cmp( '1.99.998', '99.998.997' ),
	-1,
	'matrix compare: MAJOR dominates large digit triples'
);
is(
	_cmp( '0.0.555', '42.4242.4242' ),
	-1,
	'matrix compare: leap from tiny 0.x to large MAJOR line'
);
is(
	_cmp( '1.0.55', '10.55.56' ),
	-1,
	'matrix compare: MAJOR numeric order (never string collation)'
);

is(
	_cmp( '1.8.333-beta.900', '2.11.444-alpha.1' ),
	-1,
	'matrix compare: older triple beta loses vs newer triple alpha across MAJOR'
);

is(
	_cmp( '3.1415.927', '10.71828.281' ),
	-1,
	'matrix compare: multi-digit PATCH as integers'
);

is(
	_cmp( '1.0.0-beta.11', '1.0.1-beta.9' ),
	-1,
	'matrix compare: patched release beats ornate prerelease on prior PATCH'
);

is(
	_cmp( '1.0.0-x', '1.0.1-x.y' ),
	-1,
	'matrix compare: older PATCH + short tag loses to PATCH bump + richer tag'
);

is(
	_cmp( '81.928.848', 'V81.928.848' ),
	0,
	'matrix compare: leading-V case normalisation (SemVer lane)'
);

is(
	_cmp( '2.71828.271+metal', 'v2.71828.271+wood' ),
	0,
	'matrix compare: build metadata stripped; equal cores'
);

ok(
	plugin_version_has_prerelease('1.0.0-0'),
	'matrix has_prerelease: numeric-only prerelease id 0 counts'
);

ok(
	plugin_version_has_prerelease('2.71828.182-alpha.dev.4242-rc0'),
	'matrix has_prerelease: long dotted prerelease'
);

SKIP: {
	skip 'lax single-digit tuple unsupported on this perl', 2
		unless defined( _cmp( '1', '11' ) );
	is(
		_cmp( '1', '11' ),
		-1,
		'matrix lax: tiny tuple ordering when fallback defined'
	);
	is( _cmp( '11', '1' ), 1,
		'matrix lax antisym on tiny tuple baseline' );
}

#
# Stage 1: pick-policy matrix (broken cfg strings only drop that channel)
#

is(
	_pick_channel_like_pluginsupdate(
		'1.0.0-alpha.4242', '!not-a-real-version-rel!', '2.0.0-rc.881'
	),
	'prerelease',
	'matrix pick: invalid release VERSION self-compare -> prerelease wins alone'
);

is(
	_pick_channel_like_pluginsupdate( '314.314.314', '!bad-rel!', '628.627.997' ),
	'prerelease',
	'matrix pick: only prerelease survives broken release VERSION'
);

is(
	_pick_channel_like_pluginsupdate(
		'3.4.99', '314.628.981', '!bad-pre!'
	),
	'release',
	'matrix pick: invalid prerelease VERSION -> release-only update'
);

is(
	_pick_channel_like_pluginsupdate(
		'314.717.716', '500.716.716', '500.716.716-beta.joy'
	),
	'release',
	'matrix pick: installed stable prefers release when BOTH channels advertise newer versions'
);

is(
	_pick_channel_like_pluginsupdate(
		'6.717.717-rc.omega', '7.716.716',
		'6.717.777-alpha.gamma'
	),
	'prerelease',
	'matrix pick: prerelease-installed sticky survives massive stable jump'
);

is(
	_pick_channel_like_pluginsupdate( '314.716.716', '!bad-rel!', '!bad-pre!' ),
	undef,
	'matrix pick: no update possible when BOTH channel VERSION strings refuse comparison'
);

#
# Stage 1: semver transitivity sanity (manual legs + combined)
#

is(
	_cmp( '1.0.1', '62.831.853' ),
	-1,
	'matrix transit leg A toward large MAJOR'
);

is(
	_cmp( '62.831.853', '993.983.743' ),
	-1,
	'matrix transit leg B second jump'
);

is(
	_cmp( '1.0.1', '993.983.743' ),
	-1,
	'matrix transit: direct ordering matches chaining intuition'
);

#
# v-prefix, case fold, leading zeros (common real-world cfg noise)
# Note: SemVer forbids some leading-zero forms; we coerce numerics for plugin compatibility.
#

is(
	_cmp( '01.02.03', 'v1.2.3' ),
	0,
	'leading-zero MAJOR.MINOR.PATCH vs v-tag (numeric coercion)'
);

is(
	_cmp( '080.088.089', 'V80.88.89' ),
	0,
	'leading zeros + mixed V/v on equal cores'
);

is(
	_cmp( '1.0.0-rc.01', 'v1.0.0-rc.1' ),
	0,
	'prerelease numeric ids: leading zeros compare as integers'
);

is(
	_cmp( 'v3.0.0', '2.99.99' ),
	1,
	'v-prefixed left side still orders by SemVer core'
);

is(
	_cmp( 'V2.7.1-BETA.1', 'v2.7.1-beta.1' ),
	0,
	'case fold: full version string lowercased before compare (with vers_tag-style v)'
);

is(
	_cmp( '01.0.0', '1.0.0-alpha' ),
	1,
	'zero-padded stable core still ranks above prerelease of same logical release'
);

