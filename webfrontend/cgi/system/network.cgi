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

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.1";

$cfg                = new Config::Simple('../../../config/system/general.cfg');
$installfolder      = $cfg->param("BASE.INSTALLFOLDER");
$lang               = $cfg->param("BASE.LANG");
$netzwerkanschluss  = $cfg->param("NETWORK.INTERFACE");
$netzwerkssid       = $cfg->param("NETWORK.SSID");
$netzwerkadressen   = $cfg->param("NETWORK.TYPE");
$netzwerkipadresse  = $cfg->param("NETWORK.IPADDRESS");
$netzwerkipmaske    = $cfg->param("NETWORK.MASK");
$netzwerkgateway    = $cfg->param("NETWORK.GATEWAY");
$netzwerknameserver = $cfg->param("NETWORK.DNS");

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

# Filter
quotemeta($query{'lang'});
quotemeta($saveformdata);
quotemeta($do);

$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

##########################################################################
# Language Settings
##########################################################################

# Override settings with URL param
if ($query{'lang'}) {
  $lang = $query{'lang'};
}

# Standard is german
if ($lang eq "") {
  $lang = "de";
}

# If there's no language phrases file for choosed language, use german as default
if (!-e "$installfolder/templates/system/$lang/language.dat") {
  $lang = "de";
}

# Read translations / phrases
$languagefile = "$installfolder/templates/system/$lang/language.dat";
$phrase = new Config::Simple($languagefile);

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
if (!$saveformdata || $do eq "form") {
  &form;
} else {
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form {

# Filter
quotemeta($netzwerkanschluss);
quotemeta($netzwerkssid);
quotemeta($netzwerkadressen);
quotemeta($netzwerkipadresse);
quotemeta($netzwerkipmaske);
quotemeta($netzwerkgateway);
quotemeta($netzwerknameserver);

# Defaults for template
if ($netzwerkanschluss eq "eth0") {
  $checked1 = "checked\=\"checked\"";
} else {
  $checked2 = "checked\=\"checked\"";
}

if ($netzwerkadressen eq "manual") {
  $checked4 = "checked\=\"checked\"";
} else {
  $checked3 = "checked\=\"checked\"";
}

print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0020");
$help = "network";

# Print Template
&lbheader;
open(F,"$installfolder/templates/system/$lang/network.html") || die "Missing template system/$lang/network.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

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

# Filter
quotemeta($netzwerkanschluss);
quotemeta($netzwerkssid);
quotemeta($netzwerkschluessel);
quotemeta($netzwerkadressen);
quotemeta($netzwerkipadresse);
quotemeta($netzwerkipmaske);
quotemeta($netzwerkgateway);
quotemeta($netzwerknameserver);

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
# Wireless
if ($netzwerkanschluss eq "wlan0") {

  # Manual / Static
  if ($netzwerkadressen eq "manual") {
    open(F1,"$installfolder/system/network/interfaces.wlan_static") || die "Missing file: $installfolder/system/network/interfaces.wlan_static";
     open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
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
    open(F1,"$installfolder/system/network/interfaces.wlan_dhcp") || die "Missing file: $installfolder/system/network/interfaces.wlan_dhcp";
     open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
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
    open(F1,"$installfolder/system/network/interfaces.eth_static") || die "Missing file: $installfolder/system/network/interfaces.eth_static";
     open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
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
    open(F1,"$installfolder/system/network/interfaces.eth_dhcp") || die "Missing file: $installfolder/system/network/interfaces.eth_dhcp";
     open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
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

print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0020");
$help = "network";

$message = $phrase->param("TXT0037");
$nexturl = "/admin/index.cgi";

# Print Template
&lbheader;
open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/succses.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

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

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0028");
$help = "network";

print "Content-Type: text/html\n\n";

&lbheader;
open(F,"$installfolder/templates/system/$lang/error.html") || die "Missing template system/$lang/error.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);
&footer;

exit;

}

#####################################################
# Header
#####################################################

sub lbheader {

  # create help page
  $helplink = "http://www.loxwiki.eu:80/x/o4CO";
  open(F,"$installfolder/templates/system/$lang/help/$help.html") || die "Missing template system/$lang/help/$help.html";
    @help = <F>;
    foreach (@help){
      s/[\n\r]/ /g;
      $helptext = $helptext . $_;
    }
  close(F);

  open(F,"$installfolder/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}

#####################################################
# Footer
#####################################################

sub footer {

  open(F,"$installfolder/templates/system/$lang/footer.html") || die "Missing template system/$lang/footer.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}

