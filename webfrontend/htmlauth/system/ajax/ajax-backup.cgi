#!/usr/bin/perl

# Only load libs here you definetely need.
# If there's a lib you only need for a
# single function, please load it with 
# require ....; within the function.
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::Log;
use CGI;
use JSON;
use Time::Piece;

my $error;
my $response;
my $cgi = CGI->new;
my $q = $cgi->Vars;

my $log = LoxBerry::Log->new (
    	name => 'AJAX',
	package => 'LoxBerry Backup',
	logdir => $lbstmpfslogdir,
	stderr => 1
);

LOGSTART "Request $q->{action}";

## Get status and logfile
if( $q->{action} eq "status" ) {

	my $logfile = "";
	my $logstatus = "";
	my ($exitcode) = LoxBerry::System::execute { command => 'pgrep -f clone_sd.pl' };
	my @logs = LoxBerry::Log::get_logs('LoxBerry Backup', 'Clone_SD');
	foreach my $log ( sort { $b->{LOGSTARTISO} cmp $a->{LOGSTARTISO} } @logs ) { # grab the newest one
		$logfile = $log->{FILENAME};
		$logstatus = $log->{STATUS};
		last;
	}
	my %response = (
		'notrunning' => $exitcode,
		'logfile' => $logfile,
		'logstatus' => $logstatus,
	);
	$response = to_json( \%response );
}

## Get the json Config and give it back as response
if( $q->{action} eq "getconfig" ) {
	my $configfile = "$lbsconfigdir/general.json";
	if ( -e $configfile ) {
		$response = LoxBerry::System::read_file($configfile);
		if( !$response ) {
			$response = "{ }";
		}
	}
	else {
		$response = "{ }";
	}
}

## Save the json Config and give it back as response
if( $q->{action} eq "saveconfig" ) {
	my $configfile = "$lbsconfigdir/general.json";
	require LoxBerry::JSON;
	my $jsonobj = LoxBerry::JSON->new();
	my $cfg = $jsonobj->open(filename => $configfile);
	$cfg->{'Backup'}->{'Storagepath'} = $q->{'storagepath'};
	$cfg->{'Backup'}->{'Keep_archives'} = $q->{'archive'};
	$cfg->{'Backup'}->{'Schedule'}->{'Active'} = $q->{'scheduleactive'};
	$cfg->{'Backup'}->{'Schedule'}->{'Repeat'} = $q->{'repeat'};
	$cfg->{'Backup'}->{'Schedule'}->{'Time'} = $q->{'timef'};
	$cfg->{'Backup'}->{'Schedule'}->{'Mon'} = $q->{'mon'};
	$cfg->{'Backup'}->{'Schedule'}->{'Tue'} = $q->{'tue'};
	$cfg->{'Backup'}->{'Schedule'}->{'Wed'} = $q->{'wed'};
	$cfg->{'Backup'}->{'Schedule'}->{'Thu'} = $q->{'thu'};
	$cfg->{'Backup'}->{'Schedule'}->{'Fre'} = $q->{'fre'};
	$cfg->{'Backup'}->{'Schedule'}->{'Sat'} = $q->{'sat'};
	$cfg->{'Backup'}->{'Schedule'}->{'Sun'} = $q->{'sun'};
	$jsonobj->write();

	# Create cronjob
	require Config::Crontab;
	unlink ('/tmp/crontab_loxberrybackup.txt') if (-f '/tmp/crontab_loxberrybackup.txt');
	my $ct = new Config::Crontab( -file => '/tmp/crontab_loxberrybackup.txt' );

	my @dow;
	push (@dow, "0") if (is_enabled($q->{'sun'}));
	push (@dow, "1") if (is_enabled($q->{'mon'}));
	push (@dow, "2") if (is_enabled($q->{'tue'}));
	push (@dow, "3") if (is_enabled($q->{'wed'}));
	push (@dow, "4") if (is_enabled($q->{'thu'}));
	push (@dow, "5") if (is_enabled($q->{'fre'}));
	push (@dow, "6") if (is_enabled($q->{'sat'}));

	if (is_enabled($q->{'scheduleactive'}) && scalar @dow) {
		my ($hour, $minute) = split (/:/, $q->{'timef'});
		$hour = "0" if (!$hour || $hour eq "00");
		$minute = "0" if (!$minute || $minute eq "00");
		# Run on every x week only: 
		# https://cronexpressiontogo.com/every-4-weeks-on-wednesday
		# https://stackoverflow.com/questions/350047/how-to-instruct-cron-to-execute-a-job-every-second-week/350061
		# I love Linux for it's simplicity :-)
		my $prefix ="";
		if ($q->{'repeat'} > 1) {
			my $divider = $q->{'repeat'} * 7;
			my $t = localtime;
			$prefix = '[[ $(("( $(date +%s) - $(date +%s --date=' . $t->ymd("") . ') ) / 86400 % ' . $divider . '")) -eq 0 ]] && ';
		}
		my $dow = join(",",@dow);
		my $block = new Config::Crontab::Block;
		$block->last( new Config::Crontab::Comment( -data => '## LoxBerry Backup - do not change manually. You changes will be overwritten!' ) );
		$block->last( new Config::Crontab::Env( -name => 'MAILTO', -value => '""' ) );
		$block->last( new Config::Crontab::Event( -minute  => $minute,
                		                          -hour    => $hour,
                		                          -dow     => $dow,
                                		          -command => "loxberry " . $prefix . $lbssbindir . "/clone_sd_cron.pl > /dev/null 2>&1" ) );
		$ct->last($block);
		$ct->write;
	} else {
		my $block = new Config::Crontab::Block;
		$block->last( new Config::Crontab::Comment( -data => '## LoxBerry Backup - do not change manually. You changes will be overwritten!' ) );
		$block->last( new Config::Crontab::Env( -name => 'MAILTO', -value => '""' ) );
		$ct->last($block);
		$ct->write;
	}

	# Install crontab
	if (-f '/tmp/crontab_loxberrybackup.txt') {
		execute { command => "sudo $lbhomedir/sbin/installcrontab.sh lbclonesd /tmp/crontab_loxberrybackup.txt" };
		unlink ('/tmp/crontab_loxberrybackup.txt');
	}
	$response = 1;
}

# Backup
if( $q->{action} eq "startbackup" ) {
	my $storagepath = $q->{'storagepath'};
	my $exitcode;
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
		($exitcode) = execute { command => "sudo $lbhomedir/sbin/clone_sd.pl $storagepath path" };
	} # End Child process

	my %response = (
		'error' => $exitcode,
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
