#!/usr/bin/perl
# Tests fuer webfrontend/htmlauth/system/telegram.cgi (Hilfsfunktionen)
# Kein Netzwerk, keine Schreibzugriffe auf telegram.json.
#
# Aufruf:
#   TG_CGI=/pfad/zu/telegram.cgi [TG_PROVIDER=/pfad/zu/telegram.pl] perl -I<dir> testnotify_telegram_cgi.pl
use utf8;
use strict;
use warnings;
use Test::More;
use JSON;
use Encode;
no warnings "once";
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Spec;

Test::More->builder->output(*STDOUT);
Test::More->builder->failure_output(*STDERR);

my $cgi = $ENV{TG_CGI} // "$ENV{LBHOMEDIR}/webfrontend/htmlauth/system/telegram.cgi";
require $cgi;

my $tok = '123456:' . ('A' x 35);

# token_format
my @r = tgcgi_validate({ bot_token => 'abc' }, '');
is_deeply(\@r, [0, 'ERR_TOKEN_FORMAT'], 'token_format');

# chatid_negative
@r = tgcgi_validate({
	activate_telegram => 1,
	bot_token => $tok,
	recipients_json => '[{"NAME":"Gruppe","CHAT_ID":"-1001234567890"}]',
}, '');
is($r[0], 1, 'chatid_negative');

# chatid_bad
@r = tgcgi_validate({
	activate_telegram => 1,
	bot_token => $tok,
	recipients_json => '[{"NAME":"X","CHAT_ID":"12ab"}]',
}, '');
is_deeply(\@r, [0, 'ERR_CHATID_FORMAT'], 'chatid_bad');

# activate_needs_recipient
@r = tgcgi_validate({ activate_telegram => 1, bot_token => '', recipients_json => '[]' }, $tok);
is_deeply(\@r, [0, 'ERR_NO_RECIPIENT'], 'activate_needs_recipient');

# activate_needs_token
@r = tgcgi_validate({ activate_telegram => 1, recipients_json => '[{"NAME":"A","CHAT_ID":"1"}]' }, '');
is_deeply(\@r, [0, 'ERR_NO_TOKEN'], 'activate_needs_token');

# empty rows dropped, empty name defaulted
my $m = tgcgi_merge({ BOT_TOKEN => '111:alt', RECIPIENTS => [] }, {
	recipients_json => '[{"NAME":"","CHAT_ID":""},{"NAME":"","CHAT_ID":"42"}]',
});
is_deeply($m->{RECIPIENTS}, [{ NAME => Encode::encode_utf8('Empfänger 1'), CHAT_ID => '42' }], 'empty_rows');

# keep_token
is(tgcgi_merge({ BOT_TOKEN => '111:alt' }, { bot_token => '' })->{BOT_TOKEN}, '111:alt', 'keep_token');
is(tgcgi_merge({ BOT_TOKEN => '111:alt' }, { bot_token => '9:new' })->{BOT_TOKEN}, '9:new', 'replace_token');

# public_hides_token
my $p = tgcgi_public({
	ACTIVATE_TELEGRAM => 1, BOT_TOKEN => '111:alt',
	RECIPIENTS => [{ NAME => 'A', CHAT_ID => '1' }],
	NOTIFICATION => { TELEGRAM_SYSTEM_ERRORS => 'true' },
});
ok(!exists $p->{BOT_TOKEN}, 'public: kein BOT_TOKEN');
is($p->{TOKEN_SET}, 1, 'public: TOKEN_SET');
unlike(encode_json($p), qr/111:alt/, 'public: Token nicht im JSON');

# savecfg: schreibt in ein Temp-Verzeichnis, Modus 0600, Token nur in der Datei
my $dir = tempdir(DIR => dirname(File::Spec->rel2abs($0)), CLEANUP => 1);
$main::TG_CFGFILE = "$dir/telegram.json";
$main::TG_DEFAULT = "$dir/none.default";
%main::response = ();
tgcgi_action('savecfg', {
	activate_telegram => 1, bot_token => $tok,
	recipients_json => '[{"NAME":"Ich","CHAT_ID":"42"}]',
	TELEGRAM_SYSTEM_INFOS => 'false',
});
is($main::response{error}, 0, 'savecfg ok');
is(sprintf('%04o', (stat "$dir/telegram.json")[2] & 07777), '0600', 'savecfg: chmod 0600');
my $saved = decode_json(do { local (@ARGV, $/) = ("$dir/telegram.json"); <> });
is($saved->{BOT_TOKEN}, $tok, 'savecfg: Token gespeichert');
is($saved->{NOTIFICATION}{TELEGRAM_SYSTEM_INFOS}, 'false', 'savecfg: Flag');
is($saved->{NOTIFICATION}{TELEGRAM_PLUGIN_ERRORS}, 'true', 'savecfg: Default-Flag');

