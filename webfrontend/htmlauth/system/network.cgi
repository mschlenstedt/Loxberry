#!/usr/bin/perl

# Copyright 2017 Michael Schlenstedt, michael@loxberry.de
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
use LWP::UserAgent;
use Config::Simple;
use warnings;
use strict;
# no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_network.html";

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
#our $installfolder;
our $languagefile;
our $error;
our $saveformdata;
our $checked1;
our $checked2;
our $checked3;
our $checked4;
our $netzwerkanschluss;
our $netzwerkssid;
our $netzwerkschluessel;
our $netzwerkadressen;
our $netzwerkipadresse;
our $netzwerkipmaske;
our $netzwerkgateway;
our $netzwerknameserver;
our @lines;
our $do;
our $message;
our $nexturl;
# our $lbhostname = lbhostname();

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.2.2";

print STDERR "============= network.cgi ================\n";
print STDERR "lbhomedir: $lbhomedir\n";

$cfg                = new Config::Simple("$lbsconfigdir/general.cfg");
$netzwerkanschluss  = $cfg->param("NETWORK.INTERFACE");
$netzwerkadressen   = $cfg->param("NETWORK.TYPE");

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/network.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $cfg,
			%htmltemplate_options,
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

# Everything we got from forms
$saveformdata         = param('saveformdata');
defined $saveformdata ? $saveformdata =~ tr/0-1//cd : undef;

##########################################################################
# Language Settings
##########################################################################

$lang = lblanguage();
$maintemplate->param( "LBHOSTNAME", lbhostname());
$maintemplate->param( "LANG", $lang);
$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
if (!$saveformdata) {
  print STDERR "FORM called\n";
  $maintemplate->param("FORM", 1);
  &form;
} else {
  print STDERR "SAVE called\n";
  $maintemplate->param("SAVE", 1);
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form {

	# Defaults for template
	if ($netzwerkanschluss eq "eth0") {
	  $maintemplate->param( "CHECKED1", 'checked="checked"');
	} else {
	  $maintemplate->param( "CHECKED2", 'checked="checked"');
	}

	if ($netzwerkadressen eq "manual") {
	  $maintemplate->param( "CHECKED4", 'checked="checked"');
	} else {
	  $maintemplate->param( "CHECKED3", 'checked="checked"');
	}

	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETWORK.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);

	print $maintemplate->output();
	undef $maintemplate;			

	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;
}

#####################################################
# Save
#####################################################

sub save {

	# Everything from Forms
	$netzwerkanschluss  = param('netzwerkanschluss');
	$netzwerkssid       = param('netzwerkssid');
	$netzwerkschluessel = param('netzwerkschluessel');
	$netzwerkadressen   = param('netzwerkadressen');
	$netzwerkipadresse  = param('netzwerkipadresse');
	$netzwerkipmaske    = param('netzwerkipmaske');
	$netzwerkgateway    = param('netzwerkgateway');
	$netzwerknameserver = param('netzwerknameserver');

	# Write configuration file(s)
	$cfg->param("NETWORK.INTERFACE", "$netzwerkanschluss");
	$cfg->param("NETWORK.SSID", "$netzwerkssid");
	$cfg->param("NETWORK.TYPE", "$netzwerkadressen");
	$cfg->param("NETWORK.IPADDRESS", "$netzwerkipadresse");
	$cfg->param("NETWORK.MASK", "$netzwerkipmaske");
	$cfg->param("NETWORK.GATEWAY", "$netzwerkgateway");
	$cfg->param("NETWORK.DNS", "$netzwerknameserver");

	$cfg->save();

	# Set network options
	my $interface_file = "$lbhomedir/system/network/interfaces";
	my $ethtemplate_name = undef;

	# Wireless
	if ($netzwerkanschluss eq "wlan0") {
		if ($netzwerkadressen eq "manual") {
			# Manual / Static
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.wlan_static";
		} else {
			# DHCP
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.wlan_dhcp";
		}
	# Ethernet
	} else {
		if ($netzwerkadressen eq "manual") {
			# Manual / Static
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.eth_static";
		} else {
			# DHCP	
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.eth_dhcp";
		}
	}

	my $ethtmpl = HTML::Template->new(
				filename => $ethtemplate_name,
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				#associate => $cfg,
				# debug => 1,
			) or do 
			{ $error = "System failure: Cannot open network template $ethtemplate_name";
			&error; };
			
	$ethtmpl->param( 
					'netzwerkssid' => $netzwerkssid,
					'netzwerkschluessel' => $netzwerkschluessel,
					'netzwerkipadresse' => $netzwerkipadresse,
					'netzwerkipmaske' => $netzwerkipmaske,
					'netzwerkgateway' => $netzwerkgateway,
					'netzwerknameserver' => $netzwerknameserver,
					'netzwerkdnsdomain' => 'loxberry.local',
				);
	open(my $fh, ">" , $interface_file) or do 
			{ $error = "System failure: Cannot open network file $interface_file";
			&error; };
	$ethtmpl->output(print_to => $fh);
	close $fh;
	$ethtmpl = undef;
					
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETWORK.WIDGETLABEL'};
	$maintemplate->param("NEXTURL", "/admin/system/index.cgi?form=system");

	# Print Template
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;
}

exit;


#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Error
#####################################################

sub error {

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETWORK.WIDGETLABEL'};

	my $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/error.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				# associate => $cfg,
				);
	$maintemplate->param('ERROR' => $error);
	
	LoxBerry::Web::readlanguage($maintemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;

}


