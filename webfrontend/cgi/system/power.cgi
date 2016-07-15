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
$version = "0.0.2";

$cfg             = new Config::Simple('../../../config/system/general.cfg');
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$rebootbin       = $cfg->param("BINARIES.REBOOT");
$poweroffbin     = $cfg->param("BINARIES.POWEROFF");

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
quotemeta($query{'lang'});
quotemeta($do);
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

# What should we do?

# Reboot
if ($do eq "reboot") {
  &reboot;
}

# Poweroff
if ($do eq "poweroff") {
  &poweroff;
}

# Everything else
&menu;

exit;

#####################################################
# Menue
#####################################################

sub menu {

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0027");
$help = "power";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/power.html") || die "Missing template system/$lang/power.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Reboot
#####################################################

sub reboot {

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0029");
$help = "power";

$message = $phrase->param("TXT0034");
$nexturl = "/admin/index.cgi";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/success.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

# Reboot
# Without the following workaround
# the script cannot be executed as
# background process via CGI
my $pid = fork();
die "Fork failed: $!" if !defined $pid;
if ($pid == 0) {
# do this in the child
 open STDIN, "</dev/null";
 open STDOUT, ">/dev/null";
 open STDERR, ">/dev/null";
 system("sleep 5 && sudo $rebootbin &");
}

exit;

}

#####################################################
# Poweroff
#####################################################

sub poweroff {

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0029");
$help = "power";

$message = $phrase->param("TXT0033");
$nexturl = "/admin/index.cgi";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/success.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

# Poweroff
# Without the following workaround
# the script cannot be executed as
# background process via CGI
my $pid = fork();
die "Fork failed: $!" if !defined $pid;
if ($pid == 0) {
# do this in the child
 open STDIN, "</dev/null";
 open STDOUT, ">/dev/null";
 open STDERR, ">/dev/null";
 system("sleep 5 && sudo $poweroffbin &");
}

exit;

}

#####################################################
# Header
#####################################################

sub header {

  # create help page
  $helplink = "/help/$lang/$help.html";
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
