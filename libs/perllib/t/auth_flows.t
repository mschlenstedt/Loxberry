#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use File::Path qw( make_path );

my $home;
BEGIN {
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
    }
  }
}
GENERALJSON
close($gfh);

use lib File::Spec->catdir( $FindBin::Bin, '..' );
use LoxBerry::Auth;

$LoxBerry::Auth::store_file = "$home/data/system/tokens.json";

# --- Fake-Transport --------------------------------------------------------
my $KEY  = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
my $SALT = '41B0A8F1';
my @calls;
my %behaviour = (
	api_fw          => '17.1.7.3',
	api_serial      => 'AB:CD:EF:01:02:03',
	gettoken        => 'ok',       # ok | 401 | unreachable
	rights          => 1924,
	validUntil      => 999999999,
	unreachable_all => 0,
);

my $API_BODY = sub {
	my $v = "{'snr': '$behaviour{api_serial}', 'version':'$behaviour{api_fw}', "
	      . "'hasEventSlots':true, 'isInTrust':false, 'local':true,'certTLD':'com'}";
	return '{"LL": { "control": "dev/cfg/api", "value": "' . $v . '", "Code": "200"}}';
};

$LoxBerry::Auth::transport = sub {
	my ($url, %o) = @_;
	push @calls, $url;
	return (undef, undef, 'Connection refused') if ($behaviour{unreachable_all});

	if ($url =~ m{/jdev/cfg/api$}) {
		return (200, $API_BODY->(), '200 OK');
	}
	if ($url =~ m{/jdev/sys/getkey2/}) {
		return (200, '{"LL":{"control":"dev/sys/getkey2","code":"200","value":'
		           . '{"key":"' . $KEY . '","salt":"' . $SALT . '","hashAlg":"SHA256"}}}', '200 OK');
	}
	if ($url =~ m{/jdev/sys/gettoken/}) {
		return (undef, undef, 'Connection refused') if ($behaviour{gettoken} eq 'unreachable');
		if ($behaviour{gettoken} eq '401') {
			return (401, '<html><head><title>error</title></head><body><errorcode>401</errorcode>'
			           . '</body></html>', '401 Unauthorized');
		}
		return (200, '{"LL":{"control":"dev/sys/gettoken","code":"200","value":'
		           . '{"token":"tokTESTVALUE123","key":"' . $KEY . '","validUntil":'
		           . $behaviour{validUntil} . ',"tokenRights":' . $behaviour{rights}
		           . ',"unsecurePass":false}}}', '200 OK');
	}
	return (404, 'not found', '404 Not Found');
};

# --- _ll_value -------------------------------------------------------------
is( LoxBerry::Auth::_ll_value('{"LL":{"value":{"a":1},"Code":"200"}}')->{a}, 1, 'll_value Hashref' );
is( LoxBerry::Auth::_ll_value('{"LL":{"value":"text","Code":"200"}}'), 'text', 'll_value String' );
is( LoxBerry::Auth::_ll_value('<html>kaputt</html>'), undef, 'll_value auf HTML ist undef' );
is( LoxBerry::Auth::_ll_value(''), undef, 'll_value auf leer ist undef' );

# --- _client_uuid ----------------------------------------------------------
my $uuid = LoxBerry::Auth::_client_uuid('loxberry');
like( $uuid, qr/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, 'client_uuid hat UUID-Form' );
is( LoxBerry::Auth::_client_uuid('loxberry'), $uuid, 'client_uuid ist stabil' );
isnt( LoxBerry::Auth::_client_uuid('sortmgr'), $uuid, 'client_uuid je Benutzer verschieden' );

# --- _ms_api ---------------------------------------------------------------
my $res = LoxBerry::Auth::_resolve_ms(1);
my $api = LoxBerry::Auth::_ms_api($res);
is( $api->{ok},       1,                   'ms_api ok' );
is( $api->{serial},   'AB:CD:EF:01:02:03', 'Seriennummer aus cfg/api' );
is( $api->{firmware}, '17.1.7.3',          'Firmware aus cfg/api' );

