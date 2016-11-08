#!/usr/bin/perl

# fetch.pl
# fetches weather data (current and forecast) from Wunderground

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

#use strict;
#use warnings;

##########################################################################
# Modules
##########################################################################

use LWP::UserAgent;
use JSON qw( decode_json ); 
use Getopt::Long;
use Config::Simple;
use File::HomeDir;
use Cwd 'abs_path';

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "3.0.2";

# Figure out in which subfolder we are installed
our $psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/bin\/(.*)$/$2/g;

my $home = File::HomeDir->my_home;

my $cfg             = new Config::Simple("$home/config/system/general.cfg");
my $lang            = $cfg->param("BASE.LANG");
my $installfolder   = $cfg->param("BASE.INSTALLFOLDER");
my $miniservers     = $cfg->param("BASE.MINISERVERS");
my $clouddns        = $cfg->param("BASE.CLOUDDNS");

my $pcfg             = new Config::Simple("$installfolder/config/plugins/$psubfolder/wu4lox.cfg");
my $wuurl            = $pcfg->param("SERVER.WUURL");
my $wuapikey         = $pcfg->param("SERVER.WUAPIKEY");
my $wulang           = $pcfg->param("SERVER.WULANG");
my $stationid        = $pcfg->param("SERVER.STATIONID");

# Commandline options
my $verbose = '';
my $help = '';

GetOptions ('verbose' => \$verbose,
            'quiet'   => sub { $verbose = 0 });

# Starting...
my $logmessage = "<INFO> Starting $0 Version $version";
&log;

# Get data from Wunderground Server (API request) for current conditions
my $wgqueryurlcr = "$wuurl\/$wuapikey\/conditions\/astronomy\/forecast\/hourly\/pws:1\/lang:$wulang\/q\/$stationid\.json";

$logmessage = "<INFO> Fetching Data for $stationid";
&log;
$logmessage = "<INFO> URL: $wgqueryurlcr";
&log;

my $ua = new LWP::UserAgent;
my $res = $ua->get($wgqueryurlcr);
my $json = $res->decoded_content();

# Check status of request
my $urlstatus = $res->status_line;
my $urlstatuscode = substr($urlstatus,0,3);

if ($urlstatuscode ne "200") {
  $errormessage = "<FAIL> Failed to fetch data for $stationid\. Status Code: $urlstatuscode";
  &error;
}

# Decode JSON response from server
my $decoded_json = decode_json( $json );

# Write location data into database
$logmessage = "<INFO> Saving new Data for Timestamp $decoded_json->{current_observation}->{observation_time_rfc822} to database.";
&log;

