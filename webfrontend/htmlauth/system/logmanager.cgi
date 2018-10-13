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
my $plugin;
our %navbar;


# $LoxBerry::Log::DEBUG = 1;

my $cgi = CGI->new;
$cgi->import_names('R');

# Version of this script
my $version = "1.2.5.3";

# Remove 'only used once' warnings
$R::showfilename if 0;
$R::header if 0;
$R::name if 0;

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/logmanager.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		%htmltemplate_options,
	);

my %SL = LoxBerry::System::readlanguage($maintemplate);

# Embedded mode - no headers and footers
my $embed;
if ($R::header and $R::header eq "none") {
	$embed = 1;
}

# In single plugin mode, show the Plugin name in title
if ($R::package) {
	$plugin = LoxBerry::System::plugindata($R::package);
	if ($plugin and $plugin->{PLUGINDB_TITLE}) {
		$template_title = $plugin->{PLUGINDB_TITLE} . " : Logfiles";
	} else {
		$template_title = "$R::package : Logfiles";
	}
	$maintemplate->param('SINGLE_PACKAGE', 1);
} else {
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . "Log Manager"; #$SL{'LOGMANAGER.WIDGETLABEL'};
}

$helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";

# Navigation (only for full mode)
if (!$embed and !$R::package) {
	$navbar{1}{Name} = "Logfiles";
	$navbar{1}{URL} = '?form=log';
	$navbar{1}{Notify_Package} = "logmanager";
	$navbar{1}{Notify_Name} = 'Log Database';

	$navbar{2}{Name} = "More Logfiles";
	$navbar{2}{URL} = '?form=legacylog';
	 
	$navbar{3}{Name} = "Apache Log";
	$navbar{3}{URL} = 'tools/logfile.cgi?logfile=system_tmpfs/apache2/error.log&header=html&format=template';
	$navbar{3}{target} = '_blank';
}

if (!$R::form or $R::form eq 'log') {
	$navbar{1}{active} = 1;
} elsif ($R::form eq 'legacylog') {
	$navbar{2}{active} = 1;
}

LoxBerry::Web::lbheader($template_title, $helplink) if (!$embed);

if (!$R::form or $R::form eq 'log') {
	form_log();
} elsif ($R::form eq 'legacylog') {
	form_legacylog();
} else {
	print "Error: Unknown form $R::form";
}

print $maintemplate->output();

LoxBerry::Web::lbfooter() if (!$embed);
exit;

