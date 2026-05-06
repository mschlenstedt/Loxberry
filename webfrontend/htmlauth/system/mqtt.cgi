#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Web;

my $plugintitle = "MQTT";
my $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt";
my $helptemplate = "help.html";

my $template = HTML::Template->new(
	filename => "$lbstemplatedir/mqtt.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
);

my %SL = LoxBerry::System::readlanguage($template);

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
		"Name" => "Logs",
		"URL" => "/admin/system/mqtt-gateway.cgi?form=logs"
	},
	{
		"Name" => "MQTT Finder",
		"URL" => "/admin/system/mqtt-finder.cgi"
	}
);

LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

print $template->output();

LoxBerry::Web::lbfooter();
