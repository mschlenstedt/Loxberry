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
use CGI::Session;
use File::Copy;
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
my  $url;
my  $ua;
my  $response;
our $step;
our $sid;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $installfolder;
our $languagefile;
our $session;
our $version;
our $error;
our $saveformdata;
our $checked1;
our $checked2;
our $checked3;
our $checked4;
my $urlstatus;
my $urlstatuscode;
our $adminuser;
our $adminpass1;
our $adminpass2;
our $miniserverip1;
our $miniserverport1;
our $miniserveruser1;
our $miniserverkennwort1;
our $netzwerkanschluss;
our $netzwerkssid;
our $netzwerkschluessel;
our $netzwerkadressen;
our $netzwerkipadresse;
our $netzwerkipmaske;
our $netzwerkgateway;
our $netzwerknameserver;
our @lines;
our $timezonelist;
our $zeitserver;
our $ntpserverurl;
our $zeitzone;
our $rootnewpassword;
our $output;
our $adminpasscrypted;
our $salt;
our $e;
our $loxberrypasswdhtml;
our $rootpasswdhtml;
our $rebootbin;
our $http_host = $ENV{HTTP_HOST};

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.4";

$cfg             = new Config::Simple('../../../../config/system/general.cfg');
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$rebootbin       = $cfg->param("BINARIES.REBOOT");

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
$step           = $query{'step'};
$sid            = $query{'sid'};

# Everything from Forms
$saveformdata         = param('saveformdata');
$adminuser            = param('adminuser');
$adminpass1           = param('adminpass1');
$adminpass2           = param('adminpass2');
$miniserverip1        = param('miniserverip1');
$miniserverport1      = param('miniserverport1');
$miniserveruser1      = param('miniserveruser1');
$miniserverkennwort1  = param('miniserverkennwort1');
$netzwerkanschluss    = param('netzwerkanschluss');
$netzwerkssid         = param('netzwerkssid');
$netzwerkschluessel   = param('netzwerkschluessel');
$netzwerkadressen     = param('netzwerkadressen');
$netzwerkipadresse    = param('netzwerkipadresse');
$netzwerkipmaske      = param('netzwerkipmaske');
$netzwerkgateway      = param('netzwerkgateway');
$netzwerknameserver   = param('netzwerknameserver');
$zeitserver           = param('zeitserver');
$ntpserverurl         = param('ntpserverurl');
$zeitzone             = param('zeitzone');

# Filter
quotemeta($query{'lang'});
quotemeta($query{'nostartsetup'});
quotemeta($step);
quotemeta($saveformdata);

$step                  =~ tr/0-9//cd;
$step                  = substr($step,0,1);
$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);
$sid                   =~ tr/a-z0-9//cd;
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

##########################################################################
# Session
##########################################################################

# Create new Session if none exists, else use existing one
if (!$sid) {
  $session = new CGI::Session("driver:File", undef, {Directory=>"$installfolder/webfrontend/sessioncache"});
  $sid = $session->id();
} else {
  $session = new CGI::Session("driver:File", $sid, {Directory=>"$installfolder/webfrontend/sessioncache"});
  $sid = $session->id();
}

# Sessions are valid for 24 hour
$session->expire('+24h');    # expire after 24 hour

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
if ($step eq "0" || !$step) {
  &step0;
}

if ($step eq "1") {
  &step1;
}

if ($step eq "2") {
  &step2;
}

if ($step eq "3") {
  &step3;
}

if ($step eq "4") {
  &step4;
}

if ($step eq "5") {
  &step5;
}

if ($step eq "6") {
  &step6;
}

if ($step eq "7") {
  &step7;
}

exit;

#####################################################
# Step 0
# Welcome Message
#####################################################

