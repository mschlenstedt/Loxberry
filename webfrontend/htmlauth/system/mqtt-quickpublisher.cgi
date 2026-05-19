#!/usr/bin/perl

use LoxBerry::Web;
use LoxBerry::System;
use CGI;

my $template;

my $transformerdatafile = "/dev/shm/mqttgateway_transformers.json";


my $plugintitle = "MQTT Quick Publisher";
my $helplink = "nopanels";

$template = HTML::Template->new(
		filename => "$lbstemplatedir/mqtt-quickpublisher.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
	);

our %SL = LoxBerry::System::readlanguage($template);

LoxBerry::Web::lbheader($plugintitle, $helplink, undef);

$template->param( "transformers", LoxBerry::System::read_file( $transformerdatafile ) );
print $template->output();

LoxBerry::Web::lbfooter();
