#!/usr/bin/perl

# LoxBerry notification provider: Telegram
#
# Aufrufarten (jede druckt genau ein JSON-Objekt auf STDOUT, Exit 0 = ok, 1 = Fehler):
#   telegram.pl '<json>'      Benachrichtigung an alle Empfaenger senden (aufgerufen von LoxBerry::Log)
#   telegram.pl --test        Testnachricht an alle Empfaenger
#   telegram.pl --getme       Bot pruefen (getMe)
#   telegram.pl --getupdates  Chats ermitteln, die dem Bot geschrieben haben (getUpdates)
#
# Umgebungsvariablen:
#   LBTELEGRAM_TOKEN   Bot-Token; ueberschreibt BOT_TOKEN aus telegram.json (nutzt auch die Einstellungsseite)
#   LBTELEGRAM_CONFIG  nur fuer Tests: Pfad einer Konfig, die statt telegram.json gelesen wird
#   LBTELEGRAM_DRYRUN  nur fuer Tests: nichts senden, stattdessen [{"chat_id":..,"text":..}] drucken
#
# Der Bot-Token darf nie in Ausgaben oder Benachrichtigungen landen (siehe tg_mask).

use strict;
use warnings;
use utf8;
use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::Log;
use JSON ();
use Encode ();
use LWP::UserAgent;

my $TG_MAXLEN = 4096;

exit(main()) unless caller;

