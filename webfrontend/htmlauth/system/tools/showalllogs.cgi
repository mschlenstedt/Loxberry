#!/usr/bin/perl


##########################################################################
# Modules
##########################################################################

use LoxBerry::Web;
use LoxBerry::Log;

use warnings;
use strict;

$LoxBerry::Log::DEBUG = 1;

our $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
our $template_title = "Show all logs";

# Version of this script
my $version = "1.2.0.1";

LoxBerry::Web::lbheader($template_title, $helplink);

my @logs = LoxBerry::Log::get_logs();

print "<table border='1px' style='width:100%; padding:8px; border: 1px solid #ddd; border-collapse: collapse; '>\n";

my $currpackage;

for my $log (@logs ) {
    if ($currpackage ne $log->{PACKAGE}) {
		print "<tr><td colspan='4'>\n";
		print "<h2>Package $log->{PACKAGE}</h2>\n" if (!$log->{_ISPLUGIN});
		print "<h2>Plugin $log->{PLUGINTITLE} (Package $log->{PACKAGE})</h2>\n" if ($log->{_ISPLUGIN});
		$currpackage = $log->{PACKAGE};
		print "</td></tr>\n";
		print "<th style='text-align:left'>Log name</th><th style='text-align:left'>Start time</th><th style='text-align:left'>End time</th><th style='text-align:left'>Filename</th>\n";
	}
	print "<tr>\n";
	print "<td>$log->{NAME}</td>\n";
	print "<td>$log->{LOGSTARTSTR}</td>\n";
	print "<td>$log->{LOGENDSTR}</td>\n";
	print "<td>\n";
	print '<a id="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=' . $log->{FILENAME} . '&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="action">Logfile</a>';
	print " $log->{FILENAME}\n";
	print "</td>\n";
	print "</tr>\n";
}


LoxBerry::Web::lbfooter();

