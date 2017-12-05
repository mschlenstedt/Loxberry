#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
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

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use Config::Simple;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_power.html";

our $cfg;
our $phrase;
our $namef;
our $value;
our %query;
our $lang;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $installfolder;
our $languagefile;
our $version;
our $rebootbin;
our $poweroffbin;
our $do;
our $output;
our $message;
our $nexturl;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.3.1-dev1";

$cfg                = new Config::Simple("$lbsconfigdir/general.cfg");
#$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
#$lang            = $cfg->param("BASE.LANG");
$rebootbin       = $cfg->param("BINARIES.REBOOT");
$poweroffbin     = $cfg->param("BINARIES.POWEROFF");

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/power.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $cfg,
			# debug => 1,
			);

LoxBerry::Web::readlanguage($maintemplate);

#########################################################################
# Parameter
#########################################################################

# Everything from URL
foreach (split(/&/,$ENV{'QUERY_STRING'})){
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# And this one we really want to use
$do           = $query{'do'};

# Filter
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

##########################################################################
# Language Settings
##########################################################################

$lang = lblanguage();
$maintemplate->param( "LBHOSTNAME", lbhostname());
$maintemplate->param( "LANG", $lang);
$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});
$maintemplate->param ( "NEXTURL", "/admin/system/index.cgi?form=system");


##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# What should we do?

# Reboot
if ($do eq "reboot") {
  print STDERR "REBOOT called\n";
  $maintemplate->param("REBOOT", 1);
  &reboot;
}

# Poweroff
if ($do eq "poweroff") {
  print STDERR "POWEROFF called\n";
  $maintemplate->param("POWEROFF", 1);
  &poweroff;
}

# Everything else
print STDERR "MENU called\n";
$maintemplate->param("MENU", 1);
&form;

exit;

#####################################################
# Menue
#####################################################

sub form {
	
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'POWER.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	undef $maintemplate;			
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;

exit;

}

#####################################################
# Reboot
#####################################################

sub reboot {

	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'POWER.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	undef $maintemplate;			
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	# # Reboot
	# # Without the following workaround
	# # the script cannot be executed as
	# # background process via CGI
	# my $pid = fork();
	# die "Fork failed: $!" if !defined $pid;
	# if ($pid == 0) {
	# # do this in the child
	 # open STDIN, "</dev/null";
	 # open STDOUT, ">/dev/null";
	 # open STDERR, ">/dev/null";
	 # # system("sleep 5 && sudo $rebootbin &");
	# }
	exit;
}

#####################################################
# Poweroff
#####################################################

sub poweroff {

	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'POWER.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	undef $maintemplate;			
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();

	# # Poweroff
	# # Without the following workaround
	# # the script cannot be executed as
	# # background process via CGI
	# my $pid = fork();
	# die "Fork failed: $!" if !defined $pid;
	# if ($pid == 0) {
	# # do this in the child
	 # open STDIN, "</dev/null";
	 # open STDOUT, ">/dev/null";
	 # open STDERR, ">/dev/null";
	 # # system("sleep 5 && sudo $poweroffbin &");
	# }
	exit;
}
