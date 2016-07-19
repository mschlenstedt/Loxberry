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
use File::HomeDir;
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
our $output;
our $message;
our $nexturl;
our $do;
my $home = File::HomeDir->my_home;
my $subfolder;
our $verbose;
our $maxfiles;
our $autobkp;
our $bkpcron;
our $bkpcounts;
our $selectedauto1;
our $selectedauto2;
our $selectedcron1;
our $selectedcron2;
our $selectedcron3;
our $selectedcron4;
our $selectedcron5;
our $selectedcron6;
our $languagefileplugin;
our $phraseplugin;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.4";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");

$cfg             = new Config::Simple("$installfolder/config/plugins/miniserverbackup/miniserverbackup.cfg");
$verbose         = $cfg->param("MSBACKUP.VERBOSE");
$maxfiles        = $cfg->param("MSBACKUP.MAXFILES");
$subfolder       = $cfg->param("MSBACKUP.SUBFOLDER");
$autobkp         = $cfg->param("MSBACKUP.AUTOBKP");
$bkpcron         = $cfg->param("MSBACKUP.CRON");
$bkpcounts       = $cfg->param("MSBACKUP.MAXFILES");

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

$languagefileplugin = "$installfolder/templates/plugins/miniserverbackup/$lang/language.dat";
$phraseplugin = new Config::Simple($languagefileplugin);

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
if ($saveformdata) {
  &save;
}

elsif ($do eq "log") {
  &log;
}

elsif ($do eq "backup") {
  &backup;
}

else {
  &form;
}

exit;

#####################################################
# Form
#####################################################