# --- get_token, Gutfall ----------------------------------------------------
@calls = ();
my $t = LoxBerry::Auth::get_token(1);
is( $t->{ok},         1,                   'get_token ok' );
is( $t->{token},      'tokTESTVALUE123',   'Token' );
is( $t->{validUntil}, 999999999,           'validUntil' );
is( $t->{rights},     1924,                'rights' );
is( $t->{perm},       260,                 'perm ist der Standard 0x104 = 260' );
is( $t->{user},       'loxberry',          'Benutzer' );
is( $t->{serial},     'AB:CD:EF:01:02:03', 'Seriennummer' );
is( $t->{firmware},   '17.1.7.3',          'Firmware' );

# Der authHash im gettoken-Aufruf muss exakt stimmen
# pw=TestPass!23 salt=41B0A8F1 alg=SHA256 key=0123..ef
my ($gettoken_url) = grep { m{/jdev/sys/gettoken/} } @calls;
like( $gettoken_url,
      qr{/jdev/sys/gettoken/6811aac909afa7d530fd1cf87a28e4a9db15ad4e99eea57b33944319b05a86c5/loxberry/260/},
      'authHash, Benutzer und perm stehen korrekt in der URL' );
like( $gettoken_url, qr{/LoxBerry(%20|\+)}, 'info-Feld beginnt mit LoxBerry' );

# getkey2 wurde vor gettoken geholt
my @order = map { m{/jdev/sys/(\w+)/} ? $1 : () } @calls;
is_deeply( [ grep { /^(getkey2|gettoken)$/ } @order ], [ 'getkey2', 'gettoken' ],
           'getkey2 wird unmittelbar vor gettoken geholt' );

# --- Persistenz ------------------------------------------------------------
my $stored = LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry');
is( $stored->{token},  'tokTESTVALUE123', 'Token persistiert' );
is( $stored->{rights}, 1924,              'rights persistiert' );
ok( ! exists $stored->{key},      'Einmalschluessel nicht persistiert' );
ok( ! exists $stored->{password}, 'Passwort nicht persistiert' );

# --- Zweiter Aufruf nimmt den Bestand --------------------------------------
@calls = ();
my $t2 = LoxBerry::Auth::get_token(1);
is( $t2->{token}, 'tokTESTVALUE123', 'zweiter Aufruf liefert denselben Token' );
is( scalar(@calls), 0, 'zweiter Aufruf macht keinen einzigen HTTP-Request' );

# --- force erzwingt einen neuen Token --------------------------------------
@calls = ();
LoxBerry::Auth::get_token(1, force => 1);
ok( scalar(@calls) >= 2, 'force holt neu' );

# --- Aufloesung ueber die Seriennummer klappt jetzt ------------------------
my $ts = LoxBerry::Auth::get_token('AB:CD:EF:01:02:03');
is( $ts->{ok}, 1, 'get_token ueber die Seriennummer' );

# --- Fehlendes Recht -------------------------------------------------------
$behaviour{rights} = 4;    # nur App, kein Sys-WS
my $tr = LoxBerry::Auth::get_token(1, force => 1);
is( $tr->{ok},    0,              'fehlendes Recht ist ein Fehler' );
is( $tr->{error}, 'missingright', 'Fehlercode missingright' );
like( $tr->{message}, qr/0x104|260/, 'Meldung nennt die angeforderte Permission' );
$behaviour{rights} = 1924;

# --- 401 bei gettoken ------------------------------------------------------
$behaviour{gettoken} = '401';
my $tb = LoxBerry::Auth::get_token(1, force => 1);
is( $tb->{ok},    0,                'falsche Zugangsdaten sind ein Fehler' );
is( $tb->{error}, 'badcredentials', 'Fehlercode badcredentials - der 401 kommt bei gettoken, nicht bei getkey2' );
$behaviour{gettoken} = 'ok';

