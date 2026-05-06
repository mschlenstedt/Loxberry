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
my $gatewayversion;

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
	
	
	# Load language strings
	our %SL = LoxBerry::System::readlanguage($template);

	# Push json config to template
	
	my $cfgfilecontent = LoxBerry::System::read_file($cfgfile);
	# $cfgfilecontent = jsescape($cfgfilecontent);
	$template->param('JSONCONFIG', $cfgfilecontent);
	
	# Push udpinport to template
	my $generaljsoncontent = LoxBerry::System::read_file("$lbsconfigdir/general.json");
	my $generaljson = decode_json( $generaljsoncontent );
	my $udpinport = $generaljson->{Mqtt}->{Udpinport};
	$template->param('UDPINPORT', $udpinport);
	$template->param('USELOCALBROKER', is_enabled( $generaljson->{Mqtt}->{Uselocalbroker}) );

	# Add gateway version - default to 1 for existing installations
	$gatewayversion = $generaljson->{Mqtt}->{Gatewayversion} // 1;
	$template->param("GATEWAY_VERSION", $gatewayversion);
	$template->param("GATEWAY_V2", $gatewayversion == 2 ? 1 : 0);

	# Build Miniserver list JSON for V2 subscription UI
	my @ms_list;
	foreach my $ms_id (sort { $a <=> $b } keys %{$generaljson->{Miniserver}}) {
		my $ms_data = $generaljson->{Miniserver}->{$ms_id};
		my $name = $ms_data->{Name} || "Miniserver $ms_id";
		push @ms_list, { id => int($ms_id), name => $name };
	}
	$template->param('MINISERVER_JSON', encode_json(\@ms_list));

	# Switch between forms (4 tabs: Gateway, Abonnements, Datenverkehr, Logs)

	if( !$q->{form} or $q->{form} eq "basic" or $q->{form} eq "settings" ) {
		$navbar{10}{active} = 1;
		$template->param("FORM_BASIC", 1);
		basic_form();
	}
	elsif ( $q->{form} eq "subscriptions" or $q->{form} eq "conversions" ) {
		$navbar{20}{active} = 1;
		$template->param("FORM_SUBSCRIPTIONS", 1);
		$template->param("FORM_DISABLE_BUTTONS", 1) if $gatewayversion == 2;
		subscriptions_form();
	}
	elsif ( $q->{form} eq "incoming" or $q->{form} eq "transformers" ) {
		$navbar{30}{active} = 1;
		$template->param("FORM_TOPICS", 1);
		$template->param("FORM_DISABLE_BUTTONS", 1);
		topics_form();
		transformers_form();
	}
	elsif ( $q->{form} eq "logs" ) {
		$navbar{40}{active} = 1;
		$template->param("FORM_LOGS", 1);
		$template->param("FORM_DISABLE_BUTTONS", 1);
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
	my $plugintitle = "MQTT Gateway";
	my $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt";
	my $helptemplate = "help.html";
	
	our @navbar = (
		{ "Name" => "MQTT Basics",
		  "URL" => "/admin/system/mqtt.cgi" },
		{ "Name" => "Gateway",
		  "URL" => "/admin/system/mqtt-gateway.cgi" },
		{ "Name" => $SL{'MQTT.TAB_SUBSCRIPTIONS'},
		  "URL" => "/admin/system/mqtt-gateway.cgi?form=subscriptions" },
		{ "Name" => $SL{'MQTT.V2_SECTION_TRAFFIC'},
		  "URL" => "/admin/system/mqtt-gateway.cgi?form=incoming" },
		{ "Name" => "Logs",
		  "URL" => "/admin/system/mqtt-gateway.cgi?form=logs" },
		{ "Name" => "MQTT Finder",
		  "URL" => "/admin/system/mqtt-finder.cgi" },
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
	
	
}


########################################################################
# Transformers Form 
########################################################################
sub transformers_form
{

	$template->param('transformers', LoxBerry::System::read_file($transformerdatafile) );

}

########################################################################
# Logs Form
########################################################################
sub logs_form
{

	$template->param('loglist_html', LoxBerry::Web::loglist_html( PACKAGE => 'MQTT' ));

}

########################################################################
# Basic Form (V2)
########################################################################
sub basic_form
{
	my $mslist_select_html = LoxBerry::Web::mslist_select_html( FORMID => 'Main.msno', LABEL => 'Standard Miniserver', DATA_MINI => "0" );
	$template->param('mslist_select_html', $mslist_select_html);
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
