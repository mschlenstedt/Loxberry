#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use LoxBerry::System;

my $helplink = "https://www.loxwiki.eu/x/_oYKAw";
my $helptemplate = "help_myloxberry.html";
my $template_title;

# Version of this script
my $version = "1.4.2.5";



# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('P');

if ( $P::action ) {
	print STDERR "Action: $P::action --> ajax()\n ";
	ajax();
	exit;
}

require LoxBerry::Web;
require LoxBerry::Log;

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
$navbar{2}{Notify_Package} = 'myloxberry';
$navbar{2}{Notify_Name} = 'Healthcheck';
 
$navbar{3}{Name} = "$SL{'MYLOXBERRY.LABEL_SYSINFO'}";
$navbar{3}{URL} = 'myloxberry.cgi?load=2';

LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
print LoxBerry::Log::get_notifications_html('myloxberry', 'Healthcheck');
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
	} elsif ($P::action eq "summary") {
		$checkresponse = read_healthcheck_json();
		ajax_json_output(undef, $checkresponse);
		exit;
		
	} else {
		ajax_json_output("Invalid ajax parameters");
	}
	
	push @checkparams, "output=json";
	
	my $params = join(' ', @checkparams);
	
	print STDERR "params: $params\n";
	
	eval {
		$checkresponse = `$lbhomedir/sbin/healthcheck.pl $params`;
		# print STDERR "Checkresponse: $checkresponse\n";
	};
	if($@) {
		ajax_json_output("Could not execute heathcheck.pl: $@");
	}
	
	# OBSOLETE
	# if ($P::action eq "summary") {
		# $checkresponse = generate_summary($checkresponse);
	# }
	
	if (!$checkresponse) {
		ajax_json_output("healthcheck.pl returned empty response"); 
	}
	
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


# # OBSOLETE
# sub generate_summary
# {
	# require JSON;
	# my ($data) = @_;
	# my $dataobj;
	# my %respobj;
	# my $resp;
	# my $errorstr;
	
	# eval {
		
		# if(!$data) {
			# $respobj{'errors'}++;
			# $respobj{'errorstr'} = "All checks returned no results";
		# } else {
			# $dataobj = JSON::decode_json($data);
			# # $respobj{'debug'} = $data;
			# #use Data::Dumper;
			# #print STDERR Dumper($dataobj);
			# $respobj{'unknown'} = 0;
			# $respobj{'errors'} = 0;
			# $respobj{'warnings'} = 0;
			# $respobj{'ok'} = 0;
			# $respobj{'infos'} = 0;
			
			# foreach my $element (@$dataobj) {
				# #print STDERR $element->{status} . "\n";
				# if(! $element->{status}) {
					# $respobj{'errors'}++;
					# $respobj{'unknown'}++;
				# } elsif ( $element->{status} eq "3" ) {
					# $respobj{'errors'}++;
				# } elsif ( $element->{status} eq "4" ) {
					# $respobj{'warnings'}++;
				# } elsif ( $element->{status} eq "5" ) {
					# $respobj{'ok'}++;
				# } elsif ( $element->{status} eq "6" ) {
					# $respobj{'infos'}++;
				# } else {
					# $respobj{'errors'}++;
					# $respobj{'unknown'}++;
				# }
			# }
			
		# }
		
		# $respobj{'warnings_and_errors'} = $respobj{'errors'} + $respobj{'warnings'};
		# $respobj{'epoch'} = time;
		# $resp = JSON::encode_json(\%respobj);
		
	# };
	# if ($@) {
		# $resp = '{"errors":1,"errorstr":"Exception generating summary"}';
		# print STDERR "healthcheck.pl: Exception generating summary: $@\n";
	# }
	# return $resp;
	
# }

sub read_healthcheck_json
{

	my $output;
	my $jsonfile = '/dev/shm/healthcheck.json';
	my $jsonfile_fallback = $lbhomedir.'/log/system/healthcheck.json';
	
	eval { 
		$output = LoxBerry::System::read_file($jsonfile);
	};
	if ($output) {
		return $output;
	} else {
		print STDERR "healthcheck.cgi: read_healthcheck_json: Exception: $@\n";
	}
	eval {
		$output = LoxBerry::System::read_file($jsonfile_fallback);
	};
	if ($output) {
		return $output;
	} else {
		print STDERR "healthcheck.cgi: read_healthcheck_json: Exception: $@\n";
	}
	$output = '{"errors":1,"warnings":1,"ok":0,"infos":0,"warnings_and_errors":1,"timeepoch":'.time.',"errorstr":"Could not read both healthcheck.pl json files."}';
	return $output;
}
