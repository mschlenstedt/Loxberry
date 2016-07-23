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
use DBI;
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
our $adminuser;
our $adminpass1;
our $adminpass2;
our $adminpassold;
our $output;
our $adminpasscrypted;
our $message;
our $adminuserold = $ENV{REMOTE_USER};
our $do;
our $nexturl;
our $salt;
our $dsn;
our $dbh;
our $sth;
our $sqlerr;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.2";

$cfg             = new Config::Simple('../../../config/system/general.cfg');
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");

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

# Everything from Forms
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

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0018");
$help = "admin";

# Print Template
&lbheader;
open(F,"$installfolder/templates/system/$lang/admin.html") || die "Missing template system/$lang/admin.html";
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

$adminuser            = param('adminuser');
$adminpass1           = param('adminpass1');
$adminpass2           = param('adminpass2');
$adminpassold         = param('adminpassold');

# Filter
quotemeta($adminuser);
quotemeta($adminpass1);
quotemeta($adminpass2);
quotemeta($adminpassold);

# Try to set new passwords for user "loxberry"
$output = qx(LANG="en_GB.UTF-8" $installfolder/sbin/setloxberrypasswd.exp $adminpassold $adminpass1);
if ($? eq 0) {
  $message = $phrase->param("TXT0030") . "<br><br><table border=0 cellpadding=10><tr><td><b>" . $phrase->param("TXT0031") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>$adminuser</b></td><td>" . $phrase->param("TXT0024") . " <b>$adminpass1</b></td></tr><tr><td><b>" . $phrase->param("TXT0025") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>loxberry</b></td><td>" . $phrase->param("TXT0024") . " <b>$adminpass1</b></td></tr>";
} else {
  $error = $phrase->param("TXT0032");
  &error;
  exit;
}

# Save Username/Password for Webarea
$salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
$adminpasscrypted = crypt($adminpass1,$salt);
open(F,">$installfolder/config/system/htusers.dat") || die "Missing file: config/system/htusers.dat";
 flock(F,2);
 print F "$adminuser\:$adminpasscrypted";
 flock(F,8);
close(F);

# Set MYSQL Password
# This only works if the initial password is still valid
# (password: "loxberry")
# Use eval {} here in case somthing went wrong
$sqlerr = 0;
$dsn = "DBI:mysql:database=mysql";
eval {$dbh = DBI->connect($dsn, 'root', $adminpassold )};
$sqlerr = 1 if $@;
eval {$sth = $dbh->prepare("UPDATE mysql.user SET password=Password('$adminpass1') WHERE User='root' AND Host='localhost'")};
$sqlerr = 1 if $@;
eval {$sth->execute()};
$sqlerr = 1 if $@;
eval {$sth = $dbh->prepare("FLUSH PRIVILEGES")};
$sqlerr = 1 if $@;
eval {$sth->execute()};
$sqlerr = 1 if $@;
eval {$sth->finish()};
$sqlerr = 1 if $@;
eval {$dbh->{AutoCommit} = 0};
$sqlerr = 1 if $@;
eval {$dbh->commit};
$sqlerr = 1 if $@;
if ($sqlerr eq 0) {
  $message = $message . "<tr><td><b>" . $phrase->param("TXT0042") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>root</b></td><td>" . $phrase->param("TXT0024") . " <b>$adminpass1</b></td></tr>";
}

# Finalize message for Template
$message = $message . "</table>";

print "Content-Type: text/html\n\n";
$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0029");
$help = "admin";

$nexturl = "/admin/index.cgi";

# Print Template
&lbheader;
open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/success.html";
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

