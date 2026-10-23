#!/usr/bin/perl
# Tests fuer sbin/notifyproviders/telegram.pl
# Nur reine Funktionen und der DRYRUN-Pfad: kein Netzwerk, kein Versand, keine Benachrichtigungs-DB.
#
# Aufruf:
#   TG_PROVIDER=/pfad/zu/telegram.pl perl -I<dir mit LoxBerry/Log.pm> testnotify_telegram.pl
use utf8;
use strict;
use warnings;
use LoxBerry::Log;
use Test::More;
use JSON;
use File::Basename;

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

# utf8_roundtrip (DRYRUN)
my $dir = $ENV{TG_TESTDIR} // dirname(dirname($prov));
my $cfgfile = "$dir/telegram_test_config.json";
open(my $fh, '>', $cfgfile) or die "cannot write $cfgfile: $!";
print $fh '{"ACTIVATE_TELEGRAM":1,"BOT_TOKEN":"1:x","RECIPIENTS":[{"NAME":"Test","CHAT_ID":"42"}],"NOTIFICATION":{}}';
close $fh;
{
	$LoxBerry::Log::telegram_provider = $prov;
	local $ENV{LBTELEGRAM_DRYRUN} = 1;
	local $ENV{LBTELEGRAM_TOKEN} = '1:x';
	local $ENV{LBTELEGRAM_CONFIG} = $cfgfile;
	local $ENV{PERL5LIB} = join(':', grep { defined && length } ($dir, $ENV{PERL5LIB}));
	chmod 0755, $prov;
	my $cmd = LoxBerry::Log::notify_telegram_command({SEVERITY=>3, _ISSYSTEM=>1, PACKAGE=>'t', NAME=>'n', MESSAGE=>'Benötigt Ä ß €'});
	my $out = qx($cmd 2>&1);
	my $res = eval { decode_json($out) };
	ok($res && ref($res) eq 'ARRAY', 'DRYRUN liefert JSON-Array') or diag($out);
	like($res->[0]{text} // '', qr/Benötigt Ä ß €/, 'utf8_roundtrip');
	is($res->[0]{chat_id}, '42', 'chat_id');
	unlike($out, qr/1:x/, 'Token nicht in der Ausgabe');
}
unlink $cfgfile;

done_testing();
