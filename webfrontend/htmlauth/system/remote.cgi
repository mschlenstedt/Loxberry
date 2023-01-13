#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use LoxBerry::Storage;
use JSON;
use CGI;


my $cgi = CGI->new;
my $q = $cgi->Vars;

my %pids;
my $template;

# Init template

$template = HTML::Template->new(
	filename => "$lbstemplatedir/remote.html",
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
	remote_form(); 
}

print_form();

exit;

######################################################################
# Print Form
######################################################################
sub print_form
{
	my $plugintitle = "Remote Support (V" . LoxBerry::System::lbversion() . ")";
	my $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_remote_support";
	my $helptemplate = "help.html";
	
	our @navbar = (
		{
			"Name" => "Remote Support",
			"URL" => "/admin/system/remote.cgi",
			"Notify_Package" => 'Remote Support',
			"Notify_Name" => 'remoteconnect'
		},
		{
			"Name" => "Log Files",
			"URL" => "/admin/system/remote.cgi?form=logs"
		}
	);
	
		
	LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

	if ($q->{form} ne "logs") {
		print LoxBerry::Log::get_notifications_html('Remote Support', 'remoteconnect');
	}
	print $template->output();

	LoxBerry::Web::lbfooter();


}


########################################################################
# Settings Form 
########################################################################
sub remote_form
{

	#my $mslist_select_html = LoxBerry::Web::mslist_select_html( FORMID => 'Main.msno', LABEL => 'Receiving Miniserver', DATA_MINI => "0" );
	#$template->param('mslist_select_html', $mslist_select_html);
	$template->param('LOXBERRYID', substr( LoxBerry::System::read_file("$lbsconfigdir/loxberryid.cfg"), 0, 10));

}

########################################################################
# Logs Form 
########################################################################
sub logs_form
{

	$template->param('loglist_html', LoxBerry::Web::loglist_html( PACKAGE => 'Remote Support' ));

}

