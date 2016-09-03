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


# Version of this script
$version = "0.0.1";

##########################################################################
# Modules
##########################################################################

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use File::Copy;
use Config::Simple;
use File::HomeDir;

##########################################################################
# Variables
##########################################################################

our $home	 	= File::HomeDir->my_home;
our $email 		= param('email');
our $smtpserver 	= param('smtpserver');
our $smtpport 		= param('smtpport');
our $smtpcrypt 		= param('smtpcrypt');
our $smtpauth 		= param('smtpauth');
our $smtpuser 		= param('smtpuser');
our $smtppass 		= param('smtppass');
our $lang 		= param('lang');
our $lang 		= substr($lang,0,2);
our $sudobin;
our $mailbin;
our $result;

quotemeta($email);
quotemeta($smtpserver);
quotemeta($smtpport);
quotemeta($smtpcrypt);
quotemeta($smtpauth);
quotemeta($smtpuser);
quotemeta($smtppass);
quotemeta($lang);

if (!$smtpport) {
  $smtpport = "25";
}

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.2";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installdir      = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$sudobin         = $cfg->param("BINARIES.SUDO");
$mailbin         = $cfg->param("BINARIES.MAIL");

##########################################################################
# Language Settings
##########################################################################

# Standard is german
if ($lang eq "") {
  $lang = "de";
}

# If there's no template, use german
if (!-e "$installdir/templates/system/$lang/language.dat") {
  $lang = "de";
}

# Read translations
$languagefile = "$installdir/templates/system/$lang/language.dat";
$phrase = new Config::Simple($languagefile);

##########################################################################
# Main program
##########################################################################

# Delete old temporary config file
if (-e "/tmp/tempssmtpconf.dat" && -f "/tmp/tempssmtpconf.dat" && !-l "/tmp/tempssmtpconf.dat" && -T "/tmp/tempssmtpconf.dat") {
  unlink ("/tmp/tempssmtpconf.dat");
}

# Create temporary SSMTP Config file
open(F,">/tmp/tempssmtpconf.dat") || die "Cannot open /tmp/tempssmtpconf.dat";
  flock(F,2) if($flock);
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
  flock(F,8) if($flock);
close(F);

# Install temporary ssmtp config file
my $result = qx($home/sbin/createssmtpconf.sh start 2>/dev/null);

# Send test mail
if ($lang eq "de") {
  $result = qx(echo "Dieses ist eine Test Email von Deinem LoxBerry. Es scheint alles OK zu sein." | $mailbin -a "From: $email" -s "Test Email von Deinem LoxBerry" -v $email 2>&1);
} else {
  $result = qx(echo "This is a Test from your LoxBerry. Everything seems to be OK." | $mailbin -a "From: $email" -s "Test Email from LoxBerry" -v $email 2>&1);
}

# Output
print "Content-type: text/html; charset=iso-8859-15\n\n";
$result =~ s/\n/<br>/g;
print $phrase->param("TXT0109");
print "<br><br><pre>\n";
print $result;
print "</pre>\n\n";

# ReInstall original ssmtp config file
$result = qx($home/sbin/createssmtpconf.sh stop 2>/dev/null);

# Delete old temporary config file
if (-e "/tmp/tempssmtpconf.dat" && -f "/tmp/tempssmtpconf.dat" && !-l "/tmp/tempssmtpconf.dat" && -T "/tmp/tempssmtpconf.dat") {
  unlink ("/tmp/tempssmtpconf.dat");
}

exit;
