#!/usr/bin/perl

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;
use CGI::Simple;

use warnings;
use strict;

my $q = CGI::Simple->new;
my $params = $q->Vars; 
my $nopanels = defined $params->{'nopanels'};

our $template_title = "MQTT Finder";
our $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt";
$helplink = "nopanels" if( $nopanels );

# Version of this script
my $version = "3.0.0.1";

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
			"URL" => "/admin/system/mqtt-finder.cgi"
		},
		{
			"Name" => "Log Files",
			"URL" => "/admin/system/mqtt-gateway.cgi?form=logs"
		}
	);


my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/mqtt-finder.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
# 	associate => $cgi,
#	%htmltemplate_options,
	#debug => 1,
);

my %SL = LoxBerry::System::readlanguage($maintemplate);

LoxBerry::Web::lbheader($template_title, $helplink);

print $maintemplate->output();

LoxBerry::Web::lbfooter();

