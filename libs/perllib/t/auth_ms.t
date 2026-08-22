#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use File::Path qw( make_path );

my $home;
BEGIN {
	# LoxBerry::System liest LBHOMEDIR beim Laden - daher hier, vor dem use
	require File::Temp;
	$home = File::Temp::tempdir( CLEANUP => 1 );
	$ENV{LBHOMEDIR} = $home;
}

make_path("$home/config/system");
make_path("$home/data/system");

open( my $gfh, '>', "$home/config/system/general.json" ) or die $!;
print $gfh <<'GENERALJSON';
{
  "Base": { "Lang": "de", "Version": "4.0.0.15" },
  "Miniserver": {
    "1": {
      "Name": "Miniserver", "Ipaddress": "192.0.2.10",
      "Admin": "loxberry", "Pass": "TestPass%2123",
      "Credentials": "loxberry:TestPass%2123",
      "Admin_raw": "loxberry", "Pass_raw": "TestPass!23",
      "Credentials_raw": "loxberry:TestPass!23",
      "Port": 80, "Porthttps": 443, "Preferhttps": 0
    },
    "2": {
      "Name": "MS Secure", "Ipaddress": "192.0.2.11",
      "Admin": "admin", "Pass": "secret",
      "Credentials": "admin:secret",
      "Admin_raw": "admin", "Pass_raw": "secret",
      "Credentials_raw": "admin:secret",
      "Port": 80, "Porthttps": 4443, "Preferhttps": 1,
      "Authmethod": "token"
    },
    "3": {
      "Name": "MS IPv6", "Ipaddress": "fe80::1",
      "Admin": "admin", "Pass": "secret",
      "Credentials": "admin:secret",
      "Admin_raw": "admin", "Pass_raw": "secret",
      "Credentials_raw": "admin:secret",
      "Port": 80, "Porthttps": 443, "Preferhttps": 0,
      "Authmethod": "basicauth"
    }
  }
}
GENERALJSON
close($gfh);

use lib File::Spec->catdir( $FindBin::Bin, '..' );
use LoxBerry::Auth;

$LoxBerry::Auth::store_file = "$home/data/system/tokens.json";

# --- _err ------------------------------------------------------------------
my $e = LoxBerry::Auth::_err('unreachable', 'timed out');
is( $e->{ok},      0,             'err ok ist 0' );
is( $e->{error},   'unreachable', 'err code' );
is( $e->{message}, 'timed out',   'err message' );

# --- _resolve_ms per Nummer ------------------------------------------------
my $r = LoxBerry::Auth::_resolve_ms(1);
is( $r->{ok},       1,                           'resolve MS 1 ok' );
is( $r->{msnr},     1,                           'msnr' );
is( $r->{name},     'Miniserver',                'name' );
is( $r->{baseurl},  'http://192.0.2.10:80',   'baseurl http' );
is( $r->{user},     'loxberry',                  'Benutzer aus general.json' );
is( $r->{password}, 'TestPass!23',                'Passwort aus Pass_raw, nicht aus Pass' );
is( $r->{lbsystem_user}, 'loxberry',             'lbsystem_user' );

my $r2 = LoxBerry::Auth::_resolve_ms(2);
is( $r2->{baseurl}, 'https://192.0.2.11:4443', 'baseurl https mit eigenem Port' );

my $r3 = LoxBerry::Auth::_resolve_ms(3);
is( $r3->{baseurl}, 'http://[fe80::1]:80',        'IPv6 in eckigen Klammern' );

# --- Benutzer und Passwort per Option --------------------------------------
my $ru = LoxBerry::Auth::_resolve_ms(1, user => 'sortmgr', password => 'geheim');
is( $ru->{user},     'sortmgr', 'uebergebener Benutzer' );
is( $ru->{password}, 'geheim',  'uebergebenes Passwort' );

my $rnp = LoxBerry::Auth::_resolve_ms(1, user => 'sortmgr');
is( $rnp->{user},     'sortmgr', 'uebergebener Benutzer ohne Passwort' );
is( $rnp->{password}, undef,     'kein Rueckfall auf das Passwort aus general.json' );

# --- Unbekannter Miniserver ------------------------------------------------
my $rn = LoxBerry::Auth::_resolve_ms(9);
is( $rn->{ok},    0,            'MS 9 nicht konfiguriert' );
is( $rn->{error}, 'msnotfound', 'Fehlercode msnotfound' );
is( LoxBerry::Auth::_resolve_ms(undef)->{error}, 'msnotfound', 'undef ist msnotfound' );
is( LoxBerry::Auth::_resolve_ms('')->{error},    'msnotfound', 'leer ist msnotfound' );

# --- Aufloesung ueber die Seriennummer -------------------------------------
is( LoxBerry::Auth::_resolve_ms('AB:CD:EF:01:02:03')->{error}, 'msnotfound',
    'unbekannte Seriennummer ist msnotfound' );

LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry',
	{ msnr => 1, name => 'Miniserver', firmware => '17.1.7.3' },
	{ token => 'abc', validUntil => 1, rights => 1924 } );

my $rs = LoxBerry::Auth::_resolve_ms('AB:CD:EF:01:02:03');
is( $rs->{ok},      1,                         'bekannte Seriennummer loest auf' );
is( $rs->{msnr},    1,                         'Seriennummer -> msnr 1' );
is( $rs->{serial},  'AB:CD:EF:01:02:03',       'serial durchgereicht' );
is( $rs->{baseurl}, 'http://192.0.2.10:80', 'baseurl aus general.json' );
is( LoxBerry::Auth::_resolve_ms('ab:cd:ef:01:02:03')->{msnr}, 1,
    'Seriennummer wird gross geschrieben verglichen' );

# --- auth_method -----------------------------------------------------------
is( LoxBerry::Auth::auth_method(1), 'basicauth', 'fehlender Authmethod-Schluessel ist basicauth' );
is( LoxBerry::Auth::auth_method(2), 'token',     'Authmethod token' );
is( LoxBerry::Auth::auth_method(3), 'basicauth', 'Authmethod basicauth' );
is( LoxBerry::Auth::auth_method(9), 'basicauth', 'unbekannter Miniserver ist basicauth' );
is( LoxBerry::Auth::auth_method('AB:CD:EF:01:02:03'), 'basicauth',
    'auth_method ueber die Seriennummer' );

done_testing();
