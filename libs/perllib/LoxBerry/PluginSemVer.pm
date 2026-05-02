# Lightweight SemVer 2 comparisons for plugin AUTOUPDATE/version strings,
# compatible with hyphenated prerelease labels (e.g. 1.4.1-beta.2).
#
# Fallback: Perl "lax" version objects (version.pm) when strings do not
# match SemVer normalization used here — keeps older plugin versions working.

package LoxBerry::PluginSemVer;

use strict;
use warnings;

use version;

use base 'Exporter';
our @EXPORT_OK = qw( cmp_versions has_prerelease parse_semver_trim version_defined comparable );

##########################################################################
sub trim {
	my ($s) = @_;
	return '' unless defined $s;
	for ($s) {
		s/^\s+//;
		s/\s+$//;
	}
	return $s;
}

sub _strip_v_prefix {
	my ($s) = @_;
	$s =~ s/^v//i;
	return $s;
}

# Remove SemVer build metadata (+...) for precedence comparison only.
sub _strip_build_meta {
	my ($s) = @_;
	return $s unless defined $s && $s ne '';
	$s =~ s/\+[^+]*\z//;
	return $s;
}

sub version_defined {
	my ($raw) = @_;
	return 0 unless defined $raw;
	return trim($raw) ne '' ? 1 : 0;
}

# Returns normalized string without leading "v"/whitespace/build metadata when parseable as SemVer.
sub parse_semver_trim {
	my ($raw) = @_;
	my $t = trim($raw);
	$t =~ s/^v//i;
	$t = _strip_build_meta($t);
	return undef if $t eq '';
	return undef unless _parse_semver($t);
	return $t;
}

# SemVer BASE X.Y.Z; patch optional (defaults to 0); optional prerelease after '-'.
sub _parse_semver {
	my ($s) = @_;
	if (
		$s =~ /\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\z/
	  )
	{
		return {
			core       => [ int $1, int $2, int $3 ],
			prerelease => defined $4 ? lc $4 : undef
		};
	}
	if ( $s =~ /\A(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\z/ ) {
		return {
			core       => [ int $1, int $2, 0 ],
			prerelease => defined $3 ? lc $3 : undef
		};
	}
	return undef;
}

##########################################################################
sub _cmp_prerelease_str {
	my ( $apa, $apb ) = @_;

	my $nea = !( defined $apa && $apa ne '' );
	my $neb = !( defined $apb && $apb ne '' );
	return 0  if $nea && $neb;
	return 1  if !$nea && $neb;
	return -1 if $nea && !$neb;

	my @sa = split /\./, $apa;
	my @sb = split /\./, $apb;
	my $nlen = @sa > @sb ? scalar @sa : scalar @sb;
	for my $k ( 0 .. $nlen - 1 ) {
		my $ea = $k <= $#sa;
		my $eb = $k <= $#sb;
		return -1 unless $ea;
		return 1  unless $eb;

		my $xa = $sa[$k];
		my $xb = $sb[$k];
		my $nad = $xa =~ /^\d+\z/ ? 1 : 0;
		my $nbd = $xb =~ /^\d+\z/ ? 1 : 0;
		if ( $nad && $nbd ) {
			my $c = int($xa) <=> int($xb);
			return $c if $c;
			next;
		}
		elsif ( $nad xor $nbd ) {
			return $nad ? -1 : 1;    # numeric id < non-numeric
		}
		else {
			my $c = $xa cmp $xb;
			return $c if $c;
			next;
		}
	}
	return 0;
}

sub _cmp_semver_hashes {
	my ( $pa, $pb ) = @_;
	for my $k ( 0 .. 2 ) {
		my $c = int( $pa->{core}->[$k] ) <=> int( $pb->{core}->[$k] );
		return $c if $c;
	}
	return _cmp_prerelease_str( $pa->{prerelease}, $pb->{prerelease} );
}

##########################################################################
sub has_prerelease {
	my ($raw) = @_;
	my $t = parse_semver_trim($raw);
	return 0 unless defined $t;
	my $parsed = _parse_semver($t);
	return 0 unless $parsed;
	return ( defined $parsed->{prerelease} && $parsed->{prerelease} ne '' ) ? 1 : 0;
}

sub _can_use_perl_version {
	my ($tb) = @_;
	return undef if !defined $tb || $tb eq '';
	my $slug = trim($tb);
	$slug = "v$slug" if substr( $slug, 0, 1 ) ne 'v';
	return undef unless version::is_lax($slug);
	return $slug;
}

# Returns -1 (a<b), 0 (equal), +1 (a>b).
# Fallback: perl version lax compare only when BOTH strings accept version.pm parsing.
sub cmp_versions {
	my ( $astra, $bstr ) = @_;

	return 0 if !defined $astra || !defined $bstr;

	my $ta = _strip_build_meta( _strip_v_prefix( trim($astra) ) );
	my $tb = _strip_build_meta( _strip_v_prefix( trim($bstr) ) );
	return -1 if $ta eq '';
	return 1 if $tb eq '';

	my $psa = _parse_semver($ta);
	my $psb = _parse_semver($tb);
	if ($psa && $psb) {
		return _cmp_semver_hashes( $psa, $psb );
	}

	my $la = _can_use_perl_version($ta);
	my $lb = _can_use_perl_version($tb);

	if ( defined $la && defined $lb ) {
		my $vga = eval { version->parse($la) };
		my $vgb = eval { version->parse($lb) };
		if ($vga && $vgb) {
			return $vga <=> $vgb;
		}
	}

	return 0;
}

# True when Version string compares with cmp_versions (-1,+1 acceptable)
sub comparable {
	my ($v) = @_;
	return 0 unless version_defined($v);
	my $tb = trim($v);
	my $psa = _parse_semver(
		_strip_build_meta( _strip_v_prefix($tb) ) );
	return 1 if $psa;

	my $slug = trim($tb);
	$slug = "v$slug" if substr( $slug, 0, 1 ) ne 'v';
	return version::is_lax($slug) ? 1 : 0;
}

1;
