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
use URI::Escape;
#use HTML::Entities;
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
our $useclouddns;
our $miniservercloudurl;
our $miniservercloudurlftpport;
our $curlbin;
our $grepbin;
our $awkbin;
our $miniservernote;
our $miniserverfoldername;
our $clouddnsaddress;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.6";

$cfg                = new Config::Simple('../../../config/system/general.cfg');
$installfolder      = $cfg->param("BASE.INSTALLFOLDER");
$lang               = $cfg->param("BASE.LANG");
$miniservers        = $cfg->param("BASE.MINISERVERS");
$clouddnsaddress    = $cfg->param("BASE.CLOUDDNS");
$miniserversprev    = $miniservers;
$curlbin            = $cfg->param("BINARIES.CURL");
$grepbin            = $cfg->param("BINARIES.GREP");
$awkbin             = $cfg->param("BINARIES.AWK");

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
&lbheader;

# Start
# 1. Miniserver
# URL-decode credentials from config file
$miniserverip          			= $cfg->param("MINISERVER1.IPADDRESS");
$miniserverport        			= $cfg->param("MINISERVER1.PORT");
$miniserveruser        			= uri_unescape($cfg->param("MINISERVER1.ADMIN"));
$miniserverkennwort    			= uri_unescape($cfg->param("MINISERVER1.PASS"));
$useclouddns           			= $cfg->param("MINISERVER1.USECLOUDDNS");
$miniservercloudurl    			= $cfg->param("MINISERVER1.CLOUDURL");
$miniservercloudurlftpport 	= $cfg->param("MINISERVER1.CLOUDURLFTPPORT");
$miniservernote     				= $cfg->param("MINISERVER1.NOTE");
$miniserverfoldername       = $cfg->param("MINISERVER1.NAME");

quotemeta($miniserverip);
quotemeta($miniserverport);
quotemeta($miniserveruser);
quotemeta($miniserverkennwort);
quotemeta($miniservernote);
quotemeta($miniserverfoldername);
quotemeta($useclouddns);
quotemeta($miniservercloudurl);
quotemeta($miniservercloudurlftpport);

# Workaround for Javascript in Template - Maybe better fix this in the Javascript Code...
# (If this option is 0 we need it really empty for Javascript)
if (!$useclouddns) {$useclouddns = ""};

open(F,"$installfolder/templates/system/$lang/miniserver_start.html") || die "Missing template system/$lang/miniserver_start.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

