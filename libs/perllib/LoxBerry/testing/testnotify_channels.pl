use LoxBerry::Log; use Test::More;
my $p = \&LoxBerry::Log::notify_parse_channels;
is_deeply($p->({}),                            {mail=>1,telegram=>1}, 'fehlend = alle');
is_deeply($p->({CHANNELS=>''}),                {mail=>1,telegram=>1}, 'leer = alle');
is_deeply($p->({CHANNELS=>'Telegram'}),        {telegram=>1},         'Groß/klein egal');
is_deeply($p->({CHANNELS=>'mail, telegram'}),  {mail=>1,telegram=>1}, 'kommagetrennt');
is_deeply($p->({CHANNELS=>['mail']}),          {mail=>1},             'Array-Ref');
is_deeply($p->({'CHANNELS[0]'=>'telegram'}),   {telegram=>1},         'PHP-Array');
is_deeply($p->({CHANNELS=>'pushover'}),        {mail=>1,telegram=>1}, 'nur unbekannt = alle');
is_deeply($p->({CHANNELS=>'mail,pushover'}),   {mail=>1},             'unbekannt ignoriert');
is_deeply($p->({CHANNELS=>"mail\0telegram"}),  {mail=>1,telegram=>1}, 'CGI::Vars-Wiederholfeld (\0)');
is_deeply($p->({CHANNELS=>"telegram\0"}),      {telegram=>1},         'CGI::Vars mit leerem Teil');
my %d = (PACKAGE=>'t', CHANNELS=>'mail', 'CHANNELS[0]'=>'x');
my $c = LoxBerry::Log::notify_strip_channels(\%d);
ok(!exists $c->{CHANNELS} && !exists $c->{'CHANNELS[0]'} && $c->{PACKAGE} eq 't', 'strip');
is($d{CHANNELS}, 'mail', 'Original unverändert');
my $cfg = { ACTIVATE_TELEGRAM=>1, BOT_TOKEN=>'1:x', RECIPIENTS=>[{NAME=>'a',CHAT_ID=>'5'}],
	NOTIFICATION=>{TELEGRAM_SYSTEM_ERRORS=>'true',TELEGRAM_SYSTEM_INFOS=>'true',TELEGRAM_PLUGIN_ERRORS=>'true',TELEGRAM_PLUGIN_INFOS=>'false'} };
my $w = \&LoxBerry::Log::notify_telegram_wanted;
is($w->({SEVERITY=>3,_ISSYSTEM=>1}, $cfg), 1, 'Systemfehler');
is($w->({SEVERITY=>6,_ISPLUGIN=>1}, $cfg), 0, 'Plugininfo aus');
is($w->({SEVERITY=>4,_ISSYSTEM=>1}, $cfg), 0, 'Warnung nie');
is($w->({SEVERITY=>3,_ISSYSTEM=>1}, {%$cfg, ACTIVATE_TELEGRAM=>0}), 0, 'deaktiviert');
is($w->({SEVERITY=>3,_ISSYSTEM=>1}, {%$cfg, BOT_TOKEN=>''}), 0, 'ohne Token');
is($w->({SEVERITY=>3,_ISSYSTEM=>1}, {%$cfg, RECIPIENTS=>[{NAME=>'a',CHAT_ID=>''}]}), 0, 'ohne Chat-ID');
is($w->({SEVERITY=>3,_ISSYSTEM=>1}, undef), 0, 'keine Config');

# notify_send_telegram: legt keine telegram.json an und stirbt nicht an kaputter Datei.
# Konfigordner auf ein Temp-Verzeichnis umgebogen, Provider = /bin/false (es wird nichts versendet).
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Spec;
{
	my $tdir = tempdir(DIR => dirname(File::Spec->rel2abs($0)), CLEANUP => 1);
	local $LoxBerry::System::lbsconfigdir = $tdir;
	local $LoxBerry::Log::telegram_provider = '/bin/false';
	my %n = (PACKAGE=>'t', NAME=>'n', MESSAGE=>'m', SEVERITY=>3, _ISSYSTEM=>1);
	my $ok = eval { LoxBerry::Log::notify_send_telegram(\%n); 1 };
	ok($ok, 'fehlende telegram.json: kein die') or diag($@);
	ok(!-e "$tdir/telegram.json", 'fehlende telegram.json wird nicht angelegt');
	open(my $fh, '>', "$tdir/telegram.json") or die; print $fh '{kaputt'; close $fh;
	{
		# parse() meldet den Fehler auf STDERR - hier unterdruecken
		local *STDERR;
		open(STDERR, '>', File::Spec->devnull());
		$ok = eval { LoxBerry::Log::notify_send_telegram(\%n); 1 };
		ok($ok, 'kaputte telegram.json: notify_send_telegram stirbt nicht') or diag($@);
		$ok = eval { LoxBerry::Log::notify_send_channels({%n, CHANNELS=>'telegram'}); 1 };
		ok($ok, 'kaputte telegram.json: Kanalverteiler stirbt nicht') or diag($@);
	}
	ok(-s "$tdir/telegram.json" == 7, 'kaputte telegram.json bleibt unverändert');
}
done_testing();
