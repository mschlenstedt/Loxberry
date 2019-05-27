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
my $helptemplate;
my $plugin;
our %navbar;

# $LoxBerry::Log::DEBUG = 1;

my $cgi = CGI->new;
$cgi->import_names('R');

# Version of this script
my $version = "1.4.2.1";

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

$helplink = "https://www.loxwiki.eu/x/YYgKAw";
$helptemplate = "help_logmanager.html";

# Navigation (only for full mode)
if (!$embed and !$R::package) {
	$navbar{1}{Name} = $SL{'LOGMANAGER.LOG_NAVBAR'};
	$navbar{1}{URL} = '?form=log';
	$navbar{1}{Notify_Package} = "logmanager";
	$navbar{1}{Notify_Name} = 'Log Database';

	$navbar{2}{Name} = $SL{'LOGMANAGER.LEGACY_NAVBAR'};
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

LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate) if (!$embed);

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
	
	# For embedded mode, send header
	print $cgi->header(-charset=>'utf-8') if ($embed);

	my @logs = LoxBerry::Log::get_logs($R::package, $R::name);
	# print "Logs: " . scalar (@logs) . "\n";
	@logs = sort { (defined $a->{'_ISPLUGIN'} ? $a->{'_ISPLUGIN'} : "0") cmp (defined $b->{'_ISPLUGIN'} ? $b->{'_ISPLUGIN'} : "0") } @logs;
	
	my $currpackage;
	my $currname;

	foreach my $log (@logs) {
		if (($currname and $currname ne $log->{NAME}) or ($currpackage and $currpackage ne $log->{PACKAGE})) {
			print "</table>\n";
		}
		if ($currpackage and $currpackage ne $log->{PACKAGE}) {
		print "</div>\n";		
		}
		
		my $package_esc = $log->{PACKAGE};
		$package_esc =~ tr/ /_/;
		
		if (! defined($currpackage) or ($currpackage ne $log->{PACKAGE})) {
			my $expandview = defined $R::package ? 'false' : 'true';
			print "<div data-role='collapsible' id='coll_package_$package_esc' data-content-theme='true' data-collapsed='$expandview' data-collapsed-icon='carat-d' data-expanded-icon='carat-u' data-iconpos='right'>\n";
			if($log->{'_ISPLUGIN'}) {
				print "\t<h2 class='ui-bar ui-bar-a ui-corner-all' id='package_$package_esc'>$log->{PLUGINTITLE} <span style='font-size:80%;'>(Plugin Log)</span></h2>\n";
				print LoxBerry::Web::loglevel_select_html(
					LABEL => $SL{'LOGMANAGER.CURRENT_LOGLEVEL'},
					FORMID => "loglevel_" . $package_esc,
					PLUGIN => $log->{PACKAGE}
				);
			} else {
				print "\t<h2 class='ui-bar ui-bar-a ui-corner-all' id='package_$package_esc'>" . ucfirst($log->{PACKAGE}) . " <span style='font-size:80%;'>(LoxBerry System Log)</span></h2>\n";
			}
		}
		if (! defined($currname) or ($currname ne $log->{NAME})) {
			print "\t<h4>$SL{'LOGMANAGER.LOG_GROUP'} '" . ucfirst($log->{NAME}) . "'</h4>\n";
			print "\t<table style='width:100%; padding:8px; border:1px solid #ddd; border-collapse: collapse;'>\n";
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
			# Strip other html tags
			$log->{ATTENTIONMESSAGES} =~ s|<.+?>||g;
			# Replace <br> with \n
			$log->{ATTENTIONMESSAGES} =~ s/\n/<br>\n/g;
			print "&nbsp;<a href='#attmsg_$log->{KEY}' data-rel='popup' data-transition='fade'><img alt='Info' src='/system/images/notification_info_small.svg' height='15' width='15'></a>\n";
			print "\t\t\t\t<div data-role='popup' id='attmsg_$log->{KEY}' class='ui-content' data-arrow='true' >\n";
			print "\t\t\t\t\t<a href='#' data-rel='back' class='ui-btn ui-corner-all ui-shadow ui-btn-a ui-icon-delete ui-btn-icon-notext ui-btn-left'>Close</a>\n";
			print "\t\t\t\t\t<p><b>";
			print $SL{'LOGMANAGER.ATTMSG_POPUP_HEADING'};
			print "</b><br>";
			print "$log->{ATTENTIONMESSAGES}";
			print "</p>\n";
			print "\t\t\t\t</div>";
		
		}
		
		print "</td>\n";
		print "\t\t\t<td>$log->{LOGSTARTMESSAGE}</td>\n";
		print "\t\t\t<td>"; 
		if($log->{LOGSTARTSTR}) {print "$log->{LOGSTARTSTR}";}
		print " - ";
		if($log->{LOGENDSTR}) {print "$log->{LOGENDSTR}";}
		print "</td>\n";
		print "\t\t\t<td>";
		print "<a data-role='button' href='/admin/system/tools/logfile.cgi?logfile=" . uri_escape($log->{FILENAME}) . "&header=html&format=template&only=once' target='_blank' data-inline='true' data-mini='true' data-icon='action'>$SL{'COMMON.BUTTON_OPEN'}</a>";
		print "\t\t\t\t\t<br><span style='font-size:70%;'>$log->{FILENAME}</span>\n" if ($R::showfilename);
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
	
	# This is the final array for HTML::Template
	my @displayplugins;

	##
	## Get System logfiles
	##
	
	my @files = File::Find::Rule->file()
		->name( '*.log' )
		#->nonempty
		->in( ( "$lbslogdir", "$lbstmpfslogdir") );
	
	@files = grep {not exists $dblogfiles_hash{$_}} @files; 
	
	my @systemfiles;
	foreach my $filename (@files) {
		# print STDERR "System filename: $filename\n";
		my %filedata;
		my @statdata = stat($filename);
		$filedata{'filename'} = $filename;
		$filedata{'fileshortname'} = substr($filename, rindex($filename, '/')+1);
		$filedata{'filename_esc'} = uri_escape($filename);
		$filedata{'filesize'} = LoxBerry::System::bytes_humanreadable($statdata[7]);
		#my $t = localtime($statdata[9]);
		$filedata{'filemtime'} = localtime($statdata[9])->strftime("%d.%m.%Y %H:%M");
		push @systemfiles, \%filedata;
	}
	if (@systemfiles) {
		my %systemelement;
		$systemelement{PLUGINDB_FOLDER} = 'system';
		$systemelement{PLUGINDB_TITLE} = 'LoxBerry System Logs';
		$systemelement{FILES} = \@systemfiles;
		$systemelement{ISSYSTEM} = 1;
		unshift @displayplugins, \%systemelement;
	}
	
	##
	## Get Plugin logfiles
	##

	foreach my $key (keys @plugins) {
		# print STDERR "legacylog: Plugin $plugins[$key]->{'PLUGINDB_TITLE'} \n";
		my @files = File::Find::Rule->file()
			->name( '*.log' )
			#->nonempty
			->in("$lbhomedir/log/plugins/$plugins[$key]->{'PLUGINDB_FOLDER'}");
		
		next if(!@files);
		# print STDERR "$plugins[$key]->{'PLUGINDB_TITLE'}: " . scalar @files . " found\n";
		#Remove logs from the SDK 
		@files = grep {not exists $dblogfiles_hash{$_}} @files; 
		# print STDERR "$plugins[$key]->{'PLUGINDB_TITLE'}: " . scalar @files . " left after filter\n";
		next if(!@files);
		
		# Loop through files to get size and modification date
		my @pluginfiles;
		my $basepath_length = length("$lbhomedir/log/plugins/$plugins[$key]->{'PLUGINDB_FOLDER'}") + 1;
		foreach my $filename (@files) {
			my %filedata;
			my @statdata = stat($filename);
			$filedata{'filename'} = $filename;
			$filedata{'fileshortname'} = substr($filename, $basepath_length);
			$filedata{'filename_esc'} = uri_escape($filename);
			$filedata{'filesize'} = LoxBerry::System::bytes_humanreadable($statdata[7]);
			#my $t = localtime($statdata[9]);
			$filedata{'filemtime'} = localtime($statdata[9])->strftime("%d.%m.%Y %H:%M");
			push @pluginfiles, \%filedata;
		}
		$plugins[$key]->{'FILES'} = \@pluginfiles;
		push @displayplugins, $plugins[$key];
		
	}

	# Push the displayplugins array to the template	
	$maintemplate->param("PLUGINS", \@displayplugins);
	
	return;
}
