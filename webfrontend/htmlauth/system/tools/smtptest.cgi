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
$version = "3.0.0.0";


##
## THIS SCRIPT IS OBSOLETE STARTING FROM LOXBERRY 1.4
## TESTMAIL IS SENT FROM mailserver.cgi using AJAX
##



##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use File::Copy;
use strict;

##########################################################################
# Variables
##########################################################################

my $email = param('email');
my $smtpserver = param('smtpserver');
my $smtpport = param('smtpport');
my $smtpcrypt = is_enabled(param('smtpcrypt')) ? 1 : undef;
my $smtpauth = is_enabled(param('smtpauth')) ? 1 : undef;
my $smtpuser = param('smtpuser');
my $smtppass = param('smtppass');
my $lf = param('lf'); # Linefeed in output
my $mailbin = `which mailx`;
my $result;

if (!$smtpport) {
  $smtpport = "25";
}

print STDERR "SMTPCRYPT: " . $smtpcrypt . "\n";

##########################################################################
# Language Settings
##########################################################################

my $lang = lblanguage();
my %SL = LoxBerry::System::readlanguage();

##########################################################################
# Main program
##########################################################################
my $flock;

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

  if (defined $smtpauth) {
    print F "# Authentication\n";
    print F "AuthUser=$smtpuser\n";
    print F "AuthPass=$smtppass\n\n";
  }

  if (defined $smtpcrypt) {
    print F "# Use encryption\n";
    print F "UseTLS=YES\n";
	print F "UseSTARTTLS=YES\n\n";
  }
  else {
    print F "# Dont use encryption\n";
    print F "UseTLS=NO\n";
	print F "UseSTARTTLS=NO\n\n";
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
my $result = qx($lbssbindir/createssmtpconf.sh start 2>/dev/null);

my $friendlyname = trim(LoxBerry::System::lbfriendlyname());
my $hostname = LoxBerry::System::lbhostname();
$friendlyname = defined $friendlyname ? $friendlyname : $hostname;
$friendlyname .= " LoxBerry";

require MIME::Base64;

my $subject = $SL{'MAILSERVER.TESTMAIL_SUBJECT'};
$subject= "=?utf-8?b?".MIME::Base64::encode($subject, "")."?=";
my $headerfrom = "From: =?utf-8?b?". MIME::Base64::encode($friendlyname, "") . "?= <" . $email . ">";
my $contenttype = 'Content-Type: text/plain; charset="UTF-8"';
my $message = $SL{'MAILSERVER.TESTMAIL_CONTENT'};

# Send test mail
$result = qx(echo "$message" | $mailbin -a "$headerfrom" -a "$contenttype" -s "$subject" -v $email 2>&1);

# Output
print "Content-type: text/html; charset=utf-8\n\n";

$result =~ s/\n/<br>/g if (!$lf);
print '<p>' . $SL{'MAILSERVER.MSG_TEST_INTRO'} . '</p>';
print '<div style="font-size:80%;  font-family: "Lucida Console", "Lucida Sans Typewriter", monaco, "Bitstream Vera Sans Mono", monospace;">';
print $result;
print "</div>";

# ReInstall original ssmtp config file
$result = qx($lbssbindir/createssmtpconf.sh stop 2>/dev/null);

# Delete old temporary config file
if (-e "/tmp/tempssmtpconf.dat" && -f "/tmp/tempssmtpconf.dat" && !-l "/tmp/tempssmtpconf.dat" && -T "/tmp/tempssmtpconf.dat") {
	unlink ("/tmp/tempssmtpconf.dat");
}

exit;