# Aditional Miniservers
# URL-decode credentials from config file
$msno = 2;
while ($msno <= $miniservers) {
  # Table rows
  $miniserverip       				= $cfg->param("MINISERVER$msno.IPADDRESS");
  $miniserverport     				= $cfg->param("MINISERVER$msno.PORT");
  $miniserveruser     				= uri_unescape($cfg->param("MINISERVER$msno.ADMIN"));
  $miniserverkennwort 				= uri_unescape($cfg->param("MINISERVER$msno.PASS"));
  $miniservernote     				= $cfg->param("MINISERVER$msno.NOTE");
  $miniserverfoldername     	= $cfg->param("MINISERVER$msno.NAME");
  $useclouddns        				= $cfg->param("MINISERVER$msno.USECLOUDDNS");
  $miniservercloudurl 				= $cfg->param("MINISERVER$msno.CLOUDURL");
  $miniservercloudurlftpport 	= $cfg->param("MINISERVER$msno.CLOUDURLFTPPORT");
  
  quotemeta($miniserverip);
  quotemeta($miniserverport);
  quotemeta($miniserveruser);
  quotemeta($miniserverkennwort);
  quotemeta($miniservernote);
  quotemeta($miniserverfoldername);
  quotemeta($useclouddns);
  quotemeta($miniservercloudurl);
  quotemeta($miniservercloudurlftpport);

  # Workaround for Javascript in Template - Maybe better fix this in the Javascript Code...
  # (If this option is 0 we need it really empty for Javascript)
  if (!$useclouddns) {$useclouddns = ""};

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
  # Data from form
  ${miniserverip.$msno}       				= param("miniserverip$msno");
  ${miniserverport.$msno}     				= param("miniserverport$msno");
  ${miniserveruser.$msno}     				= param("miniserveruser$msno");
  ${miniserverkennwort.$msno} 				= param("miniserverkennwort$msno");
  ${miniservernote.$msno}     				= param("miniservernote$msno");
  ${miniserverfoldername.$msno}     	= param("miniserverfoldername$msno");
  ${useclouddns.$msno}        				= param("useclouddns$msno");
  ${miniservercloudurl.$msno} 				= param("miniservercloudurl$msno");
  ${miniservercloudurlftpport.$msno} 	= param("miniservercloudurlftpport$msno");

  # Filter
  quotemeta(${miniserverip.$msno});
  quotemeta(${miniserverport.$msno});
  quotemeta(${miniserveruser.$msno});
  quotemeta(${miniserverkennwort.$msno});
  quotemeta(${useclouddns.$msno});
  quotemeta(${miniservercloudurl.$msno});
  quotemeta(${miniservercloudurlftpport.$msno});
  quotemeta(${miniservernote.$msno});
  quotemeta(${miniserverfoldername.$msno});

  # URL-Encode form data before they are used to test the connection
  ${miniserveruser.$msno} = uri_escape(${miniserveruser.$msno});
  ${miniserverkennwort.$msno} = uri_escape(${miniserverkennwort.$msno});
  
  # Test if Miniserver is reachable
  if ( ${useclouddns.$msno} eq "on" || ${useclouddns.$msno} eq "checked" || ${useclouddns.$msno} eq "true" || ${useclouddns.$msno} eq "1" )
  {
   ${useclouddns.$msno} = "1";
   our $dns_info = `$curlbin -I http://$clouddnsaddress/${miniservercloudurl.$msno} --connect-timeout 5 -m 5 2>/dev/null |$grepbin Location |$awkbin -F/ '{print \$3}'`;
   my @dns_info_pieces = split /:/, $dns_info;
   if ($dns_info_pieces[1])
   {
     $dns_info_pieces[1] =~ s/^\s+|\s+$//g;
   }
   else
   {
     $dns_info_pieces[1] = 80;
   }
   if ($dns_info_pieces[0])
   {
     $dns_info_pieces[0] =~ s/^\s+|\s+$//g;
   }
   else
   {
     $dns_info_pieces[0] = "[DNS-Error]"; 
   }
  $url = "http://${miniserveruser.$msno}:${miniserverkennwort.$msno}\@$dns_info_pieces[0]\:$dns_info_pieces[1]/dev/cfg/version";
  }
  else
  {
  $url = "http://${miniserveruser.$msno}:${miniserverkennwort.$msno}\@${miniserverip.$msno}\:${miniserverport.$msno}/dev/cfg/version";
  ${useclouddns.$msno} = "0";
  }
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
  $cfg->param("MINISERVER$msno.USECLOUDDNS", "${useclouddns.$msno}");
  $cfg->param("MINISERVER$msno.CLOUDURL", "${miniservercloudurl.$msno}");
  $cfg->param("MINISERVER$msno.CLOUDURLFTPPORT", "${miniservercloudurlftpport.$msno}");
  $cfg->param("MINISERVER$msno.NOTE", "${miniservernote.$msno}");
  $cfg->param("MINISERVER$msno.NAME", "${miniserverfoldername.$msno}");

  # Next
  $msno++;
}

# Deleting old Miniserver if any (TODO: How to delete the BLOCKs?!?)
while ($miniserversprev > $miniservers) {
  $cfg->delete("MINISERVER$miniserversprev.PORT");
  $cfg->delete("MINISERVER$miniserversprev.PASS");
  $cfg->delete("MINISERVER$miniserversprev.ADMIN");
  $cfg->delete("MINISERVER$miniserversprev.IPADDRESS");
  $cfg->delete("MINISERVER$miniserversprev.USECLOUDDNS");
  $cfg->delete("MINISERVER$miniserversprev.CLOUDURL");

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
$help = "admin";

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

