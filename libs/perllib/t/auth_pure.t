#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

# LoxBerry/ liegt neben t/ unterhalb von libs/perllib/
use lib File::Spec->catdir( $FindBin::Bin, '..' );
use LoxBerry::Auth;

# --- _norm_alg -------------------------------------------------------------
is( LoxBerry::Auth::_norm_alg('SHA256'),  'SHA256', 'norm_alg SHA256' );
is( LoxBerry::Auth::_norm_alg('sha-256'), 'SHA256', 'norm_alg sha-256 normalisiert' );
is( LoxBerry::Auth::_norm_alg('SHA1'),    'SHA1',   'norm_alg SHA1' );
is( LoxBerry::Auth::_norm_alg(undef),     'SHA1',   'norm_alg leer faellt auf SHA1 zurueck' );
is( LoxBerry::Auth::_norm_alg('MD5'),     undef,    'norm_alg unbekannt ist undef' );

# --- Hash-Kette gegen feste Referenzwerte ---------------------------------
# user=loxberry pw=Test1234 salt=41B0A8F1 token=a1b2c3d4e5f60718293a4b5c6d7e8f90
my $KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

my $pw256 = LoxBerry::Auth::_pw_hash('Test1234', '41B0A8F1', 'SHA256');
is( $pw256, '3E4A5D209675FD7633320D7F1AA5B399174D2B397ABE4FE53118FCECE38A847D',
    'pw_hash SHA256 gross geschrieben und korrekt' );
is( LoxBerry::Auth::_auth_hash('loxberry', $pw256, $KEY, 'SHA256'),
    '31db6348ae60d52f53381bc3ebf2b7b1691a55e51110ef31ac50b19b1b2f9f47',
    'auth_hash SHA256' );
is( LoxBerry::Auth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $KEY, 'SHA256'),
    '7c75d4ea7111e124200e9939ded8f9d2ece6835089a4d5ff1fb6d96e57b6dd65',
    'token_hash SHA256' );

my $pw1 = LoxBerry::Auth::_pw_hash('Test1234', '41B0A8F1', 'SHA1');
is( $pw1, '3A09820F277977B59FE88D032BBC7ECF5C2C7BCD', 'pw_hash SHA1' );
is( LoxBerry::Auth::_auth_hash('loxberry', $pw1, $KEY, 'SHA1'),
    'dde0f27175043736346411f693364a2bee2c0308', 'auth_hash SHA1' );
is( LoxBerry::Auth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $KEY, 'SHA1'),
    '9135606ae0eac2862b8536f0adc059cf57fd7e62', 'token_hash SHA1' );

# --- _parse_api_value ------------------------------------------------------
# jdev/cfg/api liefert value als STRING mit einfachen Anfuehrungszeichen -
# kein gueltiges JSON. Originalantwort von Miniserver 17.1.7.3:
my $apival = "{'snr': 'AB:CD:EF:01:02:03', 'version':'17.1.7.3', 'hasEventSlots':true, "
           . "'isInTrust':false, 'local':true,'certTLD':'com'}";
my $api = LoxBerry::Auth::_parse_api_value($apival);
is( $api->{snr},     'AB:CD:EF:01:02:03', 'parse_api_value snr' );
is( $api->{version}, '17.1.7.3',          'parse_api_value version' );
is( $api->{certTLD}, 'com',               'parse_api_value certTLD' );
is( $api->{local},   'true',              'parse_api_value unquotierter Wert' );
is( LoxBerry::Auth::_parse_api_value(''),    undef, 'parse_api_value leer' );
is( LoxBerry::Auth::_parse_api_value(undef), undef, 'parse_api_value undef' );

# --- _fw_supported ---------------------------------------------------------
is( LoxBerry::Auth::_fw_supported('17.1.7.3'),   1, 'fw 17.1.7.3 unterstuetzt' );
is( LoxBerry::Auth::_fw_supported('11.2.10.22'), 1, 'fw exakt am Floor unterstuetzt' );
is( LoxBerry::Auth::_fw_supported('11.2.10.21'), 0, 'fw knapp unter Floor abgelehnt' );
is( LoxBerry::Auth::_fw_supported('11.2.9.99'),  0, 'fw aeltere Patchlinie abgelehnt' );
is( LoxBerry::Auth::_fw_supported('12.0'),       1, 'fw mit weniger Stellen unterstuetzt' );
is( LoxBerry::Auth::_fw_supported(''),           0, 'fw leer abgelehnt' );

# --- _rights_granted -------------------------------------------------------
# perm 0x104 liefert laut Messung tokenRights 1924 = 4+128+256+512+1024
is( LoxBerry::Auth::_rights_granted(1924, $LoxBerry::Auth::PERM_SYSWS), 1, 'Sys-WS in 1924 enthalten' );
is( LoxBerry::Auth::_rights_granted(1924, $LoxBerry::Auth::PERM_APP),   1, 'App in 1924 enthalten' );
is( LoxBerry::Auth::_rights_granted(4,    $LoxBerry::Auth::PERM_SYSWS), 0, 'Sys-WS fehlt im reinen App-Token' );
is( LoxBerry::Auth::_rights_granted(1924, 0x104),                       1, 'kombiniertes Bitmuster' );

# --- Konstanten ------------------------------------------------------------
is( $LoxBerry::Auth::DEFAULT_PERM,      0x104,        'Standard-Permission App+Sys-WS' );
is( $LoxBerry::Auth::REFRESH_THRESHOLD, 7*86400,      'Erneuerungsschwelle 7 Tage' );
is( $LoxBerry::Auth::MIN_FIRMWARE,      '11.2.10.22', 'Firmware-Floor' );

done_testing();
