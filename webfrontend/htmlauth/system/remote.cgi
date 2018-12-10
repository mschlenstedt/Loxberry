#!/usr/bin/perl

# Copyright 2016-2018 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::JSON;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_remote.html";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.0.1";
my $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Language Settings
##########################################################################
my $lang = lblanguage();

##########################################################################
# Main program
##########################################################################

# Prevent 'only used once' warnings from Perl
# $R::saveformdata if 0;
$R::action if 0;
$R::value if 0;
$R::activate_mail if 0;
$R::secpin if 0;
$R::smptport if 0;
%LoxBerry::Web::htmltemplate_options if 0;

my $action = $R::action;
my $value = $R::value;

if ($action eq 'getmailcfg') { change_mailcfg("getmailcfg", $R::secpin);}
elsif ($action eq 'setmailcfg') { change_mailcfg("setmailcfg"); }
elsif ($action eq 'MAIL_SYSTEM_INFOS') { change_mailcfg("MAIL_SYSTEM_INFOS", $value);}
elsif ($action eq 'MAIL_SYSTEM_ERRORS') { change_mailcfg("MAIL_SYSTEM_ERRORS", $value);}
elsif ($action eq 'MAIL_PLUGIN_INFOS') { change_mailcfg("MAIL_PLUGIN_INFOS", $value);}
elsif ($action eq 'MAIL_PLUGIN_ERRORS') { change_mailcfg("MAIL_PLUGIN_ERRORS", $value);}
elsif ($action eq 'testmail') { testmail_button(); }


require LoxBerry::Web;
require LoxBerry::Log;


# If not ajax, it must be the form
&form;

exit;

#####################################################
# Form
#####################################################

sub form 
{
	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/remote.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		#associate => $cfg,
		%LoxBerry::Web::htmltemplate_options,
		# debug => 1,
		);

	my %SL = LoxBerry::System::readlanguage($maintemplate);

	$maintemplate->param("FORM", 1);

	# Print Template
	my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'REMOTE.WIDGETLABEL'};
	my $helplink;
	my $helptemplate;
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print LoxBerry::Log::get_notifications_html("remote");
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	exit;

}
