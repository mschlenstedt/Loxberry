#!/usr/bin/perl

use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Log;
use CGI;
use JSON;

my $error;
my $response;
my $cgi = CGI->new;
my $q = $cgi->Vars;

my $log = LoxBerry::Log->new (
	name => 'AJAX USB Storage',
	package => 'core',
	logdir => $lbstmpfslogdir,
	stderr => 1,
	loglevel => 7
);

LOGSTART "Request $q->{action}";

if( $q->{action} eq "checksecpin" ) {
	$response = to_json( { response => LoxBerry::System::check_securepin($q->{secpin}) } );
}

if( $q->{action} eq "checkformatstatus" ) {
	my $logfile = "";
	my ($exitcode) = LoxBerry::System::execute { command => 'pgrep -f format_device.pl' };
	my @logs = LoxBerry::Log::get_logs('core', 'Format Device');
	foreach my $log ( sort { $b->{LOGSTARTISO} cmp $a->{LOGSTARTISO} } @logs ) { # grab the newest one
		$logfile = $log->{FILENAME};
		last;
	}
	my %response = (
		'response' => $exitcode,
		'logfile' => $logfile,
	);
	$response = to_json( \%response );
}

if( $q->{action} eq "format" ) {
	my $device = $q->{device};
	my $pin = $q->{secpin};
	my $int_error = 0;;

	if ( ! LoxBerry::System::check_securepin($pin) ) {
		# Without the following workaround
		# the script cannot be executed as
		# background process via CGI
		my $pid = fork();
		$error++ if !defined $pid;
		if ($pid == 0) {
			# do this in the child
			open STDIN, "< /dev/null";
			open STDOUT, "> /dev/null";
			open STDERR, "> /dev/null";
			# Format
			my ($exitcode) = execute { command => "sudo $lbhomedir/sbin/format_device.pl $device" };
		} # End Child process
	} else {
		$int_error++;
	}

	my %response = (
		'error' => $int_error,
	);
	$response = to_json( \%response );

}

#####################################
# Manage Response and error
#####################################

if( defined $response and !defined $error ) {
	print "Status: 200 OK\r\n";
	print "Content-type: application/json; charset=utf-8\r\n\r\n";
	print $response;
	LOGOK "Parameters ok - responding with HTTP 200";
}
elsif ( defined $error and $error ne "" ) {
	print "Status: 500 Internal Server Error\r\n";
	print "Content-type: application/json; charset=utf-8\r\n\r\n";
	print to_json( { error => $error } );
	LOGCRIT "$error - responding with HTTP 500";
}
else {
	print "Status: 501 Not implemented\r\n";
	print "Content-type: application/json; charset=utf-8\r\n\r\n";
	$error = "Action ".$q->{action}." unknown";
	LOGCRIT "Method not implemented - responding with HTTP 501";
	print to_json( { error => $error } );
}

END {
	LOGEND if($log);
}
