#!/usr/bin/perl

# Copyright 2016-2017 Michael Schlenstedt, michael@loxberry.de
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

use CGI qw/:standard/;
use LWP::UserAgent;
# use CGI::Session;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_myloxberry.html";
my $template_title;
my $error;

##########################################################################
# Read Configuration
##########################################################################

# Version of this script
my $version = "0.3.1-dev1";
my $sversion = LoxBerry::System::lbversion();

my $cfg = new Config::Simple("$lbsconfigdir/general.cfg");
my %Config = $cfg->vars();
my $startsetup = $Config{'BASE.STARTSETUP'};

#########################################################################
# Parameter
#########################################################################

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang

# Filter 
if ($R::nostartsetup) {
  $R::nostartsetup =~ tr/0-1//cd;
  $R::nostartsetup = substr($R::nostartsetup,0,1);
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
				filename => "$lbstemplatedir/index.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $cfg,
				#debug => 1,
				#stack_debug => 1,
				);

our %SL = LoxBerry::Web::readlanguage($maintemplate);

$template_title = "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}";

##########################################################################
# Main program
##########################################################################

##########################################################################
# Check for first start and setup assistent
##########################################################################

# If no setup assistant is wanted, don't bother user anymore
if ($R::nostartsetup) {
  $startsetup = 0;
  $cfg->param("BASE.STARTSETUP", "0");
  $cfg->save();
}

# If Setup assistant wasn't started yet, ask user
if ($startsetup) {
  INFO("Startsetup called");
  #print "Content-Type: text/html\n\n";

  #$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017");
  # $help = "setup00";

  # # Print Template
  # &header;
  # open(F,"$lbhomedir/templates/system/$lang/firststart.html") || die "Missing template admin/$lang/firststart.html";
    # while (<F>) {
      # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      # print $_;
    # }
  # close(F);
  # &footer;

  exit;

}

#########################################################################
# What should we do
#########################################################################

# Nothing todo? Goto Main menu
&mainmenu;

exit;

#####################################################
# Main Meenu
#####################################################

sub mainmenu {

	if ($R::form ne "system") {

		# Load PLUGIN database
		my $plugindb_file = "$lbsdatadir/plugindatabase.dat";
		my $openerr;
		open(my $fh, "<", $plugindb_file) or ($openerr = 1);
		if ($openerr) {
			$error= "$0: Error opening plugin database $plugindb_file";
			# &error;
			return undef;
			}
		my @data = <$fh>;

		my @plugins = ();
		foreach (@data){
			s/[\n\r]//g;
			# Comments
			if ($_ =~ /^\s*#.*/) {
				next;
			}
			my @fields = split(/\|/);

			## Start Debug fields of Plugin-DB
			do {
				my $field_nr = 0;
				my $dbg_fields = "Plugin-DB Fields: ";
				foreach (@fields) {
					$dbg_fields .= "$field_nr: $_ | ";
					$field_nr++;
				}
				INFO($dbg_fields);
			} ;
			## End Debug fields of Plugin-DB
			
			my %plugin;
			# From Plugin-DB
			$plugin{PLUGIN_MD5_CHECKSUM} = $fields[0];
			$plugin{PLUGIN_AUTHOR_NAME} = $fields[1];
			$plugin{PLUGIN_AUTHOR_EMAIL} = $fields[2];
			$plugin{PLUGIN_VERSION} = $fields[3];
			$plugin{PLUGIN_NAME} = $fields[4];
			$plugin{PLUGIN_FOLDER} = $fields[5];
			$plugin{PLUGIN_TITLE} = $fields[6];
			$plugin{PLUGIN_INTERFACE} = $fields[7];
			push(@plugins, \%plugin);
		}
		$maintemplate->param('PLUGINS' => \@plugins);
	} else {
		# Create SYSTEM widget list
		
		# Prepare System Date Time for Love Clock
		our $systemdatetime = time()*1000;
		(our $sec, our $min, our $hour, our $mday, our $mon, our $year, our $wday, our $yday, our $isdst) = localtime();
		our $systemdate = $year + 1900 . "-" . sprintf ('%02d' ,$mon) . "-" . sprintf ('%02d' ,$mday);
		$maintemplate->param( 	'SEC' => $sec,
								'MIN' => $min,
								'HOUR' => $hour
							);
		
		$maintemplate->param('WIDGETS' => [
			{ 
				WIDGET_TITLE => $SL{'HEADER.PANEL_MYLOXBERRY'}, 
				WIDGET_ICON => "/system/images/icons/main_myloxberry.png",
				WIDGET_CGI => "/admin/system/myloxberry.cgi"
			} ,
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_ADMIN'},
				WIDGET_ICON => "/system/images/icons/main_admin.png", 
				WIDGET_CGI => "/admin/system/admin.cgi"
			} ,
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_MINISERVER'}, 
				WIDGET_ICON => "/system/images/icons/main_miniserver.png",
				WIDGET_CGI => "/admin/system/miniserver.cgi"
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_TIMESERVER'},
				WIDGET_ICON => "/system/images/icons/blank_64.png",
				WIDGET_CGI => "/admin/system/timeserver.cgi",
				WIDGET_CLOCK => 1
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_NETWORK'},
				WIDGET_ICON => "/system/images/icons/main_network.png",
				WIDGET_CGI => "/admin/system/network.cgi"
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_PLUGININSTALL'},
				WIDGET_ICON => "/system/images/icons/main_plugininstall.png",
				WIDGET_CGI => "/admin/system/plugininstall.cgi"
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_UPDATES'},
				WIDGET_ICON => "/system/images/icons/main_updates.png",
				WIDGET_CGI => "/admin/system/updates.cgi"
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_REBOOT'},
				WIDGET_ICON => "/system/images/icons/main_power.png",
				WIDGET_CGI => "/admin/system/power.cgi"
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_MAILSERVER'},
				WIDGET_ICON => "/system/images/icons/main_mail.png",
				WIDGET_CGI => "/admin/system/mailserver.cgi"
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_SETUPASSISTENT'},
				WIDGET_ICON => "/system/images/icons/main_setupassistent.png",
				WIDGET_CGI => "/admin/system/setup/index.cgi"
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_DONATE'},
				WIDGET_ICON => "/system/images/icons/main_donate.png",
				WIDGET_CGI => "/admin/system/donate.cgi"
			}
		]);
		
	}

	$maintemplate->param( 'SVERSION' => $sversion);
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . " <span class='hint'>V$sversion</span>";
	LoxBerry::Web::head();

	our %navbar;
	$navbar{1}{Name} = $SL{'HEADER.TITLE_PAGE_PLUGINS'};
	$navbar{1}{URL} = "index.cgi";
	$navbar{2}{Name} = $SL{'HEADER.TITLE_PAGE_SYSTEM'};
	$navbar{2}{URL} = "index.cgi?form=system";

	if ($R::form ne "system") {
		$navbar{1}{active} = 1;
		$maintemplate->param('PAGE_PLUGIN', 1);
	} else {
		$navbar{2}{active} = 1;
		$maintemplate->param('PAGE_SYSTEM', 1);
	}

	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();

	exit;

}

exit;


#####################################################
# Debugging: ERR INFO
#####################################################

sub ERR 
{
	my ($message) = @_;
	print STDERR "index.cgi ERROR: $message\n";
}
sub INFO
{
	my ($message) = @_;
	print STDERR "index.cgi INFO: $message\n";
}