# --- Firmware zu alt -------------------------------------------------------
$behaviour{api_fw} = '11.2.10.21';
@calls = ();
my $tf = LoxBerry::Auth::get_token(1, force => 1);
is( $tf->{ok},    0,          'zu alte Firmware ist ein Fehler' );
is( $tf->{error}, 'fwtooold', 'Fehlercode fwtooold' );
is( scalar( grep { m{/jdev/sys/} } @calls ), 0, 'bei zu alter Firmware wird kein Token angefragt' );
$behaviour{api_fw} = '17.1.7.3';

# --- Miniserver nicht erreichbar -------------------------------------------
$behaviour{unreachable_all} = 1;
my $tu = LoxBerry::Auth::get_token(1, force => 1);
is( $tu->{ok},    0,             'nicht erreichbar ist ein Fehler' );
is( $tu->{error}, 'unreachable', 'Fehlercode unreachable' );
$behaviour{unreachable_all} = 0;

# --- Kein Passwort ---------------------------------------------------------
@calls = ();
my $tn = LoxBerry::Auth::get_token(1, user => 'sortmgr');
is( $tn->{ok},    0,               'fremder Benutzer ohne Passwort ist ein Fehler' );
is( $tn->{error}, 'nocredentials', 'Fehlercode nocredentials' );
is( scalar(@calls), 0, 'ohne Passwort wird gar nicht erst gefragt' );

# --- Fremder Benutzer mit Passwort -----------------------------------------
my $tx = LoxBerry::Auth::get_token(1, user => 'sortmgr', password => 'geheim', perm => 0x04);
is( $tx->{ok},   1,         'fremder Benutzer mit Passwort bekommt einen Token' );
is( $tx->{perm}, 4,         'uebergebene Permission wird verwendet' );
is( $tx->{user}, 'sortmgr', 'Token gehoert dem fremden Benutzer' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'sortmgr')->{token},
    'tokTESTVALUE123', 'zweiter Benutzer steht neben dem ersten im Bestand' );


# ==========================================================================
# Task 5: request / token_info / refresh_token / kill_token
# ==========================================================================

my $TOKHASH = '3b50109633af4140485302f72bd8a2734950286ca29a4633ef6c54376540bd69';
my @optlog;
$behaviour{refresh}      = 'ok';   # ok | 401
$behaviour{kill}         = 'ok';   # ok | 401
$behaviour{cmd_401_once} = 0;

my $base_transport = $LoxBerry::Auth::transport;
$LoxBerry::Auth::transport = sub {
	my ($url, %o) = @_;
	push @optlog, { url => $url, opts => { %o } };

	if ($url =~ m{/jdev/sys/refreshjwt/}) {
		push @calls, $url;
		return (401, '<html>401</html>', '401 Unauthorized') if ($behaviour{refresh} eq '401');
		# Am echten Miniserver gemessen: HTTP 200, aber LL.code 401
		return (200, '{"LL":{"control":"dev/sys/refreshjwt","value":{},"code":"401"}}', '200 OK')
			if ($behaviour{refresh} eq 'll401');
		return (200, '{"LL":{"control":"dev/sys/refreshjwt","code":"200","value":'
		           . '{"token":"eyJ0eXAiTESTJWT","validUntil":' . $behaviour{validUntil}
		           . ',"tokenRights":1924,"unsecurePass":false}}}', '200 OK');
	}
	if ($url =~ m{/jdev/sys/killtoken/}) {
		push @calls, $url;
		return (401, '<html>401</html>', '401 Unauthorized') if ($behaviour{kill} eq '401');
		return (200, '{"LL":{"control":"dev/sys/killtoken","code":"200","value":"1"}}', '200 OK');
	}
	if ($url =~ m{autht=}) {
		push @calls, $url;
		if ($behaviour{cmd_401_once}) {
			$behaviour{cmd_401_once}--;
			return (401, '<html>401</html>', '401 Unauthorized');
		}
		return (200, '{"LL":{"control":"dev/sps/io/Test","code":"200","value":"42"}}', '200 OK');
	}
	return $base_transport->($url, %o);
};