sub step0 {

$step++;

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017");
$help = "setup00";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/setup/setup.step00.html") || die "Missing template system/$lang/setup/setup.step00.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Step 1
# Admin Account
#####################################################

sub step1 {

# Store submitted data in session file
# Nothing todo here (first form)

# Read data from Session file
$adminuser   = $session->param("adminuser");
$adminpass1  = $session->param("adminpass1");
$adminpass2  = $session->param("adminpass1");

# Filter
quotemeta($adminuser);
quotemeta($adminpass1);
quotemeta($adminpass2);

$step++;

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0018");
$help = "setup01";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/setup/setup.step01.html") || die "Missing template system/$lang/asistant/setup.step01.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Step 2
# Miniserver
#####################################################

sub step2 {

#if ($saveformdata) {
#  # Check input from Step 1
#  if ($adminuser =~ /\W+/ || length($adminuser) < 3 || length($adminuser) > 20){
#    $error = "$txt9";
#    &error;
#    exit;
#  }
#  if (!$adminpass1 || !$adminuser){
#    $error = "$txt9";
#    &error;
#    exit;
#  }
#  if ($adminpass1 !~ /^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])\S{5,}$/){
#    $error = "$txt9";
#    &error;
#    exit;
#  }
#  if ($adminpass1 =~ /\W+/){
#    $error = "$txt9";
#    &error;
#    exit;
#  }
#  if ($adminpass1 ne $adminpass2){
#    $error = "$txt9";
#    &error;
#    exit;
#  }
#}

# Store submitted data in session file
if ($saveformdata) {
  $session->param("adminuser", $adminuser);
  $session->param("adminpass1", $adminpass1);
  $session->param("miniserverip1", $miniserverip1);
  $session->param("miniserverport1", $miniserverport1);
  $session->param("miniserveruser1", $miniserveruser1);
  $session->param("miniserverkennwort1", $miniserverkennwort1);
}

# Read data from Session file
$miniserverip1       = $session->param("miniserverip1");
$miniserverport1     = $session->param("miniserverport1");
$miniserveruser1     = $session->param("miniserveruser1");
$miniserverkennwort1 = $session->param("miniserverkennwort1");

# Filter
quotemeta($miniserverip1);
quotemeta($miniserverport1);
quotemeta($miniserveruser1);
quotemeta($miniserverkennwort1);

# Default values
if (!$miniserverport1) {$miniserverport1 = "80";}

$step++;

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0019");
$help = "setup02";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/setup/setup.step02.html") || die "Missing template system/$lang/setup/setup.step02.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Step 3
# Netzwerk
#####################################################

sub step3 {

# Store submitted data in session file
if ($saveformdata) {
  $session->param("miniserverip1", $miniserverip1);
  $session->param("miniserverport1", $miniserverport1);
  $session->param("miniserveruser1", $miniserveruser1);
  $session->param("miniserverkennwort1", $miniserverkennwort1);

  # Test if Miniserver is reachable
  $url = "http://$miniserveruser1:$miniserverkennwort1\@$miniserverip1\:$miniserverport1/dev/cfg/version";
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    $urlstatus = $response->status_line;
  };
  alarm(0);

  # Error if we can't login
  $urlstatuscode = substr($urlstatus,0,3);
  if ($urlstatuscode ne "200") {
    $error = $phrase->param("TXT0003");
    &error;
    exit;
  }

}
  
# Read data from Session file
$netzwerkanschluss  = $session->param("netzwerkanschluss");
$netzwerkssid       = $session->param("netzwerkssid");
$netzwerkschluessel = $session->param("netzwerkschluessel");
$netzwerkadressen   = $session->param("netzwerkadressen");
$netzwerkipadresse  = $session->param("netzwerkipadresse");
$netzwerkipmaske    = $session->param("netzwerkipmaske");
$netzwerkgateway    = $session->param("netzwerkgateway");
$netzwerknameserver = $session->param("netzwerknameserver");

# Filter
quotemeta($netzwerkanschluss);
quotemeta($netzwerkssid);
quotemeta($netzwerkschluessel);
quotemeta($netzwerkadressen);
quotemeta($netzwerkipadresse);
quotemeta($netzwerkipmaske);
quotemeta($netzwerkgateway); 
quotemeta($netzwerknameserver);

# Defaults for template
if ($netzwerkanschluss eq "wlan0") {
  $checked2 = "checked\=\"checked\"";
} else {
  $checked1 = "checked\=\"checked\"";
}

if ($netzwerkadressen eq "manual") {
  $checked4 = "checked\=\"checked\"";
} else {
  $checked3 = "checked\=\"checked\"";
}

$step++;

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0020");
$help = "setup03";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/setup/setup.step03.html") || die "Missing template system/$lang/setup/setup.step03.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Step 4
# Timeserver
#####################################################

sub step4 {

# Store submitted data in session file
if ($saveformdata) {
   $session->param("netzwerkanschluss", $netzwerkanschluss);
   $session->param("netzwerkssid", $netzwerkssid);
   $session->param("netzwerkschluessel", $netzwerkschluessel);
   $session->param("netzwerkadressen", $netzwerkadressen);
   $session->param("netzwerkipadresse", $netzwerkipadresse);
   $session->param("netzwerkipmaske", $netzwerkipmaske);
   $session->param("netzwerkgateway", $netzwerkgateway);
   $session->param("netzwerknameserver", $netzwerknameserver);
}
  
# Read data from Session file
$zeitserver   = $session->param("zeitserver");
$ntpserverurl = $session->param("ntpserverurl");
$zeitzone     = $session->param("zeitzone");

# Filter
quotemeta($zeitserver);
quotemeta($ntpserverurl);
quotemeta($zeitzone);

# Defaults for template
if ($zeitserver eq "ntp") {
  $checked2 = "checked\=\"checked\"";
} else {
  $checked1 = "checked\=\"checked\"";
}

$step++;

# Prepare Timezones
open(F,"<$installfolder/templates/system/timezones.dat") || die "Missing template system/timezones.dat";
 flock(F,2);
 @lines = <F>;
 flock(F,8);
close(F);
foreach (@lines){
  s/[\n\r]//g;
  if ($zeitzone eq $_) {
    $timezonelist = "$timezonelist<option selected=\"selected\" value=\"$_\">$_</option>\n";
  } else {
    $timezonelist = "$timezonelist<option value=\"$_\">$_</option>\n";
  }
}

print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0021");
$help = "setup04";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/setup/setup.step04.html") || die "Missing template system/$lang/setup/setup.step04.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Step 5
# Pre-Installation
#####################################################

sub step5 {

# Store submitted data in session file
if ($saveformdata) {
   $session->param("zeitserver", $zeitserver);
   $session->param("ntpserverurl", $ntpserverurl);
   $session->param("zeitzone", $zeitzone);
}
  
$step++;

print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0022");
$help = "setup05";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/setup/setup.step05.html") || die "Missing template system/$lang/setup/setup.step05.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Step 6
# Do Installation
#####################################################

sub step6 {

# Read data from Session file
$adminuser           = $session->param("adminuser");
$adminpass1          = $session->param("adminpass1");
$adminpass2          = $session->param("adminpass1");
$miniserverip1       = $session->param("miniserverip1");
$miniserverport1     = $session->param("miniserverport1");
$miniserveruser1     = $session->param("miniserveruser1");
$miniserverkennwort1 = $session->param("miniserverkennwort1");
$netzwerkanschluss   = $session->param("netzwerkanschluss1");
$netzwerkssid        = $session->param("netzwerkssid");
$netzwerkschluessel  = $session->param("netzwerkschluessel");
$netzwerkadressen    = $session->param("netzwerkadressen");
$netzwerkipadresse   = $session->param("netzwerkipadresse");
$netzwerkipmaske     = $session->param("netzwerkipmaske");
$netzwerkgateway     = $session->param("netzwerkgateway");
$netzwerknameserver  = $session->param("netzwerknameserver");
$zeitserver          = $session->param("zeitserver");
$ntpserverurl        = $session->param("ntpserverurl");
$zeitzone            = $session->param("zeitzone");

# Filter
quotemeta($adminuser);
quotemeta($adminpass1);
quotemeta($adminpass2);
quotemeta($miniserverip1);
quotemeta($miniserverport1);
quotemeta($miniserveruser1);
quotemeta($miniserverkennwort1);
quotemeta($netzwerkanschluss);
quotemeta($netzwerkssid);
quotemeta($netzwerkschluessel);
quotemeta($netzwerkadressen);
quotemeta($netzwerkipadresse);
quotemeta($netzwerkipmaske);
quotemeta($netzwerkgateway); 
quotemeta($netzwerknameserver);
quotemeta($zeitserver);
quotemeta($ntpserverurl);
quotemeta($zeitzone);

$step++;

# Write configuration file(s)
$cfg->param("BASE.STARTSETUP", "0");
$cfg->param("BASE.LANG", "$lang");
$cfg->param("BASE.MINISERVERS", "1");
$cfg->param("MINISERVER1.PORT", "$miniserverport1");
$cfg->param("MINISERVER1.PASS", "$miniserverkennwort1");
$cfg->param("MINISERVER1.ADMIN", "$miniserveruser1");
$cfg->param("MINISERVER1.IPADDRESS", "$miniserverip1");
$cfg->param("TIMESERVER.SERVER", "$ntpserverurl");
$cfg->param("TIMESERVER.METHOD", "$zeitserver");
$cfg->param("TIMESERVER.ZONE", "$zeitzone");
$cfg->param("NETWORK.INTERFACE", "$netzwerkanschluss");
$cfg->param("NETWORK.SSID", "$netzwerkssid");
$cfg->param("NETWORK.TYPE", "$netzwerkadressen");
$cfg->param("NETWORK.IPADDRESS", "$netzwerkipadresse");
$cfg->param("NETWORK.MASK", "$netzwerkipmaske");
$cfg->param("NETWORK.GATEWAY", "$netzwerkgateway");
$cfg->param("NETWORK.DNS", "$netzwerknameserver");
$cfg->save();

# Save Username/Password for Webarea
$salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
$adminpasscrypted = crypt("$adminpass1","$salt");
open(F,">$installfolder/config/system/htusers.dat") || die "Missing file: config/system/htusers.dat";
 flock(F,2);
 print F "$adminuser:$adminpasscrypted";
 flock(F,8);
close(F);

# Try to set new passwords fpr user "root" and "loxberry"
# This only works if the initial password is still valid
# (password: "loxberry")
$rootnewpassword = generate();
$output = qx(LANG="en_GB.UTF-8" $installfolder/sbin/setrootpasswd.exp loxberry $rootnewpassword);
if ($? eq 0) {
  $rootpasswdhtml = "<tr><td><b>" . $phrase->param("TXT0026") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>root</b></td><td>" . $phrase->param("TXT0024") . " <b>$rootnewpassword</b></td></tr>";
}
# Debugging
#open(F,">/tmp/root");
# flock(F,2);
# print F "$output\n\n$rootnewpassword";
# flock(F,8);
#close(F);

$output = qx(LANG="en_GB.UTF-8" $installfolder/sbin/setloxberrypasswd.exp loxberry $adminpass1);
if ($? eq 0) {
  $loxberrypasswdhtml = "<tr><td><b>" . $phrase->param("TXT0025") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>loxberry</b></td><td>" . $phrase->param("TXT0024") . " <b>$adminpass1</b></td></tr>";
}
# Debugging
#open(F,">/tmp/loxberry");
# flock(F,2);
# print F "$output\n\n$adminpass1";
# flock(F,8);
#close(F);

# Set Timezone and sync for the very first time
$output = qx(sudo $installfolder/sbin/setdatetime.pl);

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
$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0022");
$help = "setup06";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/setup/setup.step06.html") || die "Missing template system/$lang/setup/setup.step06.html";
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
$help = "setup00";

print "Content-Type: text/html\n\n";

&header;
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

sub header {

  # create help page
  $helplink = "http://www.loxwiki.eu/display/LOXBERRY/Loxberry+Dokumentation";
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

#####################################################
# Random
#####################################################

sub generate {
        local($e) = @_;
        my($zufall,@words,$more);

        if($e =~ /^\d+$/){
                $more = $e;
        }else{
                $more = "10";
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}
