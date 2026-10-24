#!/usr/bin/perl
# Tests fuer sbin/notifyproviders/telegram.pl
# Nur reine Funktionen und der DRYRUN-Pfad: kein Netzwerk, kein Versand, keine Benachrichtigungs-DB.
#
# Aufruf:
#   TG_PROVIDER=/pfad/zu/telegram.pl [TG_LANGFILE=/pfad/zu/language_de.ini] perl -I<dir mit LoxBerry/Log.pm> testnotify_telegram.pl
# Temporaere Dateien entstehen nur in einem Unterordner neben diesem Testskript.
use utf8;
use strict;
use warnings;
use LoxBerry::Log;
use Test::More;
use JSON;
use Encode ();
use File::Basename;
use File::Spec;
use File::Temp qw(tempdir);

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
Test::More->builder->output(*STDOUT);
Test::More->builder->failure_output(*STDERR);
Test::More->builder->todo_output(*STDOUT);

my $prov = $ENV{TG_PROVIDER} // "$LoxBerry::System::lbssbindir/notifyproviders/telegram.pl";
require $prov;

my %SL = (
	'TELEGRAM.MSG_INFO'     => 'Info',
	'TELEGRAM.MSG_ERROR'    => 'Fehler',
	'TELEGRAM.MSG_TEST'     => 'Test',
	'TELEGRAM.MSG_SYSTEM'   => 'System',
	'TELEGRAM.MSG_PLUGIN'   => 'Plugin',
	'TELEGRAM.MSG_LINK'     => 'Details öffnen',
	'TELEGRAM.MSG_LOGFILE'  => 'Logdatei öffnen',
	'TELEGRAM.MSG_TESTTEXT' => 'Testnachricht',
);
my %host = (friendlyname => 'Box', hostname => 'loxberry', port => 80);

# format_error_plugin
my $t = tg_format({SEVERITY=>3, _ISPLUGIN=>1, PLUGINTITLE=>'Weather4Lox', NAME=>'upgrade',
	MESSAGE=>'Skript fehlgeschlagen', LOGFILE_REL=>'plugins/w4l/x.log'}, \%SL, \%host);
