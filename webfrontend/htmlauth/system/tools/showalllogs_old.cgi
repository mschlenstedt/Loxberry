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
my $version = "1.2.5.2";

# Remove 'only used once' warnings
$R::showfilename if 0;
$R::header if 0;
$R::name if 0;

my %SL = LoxBerry::System::readlanguage(undef);

my $embed;
if ($R::header and $R::header eq "none") {
	$embed = 1;
}

if ($R::package) {
	my $plugin = LoxBerry::System::plugindata($R::package);
	if ($plugin and $plugin->{PLUGINDB_TITLE}) {
		$template_title = $plugin->{PLUGINDB_TITLE} . " : Logfiles";
	} else {
		$template_title = "$R::package : Logfiles";
	}
} else {
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . "Log Manager"; #$SL{'LOGMANAGER.WIDGETLABEL'};
}

$helplink = "https://wiki.loxberry.de/";

LoxBerry::Web::lbheader($template_title, $helplink) if (!$embed);
print $cgi->header(-charset=>'utf-8') if ($embed);

my @logs = LoxBerry::Log::get_logs($R::package, $R::name);
my @logs = sort { $a->{'_ISPLUGIN'} <=> $b->{'_ISPLUGIN'} } @logs;

my $currpackage;
my $currname;

# print STDERR "==== SHOWALLLOGS ====\n";
foreach my $log (@logs) {
	if ($currname ne $log->{NAME} or $currpackage ne $log->{PACKAGE}) {
		print "</table>\n";
	}
	if ($currpackage ne $log->{PACKAGE}) {
	print "</div>\n";		
	}
	
	if (! defined($currpackage) or ($currpackage ne $log->{PACKAGE})) {
		my $expandview = defined $R::package ? 'false' : 'true';
		print "<div data-role='collapsible' data-content-theme='true' data-collapsed='$expandview' data-collapsed-icon='carat-d' data-expanded-icon='carat-u' data-iconpos='right'>\n";
		print "<h2 class='ui-bar ui-bar-a ui-corner-all' id='package_$log->{PACKAGE}'>" . ucfirst($log->{PACKAGE}) . " <span style='font-size:80%;'>(LoxBerry System Log)</span></h2>\n" if (!$log->{'_ISPLUGIN'});
		print "<h2 class='ui-bar ui-bar-a ui-corner-all' id='package_$log->{PACKAGE}'>$log->{PLUGINTITLE} <span style='font-size:80%;'>(Plugin Log)</span></h2>\n" if ($log->{'_ISPLUGIN'});
		# print "<tr>\n";
		# print "<th style='text-align:center'>Status</th>\n";
		# # print "<th style='text-align:left'>Log name</th>\n";
		# print "<th style='text-align:left'>Start message</th>\n";
		# print "<th style='text-align:left'>Start and End time</th>\n";
		# #print "<th style='text-align:left'>End time</th>\n";
		# print "<th style='text-align:left'>Logfile</th>\n";
		# print "<th style='text-align:left'>File size</th>\n";
		# print "</tr>\n";
	}
	if (! defined($currname) or ($currname ne $log->{NAME})) {
		print "<h4>Group '" . ucfirst($log->{NAME}) . "'</h4>\n";
		print '<table border="1px" style="width:100%; padding:8px; border:1px solid #ddd; border-collapse: collapse;">' . "\n";
	}
	
	print "<tr>\n";
	# print "<td style='text-align:center'>$log->{STATUS}</td>\n";
	print "<td style='text-align:center; background-color:#FFFFFF; width:80px; color:white; text-shadow: none;'></td>\n" if (!$log->{STATUS} or $log->{STATUS} eq "");
	print "<td style='text-align:center; background-color:#FF007F; width:80px; color:white;text-shadow: none;'>EMERGENCY</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "0");
	print "<td style='text-align:center; background-color:#990000; width:80px; color:white; text-shadow: none;'>ALERT</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "1");
	print "<td style='text-align:center; background-color:#CC0000; width:80px; color:white; text-shadow: none;'>CRITICAL</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "2");
	print "<td style='text-align:center; background-color:#FF3333; width:80px; color:white; text-shadow: none;'>Error</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "3");
	print "<td style='text-align:center; background-color:#FFFF33; width:80px; text-shadow: none;'>Warning</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "4");
	print "<td style='text-align:center; background-color:#6DAC20; width:80px; color:white; text-shadow: none;'>OK</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "5");
	print "<td style='text-align:center; background-color:#3333FF; width:80px; color:white; text-shadow: none;'>Info</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "6");
	print "<td style='text-align:center; background-color:#CCE5FF; width:80px; text-shadow: none;'>Debug</td>\n" if ($log->{STATUS} and $log->{STATUS} eq "7");
	
	# print "<td>$log->{NAME}</td>\n";
	print "<td>$log->{LOGSTARTMESSAGE}</td>\n";
	print "<td>$log->{LOGSTARTSTR} - $log->{LOGENDSTR}</td>\n";
	#print "<td>$log->{LOGENDSTR}</td>\n";
	print "<td>\n";
	print '<a id="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=' . $log->{FILENAME} . '&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="action">Logfile</a>';
	print " $log->{FILENAME}\n" if ($R::showfilename);
	print "</td>\n";
	my $filesize = -s $log->{FILENAME};
	print "<td>" . LoxBerry::System::bytes_humanreadable($filesize, "B") . "</td>\n";
	print "</tr>\n";
	
	$currpackage = $log->{'PACKAGE'};
	$currname = $log->{'NAME'};
	
}


LoxBerry::Web::lbfooter() if (!$embed);

