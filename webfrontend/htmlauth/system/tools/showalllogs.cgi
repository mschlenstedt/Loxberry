#!/usr/bin/perl


##########################################################################
# Modules
##########################################################################

use LoxBerry::Web;
use LoxBerry::Log;
use CGI;

use warnings;
use strict;

my $template_title;
my $helplink;

# $LoxBerry::Log::DEBUG = 1;

my $cgi = CGI->new;
$cgi->import_names('R');


# Version of this script
my $version = "1.2.0.2";

if ($R::package) {
	my $plugin = LoxBerry::System::plugindata($R::package);
	if ($plugin->{PLUGINDB_TITLE}) {
		$template_title = $plugin->{PLUGINDB_TITLE} . " : Logfiles";
	} else {
		$template_title = ": Logfiles";
	}
} else {
	$template_title = ": All Logfiles";
}


$helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";



LoxBerry::Web::lbheader($template_title, $helplink);

my @logs = LoxBerry::Log::get_logs($R::package, $R::name);

print "<table border='1px' style='width:100%; padding:8px; border: 1px solid #ddd; border-collapse: collapse; '>\n";

my $currpackage;

for my $log (@logs ) {
    if ($currpackage ne $log->{PACKAGE}) {
		print "<tr><td colspan='5'>\n";
		print "<h2>Logfiles Package $log->{PACKAGE}</h2>\n" if (!$log->{_ISPLUGIN});
		print "<h2>Logfiles Plugin $log->{PLUGINTITLE}</h2>\n" if ($log->{_ISPLUGIN});
		$currpackage = $log->{PACKAGE};
		print "</td></tr>\n";
		print "<th style='text-align:left'>Log name</th><th style='text-align:left'>Start time</th><th style='text-align:left'>End time</th><th style='text-align:left'>Logfile</th>\n";
		print "<th style='text-align:left'>File size</th>\n";
	}
	print "<tr>\n";
	print "<td>$log->{NAME}</td>\n";
	print "<td>$log->{LOGSTARTSTR}</td>\n";
	print "<td>$log->{LOGENDSTR}</td>\n";
	print "<td>\n";
	print '<a id="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=' . $log->{FILENAME} . '&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="action">Logfile</a>';
	print " $log->{FILENAME}\n" if ($R::showfilename);
	print "</td>\n";
	my $filesize = -s $log->{FILENAME};
	print "<td>" . LoxBerry::System::bytes_humanreadable($filesize, "B") . "</td>\n";
	print "</tr>\n";
}


LoxBerry::Web::lbfooter();

