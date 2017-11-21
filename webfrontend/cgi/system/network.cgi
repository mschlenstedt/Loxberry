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
no strict "refs"; # we need it for template system

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
our $version;
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
our $lbfriendlyname;
our @lines;
our $do;
our $message;
our $nexturl;
# our $lbhostname = lbhostname();

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.3.1-dev3";

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

my $friendlyname_changed;

# Everything from Forms
$netzwerkanschluss  = param('netzwerkanschluss');
$netzwerkssid       = param('netzwerkssid');
$netzwerkschluessel = param('netzwerkschluessel');
$netzwerkadressen   = param('netzwerkadressen');
$netzwerkipadresse  = param('netzwerkipadresse');
$netzwerkipmaske    = param('netzwerkipmaske');
$netzwerkgateway    = param('netzwerkgateway');
$netzwerknameserver = param('netzwerknameserver');
$lbfriendlyname	    = param('lbfriendlyname');

if ($lbfriendlyname ne $cfg->param("NETWORK.FRIENDLYNAME")) {
	$friendlyname_changed = 1;
}

# Write configuration file(s)
$cfg->param("NETWORK.INTERFACE", "$netzwerkanschluss");
$cfg->param("NETWORK.SSID", "$netzwerkssid");
$cfg->param("NETWORK.TYPE", "$netzwerkadressen");
$cfg->param("NETWORK.IPADDRESS", "$netzwerkipadresse");
$cfg->param("NETWORK.MASK", "$netzwerkipmaske");
$cfg->param("NETWORK.GATEWAY", "$netzwerkgateway");
$cfg->param("NETWORK.DNS", "$netzwerknameserver");
$cfg->param("NETWORK.FRIENDLYNAME", "$lbfriendlyname");

$cfg->save();

# Set network options
# Wireless
if ($netzwerkanschluss eq "wlan0") {

  # Manual / Static
  if ($netzwerkadressen eq "manual") {
    open(F1,"$lbhomedir/system/network/interfaces.wlan_static") || die "Missing file: $lbhomedir/system/network/interfaces.wlan_static";
     open(F2,">$lbhomedir/system/network/interfaces") || die "Missing file: $lbhomedir/system/network/interfaces";
      flock(F2,2);
      while (<F1>) {
        $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        print F2 $_;
      }
      flock(F2,8);
     close(F2);
    close(F1);

  # DHCP
  } else {
    open(F1,"$lbhomedir/system/network/interfaces.wlan_dhcp") || die "Missing file: $lbhomedir/system/network/interfaces.wlan_dhcp";
     open(F2,">$lbhomedir/system/network/interfaces") || die "Missing file: $lbhomedir/system/network/interfaces";
      flock(F2,2);
      while (<F1>) {
        $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        print F2 $_;
      }
      flock(F2,8);
     close(F2);
    close(F1);
  }

# Ethernet
} else {

  # Manual / Static
  if ($netzwerkadressen eq "manual") {
    open(F1,"$lbhomedir/system/network/interfaces.eth_static") || die "Missing file: $lbhomedir/system/network/interfaces.eth_static";
     open(F2,">$lbhomedir/system/network/interfaces") || die "Missing file: $lbhomedir/system/network/interfaces";
      flock(F2,2);
      while (<F1>) {
        $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        print F2 $_;
      }
      flock(F2,8);
     close(F2);
    close(F1);

  # DHCP
  } else {
    open(F1,"$lbhomedir/system/network/interfaces.eth_dhcp") || die "Missing file: $lbhomedir/system/network/interfaces.eth_dhcp";
     open(F2,">$lbhomedir/system/network/interfaces") || die "Missing file: $lbhomedir/system/network/interfaces";
      flock(F2,2);
      while (<F1>) {
        $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        print F2 $_;
      }
      flock(F2,8);
     close(F2);
    close(F1);
  }
}

if ($friendlyname_changed)
	{ 
	my $ret = system("perl $lbscgidir/tools/generatelegacytemplates.pl --force");
	if ($ret == 0) {
		print STDERR "network.cgi: generatelegacytemplates.pl's was called successfully.\n";
	} else {
		print STDERR "network.cgi: generatelegacytemplates.pl's exit code has shown an ERROR.\n";
	}
}

$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETWORK.WIDGETLABEL'};
$maintemplate->param("NEXTURL", "/admin/index.cgi");

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
			# associate => $cfg,
			);

LoxBerry::Web::readlanguage($maintemplate);
LoxBerry::Web::head();
LoxBerry::Web::pagestart();
$maintemplate->output();
LoxBerry::Web::pageend();
LoxBerry::Web::foot();
exit;

}