# Saving new current data...
open(F,">$home/data/plugins/$psubfolder/current.dat") || die "Cannot open $home/data/plugins/$psubfolder/current.dat: $!";
  binmode F, ':encoding(UTF-8)';
  print F "$decoded_json->{current_observation}->{local_epoch}|";
  print F "$decoded_json->{current_observation}->{local_time_rfc822}|";
  print F "$decoded_json->{current_observation}->{local_tz_short}|";
  print F "$decoded_json->{current_observation}->{local_tz_long}|";
  print F "$decoded_json->{current_observation}->{local_tz_offset}|";
  $city = $decoded_json->{current_observation}->{observation_location}->{city};
  $city = Encode::decode("UTF-8", $city);
  print F "$city|";
  #print F "$decoded_json->{current_observation}->{observation_location}->{city}|";
  print F "$decoded_json->{current_observation}->{display_location}->{state_name}|";
  print F "$decoded_json->{current_observation}->{observation_location}->{country_iso3166}|";
  print F "$decoded_json->{current_observation}->{observation_location}->{latitude}|";
  print F "$decoded_json->{current_observation}->{observation_location}->{longitude}|";
  # Convert elevation from feet to meter
  my $elevation = $decoded_json->{current_observation}->{observation_location}->{elevation};
  $elevation =~ s/(.*)\ ft$/$1/eg;
  $elevation = $elevation * 0.3048;
  print F "$elevation|";
  print F "$decoded_json->{current_observation}->{temp_c}|";
  print F "$decoded_json->{current_observation}->{feelslike_c}|";
  # Clean Humidity var
  my $humidity = $decoded_json->{current_observation}->{relative_humidity};
  $humidity =~ s/(.*)\%$/$1/eg;
  print F "$humidity|";
  print F "$decoded_json->{current_observation}->{wind_dir}|";
  print F "$decoded_json->{current_observation}->{wind_degrees}|";
  print F "$decoded_json->{current_observation}->{wind_kph}|";
  print F "$decoded_json->{current_observation}->{wind_gust_kph}|";
  print F "$decoded_json->{current_observation}->{windchill_c}|";
  print F "$decoded_json->{current_observation}->{pressure_mb}|";
  print F "$decoded_json->{current_observation}->{dewpoint_c}|";
  print F "$decoded_json->{current_observation}->{visibility_km}|";
  print F "$decoded_json->{current_observation}->{solarradiation}|";
  print F "$decoded_json->{current_observation}->{heat_index_c}|";
  print F "$decoded_json->{current_observation}->{UV}|";
  print F "$decoded_json->{current_observation}->{precip_today_metric}|";
  print F "$decoded_json->{current_observation}->{precip_1hr_metric}|";
  print F "$decoded_json->{current_observation}->{icon}|";;
  # Convert Weather string into Weather Code
  my $weather = $decoded_json->{current_observation}->{icon};
  #$weather =~ s/^Heavy//eg; # No Heavy
  #$weather =~ s/^Light//eg; # No Light
  #$weather =~ s/\ //eg; # No Spaces
  $weather =~ tr/A-Z/a-z/; # All Lowercase
  if ($weather eq "clear") {$weather = "1";}
  elsif ($weather eq "sunny") {$weather = "1";}
  elsif ($weather eq "partlysunny") {$weather = "3";}
  elsif ($weather eq "mostlysunny") {$weather = "2";}
  elsif ($weather eq "partlycloudy") {$weather = "2";}
  elsif ($weather eq "mostlycloudy") {$weather = "3";}
  elsif ($weather eq "cloudy") {$weather = "4";}
  elsif ($weather eq "overcast") {$weather = "4";}
  elsif ($weather eq "chanceflurries") {$weather = "18";}
  elsif ($weather eq "chancesleet") {$weather = "18";}
  elsif ($weather eq "chancesnow") {$weather = "20";}
  elsif ($weather eq "flurries") {$weather = "16";}
  elsif ($weather eq "sleet") {$weather = "19";}
  elsif ($weather eq "snow") {$weather = "21";}
  elsif ($weather eq "chancerain") {$weather = "12";}
  elsif ($weather eq "rain") {$weather = "13";}
  elsif ($weather eq "chancetstorms") {$weather = "14";}
  elsif ($weather eq "tstorms") {$weather = "15";}
  elsif ($weather eq "fog") {$weather = "6";}
  elsif ($weather eq "hazy") {$weather = "5";}
  else {$weather = "0";}
  print F "$weather|";
  print F "$decoded_json->{current_observation}->{weather}|";
  print F "$decoded_json->{moon_phase}->{percentIlluminated}|";
  print F "$decoded_json->{moon_phase}->{ageOfMoon}|";
  print F "$decoded_json->{moon_phase}->{phaseofMoon}|";
  print F "$decoded_json->{moon_phase}->{hemisphere}|";
  print F "$decoded_json->{sun_phase}->{sunrise}->{hour}|";
  print F "$decoded_json->{sun_phase}->{sunrise}->{minute}|";
  print F "$decoded_json->{sun_phase}->{sunset}->{hour}|";
  print F "$decoded_json->{sun_phase}->{sunset}->{minute}";
close(F);

