#!/usr/bin/perl

# Modules
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use File::Copy;

##########################################################################
#
## Read Settings
#
###########################################################################

require "/opt/techbox/admin/settings.dat";

# Remove trailing slashes from paths and URLs
$datadir =~ s/(.*)\/$/$1/eg;
$wgurl =~ s/(.*)\/$/$1/eg;

# Clear parameters
$email = param('email');
$email =~ tr/A-Za-z0-9\-\_\.\@//cd;

$smtpserver = param('smtpserver');
$smtpserver =~ tr/A-Za-z0-9\-\_\.\@//cd;
$smtpport = param('smtpport');
$smtpport = substr($smtpport,0,6);
$smtpport =~ tr/0-9//cd;
$smtpcrypt = param('smtpcrypt');
$smtpcrypt = substr($smtpcrypt,0,1);
$smtpcrypt =~ tr/0-1//cd;
$smtpauth = param('smtpauth');
$smtpauth = substr($smtpauth,0,1);
$smtpauth =~ tr/0-1//cd;

$smtpuser = param('smtpuser');
$smtppass = param('smtppass');

$lang = param('lang');
$lang = substr($lang,0,2);
$lang =~ tr/A-Za-z//cd;

if (!$smtpport) {
  $smtpport = "25";
}

##########################################################################
#
# Language Settings
#
##########################################################################

# Standard is german
if ($lang eq "") {
  $lang = "de";
}
if (!-e "$templatedir/$lang.language.dat") {
  $lang = "de";
}

require "$templatedir/$lang.language.dat";

# Delete old temporary config file
if (-e "/tmp/tempssmtpconf.dat" && -f "/tmp/tempssmtpconf.dat" && !-l "/tmp/tempssmtpconf.dat" && -T "/tmp/tempssmtpconf.dat") {
  unlink ("/tmp/tempssmtpconf.dat");
}
# Delete old backup file
if (-e "/etc/ssmtp/ssmtp.conf.bkp" && -f "/etc/ssmtp/ssmtp.conf.bkp" && !-l "/etc/ssmtp/ssmtp.conf.bkp" && -T "/etc/ssmtp/ssmtp.conf.bkp") {
  unlink ("/etc/ssmtp/ssmtp.conf.bkp");
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
hostname=Techbox.local

# Are users allowed to set their own From: address?
# YES - Allow the user to specify their own From: address
# NO - Use the system gen
FromLineOverride=YES
ENDFILE
  flock(F,8) if($flock);
close(F);

# Install temporary ssmtp config file
my $result = qx(sudo /opt/techbox/sbin/createssmtpconf.sh start 2>/dev/null);

# Send test mail
my $result = qx(echo "This is a Test from your TechBox. Everything seems to be OK." | mail -r "$email" -s "Test Email from TechBox" -v $email 2>&1);

# Output
print "Content-type: text/html; charset=iso-8859-15\n\n";
$result =~ s/\n/<br>/g;
print "$txt8<br><br>\n";
print $result;
print "\n\n";

# ReInstall original ssmtp config file
my $result = qx(sudo /opt/techbox/sbin/createssmtpconf.sh stop 2>/dev/null);

exit;
