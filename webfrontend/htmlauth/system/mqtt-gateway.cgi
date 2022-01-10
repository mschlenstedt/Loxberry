#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use JSON;
use CGI;
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbsconfigdir/mqttgateway.json";
my $extplugindatafile = "/dev/shm/mqttgateway_extplugindata.json";
my $transformerdatafile = "/dev/shm/mqttgateway_transformers.json";

my $cgi = CGI->new;
my $q = $cgi->Vars;

my %pids;

my $template;

if( $q->{ajax} ) {
	
	## All ajax requests are now located in
	#  mqtt-ajax.php --> For ajax responses
	#  sbin/mqtt-handler.pl --> Will do all sudo functions, called by mqtt-ajax.php
	
	my %response;
	ajax_header();
	
	print '{ "method" : "'.$q->{ajax}.' is now in mqtt-ajax.php" }';
	
	exit;

} else {
	
	## Normal request (not ajax)
	
	# Init template
	
	$template = HTML::Template->new(
		filename => "$lbstemplatedir/mqtt-gateway.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
	);
	
	
	# Push json config to template
	
	my $cfgfilecontent = LoxBerry::System::read_file($cfgfile);
	# $cfgfilecontent = jsescape($cfgfilecontent);
	$template->param('JSONCONFIG', $cfgfilecontent);
	
	# Push udpinport to template
	my $generaljsoncontent = LoxBerry::System::read_file("$lbsconfigdir/general.json");
	my $generaljson = decode_json( $generaljsoncontent );
	my $udpinport = $generaljson->{Mqtt}->{Udpinport};
	$template->param('UDPINPORT', $udpinport);
	
	# Switch between forms
	
	if( !$q->{form} or $q->{form} eq "settings" ) {
		$navbar{10}{active} = 1;
		$template->param("FORM_SETTINGS", 1);
		settings_form(); 
	}
	elsif ( $q->{form} eq "subscriptions" ) {
		$navbar{20}{active} = 1;
		$template->param("FORM_SUBSCRIPTIONS", 1);
		subscriptions_form();
	}
	elsif ( $q->{form} eq "conversions" ) {
		$navbar{30}{active} = 1;
		$template->param("FORM_CONVERSIONS", 1);
		conversions_form();
	}
	elsif ( $q->{form} eq "incoming" ) {
		$navbar{40}{active} = 1;
		$template->param("FORM_TOPICS", 1);
		$template->param("FORM_DISABLE_BUTTONS", 1);
		# $template->param("FORM_DISABLE_JS", 1);
		topics_form();
	}
	elsif ( $q->{form} eq "logs" ) {
		$navbar{90}{active} = 1;
		$template->param("FORM_LOGS", 1);
		$template->param("FORM_DISABLE_BUTTONS", 1);
		# $template->param("FORM_DISABLE_JS", 1);
		logs_form();
	}
}

print_form();

exit;

######################################################################
# Print Form
######################################################################
sub print_form
{
	my $plugintitle = "MQTT Gateway (V" . LoxBerry::System::lbversion() . ")";
	my $helplink = "https://www.loxwiki.eu/x/S4ZYAg";
	my $helptemplate = "help.html";
	
	our @navbar = (
		{
			"Name" => "MQTT Basics",
			"URL" => "/admin/system/mqtt.cgi"
		},
		{
			"Name" => "MQTT Gateway",
			"Submenu" => [
				{
					"Name" => "Gateway Settings",
					"URL" => "/admin/system/mqtt-gateway.cgi"
				},
				{
					"Name" => "Gateway Subscriptions",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=subscriptions"
				},
				{
					"Name" => "Gateway Conversions",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=conversions"
				},
				{
					"Name" => "Incoming Overview",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=incoming"
				},
				{
					"Name" => "Gateway Transformers",
					"URL" => "/admin/system/mqtt-gateway.cgi?form=transformers"
				}
			]
		},
		{
			"Name" => "MQTT Finder",
			"URL" => "/admin/system/tools/mqttfinder.cgi"
		},
		{
			"Name" => "Log Files",
			"URL" => "/admin/system/tools/showalllogs.cgi?package=mqtt"
		}
	);
	
		
	LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

	print $template->output();

	LoxBerry::Web::lbfooter();


}


########################################################################
# Settings Form 
########################################################################
sub settings_form
{

	my $mslist_select_html = LoxBerry::Web::mslist_select_html( FORMID => 'Main.msno', LABEL => 'Receiving Miniserver', DATA_MINI => "0" );
	$template->param('mslist_select_html', $mslist_select_html);

}

########################################################################
# Subscriptions Form 
########################################################################
sub subscriptions_form
{

	# Send external plugin settings to template
	my $extpluginfilecontent = LoxBerry::System::read_file($extplugindatafile);
	# $extpluginfilecontent = jsescape($extpluginfilecontent);
	$template->param('EXTPLUGINSETTINGS', $extpluginfilecontent);

}

########################################################################
# Conversions Form 
########################################################################
sub conversions_form
{

	# Send external plugin settings to template
	my $extpluginfilecontent = LoxBerry::System::read_file($extplugindatafile);
	# $extpluginfilecontent = jsescape($extpluginfilecontent);
	$template->param('EXTPLUGINSETTINGS', $extpluginfilecontent);

}

########################################################################
# Topics Form 
########################################################################
sub topics_form
{
	
	# Donate
	my $donate = "Thanks to all that have already donated for my special Test-Miniserver, making things much more easier than testing on the \"production\" house! Also, I'm buying (not <i>really</i> needed) hardware devices (e.g. Shelly's and other equipment) to test it with LoxBerry and plugins. As I'm spending my time, hopefully you support my expenses for my test environment. About a donation of about 5 or 10 Euros, or whatever amount it is worth for you, I will be very happy!";
	my $donate_done_remove = "Done! Remove this!";
	$template->param("donate", $donate);
	$template->param("donate_done_remove", $donate_done_remove);
	
}


########################################################################
# Logs Form 
########################################################################
sub logs_form
{

	$template->param('transformers', LoxBerry::System::read_file($transformerdatafile) );
	$template->param('loglist_html', LoxBerry::Web::loglist_html());

}



######################################################################
# AJAX functions
######################################################################

sub pids 
{
	
	$pids{'mqttgateway'} = trim(`pgrep mqttgateway.pl`) ;
	$pids{'mosquitto'} = trim(`pgrep mosquitto`) ;

}	

sub pkill 
{
	my ($process) = @_;
	`pkill $process`;
	Time::HiRes::sleep(0.2);
	`pkill --signal SIGKILL $process`;
	

}	
	
sub ajax_header
{
	print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '501 NOT IMPLEMENTED',
	);	
}	
	

#################################################################################
# Escape a json string for JavaScript code
#################################################################################
sub jsescape
{
	my ($stringToEscape) = shift;
		
	my $resultjs;
	
	if($stringToEscape) {
		my %translations = (
		"\r" => "\\r",
		"\n" => "\\n",
		"'"  => "\\'",
		"\\" => "\\\\",
		);
		my $meta_chars_class = join '', map quotemeta, keys %translations;
		my $meta_chars_re = qr/([$meta_chars_class])/;
		$stringToEscape =~ s/$meta_chars_re/$translations{$1}/g;
	}
	return $stringToEscape;
}