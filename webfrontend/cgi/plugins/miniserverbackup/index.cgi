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
our $selectedcounts1;
our $selectedcounts2;
our $selectedcounts3;
our $selectedcounts4;
our $selectedcounts5;
our $selectedcounts6;
our $selectedcounts7;
our $selectedcounts8;
our $selectedcounts9;
our $selectedcounts10;
our $selectedcounts11;
our $selectedcounts12;
our $selectedcounts13;
our $selectedcounts14;
our $selectedcounts15;
our $selectedcounts16;
our $selectedcounts17;
our $selectedcounts18;
our $selectedcounts19;
our $selectedcounts20;
our $selectedcounts21;
our $selectedcounts22;
our $selectedcounts23;
our $selectedcounts24;
our $selectedcounts25;
our $selectedcounts26;
our $selectedcounts27;
our $selectedcounts28;
our $selectedcounts29;
our $selectedcounts30;
our $selectedcounts31;
our $selectedcounts32;
our $selectedcounts33;
our $selectedcounts34;
our $selectedcounts35;
our $selectedcounts36;
our $selectedcounts37;
our $selectedcounts38;
our $selectedcounts39;
our $selectedcounts40;
our $selectedcounts41;
our $selectedcounts42;
our $selectedcounts43;
our $selectedcounts44;
our $selectedcounts45;
our $selectedcounts46;
our $selectedcounts47;
our $selectedcounts48;
our $languagefileplugin;
our $phraseplugin;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.1";

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
# Todo: Ugly - could this be done mopre elegantly?!?

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

if ($bkpcounts eq "1") {
  $selectedcounts1 = "selected=selected";
} elsif ($bkpcounts eq "2") {
  $selectedcounts2 = "selected=selected";
} elsif ($bkpcounts eq "3") {
  $selectedcounts3 = "selected=selected";
} elsif ($bkpcounts eq "4") {
  $selectedcounts4 = "selected=selected";
} elsif ($bkpcounts eq "5") {
  $selectedcounts5 = "selected=selected";
} elsif ($bkpcounts eq "6") {
  $selectedcounts6 = "selected=selected";
} elsif ($bkpcounts eq "7") {
  $selectedcounts7 = "selected=selected";
} elsif ($bkpcounts eq "8") {
  $selectedcounts8 = "selected=selected";
} elsif ($bkpcounts eq "9") {
  $selectedcounts9 = "selected=selected";
} elsif ($bkpcounts eq "10") {
  $selectedcounts10 = "selected=selected";
} elsif ($bkpcounts eq "11") {
  $selectedcounts11 = "selected=selected";
} elsif ($bkpcounts eq "12") {
  $selectedcounts12 = "selected=selected";
} elsif ($bkpcounts eq "13") {
  $selectedcounts13 = "selected=selected";
} elsif ($bkpcounts eq "14") {
  $selectedcounts14 = "selected=selected";
} elsif ($bkpcounts eq "15") {
  $selectedcounts15 = "selected=selected";
} elsif ($bkpcounts eq "16") {
  $selectedcounts16 = "selected=selected";
} elsif ($bkpcounts eq "17") {
  $selectedcounts17 = "selected=selected";
} elsif ($bkpcounts eq "18") {
  $selectedcounts10 = "selected=selected";
} elsif ($bkpcounts eq "19") {
  $selectedcounts19 = "selected=selected";
} elsif ($bkpcounts eq "20") {
  $selectedcounts20 = "selected=selected";
} elsif ($bkpcounts eq "21") {
  $selectedcounts21 = "selected=selected";
} elsif ($bkpcounts eq "22") {
  $selectedcounts22 = "selected=selected";
} elsif ($bkpcounts eq "23") {
  $selectedcounts23 = "selected=selected";
} elsif ($bkpcounts eq "24") {
  $selectedcounts24 = "selected=selected";
} elsif ($bkpcounts eq "25") {
  $selectedcounts25 = "selected=selected";
} elsif ($bkpcounts eq "26") {
  $selectedcounts26 = "selected=selected";
} elsif ($bkpcounts eq "27") {
  $selectedcounts27 = "selected=selected";
} elsif ($bkpcounts eq "28") {
  $selectedcounts28 = "selected=selected";
} elsif ($bkpcounts eq "29") {
  $selectedcounts29 = "selected=selected";
} elsif ($bkpcounts eq "30") {
  $selectedcounts30 = "selected=selected";
} elsif ($bkpcounts eq "31") {
  $selectedcounts31 = "selected=selected";
} elsif ($bkpcounts eq "32") {
  $selectedcounts32 = "selected=selected";
} elsif ($bkpcounts eq "33") {
  $selectedcounts33 = "selected=selected";
} elsif ($bkpcounts eq "34") {
  $selectedcounts34 = "selected=selected";
} elsif ($bkpcounts eq "35") {
  $selectedcounts35 = "selected=selected";
} elsif ($bkpcounts eq "36") {
  $selectedcounts36 = "selected=selected";
} elsif ($bkpcounts eq "37") {
  $selectedcounts37 = "selected=selected";
} elsif ($bkpcounts eq "38") {
  $selectedcounts38 = "selected=selected";
} elsif ($bkpcounts eq "39") {
  $selectedcounts39 = "selected=selected";
} elsif ($bkpcounts eq "40") {
  $selectedcounts40 = "selected=selected";
} elsif ($bkpcounts eq "41") {
  $selectedcounts41 = "selected=selected";
} elsif ($bkpcounts eq "42") {
  $selectedcounts42 = "selected=selected";
} elsif ($bkpcounts eq "43") {
  $selectedcounts43 = "selected=selected";
} elsif ($bkpcounts eq "44") {
  $selectedcounts44 = "selected=selected";
} elsif ($bkpcounts eq "45") {
  $selectedcounts45 = "selected=selected";
} elsif ($bkpcounts eq "46") {
  $selectedcounts46 = "selected=selected";
} elsif ($bkpcounts eq "47") {
  $selectedcounts47 = "selected=selected";
} elsif ($bkpcounts eq "48") {
  $selectedcounts48 = "selected=selected";
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

print "Content-Type: text/ascii\n\n";
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
  $helplink = "/help/";
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