# Saving new daily forecast data...
open(F,">$home/data/plugins/$psubfolder/dailyforecast.dat") || die "Cannot open $home/data/plugins/$psubfolder/current.dat: $!";
  binmode F, ':encoding(UTF-8)';
  for my $results( @{$decoded_json->{forecast}->{simpleforecast}->{forecastday}} ){
    print F $results->{period} . "|";
    print F $results->{date}->{epoch} . "|";
    if(length($results->{date}->{month}) == 1) { $results->{date}->{month}="0$results->{date}->{month}"; }
    if(length($results->{date}->{day}) == 1) { $results->{date}->{day}="0$results->{date}->{day}"; }
    if(length($results->{date}->{hour}) == 1) { $results->{date}->{hour}="0$results->{date}->{hour}"; }
    if(length($results->{date}->{min}) == 1) { $results->{date}->{min}="0$results->{date}->{min}"; }
    print F "$results->{date}->{day}|";
    print F "$results->{date}->{month}|";
    print F "$results->{date}->{monthname}|";
    print F "$results->{date}->{monthname_short}|";
    print F "$results->{date}->{year}|";
    print F "$results->{date}->{hour}|";
    print F "$results->{date}->{min}|";
    print F "$results->{date}->{weekday}|";
    print F "$results->{date}->{weekday_short}|";
    print F "$results->{high}->{celsius}|";
    print F "$results->{low}->{celsius}|";
    print F "$results->{pop}|";
    print F "$results->{qpf_allday}->{mm}|";
    print F "$results->{snow_allday}->{cm}|";
    print F "$results->{maxwind}->{kph}|";
    print F "$results->{maxwind}->{dir}|";
    print F "$results->{maxwind}->{degrees}|";
    print F "$results->{avewind}->{kph}|";
    print F "$results->{avewind}->{dir}|";
    print F "$results->{avewind}->{degrees}|";
    print F "$results->{avehumidity}|";
    print F "$results->{maxhumidity}|";
    print F "$results->{minhumidity}|";
    print F "$results->{icon}|";
    # Convert Weather string into Weather Code
    my $weather = $results->{icon};
    #$weather =~ s/^Heavy//eg; # No Heavy
    #$weather =~ s/^Light//eg; # No Light
    #$weather =~ s/\ //eg; # No Spaces
    $weather =~ tr/A-Z/a-z/; # All Lowercase
    if ($weather eq "clear") {$weather = "1";}
    elsif ($weather eq "sunny") {$weather = "1";}
    elsif ($weather eq "partlysunny") {$weather = "3";}
    elsif ($weather eq "mostlysunny") {$weather = "2";}
    elsif ($weather eq "partlycloudy") {$weather = "2";}
    elsif ($weather eq "mostlycloudy") {$weather = "3";}
    elsif ($weather eq "cloudy") {$weather = "4";}
    elsif ($weather eq "overcast") {$weather = "4";}
    elsif ($weather eq "chanceflurries") {$weather = "18";}
    elsif ($weather eq "chancesleet") {$weather = "18";}
    elsif ($weather eq "chancesnow") {$weather = "20";}
    elsif ($weather eq "flurries") {$weather = "16";}
    elsif ($weather eq "sleet") {$weather = "19";}
    elsif ($weather eq "snow") {$weather = "21";}
    elsif ($weather eq "chancerain") {$weather = "12";}
    elsif ($weather eq "rain") {$weather = "13";}
    elsif ($weather eq "chancetstorms") {$weather = "14";}
    elsif ($weather eq "tstorms") {$weather = "15";}
    elsif ($weather eq "fog") {$weather = "6";}
    elsif ($weather eq "hazy") {$weather = "5";}
    else {$weather = "0";}
    print F "$weather|";
    print F "$results->{conditions}";
  print F "\n";
  }
close(F);

