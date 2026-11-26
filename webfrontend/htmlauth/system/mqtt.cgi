#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use CGI qw/:standard/;
use JSON;

# AJAX: SecurePIN check
my $cgi = CGI->new;
if ($cgi->param("action") && $cgi->param("action") eq "checksecpin") {
	my %resp;
	my $checkres = LoxBerry::System::check_securepin($cgi->param("secpin"));
	$resp{error} = int($checkres);
	print header('application/json');
	print to_json(\%resp);
	exit;
}

# AJAX: broker settings incl. user and password - only after a correct
# SecurePIN (#1624). The page reads them from here, not from ajax-generic.php.
if ($cgi->param("action") && $cgi->param("action") eq "getcfg") {
	my %resp;
	my $checkres = LoxBerry::System::check_securepin(scalar $cgi->param("secpin"));
	$resp{error} = int($checkres // 0);
	if ( !$resp{error} ) {
		require LoxBerry::JSON;
		my $jsonobj = LoxBerry::JSON->new();
		my $cfg = $jsonobj->open(filename => "$lbsconfigdir/general.json", readonly => 1);
		$resp{Mqtt} = ( $cfg && $cfg->{Mqtt} ) ? $cfg->{Mqtt} : {};
	}
	print header(-type => 'application/json', -Cache_Control => 'no-store');
	print to_json(\%resp);
	exit;
}

my $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt";
my $helptemplate = "help.html";

my $template = HTML::Template->new(
	filename => "$lbstemplatedir/mqtt.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
);

my %SL = LoxBerry::System::readlanguage($template);
my $plugintitle = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'MQTT.WIDGETLABEL'};

our @navbar = (
	{
		"Name" => "MQTT Basics",
		"URL" => "/admin/system/mqtt.cgi"
	},
	{
		"Name" => "Gateway",
		"URL" => "/admin/system/mqtt-gateway.cgi"
	},
	{
		"Name" => $SL{'MQTT.TAB_SUBSCRIPTIONS'},
		"URL" => "/admin/system/mqtt-gateway.cgi?form=subscriptions"
	},
	{
		"Name" => $SL{'MQTT.V2_SECTION_TRAFFIC'},
		"URL" => "/admin/system/mqtt-gateway.cgi?form=incoming"
	},
	{
		"Name" => "MQTT Finder",
		"URL" => "/admin/system/mqtt-finder.cgi"
	},
	{
		"Name" => "Logs",
		"URL" => "/admin/system/mqtt-gateway.cgi?form=logs"
	}
);

LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);
# Alle Meldungen des Pakets mqtt - dieselben, die die MQTT-Kachel zählt
print LoxBerry::Log::get_notifications_html('mqtt');

print $template->output();

LoxBerry::Web::lbfooter();