# Umlaute: UTF-8-Bytes rein -> UTF-8-Bytes raus (kein Doppel-Encoding)
my $kueche = Encode::encode_utf8('K' . chr(252) . 'che');
my $um = tgcgi_merge({}, { recipients_json => Encode::encode_utf8('[{"NAME":"K' . chr(252) . 'che","CHAT_ID":"1"}]') });
is($um->{RECIPIENTS}[0]{NAME}, $kueche, 'umlaut_merge');

# savecfg zweimal mit identischer Eingabe: beide Male Erfolg (write() meldet "unveraendert" leer)
my %same = (
	activate_telegram => 1, bot_token => $tok,
	recipients_json => Encode::encode_utf8('[{"NAME":"K' . chr(252) . 'che","CHAT_ID":"7"}]'),
);
%main::response = ();
tgcgi_action('savecfg', { %same });
is($main::response{error}, 0, 'savecfg_1 ok');
%main::response = ();
tgcgi_action('savecfg', { %same });
is($main::response{error}, 0, 'savecfg_unchanged ok');
# Datei ist UTF-8: decode_json liefert Zeichen (u-Umlaut = chr 252), bei Doppel-Encoding kaeme mehr heraus
my $s2 = decode_json(do { local (@ARGV, $/) = ("$dir/telegram.json"); <> });
is($s2->{RECIPIENTS}[0]{NAME}, 'K' . chr(252) . 'che', 'umlaut gespeichert');

# Round trip: getcfg -> Browser sendet zurueck -> save: Bytes unveraendert
%main::response = ();
tgcgi_action('getcfg', {});
my $browser_json = to_json($main::response{RECIPIENTS});
utf8::downgrade($browser_json);  # wie auf der Leitung: Bytes
for (1 .. 2) {
	%main::response = ();
	tgcgi_action('savecfg', { bot_token => '', recipients_json => $browser_json });
	is($main::response{error}, 0, 'roundtrip save ok');
}
my $s3 = decode_json(do { local (@ARGV, $/) = ("$dir/telegram.json"); <> });
is($s3->{RECIPIENTS}[0]{NAME}, 'K' . chr(252) . 'che', 'roundtrip: Umlaute unveraendert');
is(sprintf('%04o', (stat "$dir/telegram.json")[2] & 07777), '0600', 'chmod 0600 nach Mehrfach-Save');

# Erstanlage: Datei darf nie fuer andere lesbar sein
$main::TG_CFGFILE = "$dir/neu.json";
%main::response = ();
tgcgi_action('savecfg', { %same });
is(sprintf('%04o', (stat "$dir/neu.json")[2] & 07777), '0600', 'neu angelegt mit 0600');

# Provider: STDERR verworfen, kein Token in der Ausgabe, Nicht-JSON -> generischer Fehler
my $fake = "$dir/fake.sh";
open(my $fh, '>', $fake) or die; print $fh "#!/bin/sh\necho \"geheim \$LBTELEGRAM_TOKEN\" >&2\necho '{\"ok\":1,\"username\":\"bot\"}'\n"; close $fh;
chmod 0755, $fake;
$main::TG_PROVIDER = $fake;
my $out = tgcgi_provider('--getme', $tok);
is_deeply(decode_json($out), { ok => 1, username => 'bot' }, 'provider: JSON durchgereicht');
unlike($out, qr/geheim|\Q$tok\E/, 'provider: kein STDERR/Token');
open($fh, '>', $fake) or die; print $fh "#!/bin/sh\necho kaputt\n"; close $fh;
is(decode_json(tgcgi_provider('--getme', undef))->{ok}, 0, 'provider: Nicht-JSON -> ok=0');