################################################
# Form log (default)
################################################
sub form_log
{
	$maintemplate->param( 'FORM_LOG', 1);
	print LoxBerry::Log::get_notifications_html("logmanager", 'Log Database');
	
	$LoxBerry::Log::DEBUG=1;
	
	
	# For embedded mode, send header
	print $cgi->header(-charset=>'utf-8') if ($embed);

	my @logs = LoxBerry::Log::get_logs($R::package, $R::name);
	# print "Logs: " . scalar (@logs) . "\n";
	@logs = sort { $a->{'_ISPLUGIN'} cmp $b->{'_ISPLUGIN'} } @logs;
	
	my $currpackage;
	my $currname;

	foreach my $log (@logs) {
		if (($currname and $currname ne $log->{NAME}) or ($currpackage and $currpackage ne $log->{PACKAGE})) {
			print "</table>\n";
		}
		if ($currpackage and $currpackage ne $log->{PACKAGE}) {
		print "</div>\n";		
		}
		
		if (! defined($currpackage) or ($currpackage ne $log->{PACKAGE})) {
			my $expandview = defined $R::package ? 'false' : 'true';
			print "<div data-role='collapsible' id='coll_package_$log->{PACKAGE}' data-content-theme='true' data-collapsed='$expandview' data-collapsed-icon='carat-d' data-expanded-icon='carat-u' data-iconpos='right'>\n";
			if($log->{'_ISPLUGIN'}) {
				print "\t<h2 class='ui-bar ui-bar-a ui-corner-all' id='package_$log->{PACKAGE}'>$log->{PLUGINTITLE} <span style='font-size:80%;'>(Plugin Log)</span></h2>\n";
				print LoxBerry::Web::loglevel_select_html(
					LABEL => "Current Loglevel",
					FORMID => "loglevel_" . $log->{PACKAGE},
					PLUGIN => $log->{PACKAGE}
				);
			} else {
				print "\t<h2 class='ui-bar ui-bar-a ui-corner-all' id='package_$log->{PACKAGE}'>" . ucfirst($log->{PACKAGE}) . " <span style='font-size:80%;'>(LoxBerry System Log)</span></h2>\n";
			}
		}
		if (! defined($currname) or ($currname ne $log->{NAME})) {
			print "\t<h4>Group '" . ucfirst($log->{NAME}) . "'</h4>\n";
			print "\t<table border='1px' style='width:100%; padding:8px; border:1px solid #ddd; border-collapse: collapse;'>\n";
		}
		
		print "\t\t<tr>\n";
		print "\t\t\t<td style='text-align:center; background-color:#FFFFFF; width:80px; color:white; text-shadow: none;'>" if (!defined $log->{STATUS} or $log->{STATUS} eq "");
		print "\t\t\t<td style='text-align:center; background-color:#FF007F; width:125px; color:white;text-shadow: none;'>EMERGENCY" if (defined $log->{STATUS} and $log->{STATUS} eq "0");
		print "\t\t\t<td style='text-align:center; background-color:#990000; width:80px; color:white; text-shadow: none;'>ALERT" if (defined $log->{STATUS} and $log->{STATUS} eq "1");
		print "\t\t\t<td style='text-align:center; background-color:#CC0000; width:80px; color:white; text-shadow: none;'>CRITICAL" if (defined $log->{STATUS} and $log->{STATUS} eq "2");
		print "\t\t\t<td style='text-align:center; background-color:#FF3333; width:80px; color:white; text-shadow: none;'>Error" if (defined $log->{STATUS} and $log->{STATUS} eq "3");
		print "\t\t\t<td style='text-align:center; background-color:#FFFF33; width:80px; text-shadow: none;'>Warning" if (defined $log->{STATUS} and $log->{STATUS} eq "4");
		print "\t\t\t<td style='text-align:center; background-color:#6DAC20; width:80px; color:white; text-shadow: none;'>OK" if (defined $log->{STATUS} and $log->{STATUS} eq "5");
		print "\t\t\t<td style='text-align:center; background-color:#3333FF; width:80px; color:white; text-shadow: none;'>Info" if (defined $log->{STATUS} and $log->{STATUS} eq "6");
		print "\t\t\t<td style='text-align:center; background-color:#CCE5FF; width:80px; text-shadow: none;'>Debug" if (defined $log->{STATUS} and $log->{STATUS} eq "7");
		
		# Show info symbol for attention messages
		if(defined $log->{STATUS} and $log->{STATUS} <= 4 and defined $log->{ATTENTIONMESSAGES} and $log->{ATTENTIONMESSAGES} ne "") {
			$log->{ATTENTIONMESSAGES} =~ s/\n/<br>\n/g;
			print "&nbsp;<a href='#attmsg_$log->{KEY}' data-rel='popup' data-transition='fade'><img src='/system/images/notification_info_small.svg' height='15' width='15'></a>\n";
			print "\t\t\t\t<div data-role='popup' id='attmsg_$log->{KEY}' class='ui-content' data-arrow='true' >\n";
			print "\t\t\t\t\t<a href='#' data-rel='back' class='ui-btn ui-corner-all ui-shadow ui-btn-a ui-icon-delete ui-btn-icon-notext ui-btn-left'>Close</a>\n";
			print "\t\t\t\t\t<p><b>";
			print "Summery of important logfile messages:";
			print "</b><br>";
			print "$log->{ATTENTIONMESSAGES}";
			print "</p>\n";
			print "\t\t\t\t</div>";
		
		}
		
		
		
		print "</td>\n";
		print "\t\t\t<td>$log->{LOGSTARTMESSAGE}</td>\n";
		print "\t\t\t<td>$log->{LOGSTARTSTR} - $log->{LOGENDSTR}</td>\n";
		print "\t\t\t<td>";
		print "<a id='btnlogs' data-role='button' href='/admin/system/tools/logfile.cgi?logfile=$log->{FILENAME}&header=html&format=template' target='_blank' data-inline='true' data-mini='true' data-icon='action'>Logfile</a>";
		print "\t\t\t\t\t$log->{FILENAME}\n" if ($R::showfilename);
		print "</td>\n";
		my $filesize = -s $log->{FILENAME};
		print "\t\t\t<td>" . LoxBerry::System::bytes_humanreadable($filesize, "B") . "</td>\n";
		print "\t\t</tr>\n";
		
		$currpackage = $log->{'PACKAGE'};
		$currname = $log->{'NAME'};
		
	}
	
	# lastline-Closing
	if (@logs) {
		print "\t</table>\n";
		print "</div>\n";
	}	
	
	return;
}

################################################
# Form legacylog
################################################

sub form_legacylog
{
	require File::Find::Rule;
	require Time::Piece;
	
	$maintemplate->param( 'FORM_LEGACYLOG', 1);
	
	# Read plugin list
	my @plugins;
	if($R::package) {
		push(@plugins, \$plugin);
	} else {
		@plugins = LoxBerry::System::get_plugins();
		@plugins = sort { $a->{'PLUGINDB_TITLE'} cmp $b->{'PLUGINDB_TITLE'} } @plugins;
	}
	
	# Generate logfile list of LogDB
	my @logs = LoxBerry::Log::get_logs($R::package);
	
	# Uniquify logfiles from LogDB
	my %dblogfiles_hash;
	foreach(@logs) {
		$dblogfiles_hash{$_->{'FILENAME'}} = 1;
	}
	
	# Get all logfiles of plugin log directories
	my @displayplugins;
	foreach my $key (keys @plugins) {
		my @files = File::Find::Rule->file()
			->name( '*.log' )
			#->nonempty
			->in("$lbhomedir/log/plugins/$plugins[$key]->{'PLUGINDB_FOLDER'}");
		
		next if(!@files);
		#Remove logs from the SDK 
		@files = grep {not exists $dblogfiles_hash{$_}} @files; 
		
		# Loop through files to get size and modification date
		my @pluginfiles;
		my $basepath_length = length("$lbhomedir/log/plugins/$plugins[$key]->{'PLUGINDB_FOLDER'}") + 1;
		foreach my $filename (@files) {
			my %filedata;
			my @statdata = stat($filename);
			$filedata{'filename'} = $filename;
			$filedata{'fileshortname'} = substr($filename, $basepath_length);
			$filedata{'filesize'} = LoxBerry::System::bytes_humanreadable($statdata[7]);
			#my $t = localtime($statdata[9]);
			$filedata{'filemtime'} = localtime($statdata[9])->strftime("%d.%m.%Y %H:%M");
			push @pluginfiles, \%filedata;
		}
		$plugins[$key]->{'FILES'} = \@pluginfiles;
		push @displayplugins, $plugins[$key];
		
	}
	
	#require Data::Dumper;
	#print Data::Dumper->Dump(\@plugins) . "\n";
		
	
	$maintemplate->param("PLUGINS", \@displayplugins);
	
	return;
}