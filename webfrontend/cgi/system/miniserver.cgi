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
#use warnings;
#use strict;
#no strict "refs"; # we need it for template system

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
our $output;
our $message;
our $do;
my  $url;
my  $ua;
my  $response;
my  $urlstatus;
my  $urlstatuscode;
our $nexturl;
our $miniservers;
our $miniserversprev;
our $msno;
our $miniserverip;
our $miniserverport;
our $miniserveruser;
our $miniserverkennwort;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.2";

$cfg                = new Config::Simple('../../../config/system/general.cfg');
$installfolder      = $cfg->param("BASE.INSTALLFOLDER");
$lang               = $cfg->param("BASE.LANG");
$miniservers        = $cfg->param("BASE.MINISERVERS");
$miniserversprev    = $miniservers;

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

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0019");
$help = "miniserver";

# Print Template
&header;

# Start
# 1. Miniserver
$miniserverip       = $cfg->param("MINISERVER1.IPADDRESS");
$miniserverport     = $cfg->param("MINISERVER1.PORT");
$miniserveruser     = $cfg->param("MINISERVER1.ADMIN");
$miniserverkennwort = $cfg->param("MINISERVER1.PASS");
quotemeta($miniserverip);
quotemeta($miniserverport);
quotemeta($miniserveruser);
quotemeta($miniserverkennwort);
open(F,"$installfolder/templates/system/$lang/miniserver_start.html") || die "Missing template system/$lang/miniserver_start.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

# Aditional Miniservers
$msno = 2;
while ($msno <= $miniservers) {
  # Table rows
  $miniserverip       = $cfg->param("MINISERVER$msno.IPADDRESS");
  $miniserverport     = $cfg->param("MINISERVER$msno.PORT");
  $miniserveruser     = $cfg->param("MINISERVER$msno.ADMIN");
  $miniserverkennwort = $cfg->param("MINISERVER$msno.PASS");
  quotemeta($miniserverip);
  quotemeta($miniserverport);
  quotemeta($miniserveruser);
  quotemeta($miniserverkennwort);
  open(F,"$installfolder/templates/system/$lang/miniserver_row.html") || die "Missing template system/$lang/miniserver_row.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
  close(F);
  $msno++;
}

# End
open(F,"$installfolder/templates/system/$lang/miniserver_end.html") || die "Missing template system/$lang/miniserver_end.html";
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
# Not conform with use strict;, but no idea for a better solution...
$miniservers =  param('miniservers');
quotemeta($miniservers);
$cfg->param("BASE.MINISERVERS", "$miniservers");

$msno = 1;
while ($msno <= $miniservers) {
  # Variables
  #our ${miniserverip.$msno};
  #our ${miniserverport.$msno};
  #our ${miniserveruser.$msno};
  #our ${miniserverkennwort.$msno};
  # Data from form
  ${miniserverip.$msno}       = param("miniserverip$msno");
  ${miniserverport.$msno}     = param("miniserverport$msno");
  ${miniserveruser.$msno}     = param("miniserveruser$msno");
  ${miniserverkennwort.$msno} = param("miniserverkennwort$msno");

  # Filter
  quotemeta(${miniserverip.$msno});
  quotemeta(${miniserverport.$msno});
  quotemeta(${miniserveruser.$msno});
  quotemeta(${miniserverkennwort.$msno});

  # Test if Miniserver is reachable
  $url = "http://${miniserveruser.$msno}:${miniserverkennwort.$msno}\@${miniserverip.$msno}\:${miniserverport.$msno}/dev/cfg/version";
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
    $error = $phrase->param("TXT0041");
    $error = $error . " " . $msno;
    $error = $error . ". " . $phrase->param("TXT0003");
    &error;
    exit;
  }

  # Write configuration file(s)
  $cfg->param("MINISERVER$msno.PORT", "${miniserverport.$msno}");
  $cfg->param("MINISERVER$msno.PASS", "${miniserverkennwort.$msno}");
  $cfg->param("MINISERVER$msno.ADMIN", "${miniserveruser.$msno}");
  $cfg->param("MINISERVER$msno.IPADDRESS", "${miniserverip.$msno}");
  
  # Next
  $msno++;
}

# Deleting old Miniserver if any (TODO: How to delete the BLOCKs?!?)
while ($miniserversprev > $miniservers) {
  $cfg->delete("MINISERVER$miniserversprev.PORT");
  $cfg->delete("MINISERVER$miniserversprev.PASS");
  $cfg->delete("MINISERVER$miniserversprev.ADMIN");
  $cfg->delete("MINISERVER$miniserversprev.IPADDRESS");
  # Does not work: $cfg->delete(-block=>'MINISERVER2');
  $miniserversprev--;
}

# Save Config
$cfg->save();

print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0029");
$help = "miniserver";

$message = $phrase->param("TXT0035");
$nexturl = "/admin/index.cgi";

# Print Template
&header;
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
$help = "admin";

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

