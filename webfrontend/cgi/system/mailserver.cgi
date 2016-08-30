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
use File::HomeDir;
use warnings;
use strict;
no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

our $cfg;
our $mcfg;
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
our $do;
our $checked1;
our $checked2;
our $home = File::HomeDir->my_home;
our $email;
our $smtpserver;
our $smtpport;
our $smtpcrypt;
our $smtpauth;
our $smtpuser;
our $smtppass;
our $message;
our $nexturl;
our $mailbin;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.1";

$cfg                = new Config::Simple("$home/config/system/general.cfg");
$installfolder      = $cfg->param("BASE.INSTALLFOLDER");
$lang               = $cfg->param("BASE.LANG");
$mailbin            = $cfg->param("BINARIES.MAIL");
$do                 = "";
$helptext           = "";

$mcfg               = new Config::Simple("$home/config/system/mail.cfg");
$email              = $mcfg->param("SMTP.EMAIL");
$smtpserver         = $mcfg->param("SMTP.SMTPSERVER");
$smtpport           = $mcfg->param("SMTP.PORT");
$smtpcrypt          = $mcfg->param("SMTP.CRYPT");
$smtpauth           = $mcfg->param("SMTP.AUTH");
$smtpuser           = $mcfg->param("SMTP.SMTPUSER");
$smtppass           = $mcfg->param("SMTP.SMTPPASS");

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
if (!$saveformdata || $do eq "form") 
{
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
quotemeta($email);
quotemeta($smtpserver);
quotemeta($smtpport);
quotemeta($smtpcrypt);
quotemeta($smtpauth);
quotemeta($smtpuser);
quotemeta($smtppass);

# Defaults for template
if ($smtpcrypt) {
  $checked1 = "checked\=\"checked\"";
}
if ($smtpauth) {
  $checked2 = "checked\=\"checked\"";
}

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0110");
$help = "mailserver";

# Print Template
&lbheader;
open(F,"$installfolder/templates/system/$lang/mailserver.html") || die "Missing template system/$lang/mailserver.html";
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
$email        = param('email');
$smtpserver   = param('smtpserver');
$smtpport     = param('smtpport');
$smtpcrypt    = param('smtpcrypt');
$smtpauth     = param('smtpauth');
$smtpuser     = param('smtpuser');
$smtppass     = param('smtppass');

# Filter
quotemeta($email);
quotemeta($smtpserver);
quotemeta($smtpport);
quotemeta($smtpcrypt);
quotemeta($smtpauth);
quotemeta($smtpuser);
quotemeta($smtppass);

# Write configuration file(s)
$mcfg->param("SMTP.ISCONFIGURED", "1");
$mcfg->param("SMTP.EMAIL", "$email");
$mcfg->param("SMTP.SMTPSERVER", "$smtpserver");
$mcfg->param("SMTP.PORT", "$smtpport");
$mcfg->param("SMTP.CRYPT", "$smtpcrypt");
$mcfg->param("SMTP.AUTH", "$smtpauth");
$mcfg->param("SMTP.SMTPUSER", "$smtpuser");
$mcfg->param("SMTP.SMTPPASS", "$smtppass");
$mcfg->save();

# Activate new configuration

# Create temporary SSMTP Config file
open(F,">/tmp/tempssmtpconf.dat") || die "Cannot open /tmp/tempssmtpconf.dat";
  print F <<ENDFILE;
#
# Config file for sSMTP sendmail
#
# The person who gets all mail for userids < 1000
# Make this empty to disable rewriting.
ENDFILE

print F "root=$email\n\n";

  print F <<ENDFILE;
# The place where the mail goes. The actual machine name is required no
# MX records are consulted. Commonly mailhosts are named mail.domain.com
ENDFILE
  print F "mailhub=$smtpserver\:$smtpport\n\n";

  if ($smtpauth) {
    print F "# Authentication\n";
    print F "AuthUser=$smtpuser\n";
    print F "AuthPass=$smtppass\n\n";
  }

  if ($smtpcrypt) {
    print F "# Use encryption\n";
    print F "UseSTARTTLS=YES\n\n";
  }

  print F <<ENDFILE;
# Where will the mail seem to come from?
#rewriteDomain=

# The full hostname
hostname=loxberry.local

# Are users allowed to set their own From: address?
# YES - Allow the user to specify their own From: address
# NO - Use the system gen
FromLineOverride=YES
ENDFILE
close(F);

# Install temporary ssmtp config file
my $result = qx($home/sbin/createssmtpconf.sh start 2>/dev/null);

if ($lang eq "de") {
  $result = qx(echo "Dieses ist eine Test Email von Deinem LoxBerry. Es scheint alles OK zu sein." | $mailbin -a "From: $email" -s "Test Email von Deinem LoxBerry" -v $email 2>&1);
} else {
  $result = qx(echo "This is a Test from your LoxBerry. Everything seems to be OK." | $mailbin -a "From: $email" -s "Test Email from LoxBerry" -v $email 2>&1);
}

# Delete old temporary config file
if (-e "/tmp/tempssmtpconf.dat" && -f "/tmp/tempssmtpconf.dat" && !-l "/tmp/tempssmtpconf.dat" && -T "/tmp/tempssmtpconf.dat") {
  unlink ("/tmp/tempssmtpconf.dat");
}

# Template Output
print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0110");
$help = "mailserver";

$message = $phrase->param("TXT0111");
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

