#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::Log;
use File::Find::Rule;

my $version = "3.0.0.0";
my $log;

# Commandline parameters
my $command = $ARGV[0];
$command = "none" if !$ARGV[0];

if ($command ne "start" && $command ne "stop" && $command ne "check") {
	print "Command missing. Use $0 [start|stop|check]\n";
	exit (1);
}

# Read config
my $cfgfile = $lbsconfigdir . "/general.json";
my $jsonobj = LoxBerry::JSON->new();
my $cfg = $jsonobj->open(filename => $cfgfile);

#
# Start connection
#
if ($command eq "start") {
	
	# Create a logging object
	$log = LoxBerry::Log->new ( 
		package => 'Remote Support', 
		name => 'Remoteconnect', 
		logdir => $lbslogdir, 
		loglevel => LoxBerry::System::systemloglevel(),
		stdout => 1,
	);
	my $logfile = $log->filename();
	
	LOGSTART "Remote Connect for Support";
	LOGINF "Version of this script: $version";
	LOGINF "Commandline parameter: $command";

	# Get TryCloudFlare Binary
	if (!-e "$lbsbindir/cloudflared") {
		LOGINF "Downloading cloudflare daemon...";
		my $cloudflaredbin;
		if (-e $lbsconfigdir . "/is_raspberry.cfg") {
			$cloudflaredbin = "cloudflared-linux-arm";
		} 
		elsif (-e $lbsconfigdir . "/is_x64.cfg") {
			$cloudflaredbin = "cloudflared-linux-amd64";
		}
		elsif (-e $lbsconfigdir . "/is_x86.cfg") {
			$cloudflaredbin = "cloudflared-linux-386";
		} else {
			LOGERR "Cannot determine your architecture: Seems not to be Raspberry, x64 or x86. Cannot continue.";
			exit (1);
		}
		my ($exitcode) = execute { command => "curl -connect-timeout 10 --max-time 300 --retry 2 -s -L https://github.com/cloudflare/cloudflared/releases/latest/download/$cloudflaredbin -o $lbsbindir/cloudflared", log => $log };
		if ($exitcode != 0) {
			LOGERR "Something went wrong while downloading $cloudflaredbin. Exitcode: $exitcode";
			exit (1);
		}
		($exitcode) = execute { command => "chmod +x $lbsbindir/cloudflared" };
	}

	# Connect
	LOGINF "Connect to Cloudflare Service...";
	&killcfd;
	my ($exitcode) = execute { command => "$lbsbindir/cloudflared --url http://" . LoxBerry::System::get_localip() . ":" . LoxBerry::System::lbwebserverport() . " > /tmp/remoteconnect.log 2>&1 &" };
	if ($exitcode != 0) {
		LOGERR "Could not start Cloudflare Daemon. Exitcode: $exitcode";
		&killcfd;
		exit (1);
	}
	my $remoteurl = &remoteurl();
	if (!$remoteurl) {
		LOGERR "Could not get remote URL from Cloudflare. Giving up.";
		&killcfd;
		exit (1);
	} else {
		LOGOK "Connected to Cloudflare. Remote URL is: $remoteurl";
		# Register connection
		my $loxberryid = LoxBerry::System::read_file("$lbsconfigdir/loxberryid.cfg");
		my $remoteurl = url_encode($remoteurl);
		my ($exitcode) = execute { command => "curl -connect-timeout 5 --max-time 5 --retry 2 -s -L https://supportvpn.loxberry.de/register.cgi?remoteurl=$remoteurl&id=$loxberryid&do=register", log => $log };
		# Set Autoconnect if enabled
		if ( is_enabled($cfg->{'Remote'}->{'Autoconnect'}) ) {
			LOGINF "Activate Autoconnect after a reboot.";
			LoxBerry::System::write_file("$lbslogdir/remote.autoconnect", time());
		}
	}
	exit (0);

}

#
# Stop connection
#
if ($command eq "stop") {
	
	# Create a logging object
	$log = LoxBerry::Log->new ( 
		package => 'Remote Support', 
		name => 'Remoteconnect', 
		logdir => $lbslogdir, 
		loglevel => LoxBerry::System::systemloglevel(),
		stdout => 1,
	);
	my $logfile = $log->filename();
	
	LOGSTART "Remote Connect for Support";
	LOGINF "Version of this script: $version";
	LOGINF "Commandline parameter: $command";

	# Connect
	LOGINF "Disconnect from Cloudflare Service...";
	&killcfd;
	my $loxberryid = LoxBerry::System::read_file("$lbsconfigdir/loxberryid.cfg");
	my ($exitcode) = execute { command => "curl -connect-timeout 5 --max-time 5 --retry 2 -s -L https://supportvpn.loxberry.de/register.cgi?id=$loxberryid&do=unregister", log => $log };
	exit (0);

}

#
# Check connection
#
if ($command eq "check") {

	my $remoteurl = &remoteurl();

	if ($remoteurl) {
		my ($exitcode,$output) = execute { command => "curl -connect-timeout 5 --max-time 5 --retry 2 -s -I $remoteurl" };
		if ($exitcode eq 0 && $output =~ /HTTP.*200/) {
			print "$remoteurl";
			exit (0);
		} 
	}
	print "ERROR";
	exit(1);

}

exit;

#
# Subs
#
sub remoteurl {
	my $remoteurl;
	for(my $i = 1;$i <= 120;$i++) {
		$remoteurl = `cat /tmp/remoteconnect.log | awk '/.*https.*trycloudflare\\.com.*/ {print \$4}'`;
		chomp ($remoteurl);
		if ($remoteurl =~ /^https.*/) {
			last;
		} else {
			sleep (1);
		}
	}
	return ($remoteurl);
}

sub killcfd {
	my ($exitcode) = execute { command => "pkill cloudflared" };
	unlink("$lbslogdir/remote.autoconnect");
	return();
}

# Always execute
END {
	LOGEND "Finished" if $log;
}
