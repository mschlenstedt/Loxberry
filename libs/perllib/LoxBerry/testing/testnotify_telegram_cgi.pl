#!/usr/bin/perl
# Tests fuer webfrontend/htmlauth/system/telegram.cgi (Hilfsfunktionen)
# Kein Netzwerk, keine Schreibzugriffe auf telegram.json.
#
# Aufruf:
#   TG_CGI=/pfad/zu/telegram.cgi perl -I<dir> testnotify_telegram_cgi.pl
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

done_testing();
