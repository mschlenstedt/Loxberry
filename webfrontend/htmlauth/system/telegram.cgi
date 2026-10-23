#!/usr/bin/perl

# Telegram als zweiter Benachrichtigungskanal: Einstellungen speichern und pruefen.
# AJAX-Aktionen (POST action=...): getcfg, savecfg, test, getme, getchats
# Der Bot-Token verlaesst den Server nie (keine Ausgabe an den Browser).

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::JSON;
use CGI;
use JSON;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

# Ueberschreibbar fuer Tests
our $TG_CFGFILE  = "$lbsconfigdir/telegram.json";
our $TG_DEFAULT  = "$lbsconfigdir/telegram.json.default";
our $TG_PROVIDER = "$lbssbindir/notifyproviders/telegram.pl";

our $cgi;
our %response;
our %SL;

my @NOTIFY_KEYS = qw(TELEGRAM_SYSTEM_ERRORS TELEGRAM_SYSTEM_INFOS TELEGRAM_PLUGIN_ERRORS TELEGRAM_PLUGIN_INFOS);

main() unless caller;

##########################################################################
# Main program
##########################################################################

sub main
{
	$cgi = CGI->new;
	$cgi->import_names('R');

	%response = ( error => -1, message => "Unspecified error" );

	# Prevent 'only used once' warnings from Perl
	$R::action if 0;

	my $action = $R::action // '';
	if ($action ne '') {
		%SL = LoxBerry::System::readlanguage(undef);
		my %in = map { $_ => scalar $cgi->param($_) } $cgi->param;
		tgcgi_action($action, \%in);
		jsonresponse();
	}

	# Keine Aktion: Seite
	form();
	exit(0);
}

sub tgcgi_action
{
	my ($action, $in) = @_;

	if ($action eq 'getcfg') {
		my $pub = tgcgi_public(tgcgi_load());
		%response = ( %$pub, error => 0 );
		return;
	}
	if ($action eq 'savecfg') {
		return tgcgi_save($in);
	}
	if ($action eq 'test' or $action eq 'getme' or $action eq 'getchats') {
		my %mode = ( test => '--test', getme => '--getme', getchats => '--getupdates' );
		my $token = ($action ne 'test' && defined $in->{bot_token} && $in->{bot_token} ne '') ? $in->{bot_token} : undef;
		my $out = tgcgi_provider($mode{$action}, $token);
		%response = ( customresponse => 1, output => $out, error => 0 );
		return;
	}
	$response{error} = 1;
	$response{message} = "Unknown action";
	return;
}

##########################################################################
# Konfiguration lesen / schreiben
##########################################################################

sub tgcgi_load
{
	my $file = -e $TG_CFGFILE ? $TG_CFGFILE : $TG_DEFAULT;
	my $obj = LoxBerry::JSON->new();
	my $cfg = $obj->open(filename => $file, readonly => 1) || {};
	$cfg->{ACTIVATE_TELEGRAM} //= 0;
	$cfg->{BOT_TOKEN} //= '';
	$cfg->{RECIPIENTS} = [] if ref $cfg->{RECIPIENTS} ne 'ARRAY';
	$cfg->{NOTIFICATION} = {} if ref $cfg->{NOTIFICATION} ne 'HASH';
	$cfg->{NOTIFICATION}{$_} //= 'true' for @NOTIFY_KEYS;
	return $cfg;
}

sub tgcgi_save
{
	my ($in) = @_;

	my $cfg = tgcgi_load();
	my ($ok, $errkey) = tgcgi_validate($in, $cfg->{BOT_TOKEN});
	if (!$ok) {
		$response{error} = 1;
		$response{message} = $SL{"TELEGRAM.$errkey"} // $errkey;
		return;
	}
	$cfg = tgcgi_merge($cfg, $in);

	my $saved = eval {
		# Datei nie fuer andere lesbar anlegen (Token)
		my $oldumask = umask(077);
		my $obj = LoxBerry::JSON->new();
		my $data = $obj->open(filename => $TG_CFGFILE);
		umask($oldumask);
		die "open failed\n" if !$data;
		chmod(0600, $TG_CFGFILE) or die "chmod failed\n";
		%$data = %$cfg;
		# write() liefert bei unveraenderten Daten leer zurueck - Erfolg per Nachlesen pruefen
		$obj->write();
		my $check = LoxBerry::JSON->new()->open(filename => $TG_CFGFILE, readonly => 1);
		die "verify failed\n" if !$check;
		my $j = JSON->new->canonical(1);
		die "verify failed\n" if $j->encode($check) ne $j->encode($cfg);
		chmod(0600, $TG_CFGFILE) or die "chmod failed\n";
		1;
	};
	if (!$saved) {
		$response{error} = 1;
		$response{message} = $SL{'TELEGRAM.SAVE_ERROR'};
		return;
	}
	$response{error} = 0;
	$response{message} = $SL{'TELEGRAM.SAVE_OK'};
	return;
}

##########################################################################
# Hilfsfunktionen (fuer Tests per require ladbar)
##########################################################################

