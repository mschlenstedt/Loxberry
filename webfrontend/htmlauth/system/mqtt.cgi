#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Web;

my $plugintitle = "MQTT (V" . LoxBerry::System::lbversion() . ")";
my $helplink = "https://www.loxwiki.eu/x/S4ZYAg";
my $helptemplate = "help.html";

	our @navbar = (
		{
			"Name" => "MQTT Basics",
			"URL" => "/admin/system/mqtt.cgi"
		},
		{
			"Name" => "MQTT Gateway",
			"Submenu" => [
				{
					"Name" => "Gateway Settings",
					"URL" => "/admin/system/mqtt-gateway.cgi"
				},
				{
					"Name" => "Gateway Subscriptions",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=subscriptions"
				},
				{
					"Name" => "Gateway Conversions",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=conversions"
				},
				{
					"Name" => "Incoming Overview",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=incoming"
				},
				{
					"Name" => "Gateway Transformers",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=transformers"
				}
			]
		},
		{
			"Name" => "MQTT Finder",
			"URL" => "/admin/system/tools/mqttfinder.cgi"
		},
		{
			"Name" => "Log Files",
			"URL" => "/admin/system/mqtt-gateway.cgi?form=logs"
		}
	);
	
my $template = HTML::Template->new(
	filename => "$lbstemplatedir/mqtt.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
);
	
LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

print $template->output();

LoxBerry::Web::lbfooter();
