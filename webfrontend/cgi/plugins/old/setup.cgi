#!/usr/bin/perl

# Version of this script
$version = "0.0.1";

##########################################################################
#
# Modules
#
##########################################################################

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use LWP::UserAgent;

##########################################################################
#
# Read Settings
#
##########################################################################

require "/opt/techbox/admin/settings.dat";

# Remove trailing slashes from paths and URLs
$webpath =~ s/(.*)\/$/$1/eg;
$datadir =~ s/(.*)\/$/$1/eg;
$templatedir =~ s/(.*)\/$/$1/eg;

#########################################################################
#
# PARAMETER
#
#########################################################################

# Everything from URL
foreach (split(/&/,$ENV{'QUERY_STRING'})){
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  if($query{$namef}){
    $query{$namef} .= ",$value";
    $Multiple{$namef} = 1;
  }else{
    $query{$namef} = $value;
  }
}
# And this one we really want to use
foreach $var ("lang","step") {
  ${$var} = $query{$var};
}

# Everything from Forms
foreach $var ("miniserverip","admin","pass","location","wundergroundkey","email","smtpserver",
              "smtpport","smtpcrypt","smtpauth","smtpuser","smtppass","adminuser","adminpass1",
              "adminpass2") {
  ${$var} = param($var);
}

$miniserverip =~ tr/0-9\.//cd;
$miniserverip = substr($miniserverip,0,14);
$admin =~ tr/A-Za-z0-9\-\_ÈËÍ‚‡·˙˚˘Áˆ‰¸ﬂ÷ƒ‹//cd;
$location =~ tr/a-zA-Z0-9\.\,//cd;
$wundergroundkey =~ tr/a-zA-Z0-9//cd;
$email =~ tr/A-Za-z0-9\-\_\.\@//cd;
$smtpserver =~ tr/A-Za-z0-9\-\_\.\@//cd;
$smtpport = substr($smtpport,0,6);
$smtpport =~ tr/0-9//cd;
$smtpcrypt = substr($smtpcrypt,0,1);
$smtpcrypt =~ tr/0-1//cd;
$smtpauth = substr($smtpauth,0,1);
$smtpauth =~ tr/0-1//cd;

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

#########################################################################
#
# What should we do
#
#########################################################################

# Step 1 or beginning
if ($step eq "0" || !$step) {
  &step0;
}

if ($step eq "1") {
  &step1;
}

if ($step eq "2") {
  &step2;
}

if ($step eq "3") {
  &step3;
}

if ($step eq "4") {
  &step4;
}

if ($step eq "5") {
  &step5;
}

exit;

#####################################################
# 
# Step 0
#
# Welcome Message
#
#####################################################

sub step0 {

$step++;

print "Content-Type: text/html\n\n";

open(F,"$templatedir/setup/$lang.setup.step00.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

#####################################################
# 
# Step 1
#
# Miniserver Data
#
#####################################################

sub step1 {

$step++;

print "Content-Type: text/html\n\n";

open(F,"$templatedir/setup/$lang.setup.step01.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

#####################################################
# 
# Step 2
#
# Weatherground Data
#
#####################################################

sub step2 {

# Test if Miniserver is reachable
my $url = "http://$admin:$pass\@$miniserverip/dev/sps/status";
my $ua = LWP::UserAgent->new;
$ua->timeout(5);
$ua->env_proxy;
my $response = $ua->get($url);

if (!$response->is_success) {
  $error = $txt3;
  &error;
  exit;
}

$step++;

print "Content-Type: text/html\n\n";

open(F,"$templatedir/setup/$lang.setup.step02.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

#####################################################
# 
# Step 3
#
# Mailserver Data
#
#####################################################

sub step3 {

# Test if we have a Wunderground key
if (!$wundergroundkey) {
  $error = $txt7;
  &error;
  exit;
}

# If no location was given, use "autoip"
if (!$location) {
  $location = "autoip";
}

$step++;

print "Content-Type: text/html\n\n";

open(F,"$templatedir/setup/$lang.setup.step03.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

#####################################################
# 
# Step 4
#
# Admin Password
#
#####################################################

sub step4 {

if (!$smtpport) {
  $smtpport = "25";
}

$step++;

print "Content-Type: text/html\n\n";

open(F,"$templatedir/setup/$lang.setup.step04.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

#####################################################
# 
# Step 5
#
# Install
#
#####################################################

sub step5 {

if ($adminuser =~ /\W+/){
  $error = "$txt9";
  &error;
  exit;
}

if (!$adminpass1 || !$adminuser){
  $error = "$txt10";
  &error;
  exit;
}

if ($adminpass1 ne $adminpass2){
  $error = "$txt11";
  &error;
  exit;
}

$step++;

print "Content-Type: text/html\n\n";

open(F,"$templatedir/setup/$lang.setup.step05.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

exit;

#####################################################
# 
# Error
#
#####################################################

sub error {

print "Content-Type: text/html\n\n";

open(F,"$templatedir/setup/$lang.setup.error.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

exit;
