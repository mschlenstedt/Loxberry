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

my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/mqtt-finder.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
);

my %SL = LoxBerry::System::readlanguage($maintemplate);

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

LoxBerry::Web::lbheader($template_title, $helplink);

print $maintemplate->output();

LoxBerry::Web::lbfooter();
