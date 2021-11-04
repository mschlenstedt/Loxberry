#!/usr/bin/perl

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;

use warnings;
use strict;

our $template_title = "MQTT Finder";
#our $helplink = "https://loxwiki.eu";
our $helplink = "nopanels";

# Version of this script
my $version = "2.4.0.1";

my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/mqttfinder.html",
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

