#!/usr/bin/perl

# Copyright 2017 CF for LoxBerry, christiantf@gmx.at
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
use LoxBerry::Web;
print STDERR "Execute myloxberry.cgi\n######################\n";

use CGI;
use warnings;
use strict;
my $load="";
##########################################################################
# Variables
##########################################################################

my $helplink = "https://www.loxwiki.eu/x/_oYKAw";
my $helptemplate = "help_myloxberry.html";
my $template_title;
my $error;

my $cfg;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.2.2";

my $sversion = LoxBerry::System::lbversion();

$cfg             = new Config::Simple("$lbsconfigdir/general.cfg");
#########################################################################
# Parameter
#########################################################################

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang
$load = $R::load if $R::load;

# Set default if not available
if (!$cfg->param("BASE.SENDSTATISTIC")) {
	$cfg->param("BASE.SENDSTATISTIC", "on");
	$cfg->save();
}

##########################################################################
# Language Settings
##########################################################################

if ($R::lang) {
	# Nice feature: We override language detection of LoxBerry::Web
	$LoxBerry::Web::lang = substr($R::lang, 0, 2);
}
# If we did the 'override', lblanguage will give us that language
my $lang = lblanguage();

our $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/myloxberry.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $cfg,
				#debug => 1,
				#stack_debug => 1,
				);

our %SL = LoxBerry::System::readlanguage($maintemplate);

$template_title = "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}: $SL{'MYLOXBERRY.WIDGETLABEL'} v$sversion";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

our %navbar;
$navbar{1}{Name} = "$SL{'MYLOXBERRY.LABEL_SETTINGS'}";
$navbar{1}{URL} = 'myloxberry.cgi?load=1';

$navbar{2}{Name} = "$SL{'MYLOXBERRY.LABEL_HEALTHCHECK'}";
$navbar{2}{URL} = 'healthcheck.cgi';
 
$navbar{3}{Name} = "$SL{'MYLOXBERRY.LABEL_SYSINFO'}";
$navbar{3}{URL} = 'myloxberry.cgi?load=2';

# Menu
if (!$R::saveformdata && $load eq "2") {
  $navbar{3}{active} = 1;
  &form;
} elsif (!$R::saveformdata) {
  $navbar{1}{active} = 1;
  &form;
} else {
  &save;
}

exit;

#####################################################
# Form / Menu 
#####################################################

sub form {

	if ($lang ne "en") {
		$maintemplate->param( "ISNOTENGLISH", 1);
	}

	if ($load eq "2") {
		$maintemplate->param( "FORM2", 1);
	} else {
		$maintemplate->param( "FORM1", 1);
	}

	$maintemplate->param ("SELFURL", $ENV{REQUEST_URI});

	my @values = LoxBerry::Web::iso_languages(1, 'values');
	my %labels = LoxBerry::Web::iso_languages(1, 'labels');
	my $langselector_popup = $cgi->popup_menu( 
			-name => 'languageselector',
			id => 'languageselector',
			-labels => \%labels,
			#-attributes => \%labels,
			-values => \@values,
			-default => $lang,
		);
	$maintemplate->param('LANGSELECTOR', $langselector_popup);
	
	our $sendstatistic_checkbox = $cgi->checkbox( -name => 'sendstatistic',
			  -checked => is_enabled($cfg->param("BASE.SENDSTATISTIC")),
			  -label => $SL{'MYLOXBERRY.LABEL_SENDSTATISTIC'}
	);
	$maintemplate->param('SENDSTATISTIC_CHECKBOX', $sendstatistic_checkbox);
		
	# Print Template
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Save
#####################################################
sub save
{
	my $friendlyname_changed;

	$maintemplate->param( "SAVE", 1);
	$maintemplate->param("SELFURL", $ENV{REQUEST_URI});
	$maintemplate->param("NEXTURL", "/admin/system/index.cgi?form=system");

	if ($R::lbfriendlyname ne $cfg->param("NETWORK.FRIENDLYNAME")) {
		$friendlyname_changed = 1;
	}
	$cfg->param("NETWORK.FRIENDLYNAME", $R::lbfriendlyname);
	$R::sendstatistic if (0);
	my $sendstatistic = is_enabled($R::sendstatistic) ? "on" : "off";
	$cfg->param("BASE.SENDSTATISTIC", $sendstatistic);
	$cfg->save();
	
	if ($friendlyname_changed)
	{ 
		my $ret = system("perl $lbshtmlauthdir/tools/generatelegacytemplates.pl --force");
		if ($ret == 0) {
			print STDERR "network.cgi: generatelegacytemplates.pl's was called successfully.\n";
		} else {
			print STDERR "network.cgi: generatelegacytemplates.pl's exit code has shown an ERROR.\n";
		}
	}
	
	# Print Template
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;
	
	
}


#####################################################
# Error
#####################################################

sub error {

	my $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/error.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				# associate => $cfg,
				);
	$maintemplate->param( "ERROR", $error);
	LoxBerry::System::readlanguage($maintemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;

}