sub main
{
	my $arg = $ARGV[0];
	if (!defined $arg or $arg eq '') {
		tg_out({ ok => 0, error => 'missing argument' });
		return 1;
	}

	my $cfgfile = $ENV{LBTELEGRAM_CONFIG} || "$LoxBerry::System::lbsconfigdir/telegram.json";
	my $cfg = {};
	if (-r $cfgfile) {
		my $cfgobj = LoxBerry::JSON->new();
		$cfg = $cfgobj->open(filename => $cfgfile, readonly => 1) || {};
	}
	my $token = defined $ENV{LBTELEGRAM_TOKEN} && $ENV{LBTELEGRAM_TOKEN} ne '' ? $ENV{LBTELEGRAM_TOKEN} : ($cfg->{BOT_TOKEN} // '');

	my %SL = LoxBerry::System::readlanguage(undef, undef, 1);
	my $hostname = LoxBerry::System::lbhostname();
	my $friendlyname = LoxBerry::System::lbfriendlyname();
	$friendlyname = $hostname if (!defined $friendlyname or $friendlyname eq '');
	my %host = (
		friendlyname => $friendlyname,
		hostname     => $hostname,
		port         => LoxBerry::System::lbwebserverport(),
	);

	if ($arg eq '--getme') {
		return tg_mode_getme($token);
	}
	if ($arg eq '--getupdates') {
		return tg_mode_getupdates($token);
	}

	my $text;
	my $mode;
	if ($arg eq '--test') {
		$mode = 'test';
		$text = tg_format_test(\%SL, \%host);
	}
	else {
		$mode = 'notify';
		my $p = tg_decode_arg($arg);
		if (ref($p) ne 'HASH') {
			tg_out({ ok => 0, error => 'invalid notification argument' });
			return 1;
		}
		$text = tg_format($p, \%SL, \%host);
	}

	my @recipients = grep { ref($_) eq 'HASH' and defined $_->{CHAT_ID} and $_->{CHAT_ID} ne '' } @{ $cfg->{RECIPIENTS} || [] };

	if ($ENV{LBTELEGRAM_DRYRUN}) {
		tg_out([ map { { chat_id => "$_->{CHAT_ID}", text => $text } } @recipients ]);
		return 0;
	}

	if ($token eq '' or !@recipients) {
		tg_out({ ok => 0, results => [], error => 'no bot token or no recipients configured' });
		return 1;
	}

	my @results;
	foreach my $r (@recipients) {
		my ($ok, $res) = tg_api($token, 'sendMessage', {
			chat_id                  => "$r->{CHAT_ID}",
			text                     => $text,
			parse_mode               => 'HTML',
			disable_web_page_preview => JSON::true(),
		});
		push @results, {
			NAME    => $r->{NAME} // '',
			CHAT_ID => "$r->{CHAT_ID}",
			ok      => $ok ? 1 : 0,
			($ok ? () : (error => $res)),
		};
	}

	my @failed = grep { !$_->{ok} } @results;
	tg_report_errors(\@failed, \%SL);

	tg_out({ ok => (@failed ? 0 : 1), results => \@results });
	return @failed ? 1 : 0;
}

########################################################
# Modes: getMe / getUpdates
########################################################

sub tg_mode_getme
{
	my ($token) = @_;
	if ($token eq '') {
		tg_out({ ok => 0, error => 'no bot token configured' });
		return 1;
	}
	my ($ok, $res) = tg_api($token, 'getMe', {});
	if (!$ok) {
		tg_out({ ok => 0, error => $res });
		return 1;
	}
	tg_out({ ok => 1, username => $res->{username} // '' });
	return 0;
}

sub tg_mode_getupdates
{
	my ($token) = @_;
	if ($token eq '') {
		tg_out({ ok => 0, error => 'no bot token configured' });
		return 1;
	}
	my ($ok, $res) = tg_api($token, 'getUpdates', {
		limit           => 100,
		timeout         => 0,
		allowed_updates => [ 'message', 'channel_post', 'my_chat_member' ],
	});
	if (!$ok) {
		tg_out({ ok => 0, error => $res });
		return 1;
	}

	my (%seen, @chats);
	# Updates come in ascending order, newest first is wanted
	foreach my $u (reverse @{ $res || [] }) {
		my $chat;
		foreach my $key (qw(message channel_post my_chat_member)) {
			if (ref($u->{$key}) eq 'HASH' and ref($u->{$key}->{chat}) eq 'HASH') {
				$chat = $u->{$key}->{chat};
				last;
			}
		}
		next if (!$chat or !defined $chat->{id});
		my $id = "$chat->{id}";
		next if ($seen{$id}++);
		my $name;
		if (defined $chat->{title} and $chat->{title} ne '') {
			$name = $chat->{title};
		}
		else {
			$name = join(' ', grep { defined and $_ ne '' } ($chat->{first_name}, $chat->{last_name}));
			$name = '@' . $chat->{username} if ($name eq '' and defined $chat->{username} and $chat->{username} ne '');
		}
		push @chats, { CHAT_ID => $id, NAME => $name };
		last if (@chats >= 10);
	}
	tg_out({ ok => 1, chats => \@chats });
	return 0;
}

########################################################
# Error handling for the notification mode
# The error notification is restricted to the mail channel, so it can
# never be routed back to telegram.
########################################################

sub tg_report_errors
{
	my ($failed, $SL) = @_;

	if (@$failed) {
		my @cnt = LoxBerry::Log::get_notification_count("telegram", "telegramerror");
		my $sum = $cnt[2] // 0;
		if ($sum == 0) {
			my $err = $failed->[0]->{error} // '';
			LoxBerry::Log::notify_ext({
				PACKAGE  => 'telegram',
				NAME     => 'telegramerror',
				MESSAGE  => ($SL->{'TELEGRAM.NOTIFY_SEND_ERROR'} // '') . " $err",
				SEVERITY => 3,
				_ISSYSTEM => 1,
				CHANNELS => 'mail',
			});
		}
	}
	else {
		LoxBerry::Log::delete_notifications("telegram", "telegramerror");
	}
}

########################################################
# Formatting
########################################################

sub tg_esc
{
	my ($s) = @_;
	$s = '' if (!defined $s);
	$s =~ s/&/&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	return $s;
}

# Attribute value (href): additionally escape quotes
sub tg_esc_attr
{
	my $s = tg_esc(@_);
	$s =~ s/"/&quot;/g;
	return $s;
}

# Notification message to Telegram-HTML: br/p -> newline, other tags removed, then escaped
sub tg_message_plain
{
	my ($m) = @_;
	$m = '' if (!defined $m);
	$m =~ s{<\s*br\s*/?\s*>}{\n}gi;
	$m =~ s{</?\s*p(?:\s[^>]*)?>}{\n}gi;
	$m =~ s{</?[A-Za-z][^>]*>}{}g;
	$m =~ s/^\s+|\s+$//g;
	return $m;
}

sub tg_capitalize
{
	my ($s) = @_;
	$s = '' if (!defined $s);
	$s =~ s/([^\s\w]*)(\S+)/$1\u\L$2/g;
	return $s;
}

# tg_format(\%p, \%SL, \%host) -> text
sub tg_format
{
	my ($p, $SL, $host) = @_;
	my $iserror = ($p->{SEVERITY} // 0) == 3;
	my $fn = tg_esc($host->{friendlyname});

	my @head;
	push @head, ($iserror ? '🔴' : 'ℹ️') . ' <b>' . tg_esc($SL->{$iserror ? 'TELEGRAM.MSG_ERROR' : 'TELEGRAM.MSG_INFO'})
		. " · $fn LoxBerry</b>";

	my $package = tg_capitalize($p->{PACKAGE});
	my $name = tg_capitalize($p->{NAME});
	if ($p->{_ISSYSTEM}) {
		push @head, '<b>' . tg_esc($SL->{'TELEGRAM.MSG_SYSTEM'}) . '</b> · ' . tg_esc("$package $name");
	}
	elsif ($p->{_ISPLUGIN}) {
		my $title = defined $p->{PLUGINTITLE} && $p->{PLUGINTITLE} ne '' ? $p->{PLUGINTITLE} : $package;
		push @head, '<b>' . tg_esc($SL->{'TELEGRAM.MSG_PLUGIN'}) . ' ' . tg_esc($title) . '</b> · ' . tg_esc($name);
	}

	my @tail;
	if (defined $p->{LINK} and $p->{LINK} ne '') {
		push @tail, '<a href="' . tg_esc_attr($p->{LINK}) . '">' . tg_esc($SL->{'TELEGRAM.MSG_LINK'}) . '</a>';
	}
	if (defined $p->{LOGFILE_REL} and $p->{LOGFILE_REL} ne '') {
		push @tail, '<a href="http://' . tg_esc_attr($host->{hostname}) . ':' . tg_esc_attr($host->{port})
			. '/admin/system/tools/logfile.cgi?logfile=' . tg_esc_attr($p->{LOGFILE_REL})
			. '&amp;header=html&amp;format=template">' . tg_esc($SL->{'TELEGRAM.MSG_LOGFILE'}) . '</a>';
	}

	my $msg = tg_message_plain($p->{MESSAGE});
	my $build = sub {
		my ($m) = @_;
		my @lines = @head;
		push @lines, tg_esc($m) if ($m ne '');
		push @lines, @tail;
		return join("\n", @lines);
	};

	my $text = $build->($msg);
	if (length($text) > $TG_MAXLEN) {
		# Only MESSAGE is shortened (binary search for the longest fitting prefix)
		my ($lo, $hi) = (0, length($msg));
		while ($lo < $hi) {
			my $mid = int(($lo + $hi + 1) / 2);
			if (length($build->(substr($msg, 0, $mid) . '…')) <= $TG_MAXLEN) { $lo = $mid; }
			else { $hi = $mid - 1; }
		}
		$text = $build->(substr($msg, 0, $lo) . '…');
	}
	return $text;
}

sub tg_format_test
{
	my ($SL, $host) = @_;
	return '✅ <b>' . tg_esc($SL->{'TELEGRAM.MSG_TEST'}) . ' · ' . tg_esc($host->{friendlyname}) . " LoxBerry</b>\n"
		. tg_esc($SL->{'TELEGRAM.MSG_TESTTEXT'});
}

########################################################
# Helpers
########################################################

# Replace the token by *** (also in error texts containing the API URL)
sub tg_mask
{
	my ($text, $token) = @_;
	$text = '' if (!defined $text);
	return $text if (!defined $token or $token eq '');
	$text =~ s/\Q$token\E/***/g;
	return $text;
}

# tg_api($token, $method, \%params) -> ($ok, $result_or_errortext)
sub tg_api
{
	my ($token, $method, $params) = @_;

	my $ua = LWP::UserAgent->new(timeout => 10, ssl_opts => { verify_hostname => 1 });
	$ua->agent('LoxBerry-Telegram/1.0');
	my $resp = eval {
		$ua->post(
			"https://api.telegram.org/bot$token/$method",
			'Content-Type' => 'application/json; charset=utf-8',
			Content        => JSON->new->utf8->encode($params || {}),
		);
	};
	if (!$resp) {
		return (0, tg_mask("request failed: " . ($@ // 'unknown'), $token));
	}

	my $data = eval { JSON->new->utf8->decode($resp->decoded_content(charset => 'none')) };
	if (ref($data) eq 'HASH' and $data->{ok}) {
		return (1, $data->{result});
	}
	my $err = ref($data) eq 'HASH' && defined $data->{description} ? $data->{description} : $resp->status_line;
	return (0, tg_mask($err, $token));
}

# Argument is UTF-8; fall back to Latin-1 if the caller handed over a downgraded string
sub tg_decode_arg
{
	my ($arg) = @_;
	my $copy = $arg;
	my $chars = eval { Encode::decode('UTF-8', $copy, Encode::FB_CROAK() | Encode::LEAVE_SRC()) };
	$chars = Encode::decode('ISO-8859-1', $arg) if (!defined $chars);
	return eval { JSON->new->decode($chars) };
}

sub tg_out
{
	my ($obj) = @_;
	print JSON->new->utf8->canonical->encode($obj), "\n";
}

1;
