#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

use_ok 'LoxBerry::PluginSemVer' or BAIL_OUT('cannot load PluginSemVer');

ok( LoxBerry::PluginSemVer->can('cmp_versions'),    'cmp_versions available' );
ok( LoxBerry::PluginSemVer->can('has_prerelease'),  'has_prerelease available' );
ok( LoxBerry::PluginSemVer->can('comparable'),      'comparable available' );

my $cmp = \&LoxBerry::PluginSemVer::cmp_versions;

is( $cmp->( '1.4.1-beta.2', '1.4.1-beta.4' ), -1, 'beta.2 older than beta.4' );
is( $cmp->( '1.4.1-beta.4', '1.4.1-beta.2' ),  1, 'beta.4 newer than beta.2' );
is( $cmp->( '1.4.1',        '1.4.1-beta.4' ),  1, 'release newer than prerelease (same BASE)' );
is( $cmp->( '1.4.1-beta.4', '1.4.1' ),        -1, 'prerelease older than release' );

ok( LoxBerry::PluginSemVer::comparable('1.4.1-beta.2'), 'semver prerelease comparable' );
ok( LoxBerry::PluginSemVer::has_prerelease('1.4.1-beta.2'), 'detect prerelease suffix' );

done_testing();
