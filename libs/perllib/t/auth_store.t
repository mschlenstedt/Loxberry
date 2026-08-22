#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw( tempdir );
use JSON;

use lib File::Spec->catdir( $FindBin::Bin, '..' );
use LoxBerry::Auth;

my $dir = tempdir( CLEANUP => 1 );
$LoxBerry::Auth::store_file = "$dir/tokens.json";

sub slurp {
	my ($file) = @_;
	open( my $fh, '<', $file ) or die "cannot read $file: $!";
	local $/;
	my $content = <$fh>;
	close($fh);
	return $content;
}

is( LoxBerry::Auth::_store_file(), "$dir/tokens.json", 'store_file folgt dem Testhaken' );

# --- Lesen ohne Datei ------------------------------------------------------
my $empty = LoxBerry::Auth::_store_read();
is_deeply( $empty, {}, 'fehlende Datei liefert leeren Hashref' );
ok( ! -e "$dir/tokens.json", 'Lesen legt die Datei nicht an' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry'), undef,
    'get_token auf leerem Bestand ist undef' );

# --- Schreiben -------------------------------------------------------------
my %msmeta = (
	msnr          => 1,
	name          => 'Miniserver',
	is_lbsystem   => JSON::true,
	lbsystem_user => 'loxberry',
	firmware      => '17.1.7.3',
	checked       => 556606212,
);
my %tok = (
	token      => 'abc123',
	validUntil => 564559554,
	rights     => 1924,
	perm       => 260,
	acquired   => 556606212,
	info       => 'LoxBerry testhost',
);
is( LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry', \%msmeta, \%tok), 1,
    'erstes put schreibt' );
ok( -e "$dir/tokens.json", 'Datei wurde angelegt' );

my $mode = (stat("$dir/tokens.json"))[2] & 07777;
is( $mode, 0600, 'Datei hat Rechte 0600' );

my $got = LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry');
is( $got->{token},      'abc123',   'Token gelesen' );
is( $got->{validUntil}, 564559554,  'validUntil gelesen' );
is( $got->{rights},     1924,       'rights gelesen' );

# Struktur wie in der Spec
my $raw = JSON::from_json( slurp("$dir/tokens.json") );
is( $raw->{'AB:CD:EF:01:02:03'}{name},          'Miniserver', 'Miniserver-Metadaten auf oberster Ebene' );
is( $raw->{'AB:CD:EF:01:02:03'}{firmware},      '17.1.7.3',   'firmware gespeichert' );
is( $raw->{'AB:CD:EF:01:02:03'}{lbsystem_user}, 'loxberry',   'lbsystem_user gespeichert' );
ok( exists $raw->{'AB:CD:EF:01:02:03'}{users}{loxberry},      'Benutzer unter users' );
ok( ! exists $raw->{'AB:CD:EF:01:02:03'}{users}{loxberry}{password}, 'kein Passwort im Bestand' );
ok( ! exists $raw->{'AB:CD:EF:01:02:03'}{users}{loxberry}{key},      'kein Einmalschluessel im Bestand' );

# --- Nur bei echter Aenderung schreiben ------------------------------------
my $mtime_before = (stat("$dir/tokens.json"))[9];
sleep 1;
is( LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry', \%msmeta, \%tok), 0,
    'unveraendertes put schreibt nicht' );
is( (stat("$dir/tokens.json"))[9], $mtime_before, 'mtime unveraendert - die SD-Karte bleibt verschont' );

my %tok2 = (%tok, token => 'def456');
is( LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry', \%msmeta, \%tok2), 1,
    'geaendertes put schreibt' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry')->{token}, 'def456',
    'neuer Token gelesen' );

# --- Zweiter Benutzer, zweiter Miniserver ----------------------------------
LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'sortmgr', \%msmeta, \%tok);
LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:04', 'loxberry',
	{ msnr => 2, name => 'MS2', is_lbsystem => JSON::false, firmware => '15.0.0.1', checked => 1 },
	\%tok );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'sortmgr')->{token},  'abc123', 'zweiter Benutzer' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry')->{token}, 'def456', 'erster Benutzer unberuehrt' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:04', 'loxberry')->{token}, 'abc123', 'zweiter Miniserver' );

# --- Loeschen --------------------------------------------------------------
is( LoxBerry::Auth::_store_del_token('AB:CD:EF:01:02:03', 'sortmgr'), 1, 'del schreibt' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'sortmgr'), undef, 'Eintrag ist weg' );
is( LoxBerry::Auth::_store_del_token('AB:CD:EF:01:02:03', 'sortmgr'), 0, 'zweites del schreibt nicht' );

# --- _store_update sieht den gesamten Bestand ------------------------------
my $seen;
LoxBerry::Auth::_store_update( sub {
	my ($data) = @_;
	$seen = [ sort keys %$data ];
	return;
} );
is_deeply( $seen, [ 'AB:CD:EF:01:02:03', 'AB:CD:EF:01:02:04' ], 'update sieht beide Miniserver' );

# --- Kaputte Datei bringt nichts zum Absturz -------------------------------
open( my $fh, '>', "$dir/tokens.json" ) or die;
print $fh "{ das ist kein json";
close($fh);
is_deeply( LoxBerry::Auth::_store_read(), {}, 'unlesbare Datei liefert leeren Hashref' );

# --- Prozess-Cache ---------------------------------------------------------
LoxBerry::Auth::_cache_clear();
LoxBerry::Auth::_store_put_token('AA:BB:CC:DD:EE:FF', 'cacheuser',
	{ msnr => 1 }, { token => 'cached1', validUntil => 5, rights => 1924 } );

# Datei unter dem Prozess wegziehen - der Cache muss weiter antworten
unlink("$dir/tokens.json");
is( LoxBerry::Auth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser')->{token}, 'cached1',
    'get_token bedient sich aus dem Prozess-Cache, ohne die Datei zu lesen' );

# nach _cache_clear ist die Information weg, weil auch die Datei weg ist
LoxBerry::Auth::_cache_clear();
is( LoxBerry::Auth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser'), undef,
    'ohne Cache und ohne Datei ist nichts mehr da' );

# ein Schreibvorgang aktualisiert den Cache mit
LoxBerry::Auth::_store_put_token('AA:BB:CC:DD:EE:FF', 'cacheuser',
	{ msnr => 1 }, { token => 'cached2', validUntil => 5, rights => 1924 } );
is( LoxBerry::Auth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser')->{token}, 'cached2',
    'put aktualisiert den Cache' );

# und ein Loeschen raeumt ihn
LoxBerry::Auth::_store_del_token('AA:BB:CC:DD:EE:FF', 'cacheuser');
is( LoxBerry::Auth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser'), undef,
    'del raeumt den Cache mit' );

done_testing();
