#!/usr/bin/perl

use LoxBerry::Web;
use CGI;

my $template;

my $transformerdatafile = "/dev/shm/mqttgateway_transformers.json";


my $plugintitle = "MQTT Quick Publisher";
my $helplink = "nopanels";
  
LoxBerry::Web::lbheader($plugintitle, $helplink, undef);

$template = HTML::Template->new(
		filename => "$lbstemplatedir/mqtt-quickpublisher.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
	);

$template->param( "transformers", LoxBerry::System::read_file( $transformerdatafile ) );
print $template->output();

# LoxBerry::Web::lbfooter();
