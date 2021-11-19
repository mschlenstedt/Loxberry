#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Web;

our $template_title = "LoxBerry File Analyzer";
our $helplink = "https://loxwiki.eu";

our $htmlhead = '<script type="application/javascript" src="/system/scripts/vue3/vue.global.js"></script>';

# Version of this script
my $version = "3.0.0.1";

my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/fileanalyzer.html",
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

