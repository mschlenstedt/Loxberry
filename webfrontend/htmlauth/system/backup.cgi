#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use LoxBerry::Storage;
use JSON;
use CGI;
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbsconfigdir/backup.json";

my $cgi = CGI->new;
my $q = $cgi->Vars;

my %pids;
my $template;

# Init template

$template = HTML::Template->new(
	filename => "$lbstemplatedir/backup.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
);

my %SL = LoxBerry::System::readlanguage($template);

# Switch between forms
if ( $q->{form} eq "logs" ) {
	$navbar{20}{active} = 1;
	$template->param("FORM_LOGS", 1);
	logs_form();
} else {
	$navbar{10}{active} = 1;
	$template->param("FORM_SETTINGS", 1);
	backup_form(); 
}

print_form();

exit;

######################################################################
# Print Form
######################################################################
sub print_form
{
	my $plugintitle = "Backup (V" . LoxBerry::System::lbversion() . ")";
	my $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_backup";
	my $helptemplate = "help.html";
	
	our @navbar = (
		{
			"Name" => "Backup",
			"URL" => "/admin/system/backup.cgi",
			"Notify_Package" => 'backup',
			"Notify_Name" => 'clone_sd'
		},
		{
			"Name" => "Log Files",
			"URL" => "/admin/system/backup.cgi?form=logs"
		}
	);
	
		
	LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

	if ($q->{form} ne "logs") {
		print LoxBerry::Log::get_notifications_html('backup', 'clone_sd');
	}
	print $template->output();

	LoxBerry::Web::lbfooter();


}


########################################################################
# Settings Form 
########################################################################
sub backup_form
{

	#my $mslist_select_html = LoxBerry::Web::mslist_select_html( FORMID => 'Main.msno', LABEL => 'Receiving Miniserver', DATA_MINI => "0" );
	#$template->param('mslist_select_html', $mslist_select_html);
	my $storages = LoxBerry::Storage::get_storage_html(formid => 'storagepath', type_usb => 1, type_net => 1, type_custom => 1, custom_folder => 1, readwriteonly => 1, show_browse => 1, data_mini => 1);
	$template->param('STORAGES_HTML', $storages);

}

########################################################################
# Logs Form 
########################################################################
sub logs_form
{

	$template->param('loglist_html', LoxBerry::Web::loglist_html( PACKAGE => 'LoxBerry Backup' ));

}