# Provider-Ausgabe mit Umlaut (UTF-8 wie tg_out) geht genau einmal kodiert an den Browser
my $empf = Encode::encode_utf8('Empf' . chr(228) . 'nger 1');
open($fh, '>:raw', $fake) or die;
print $fh "#!/bin/sh\necho '{\"ok\":1,\"results\":[{\"CHAT_ID\":\"1\",\"NAME\":\"$empf\",\"ok\":1}]}'\n";
close $fh;
$out = tgcgi_provider('--test', undef);
my $cnt = () = $out =~ /\Q$empf\E/g;
is($cnt, 1, 'provider: Umlaut genau einmal UTF-8-kodiert');
unlike($out, qr/\xC3\x83/, 'provider: kein Doppel-Encoding');
is(decode_json($out)->{results}[0]{NAME}, 'Empf' . chr(228) . 'nger 1', 'provider: Browser dekodiert Empfaenger korrekt');

sub quiet(&)
{
	my ($code) = @_;
	local *STDERR;
	open(STDERR, '>', File::Spec->devnull());
	return $code->();
}
sub write_raw { my ($f, $c) = @_; open(my $h, '>:raw', $f) or die "$f: $!"; print $h $c; close $h; }

# getcfg legt weder telegram.json noch .default an
$main::TG_CFGFILE = "$dir/fehlt.json";
$main::TG_DEFAULT = "$dir/fehlt.json.default";
%main::response = ();
tgcgi_action('getcfg', {});
is($main::response{error}, 0, 'getcfg ohne Dateien ok');
is($main::response{NOTIFICATION}{TELEGRAM_SYSTEM_ERRORS}, 'true', 'getcfg ohne Dateien: eingebaute Defaults');
ok(!-e $main::TG_CFGFILE, 'getcfg legt keine telegram.json an');
ok(!-e $main::TG_DEFAULT, 'getcfg legt keine .default an');

# Kaputte Vorlage -> eingebaute Defaults
write_raw("$dir/kaputt.default", '{kaputt');
$main::TG_DEFAULT = "$dir/kaputt.default";
%main::response = ();
my $lived = eval { quiet { tgcgi_action('getcfg', {}) }; 1 };
ok($lived, 'kaputte .default: kein die') or diag($@);
is($main::response{error}, 0, 'kaputte .default: eingebaute Defaults');

# Kaputte telegram.json -> sauberes Fehler-JSON, Datei bleibt unveraendert
write_raw("$dir/kaputt.json", '{kaputt');
$main::TG_CFGFILE = "$dir/kaputt.json";
for my $act ('getcfg', 'savecfg') {
	%main::response = ();
	$lived = eval { quiet { tgcgi_action($act, { %same }) }; 1 };
	ok($lived, "kaputte telegram.json ($act): kein die") or diag($@);
	is($main::response{error}, 1, "kaputte telegram.json ($act): error=1");
	like($main::response{message} // '', qr/telegram\.json/, "kaputte telegram.json ($act): Meldung");
	ok(!exists $main::response{BOT_TOKEN}, "kaputte telegram.json ($act): kein Token");
}
is(do { local (@ARGV, $/) = ("$dir/kaputt.json"); <> }, '{kaputt', 'kaputte telegram.json bleibt unveraendert');

# Ende-zu-Ende mit echtem Provider (TG_PROVIDER): kaputte Konfig -> Fehler-JSON statt die
SKIP: {
	skip 'TG_PROVIDER nicht gesetzt', 2 if !$ENV{TG_PROVIDER};
	$main::TG_PROVIDER = $ENV{TG_PROVIDER};
	# Dieselben Bibliotheken wie dieser Test (z. B. -I Testordner mit neuer Log.pm)
	my @libs = map { File::Spec->rel2abs($_) } grep { !ref($_) && -d "$_/LoxBerry" } @INC;
	local $ENV{PERL5LIB} = join(':', grep { defined && length } (@libs, $ENV{PERL5LIB}));
	my $r = decode_json(tgcgi_provider('--test', undef));
	is($r->{ok}, 0, 'echter Provider, kaputte Konfig: ok=0');
	ok($r->{error} && $r->{error} ne ($main::SL{'TELEGRAM.ERR_PROVIDER'} // 'Provider error'), 'echter Provider: eigene Fehlermeldung (kein Absturz)') or diag(encode_json($r));
}

done_testing();
