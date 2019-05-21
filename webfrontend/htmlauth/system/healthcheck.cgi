#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use LoxBerry::Web;
use JSON;

my $helplink = "https://www.loxwiki.eu/x/_oYKAw";
my $helptemplate = "help_myloxberry.html";
my $template_title;

# Version of this script
my $version = "1.4.2.3";



# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('P');

if ( $P::action ) {
	print STDERR "Action: $P::action --> ajax()\n ";
	ajax();
	exit;
}

my $sversion = LoxBerry::System::lbversion();

our $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/healthcheck.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				# associate => $cfg,
				);

our %SL = LoxBerry::System::readlanguage($maintemplate);

$template_title = "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}: $SL{'MYLOXBERRY.WIDGETLABEL'} v$sversion";

# Navbar
our %navbar;
$navbar{1}{Name} = "$SL{'MYLOXBERRY.LABEL_SETTINGS'}";
$navbar{1}{URL} = 'myloxberry.cgi?load=1';

$navbar{2}{Name} = "$SL{'MYLOXBERRY.LABEL_HEALTHCHECK'}";
$navbar{2}{URL} = 'healthcheck.cgi';
$navbar{2}{active} = 1;
 
$navbar{3}{Name} = "$SL{'MYLOXBERRY.LABEL_SYSINFO'}";
$navbar{3}{URL} = 'myloxberry.cgi?load=2';

LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
print $maintemplate->output();
LoxBerry::Web::lbfooter();



sub ajax
{
	my @checkparams;
	my $error;
	my $checkresponse;
	
	if($P::action eq "titles") {
		push @checkparams, "action=titles";
	} elsif ($P::action eq "check" and defined $P::check)  {
		push @checkparams, "action=check";
		push @checkparams, "check=$P::check";
	} elsif ($P::action eq "check") {
		push @checkparams, "action=check";
	} else {
		ajax_json_output("Invalid ajax parameters");
	}
	
	push @checkparams, "output=json";
	
	
	my $params = join(' ', @checkparams);
	
	print STDERR "params: $params\n";
	
	eval {
		$checkresponse = `$lbhomedir/sbin/healthcheck.pl $params`;
		print STDERR "Checkresponse: $checkresponse\n";
	};
	if($@) {
		ajax_json_output("Could not execute heathcheck.pl: $@");
	}
	if (!$checkresponse) {
		ajax_json_output("healthcheck.pl returned empty response"); 
	}
	# eval {
		# decode_json($checkresponse);
	# };
	# if($@) {
		# ajax_json_output("Invalid json: $@\n$checkresponse");
	# }
	
	ajax_json_output(undef, $checkresponse);	


}

sub ajax_json_output
{
	my ($error, $data) = @_;
	
	if($error or !$data) {
		# print $cgi->header('application/json;charset=utf-8');
		print $cgi->header(
			-type=>'text/plain;charset=utf-8',
			-status=> "500 Internal Server Error"
		);
		print "ERROR: $error";
		
	} else {
		print $cgi->header(
			-type=>'application/json;charset=utf-8',
			-status=> '200 OK'
		);
		print $data;
	}
	exit;
}
