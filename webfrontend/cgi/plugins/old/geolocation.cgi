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

require "/opt/techbox/admin/settings.dat";

# Remove trailing slashes from paths and URLs
$datadir =~ s/(.*)\/$/$1/eg;
$wgurl =~ s/(.*)\/$/$1/eg;

# Clear parameters
$query = param('query');
$query =~ tr/A-Za-z0-9\-\_éèêâàáúûùçöäüßÖÄÜ\%\ //cd;
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

# URL to Google Geocode API
$queryurl = "http://maps.googleapis.com/maps/api/geocode/json?sensor=false&address=$query";

# If $query is empty, exit
if (!$query) {

  print "Content-type: text/html; charset=iso-8859-15\n\n";
  print "<b>$txt4</b><br><br>";
  print "<input type=\"radio\" name=\"location\" value=\"autoip\" checked=\"checked\">";
  print "$txt5";
  print "<br>\n";
  exit;

}

# If we received a query, send it to Google API
$ua = new LWP::UserAgent;
$res = $ua->get($queryurl);

$json=$res->decoded_content();

$urlstatus = $res->status_line;
$urlstatuscode = substr($urlstatus,0,3);

# Print out Dumper Output if we are in Debug Mode
if ($debug) {
  print "Content-type: text/plain\n\n";
  print "Status: $urlstatuscode\n";
  print "        $urlstatus\n\n";
  print Dumper ($json);
  exit;
}

if ($urlstatuscode ne "200") {

  print "Content-type: text/html; charset=iso-8859-15\n\n";
  print "<b>$txt4</b><br><br>";
  print "<input type=\"radio\" name=\"location\" value=\"autoip\" checked=\"checked\">";
  print "$txt5";
  print "<br>\n";
  exit;

}

# JSON Answer
$decoded_json = decode_json( $json );

# Count results
$numrestotal = 0;
for my $results( @{$decoded_json->{results}} ){
  $numrestotal++;
}

if (!$numrestotal) {

  print "Content-type: text/html; charset=iso-8859-15\n\n";
  print "$txt6<br><br>";
  print "<input type=\"radio\" name=\"location\" value=\"autoip\" checked=\"checked\">";
  print "$txt5";
  print "<br>\n";
  exit;

}

# Print search results
print "Content-type: text/html; charset=iso-8859-15\n\n";
print "<input type=\"radio\" name=\"location\" value=\"autoip\" checked=\"checked\">";
print "$txt5";
print "<br>\n";
$i = 1;
for my $results( @{$decoded_json->{results}} ){
  print "<input type=\"radio\" name=\"location\" value=\"" . $results->{geometry}->{location}->{lat} . "," . "$results->{geometry}->{location}->{lng}" . "\">";
  print "$results->{formatted_address}";
  print "<br>\n";
  $i++;
};

exit;
