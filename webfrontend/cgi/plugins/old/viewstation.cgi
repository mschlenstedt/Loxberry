#!/usr/bin/perl

# Modules
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use LWP::UserAgent;
use JSON qw( decode_json ); 
use Data::Dumper;

##########################################################################
#
## Read Settings
#
###########################################################################

require "/usr/lib/cgi-bin/data/settings.dat";

# Remove trailing slashes from paths and URLs
$datadir =~ s/(.*)\/$/$1/eg;
$wgurl =~ s/(.*)\/$/$1/eg;

# Clear parameters
$query = param('query');
$query =~ tr/A-Za-z0-9\-\_éèêâàáúûùçöäüßÖÄÜ\%\ \.\,//cd;
$wgapikey = param('key');
$wgapikey =~ tr/A-Za-z0-9//cd;
$debug = param('debug');
$debug = substr($debug,0,1);
$debug =~ tr/0-1//cd;
$lang = param('lang');
$lang = substr($lang,0,2);
$lang =~ tr/A-Za-z//cd;


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


#####################################################
#
# Lookup Station at Wunderground
#
#####################################################

# If $query is empty, exit
if (!$query) {
  $error = "$txt12";
  &error;
  exit;
}

# If $wgapikey is empty, exit
if (!$wgapikey) {
  $error = "$txt13";
  &error;
  exit;
}

# Wunderground don't use ISO-codes for language...
if ($lang eq "de") {
  $wlang = "DL";
} else {
  $wlang = $lang;
  $wlang =~ tr/a-z/A-Z/cd;
}

# Check type of station

# IP address
if ($query =~ /^autoip$/) {
  $type = "ip";
  $querytype = "";
  $usepws = "1";
}

# LatLong
elsif ($query =~ /^\d+\.?\d*\,\d+\.?\d*$/) {
  $type = "latlong";
  $querytype = "";
  $usepws = "1";
}

# Station ID (not a PWS)
elsif ($query =~ /^\d{5}$/) {
  $type = "zmw";
  $querytype = "zmw:00000.1.";
  $usepws = "0";
}

# Full ZMW
elsif ($query =~ /^\d{5}\.\d{1}\.\d{5}$/) {
  $type = "zmw";
  $querytype = "zmw:";
  $usepws = "0";
}

# Airport Code
elsif ($query =~ /^\w{4}$/) {
  $type = "airport";
  $querytype = "";
  $usepws = "0";
}

# Try PWS if eversthing else fails
else {
  $type = "pws";
  $querytype = "pws:";
  $usepws = "1";
}

# Create Query for WG API
$wgqueryurl = "$wgurl/$wgapikey/conditions/lang:$wlang/pws:$usepws/q/$querytype$query\.json";

# Get Data from API
$ua = new LWP::UserAgent;
$res = $ua->get($wgqueryurl);
$json=$res->decoded_content();

# Check status of request
$urlstatus = $res->status_line;
$urlstatuscode = substr($urlstatus,0,3);

# Error - not reachable
if ($urlstatuscode ne "200") {
  $error = $txt14;
  &error;
  exit;
}

# Print out Dumper Output if we are in Debug Mode
if ($debug) {
  print "Content-type: text/plain\n\n";
  print "URL: $wgqueryurl\n";
  print "Type: $type\n\n";
  print Dumper ($json);
  exit;
}

# Decode JSON response from server
$decoded_json = decode_json( $json );

# If we haven't found the weather station
if ($decoded_json->{response}->{error}->{type} eq "querynotfound") {
  $error = $txt15;
  &error;
  exit;
}

# If the key isn't valid
if ($decoded_json->{response}->{error}->{type} eq "keynotfound") {
  $error = $txt16;
  &error;
  exit;
}

# Set all Data into vars
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($decoded_json->{current_observation}->{observation_epoch});
$year = $year+1900;
$mon = $mon+1;
if(length($mon) == 1) { $mon="0$mon"; }
if(length($mday) == 1) { $mday="0$mday"; }
if(length($hour) == 1) { $hour="0$hour"; }
if(length($min) == 1) { $min="0$min"; }
if(length($sec) == 1) { $sec="0$sec"; }
if ($metric) {$date = "$mday\.$mon\.$year $hour:$min:$sec"};
if (!$metric) {$date = "$year-$mon-$day $hourr:$min:$sec"};
$loc_n = $decoded_json->{current_observation}->{observation_location}->{city};
$loc_c = $decoded_json->{current_observation}->{display_location}->{state_name};
$loc_ccode = $decoded_json->{current_observation}->{observation_location}->{country_iso3166};
$loc_lat = $decoded_json->{current_observation}->{observation_location}->{latitude};
$loc_long = $decoded_json->{current_observation}->{observation_location}->{longitude};
$loc_el = $decoded_json->{current_observation}->{observation_location}->{elevation};
$loc_el =~ s/(.*)\ ft$/$1/eg;
if ($metric) {$loc_el = $loc_el * 0.3048;}
if ($metric) {$tt = $decoded_json->{current_observation}->{temp_c}};
if ($metric) {$tt_fl = $decoded_json->{current_observation}->{feelslike_c}};
if (!$metric) {$tt = $decoded_json->{current_observation}->{temp_f}};
if (!$metric) {$tt_fl = $decoded_json->{current_observation}->{feelslike_f}};
$hu = $decoded_json->{current_observation}->{relative_humidity};
$hu =~ s/(.*)\%$/$1/eg;
$w_dirdes = $decoded_json->{current_observation}->{wind_dir};
$w_dir = $decoded_json->{current_observation}->{wind_degrees};
if ($metric) {$w_sp = $decoded_json->{current_observation}->{wind_kph}};
if ($metric) {$w_gu = $decoded_json->{current_observation}->{wind_gust_kph}};
if (!$metric) {$w_sp = $decoded_json->{current_observation}->{wind_mph}};
if (!$metric) {$w_gu = $decoded_json->{current_observation}->{wind_gust_mph}};
if ($metric) {$pr = $decoded_json->{current_observation}->{pressure_mb}};
if (!$metric) {$pr = $decoded_json->{current_observation}->{pressure_in}};
if ($metric) {$dp = $decoded_json->{current_observation}->{dewpoint_c}};
if (!$metric) {$dp = $decoded_json->{current_observation}->{dewpoint_f}};
if ($metric) {$vis = $decoded_json->{current_observation}->{visibility_km}};
if (!$metric) {$vis = $decoded_json->{current_observation}->{visibility_mi}};
$sr = $decoded_json->{current_observation}->{solarradiation};
if ($metric) {$hi = $decoded_json->{current_observation}->{heat_index_c}};
if (!$metric) {$hi = $decoded_json->{current_observation}->{heat_index_f}};
$uvi = $decoded_json->{current_observation}->{UV};
if ($metric) {$prec = $decoded_json->{current_observation}->{precip_today_metric}};
if (!$metric) {$prec = $decoded_json->{current_observation}->{precip_today_in}};
$weather = $decoded_json->{current_observation}->{weather};

print "Content-Type: text/html\n\n";

open(F,"$templatedir/admin/$lang.admin.viewstation.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;


#####################################################
#
# Error
#
#####################################################

sub error {

print "Content-Type: text/html\n\n";

open(F,"$templatedir/admin/$lang.admin.error.html") || die "Missing template.";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);

exit;

}

exit;