# Empfaengerliste aus recipients_json bereinigen. undef = Feld nicht uebergeben.
# Rueckgabe: (\@liste, $fehlerschluessel)
sub tgcgi_recipients
{
	my ($in) = @_;
	return (undef, undef) if !defined $in->{recipients_json};
	my $raw = eval { decode_json($in->{recipients_json}) };
	return (undef, 'SAVE_ERROR') if ref $raw ne 'ARRAY';

	my @list;
	foreach my $r (@$raw) {
		next if ref $r ne 'HASH';
		my ($name, $id) = map { defined $_ ? $_ : '' } @$r{qw(NAME CHAT_ID)};
		# decode_json lieferte Zeichen; gespeichert wird UTF-8 als Bytes (wie LoxBerry::JSON)
		utf8::encode($name);
		utf8::encode($id);
		$name =~ s/^\s+|\s+$//g;
		$id =~ s/^\s+|\s+$//g;
		next if $name eq '' and $id eq '';
		return (undef, 'ERR_CHATID_FORMAT') if $id !~ /^-?\d+$/;
		push @list, { NAME => $name, CHAT_ID => $id };
	}
	my $n = 0;
	foreach my $r (@list) {
		$n++;
		$r->{NAME} = "Empfänger $n" if $r->{NAME} eq '';
	}
	return (\@list, undef);
}

sub tgcgi_validate
{
	my ($in, $stored_token) = @_;
	$stored_token //= '';

	my $token = $in->{bot_token} // '';
	$token =~ s/^\s+|\s+$//g;
	return (0, 'ERR_TOKEN_FORMAT') if $token ne '' and $token !~ /^\d+:[A-Za-z0-9_-]{30,}$/;

	my ($list, $err) = tgcgi_recipients($in);
	return (0, $err) if $err;

	if ($in->{activate_telegram}) {
		return (0, 'ERR_NO_TOKEN') if $token eq '' and $stored_token eq '';
		# Der Browser sendet die Empfaengerliste immer mit
		return (0, 'ERR_NO_RECIPIENT') if !$list or !@$list;
	}
	return (1, undef);
}

sub tgcgi_merge
{
	my ($cfg, $in) = @_;
	$cfg //= {};

	my $token = $in->{bot_token} // '';
	$token =~ s/^\s+|\s+$//g;
	$cfg->{BOT_TOKEN} = $token if $token ne '';
	$cfg->{BOT_TOKEN} //= '';

	$cfg->{ACTIVATE_TELEGRAM} = $in->{activate_telegram} ? 1 : 0 if defined $in->{activate_telegram};

	my ($list) = tgcgi_recipients($in);
	$cfg->{RECIPIENTS} = $list if $list;
	$cfg->{RECIPIENTS} //= [];

	$cfg->{NOTIFICATION} = {} if ref $cfg->{NOTIFICATION} ne 'HASH';
	foreach my $k (@NOTIFY_KEYS) {
		if (defined $in->{$k}) {
			$cfg->{NOTIFICATION}{$k} = ($in->{$k} eq 'true' || $in->{$k} eq '1') ? 'true' : 'false';
		}
	}
	return $cfg;
}

sub tgcgi_public
{
	my ($cfg) = @_;
	my %notif = %{ $cfg->{NOTIFICATION} || {} };
	return {
		ACTIVATE_TELEGRAM => $cfg->{ACTIVATE_TELEGRAM} ? 1 : 0,
		TOKEN_SET         => (defined $cfg->{BOT_TOKEN} && $cfg->{BOT_TOKEN} ne '') ? 1 : 0,
		RECIPIENTS        => [ @{ $cfg->{RECIPIENTS} || [] } ],
		NOTIFICATION      => \%notif,
	};
}

# Ruft den Provider auf; liefert immer einen gueltigen JSON-String.
# STDERR des Providers wird verworfen, der Token geht nur per Umgebung.
sub tgcgi_provider
{
	my ($mode, $token) = @_;
	my $out = '';
	{
		local $ENV{LBTELEGRAM_TOKEN} = $token if defined $token and $token ne '';
		local $ENV{LBTELEGRAM_CONFIG} = $TG_CFGFILE;
		my $pid = open(my $ph, '-|');
		if (defined $pid) {
			if ($pid == 0) {
				open(STDERR, '>', '/dev/null');
				exec($TG_PROVIDER, $mode) or exit(1);
			}
			local $/;
			$out = <$ph>;
			close($ph);
		}
	}
	my $parsed = eval { from_json($out // '') };
	if (ref $parsed ne 'HASH') {
		return to_json({ ok => 0, error => ($SL{'TELEGRAM.ERR_PROVIDER'} // 'Provider error') });
	}
	delete $parsed->{BOT_TOKEN};
	return to_json($parsed);
}

##########################################################################
# Ausgabe
##########################################################################

sub jsonresponse
{
	if ($response{error} == -1) {
		print $cgi->header(-type => 'application/json', -charset => 'utf-8', -status => '500 Internal Server Error');
	} else {
		print $cgi->header(-type => 'application/json', -charset => 'utf-8', -status => '200 OK');
	}

	if (!$response{customresponse}) {
		print to_json(\%response);
	} else {
		print $response{output};
	}
	exit($response{error});
}

sub form
{
	no warnings 'once';
	require LoxBerry::Web;
	require LoxBerry::Log;

	my $helptemplate = "help_telegram.html";
	my $helplink = "";    # Wiki-Seite folgt

	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/telegram.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
		%LoxBerry::Web::htmltemplate_options,
	);

	%SL = LoxBerry::System::readlanguage($maintemplate);

	my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'TELEGRAM.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print LoxBerry::Log::get_notifications_html("telegram");
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	return;
}

1;
