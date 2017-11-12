#!/usr/bin/perl

# Copyright 2017 Michael Schlenstedt, michael@loxberry.de
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

use LoxBerry::System;
use Config::Simple;

# As long as LoxBerry::system does not provide all ENV
my $lbsconfig = $ENV{LBSCONFIG};
my $lbslog = $ENV{LBSLOG};

our $logmessage;
our $verbose = 1;

my $cfg      = new Config::Simple("$lbsconfig/general.cfg");
my $sendstat = is_enabled( $cfg->param("BASE.SENDSTATISTIC") );
my $curlbin  = $cfg->param("BINARIES.CURL");

# Create new ID if no exists
if (!-e "$lbsconfig/loxberryid.cfg" && $sendstat) {

  $logmessage = "INFO: Creating new random ID\n";
  &log;

  open(F,">$lbsconfig/loxberryid.cfg") or die "Cannot write $lbsconfig/loxberryid.cfg: $!";
    flock(F,2);
    print F generate(128);
    flock(F,8);
  close(F);

}

# Send ID to loxberry.de fpr usage statistics. Nothing more than Date/Time (in Unixformat) and
# the randomly ID will be send. No personal data, no data of your LoxBerry.
if ($sendstat) {

  open(F,"<$lbsconfig/loxberryid.cfg") or die "Cannot write $lbsconfig/loxberryid.cfg: $!";
    flock(F,2);
    my $lbid = <F>;
    flock(F,8);
  close(F);

  my $timestamp = time;
  my $output = qx($curlbin -f -k -s -S --show-error https://stats.loxberry.de/cgi-bin/get.cgi?id=$lbid&timestamp=$timestamp 2>&1);

  if (!$ouput) {
    $logmessage = "FAIL: Some error occurred. Giving up.\n";
  } else {
    $logmessage = "INFO: $output\n";
  }
  &log;

}


exit;

#
# Subs
#

# Create Random ID
sub generate {
        local($e) = @_;
        my($zufall,@words,$more);

        if($e =~ /^\d+$/){
                $more = $e;
        }else{
                $more = "8";
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}

# Logfile
sub log {
# Today's date for logfile
  (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime();
  $year = $year+1900;
  $mon = $mon+1;
  $mon = sprintf("%02d", $mon);
  $mday = sprintf("%02d", $mday);
  $hour = sprintf("%02d", $hour);
  $min = sprintf("%02d", $min);
  $sec = sprintf("%02d", $sec);

  if ($verbose || $error) {print "$logmessage";}

  # Logfile
  open(F,">>$lbslog/loxberryid.log");
    print F "$year-$mon-$mday $hour:$min:$sec $logmessage";
  close (F);

  return ();
}