sub form {

# Filter
quotemeta($verbose);
quotemeta($maxfiles);
quotemeta($autobkp);
quotemeta($bkpcron);
quotemeta($bkpcounts);

# Prepare form defaults
if ($autobkp eq "on") {
  $selectedauto2 = "selected=selected";
} else {
  $selectedauto1 = "selected=selected";
}

if ($bkpcron eq "15min") {
  $selectedcron1 = "selected=selected";
} elsif ($bkpcron eq "30min") {
  $selectedcron2 = "selected=selected";
} elsif ($bkpcron eq "60min") {
  $selectedcron3 = "selected=selected";
} elsif ($bkpcron eq "1d") {
  $selectedcron4 = "selected=selected";
} elsif ($bkpcron eq "1w") {
  $selectedcron5 = "selected=selected";
} elsif ($bkpcron eq "1m") {
  $selectedcron6 = "selected=selected";
}

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0040");

# Print Template
&header;
open(F,"$installfolder/templates/plugins/miniserverbackup/$lang/settings.html") || die "Missing template plugins/miniserverbackup/$lang/settings.html";
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
$autobkp    = param('autobkp');
$bkpcron    = param('bkpcron');
$bkpcounts  = param('bkpcounts');

# Filter
quotemeta($autobkp);
quotemeta($bkpcron);
quotemeta($bkpcounts);

# Write configuration file(s)
$cfg->param("MSBACKUP.AUTOBKP", "$autobkp");
$cfg->param("MSBACKUP.CRON", "$bkpcron");
$cfg->param("MSBACKUP.MAXFILES", "$bkpcounts");
$cfg->save();

# Create Cronjob
if ($autobkp eq "on") {
  if ($bkpcron eq "15min") {
    system ("ln -s $installfolder/webfrontend/cgi/plugins/$subfolder/bin/createmsbackup.pl $installfolder/system/cron/cron.15min/$subfolder");
    unlink ("$installfolder/system/cron/cron.30min/$subfolder");
    unlink ("$installfolder/system/cron/cron.hourly/$subfolder");
    unlink ("$installfolder/system/cron/cron.daily/$subfolder");
    unlink ("$installfolder/system/cron/cron.weekly/$subfolder");
    unlink ("$installfolder/system/cron/cron.monthly/$subfolder");
  }
  if ($bkpcron eq "30min") {
    system ("ln -s $installfolder/webfrontend/cgi/plugins/$subfolder/bin/createmsbackup.pl $installfolder/system/cron/cron.30min/$subfolder");
    unlink ("$installfolder/system/cron/cron.15min/$subfolder");
    unlink ("$installfolder/system/cron/cron.hourly/$subfolder");
    unlink ("$installfolder/system/cron/cron.daily/$subfolder");
    unlink ("$installfolder/system/cron/cron.weekly/$subfolder");
    unlink ("$installfolder/system/cron/cron.monthly/$subfolder");
  }
  if ($bkpcron eq "60min") {
    system ("ln -s $installfolder/webfrontend/cgi/plugins/$subfolder/bin/createmsbackup.pl $installfolder/system/cron/cron.hourly/$subfolder");
    unlink ("$installfolder/system/cron/cron.15min/$subfolder");
    unlink ("$installfolder/system/cron/cron.30min/$subfolder");
    unlink ("$installfolder/system/cron/cron.daily/$subfolder");
    unlink ("$installfolder/system/cron/cron.weekly/$subfolder");
    unlink ("$installfolder/system/cron/cron.monthly/$subfolder");
  }
  if ($bkpcron eq "1d") {
    system ("ln -s $installfolder/webfrontend/cgi/plugins/$subfolder/bin/createmsbackup.pl $installfolder/system/cron/cron.daily/$subfolder");
    unlink ("$installfolder/system/cron/cron.15min/$subfolder");
    unlink ("$installfolder/system/cron/cron.30min/$subfolder");
    unlink ("$installfolder/system/cron/cron.hourly/$subfolder");
    unlink ("$installfolder/system/cron/cron.weekly/$subfolder");
    unlink ("$installfolder/system/cron/cron.monthly/$subfolder");
  }
  if ($bkpcron eq "1w") {
    system ("ln -s $installfolder/webfrontend/cgi/plugins/$subfolder/bin/createmsbackup.pl $installfolder/system/cron/cron.weekly/$subfolder");
    unlink ("$installfolder/system/cron/cron.15min/$subfolder");
    unlink ("$installfolder/system/cron/cron.30min/$subfolder");
    unlink ("$installfolder/system/cron/cron.hourly/$subfolder");
    unlink ("$installfolder/system/cron/cron.daily/$subfolder");
    unlink ("$installfolder/system/cron/cron.monthly/$subfolder");
  }
  if ($bkpcron eq "1m") {
    system ("ln -s $installfolder/webfrontend/cgi/plugins/$subfolder/bin/createmsbackup.pl $installfolder/system/cron/cron.monthly/$subfolder");
    unlink ("$installfolder/system/cron/cron.15min/$subfolder");
    unlink ("$installfolder/system/cron/cron.30min/$subfolder");
    unlink ("$installfolder/system/cron/cron.hourly/$subfolder");
    unlink ("$installfolder/system/cron/cron.daily/$subfolder");
    unlink ("$installfolder/system/cron/cron.weekly/$subfolder");
  }
} else {
  unlink ("$installfolder/system/cron/cron.15min/$subfolder");
  unlink ("$installfolder/system/cron/cron.30min/$subfolder");
  unlink ("$installfolder/system/cron/cron.hourly/$subfolder");
  unlink ("$installfolder/system/cron/cron.daily/$subfolder");
  unlink ("$installfolder/system/cron/cron.weekly/$subfolder");
  unlink ("$installfolder/system/cron/cron.monthly/$subfolder");
}

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0040");

$message = $phraseplugin->param("TXT0002");
$nexturl = "./index.cgi?do=form";

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

#####################################################
# Logfile
#####################################################

sub log {

if (!-e "$installfolder/log/plugins/miniserverbackup/backuplog.log") {
  $error = $phraseplugin->param("TXT0004");
  &error;
  exit;
}

print "Content-Type: text/plain\n\n";
open(F,"$installfolder/log/plugins/miniserverbackup/backuplog.log") || die "Missing file /log/plugins/miniserverbackup/backuplog.log";
  while (<F>) {
    print $_;
  }
close(F);

exit;

}

#####################################################
# Manual backup
#####################################################

sub backup {


print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0040");

$message = $phraseplugin->param("TXT0003");
$nexturl = "./index.cgi?do=form";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/succses.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

# Create Backup
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
 system("./bin/createmsbackup.pl &");
}

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
  open(F,"$installfolder/templates/plugins/miniserverbackup/$lang/help.html") || die "Missing template plugins/miniserverbackup/$lang/help.html";
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