like($t, qr/^🔴 <b>Fehler · /, 'error: Kopf');
like($t, qr{<b>Plugin Weather4Lox</b> · Upgrade}, 'plugin: Zeile');
like($t, qr{logfile=plugins/w4l/x\.log&amp;header=html}, 'logfile-Link');
like($t, qr{http://loxberry:80/admin/system/tools/logfile\.cgi\?}, 'logfile-Host');

# format_info_system
$t = tg_format({SEVERITY=>6, _ISSYSTEM=>1, PACKAGE=>'updates', NAME=>'check', MESSAGE=>'ok'}, \%SL, \%host);
like($t, qr/^ℹ️ <b>Info · /, 'info: Kopf');
like($t, qr{<b>System</b> · Updates Check}, 'system: Zeile');
unlike($t, qr/<a /, 'kein Link ohne LINK/LOGFILE_REL');

# LINK
$t = tg_format({SEVERITY=>6, _ISSYSTEM=>1, PACKAGE=>'a', NAME=>'b', MESSAGE=>'m', LINK=>'http://x/?a=1&b=2'}, \%SL, \%host);
like($t, qr{<a href="http://x/\?a=1&amp;b=2">Details öffnen</a>}, 'LINK');

# escape
$t = tg_format({SEVERITY=>3, _ISSYSTEM=>1, PACKAGE=>'t', NAME=>'n',
	MESSAGE=>'a<b>fett</b> & <script>x</script> 3 < 4'}, \%SL, \%host);
like($t, qr/afett &amp; x 3 &lt; 4/, 'escape');
unlike($t, qr/<script/, 'kein script');

# br/p -> Zeilenumbruch
$t = tg_format({SEVERITY=>3, _ISSYSTEM=>1, PACKAGE=>'t', NAME=>'n', MESSAGE=>'eins<br>zwei<p>drei</p>'}, \%SL, \%host);
like($t, qr/eins\nzwei\ndrei/, 'br/p');

# truncate
$t = tg_format({SEVERITY=>3, _ISSYSTEM=>1, PACKAGE=>'t', NAME=>'n', MESSAGE=>'x' x 5000, LINK=>'http://x/'}, \%SL, \%host);
ok(length($t) <= 4096, 'truncate: Laenge ' . length($t));
like($t, qr/x…\n/, 'truncate: Ende mit …');
like($t, qr{<a href="http://x/">Details öffnen</a>$}, 'truncate: Link bleibt');

# test message
$t = tg_format_test(\%SL, \%host);
is($t, "✅ <b>Test · Box LoxBerry</b>\nTestnachricht", 'Testnachricht');

# mask
is(tg_mask('err bot123:ABC/x', '123:ABC'), 'err bot***/x', 'mask');
is(tg_mask('nix', ''), 'nix', 'mask ohne Token');

# Arbeitsverzeichnis neben dem Testskript (nie im sbin-Ordner), wird am Ende geloescht
my $dir = tempdir(DIR => dirname(File::Spec->rel2abs($0)), CLEANUP => 1);
# Der Provider soll dieselbe LoxBerry::Log laden wie dieser Test (z. B. aus dem Testordner)
my $libdir = dirname(dirname(File::Spec->rel2abs($INC{'LoxBerry/Log.pm'})));

sub write_bytes
{
	my ($file, $bytes) = @_;
	open(my $fh, '>:raw', $file) or die "cannot write $file: $!";
	print $fh $bytes;
	close $fh;
}

# utf8_roundtrip (DRYRUN)
my $cfgfile = "$dir/telegram_test_config.json";
write_bytes($cfgfile, '{"ACTIVATE_TELEGRAM":1,"BOT_TOKEN":"1:x","RECIPIENTS":[{"NAME":"Test","CHAT_ID":"42"}],"NOTIFICATION":{}}');
{
	local $LoxBerry::Log::telegram_provider = $prov;
	local $ENV{LBTELEGRAM_DRYRUN} = 1;
	local $ENV{LBTELEGRAM_TOKEN} = '1:x';
	local $ENV{LBTELEGRAM_CONFIG} = $cfgfile;
	local $ENV{PERL5LIB} = join(':', grep { defined && length } ($libdir, $ENV{PERL5LIB}));
	my $cmd = LoxBerry::Log::notify_telegram_command({SEVERITY=>3, _ISSYSTEM=>1, PACKAGE=>'t', NAME=>'n', MESSAGE=>'Benötigt Ä ß €'});
	my $out = qx($cmd 2>&1);
	my $res = eval { decode_json($out) };
	ok($res && ref($res) eq 'ARRAY', 'DRYRUN liefert JSON-Array') or diag($out);
	like($res->[0]{text} // '', qr/Benötigt Ä ß €/, 'utf8_roundtrip');
	is($res->[0]{chat_id}, '42', 'chat_id');
	unlike($out, qr/1:x/, 'Token nicht in der Ausgabe');
}

# Umlaute aus Sprachdatei und Friendlyname: readlanguage und general.json liefern UTF-8-Bytes.
# Sprachdatei wie readlanguage lesen (read_file + _parse_lang_file); TG_LANGFILE = echte language_de.ini
{
	my %SLb;
	my $langfile = $ENV{TG_LANGFILE};
	my $content = (defined $langfile && -e $langfile)
		? LoxBerry::System::read_file($langfile)
		: Encode::encode_utf8(qq([TELEGRAM]\nMSG_ERROR="Fehler"\nMSG_SYSTEM="System"\nMSG_LOGFILE="Logdatei öffnen"\n));
	LoxBerry::System::_parse_lang_file($content, \%SLb);
	is($SLb{'TELEGRAM.MSG_LOGFILE'}, Encode::encode_utf8('Logdatei öffnen'), 'Sprachdatei liefert Bytes' . (defined $langfile ? " ($langfile)" : ''));
	# Friendlyname wie lbfriendlyname() ihn liefert: JSON::from_json auf die rohen Bytes von general.json
	my $fnraw = JSON::from_json('{"x":"' . Encode::encode_utf8('Küche') . '"}')->{x};
	ok(utf8::is_utf8($fnraw) && length($fnraw) == 6, 'Friendlyname-Eingabe in Form von lbfriendlyname (geflaggt, Bytes als Zeichen)');
	my ($SLc, $hostc) = tg_prepare(\%SLb, { friendlyname => $fnraw, hostname => 'loxberry', port => 80 });
	my $u = tg_format({SEVERITY=>3, _ISSYSTEM=>1, PACKAGE=>'t', NAME=>'n', MESSAGE=>'m', LOGFILE_REL=>'system/x.log'}, $SLc, $hostc);
	like($u, qr{>Logdatei öffnen</a>}, 'Umlaut aus Sprachdatei als Zeichen');
	like($u, qr{· Küche LoxBerry</b>}, 'Friendlyname mit Umlaut als Zeichen');
	unlike($u, qr/Ã/, 'kein Doppel-Encoding im Text');
	my (undef, $h2) = tg_prepare({}, { friendlyname => '', hostname => 'lb' });
	is($h2->{friendlyname}, 'lb', 'leerer Friendlyname -> Hostname');
	is(tg_chars('Küche'), 'Küche', 'Zeichen bleiben unverändert');
	is(tg_chars(Encode::encode_utf8('Küche')), 'Küche', 'UTF-8-Bytes werden dekodiert');
	is(tg_chars("Gr\x{fc}n \x{263a}"), "Gr\x{fc}n \x{263a}", 'Zeichen über 0xFF bleiben unverändert');
}

# --test: Empfaengername mit Umlaut steht genau einmal UTF-8-kodiert in der Ausgabe.
# Versand (tg_api) und Fehlermeldung (tg_report_errors) sind ersetzt - kein Netzwerk, keine DB.
{
	my $ucfg = "$dir/umlaut.json";
	write_bytes($ucfg, Encode::encode_utf8('{"ACTIVATE_TELEGRAM":1,"BOT_TOKEN":"1:x","RECIPIENTS":[{"NAME":"Küche","CHAT_ID":"42"}],"NOTIFICATION":{}}'));
	local $ENV{LBTELEGRAM_CONFIG} = $ucfg;
	delete local $ENV{LBTELEGRAM_DRYRUN};
	delete local $ENV{LBTELEGRAM_TOKEN};
	my (@sent, $reported);
	no warnings qw(redefine once);
	local *main::tg_api = sub { push @sent, [ @_ ]; return (1, {}); };
	local *main::tg_report_errors = sub { $reported++; };
	local @ARGV = ('--test');
	my $buf = '';
	open(my $cap, '>', \$buf) or die;
	my $old = select($cap);
	my $rc = main();
	select($old);
	close($cap);
	is($rc, 0, '--test: Rueckgabe 0');
	is(scalar(@sent), 1, '--test: ein (simulierter) Versand');
	is($sent[0][1], 'sendMessage', '--test: sendMessage');
	ok(utf8::is_utf8($sent[0][2]{text}) || $sent[0][2]{text} !~ /[\x80-\xff]/, '--test: Text als Zeichen an tg_api');
	my $enc = Encode::encode_utf8('Küche');
	my $cnt = () = $buf =~ /\Q$enc\E/g;
	is($cnt, 1, '--test: "Küche" genau einmal UTF-8-kodiert');
	unlike($buf, qr/\xC3\x83/, '--test: kein Doppel-Encoding');
	my $res = eval { decode_json($buf) };
	is($res && $res->{results}[0]{NAME}, 'Küche', '--test: NAME dekodiert korrekt');
	is($reported, 1, '--test: Fehlerbehandlung aufgerufen (ersetzt)');
}

# Kaputte Konfig: sauberes Fehler-JSON statt die
{
	my $bcfg = "$dir/broken.json";
	write_bytes($bcfg, '{kaputt');
	local $ENV{LBTELEGRAM_CONFIG} = $bcfg;
	delete local $ENV{LBTELEGRAM_TOKEN};
	no warnings qw(redefine once);
	local *main::tg_api = sub { die "tg_api darf nicht aufgerufen werden\n" };
	for my $mode ('--test', '--getme', '{"SEVERITY":3,"_ISSYSTEM":1,"MESSAGE":"m"}') {
		local @ARGV = ($mode);
		my $buf = '';
		open(my $cap, '>', \$buf) or die;
		my $old = select($cap);
		my $rc = eval { main() };
		select($old);
		close($cap);
		is($rc, 1, "kaputte Konfig ($mode): Rueckgabe 1") or diag($@);
		my $res = eval { decode_json($buf) };
		ok($res && !$res->{ok} && $res->{error}, "kaputte Konfig ($mode): Fehler-JSON");
	}
	is(tg_read_config("$dir/fehlt.json")->{x}, undef, 'fehlende Konfig = {}');
	ok(!-e "$dir/fehlt.json", 'fehlende Konfig wird nicht angelegt');
}

done_testing();