# Ausgangslage: frischer, lange gueltiger Token fuer loxberry
LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry',
	{ msnr => 1, name => 'Miniserver', firmware => '17.1.7.3' },
	{ token => 'tokTESTVALUE123', validUntil => LoxBerry::System::epoch2lox() + 60*86400,
	  rights => 1924, perm => 260, acquired => 1, info => 'LoxBerry testhost' } );

# --- token_info ------------------------------------------------------------
@calls = ();
my $ti = LoxBerry::Auth::token_info(1);
is( $ti->{ok},     1,                   'token_info ok' );
is( $ti->{token},  'tokTESTVALUE123',   'token_info Token' );
is( $ti->{rights}, 1924,                'token_info rights' );
is( $ti->{user},   'loxberry',          'token_info Benutzer' );
is( $ti->{serial}, 'AB:CD:EF:01:02:03', 'token_info Seriennummer' );
cmp_ok( $ti->{expires_in}, '>', 59*86400, 'token_info Restlaufzeit in Sekunden' );
is( LoxBerry::Auth::token_info(1, user => 'niemand')->{error}, 'notoken',
    'token_info ohne Bestand ist notoken' );

# --- request, Gutfall ------------------------------------------------------
@calls = ();
my ($content, $info) = LoxBerry::Auth::request(1, '/jdev/sps/io/Test');
is( $info->{code},  200, 'request code 200' );
is( $info->{error}, 0,   'request error 0' );
like( $content, qr/"value":"42"/, 'request liefert den Body' );

my ($cmd_url) = grep { m{/jdev/sps/io/Test} } @calls;
like( $cmd_url, qr{\?autht=\Q$TOKHASH\E&user=loxberry$},
      'autht traegt den Token-Hash, user haengt an' );

# getkey2 wird vor JEDEM signierten Request neu geholt - der Schluessel ist einmalig
@calls = ();
LoxBerry::Auth::request(1, '/jdev/sps/io/Test');
is( scalar( grep { m{/jdev/sys/getkey2/} } @calls ), 1,
    'jeder Request holt genau einen frischen Einmalschluessel' );

# --- Kommando mit eigenem Query-String -------------------------------------
@calls = ();
LoxBerry::Auth::request(1, '/jdev/sps/io/Test?state=on');
my ($q_url) = grep { m{/jdev/sps/io/Test} } @calls;
like( $q_url, qr{\?state=on&autht=}, 'vorhandener Query-String wird mit & ergaenzt' );

# --- 401: einmal neu beschaffen und wiederholen ----------------------------
@calls = ();
$behaviour{cmd_401_once} = 1;
my ($c2, $i2) = LoxBerry::Auth::request(1, '/jdev/sps/io/Test');
is( $i2->{code},  200, '401 fuehrt zu einem erfolgreichen zweiten Versuch' );
is( $i2->{error}, 0,   'kein Fehler nach dem Wiederholen' );
is( scalar( grep { m{/jdev/sys/gettoken/} } @calls ), 1,
    'genau ein neuer Token wird beschafft' );

# --- 401 auch beim zweiten Versuch -----------------------------------------
@calls = ();
$behaviour{cmd_401_once} = 2;
my ($c3, $i3) = LoxBerry::Auth::request(1, '/jdev/sps/io/Test');
is( $i3->{error},   1,         'zweimal 401 bleibt ein Fehler' );
is( $i3->{errcode}, 'revoked', 'Fehlercode revoked' );
is( $c3, undef, 'kein Inhalt bei revoked' );
$behaviour{cmd_401_once} = 0;

# --- Abgelaufener Token wird neu beschafft ---------------------------------
LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry',
	{ msnr => 1 },
	{ token => 'tokTESTVALUE123', validUntil => LoxBerry::System::epoch2lox() - 10,
	  rights => 1924, perm => 260, acquired => 1, info => 'x' } );