# Saving new hourly forecast data...
open(F,">$home/data/plugins/$psubfolder/hourlyforecast.dat") || die "Cannot open $home/data/plugins/$psubfolder/hourlyforecast.dat: $!";
  binmode F, ':encoding(UTF-8)';
  $i = 1;
  for my $results( @{$decoded_json->{hourly_forecast}} ){
    print F "$i|";
    print F "$results->{FCTTIME}->{epoch}|";
    print F "$results->{FCTTIME}->{mday_padded}|";
    print F "$results->{FCTTIME}->{mon_padded}|";
    print F "$results->{FCTTIME}->{month_name}|";
    print F "$results->{FCTTIME}->{month_name_abbrev}|";
    print F "$results->{FCTTIME}->{year}|";
    print F "$results->{FCTTIME}->{hour_padded}|";
    print F "$results->{FCTTIME}->{min}|";
    print F "$results->{FCTTIME}->{weekday_name}|";
    print F "$results->{FCTTIME}->{weekday_name_abbrev}|";
    print F "$results->{temp}->{metric}|";
    print F "$results->{feelslike}->{metric}|";
    print F "$results->{heatindex}->{metric}|";
    print F "$results->{humidity}|";
    print F "$results->{wdir}->{dir}|";
    print F "$results->{wdir}->{degrees}|";
    print F "$results->{wspd}->{metric}|";
    print F "$results->{windchill}->{metric}|";
    print F "$results->{mslp}->{metric}|";
    print F "$results->{dewpoint}->{metric}|";
    print F "$results->{sky}|";
    print F "$results->{wx}|";
    print F "$results->{uvi}|";
    print F "$results->{qpf}->{metric}|";
    print F "$results->{snow}->{metric}|";
    print F "$results->{pop}|";
    print F "$results->{fctcode}|";
    print F "$results->{icon}|";
    print F "$results->{condition}";
    print F "\n";
    $i++;
  }
close(F);

# Clean Up Databases
open(F,"+<$home/data/plugins/$psubfolder/current.dat") || die "Cannot open $home/data/plugins/$psubfolder/current.dat: $!";
 my @lines = <F>;
 seek(F,0,0);
 truncate(F,0);
 foreach (@lines){
   s/[\n\r]//g;
   if($_ =~ /^#/) {
     print F "$_\n";
     next;
   }
   s/\|--\|/"|0|"/eg;
   s/\|na\|/"|-9999.00|"/eg;
   s/\|NA\|/"|-9999.00|"/eg;
   s/\|n\/a\|/"|-9999.00|"/eg;
   s/\|N\/A\|/"|-9999.00|"/eg;
   print F "$_\n";
 }
close(F);

open(F,"+<$home/data/plugins/$psubfolder/dailyforecast.dat") || die "Cannot open $home/data/plugins/$psubfolder/dailyforecast.dat: $!";
 my @lines = <F>;
 seek(F,0,0);
 truncate(F,0);
 foreach (@lines){
   s/[\n\r]//g;
   if($_ =~ /^#/) {
     print F "$_\n";
     next;
   }
   s/\|--\|/"|0|"/eg;
   s/\|na\|/"|-9999.00|"/eg;
   s/\|NA\|/"|-9999.00|"/eg;
   s/\|n\/a\|/"|-9999.00|"/eg;
   s/\|N\/A\|/"|-9999.00|"/eg;
   print F "$_\n";
 }
close(F);

open(F,"+<$home/data/plugins/$psubfolder/hourlyforecast.dat") || die "Cannot open $home/data/plugins/$psubfolder/hourlyforecast.dat: $!";
 my @lines = <F>;
 seek(F,0,0);
 truncate(F,0);
 foreach (@lines){
   s/[\n\r]//g;
   if($_ =~ /^#/) {
     print F "$_\n";
     next;
   }
   s/\|--\|/"|0|"/eg;
   s/\|na\|/"|-9999.00|"/eg;
   s/\|NA\|/"|-9999.00|"/eg;
   s/\|n\/a\|/"|-9999.00|"/eg;
   s/\|N\/A\|/"|-9999.00|"/eg;
   print F "$_\n";
 }
close(F);

# Give OK status to client.
$logmessage = "<OK> Current Data and Forecasts saved successfully.";
&log;

# Data to Loxone
if ($verbose) { 
  system ("$home/webfrontend/cgi/plugins/$psubfolder/bin/datatoloxone.pl -v");
} else {
  system ("$home/webfrontend/cgi/plugins/$psubfolder/bin/datatoloxone.pl");
}

# Exit
exit;

##########################################################################
# Subroutinen
##########################################################################

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

  # Logfile
  open(F,">>$installfolder/log/plugins/$psubfolder/wu4lox.log");
    print F "$year-$mon-$mday $hour:$min:$sec $logmessage\n";
  close (F);

  if ($verbose || $error) {print "$logmessage\n";}

  return();

}

# Error Message
sub error {
  $logmessage = "$errormessage";
  &log;
  exit;
}