@calls = ();
LoxBerry::Auth::request(1, '/jdev/sps/io/Test');
is( scalar( grep { m{/jdev/sys/gettoken/} } @calls ), 1,
    'abgelaufener Token wird neu beschafft' );
is( scalar( grep { m{/jdev/sys/refreshjwt/} } @calls ), 0,
    'abgelaufener Token wird nicht erneuert, sondern neu geholt' );

# --- Token unter der Schwelle wird erneuert --------------------------------
LoxBerry::Auth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry',
	{ msnr => 1 },
	{ token => 'tokTESTVALUE123', validUntil => LoxBerry::System::epoch2lox() + 3*86400,
	  rights => 1924, perm => 260, acquired => 1, info => 'x' } );
@calls = ();
LoxBerry::Auth::request(1, '/jdev/sps/io/Test');
is( scalar( grep { m{/jdev/sys/refreshjwt/} } @calls ), 1,
    'Restlaufzeit unter 7 Tagen loest refreshjwt aus' );
is( scalar( grep { m{/jdev/sys/gettoken/} } @calls ), 0,
    'Erneuerung braucht kein gettoken und kein Passwort' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry')->{token},
    'eyJ0eXAiTESTJWT', 'der erneuerte JWT ersetzt den alten Token im Bestand' );

# --- refresh_token direkt --------------------------------------------------
my $rt = LoxBerry::Auth::refresh_token(1);
is( $rt->{ok},    1,                 'refresh_token ok' );
is( $rt->{token}, 'eyJ0eXAiTESTJWT', 'refresh_token liefert den JWT' );
is( LoxBerry::Auth::refresh_token(1, user => 'niemand')->{error}, 'notoken',
    'refresh_token ohne Bestand ist notoken' );

$behaviour{refresh} = '401';
is( LoxBerry::Auth::refresh_token(1)->{error}, 'revoked',
    '401 bei refreshjwt bedeutet: Token serverseitig widerrufen' );

# Der Miniserver spiegelt den LL-Code NICHT immer in den HTTP-Status - am
# echten Geraet antwortet refreshjwt mit HTTP 200 und LL.code 401.
$behaviour{refresh} = 'll401';
is( LoxBerry::Auth::refresh_token(1)->{error}, 'revoked',
    'HTTP 200 mit LL-Code 401 wird als Ablehnung erkannt' );
$behaviour{refresh} = 'ok';

# autht traegt den Klartext-Token, der Pfad den Hash
@calls = ();
LoxBerry::Auth::refresh_token(1);
my ($rj_url) = grep { m{/jdev/sys/refreshjwt/} } @calls;
like( $rj_url, qr{/jdev/sys/refreshjwt/[0-9a-f]{64}/loxberry\?autht=},
      'refreshjwt: Token-Hash im Pfad' );
unlike( $rj_url, qr{autht=[0-9a-f]{64}&}, 'refreshjwt: autht ist NICHT der Hash' );
like( $rj_url, qr{autht=eyJ0eXAiTESTJWT&}, 'refreshjwt: autht ist der Klartext-Token' );

# --- kill_token ------------------------------------------------------------
is( LoxBerry::Auth::kill_token(1, user => 'sortmgr')->{error}, 'nopassword',
    'kill_token ohne Passwort ist nopassword' );

@optlog = ();
my $kt = LoxBerry::Auth::kill_token(1);
is( $kt->{ok}, 1, 'kill_token mit dem Passwort aus general.json' );
my ($killcall) = grep { $_->{url} =~ m{/jdev/sys/killtoken/} } @optlog;
is( $killcall->{opts}{basicauth_user},     'loxberry',   'killtoken nutzt Basic-Auth' );
is( $killcall->{opts}{basicauth_password}, 'TestPass!23', 'Basic-Auth mit dem Klartext-Passwort' );
is( LoxBerry::Auth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry'), undef,
    'nach kill_token ist der Eintrag aus dem Bestand entfernt' );

done_testing();
