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

if ($command ne "start" && $command ne "stop" && $command ne "status") {
	print "Command missing. Use $0 [start|stop|status]\n";
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

	# Connect
	LOGINF "Connect to Cloudflare Service...";
	my $cloudflared = &cloudflaredbin;
	if (!$cloudflared) {
		LOGERR "Cloudflare daemon (cloudflared) not found. Install it with: apt-get install cloudflared";
		exit (1);
	}
	LOGINF "Using Cloudflare daemon: $cloudflared";
	&killcfd;
	unlink('/tmp/remoteconnect.log');
	my ($exitcode) = execute { command => "$cloudflared --url http://" . LoxBerry::System::get_localip() . ":" . LoxBerry::System::lbwebserverport() . " > /tmp/remoteconnect.log 2>&1 &" };
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
		require URI::Escape;
		my $remoteurl = uri_escape($remoteurl);
		my ($exitcode) = execute { command => "curl -k --connect-timeout 5 --max-time 5 --retry 2 -s -L \"https://www.loxberry.de/supportvpn/register.cgi?remoteurl=$remoteurl&id=$loxberryid&do=register\"" };
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
	my ($exitcode) = execute { command => "curl -k --connect-timeout 5 --max-time 5 --retry 2 -s -L \"https://www.loxberry.de/supportvpn/register.cgi?id=$loxberryid&do=unregister\"" };
	unlink('/tmp/remoteconnect.log');
	unlink("$lbslogdir/remote.autoconnect");
	exit (0);

}

#
# Check connection
#
if ($command eq "status") {

	my $remoteurl = &remoteurl();
	my ($exitcode,$output) = execute { command => "pgrep cloudflared" };

	if ($remoteurl && $exitcode eq 0) {
		# my ($exitcode,$output) = execute { command => "curl --connect-timeout 5 --max-time 5 --retry 2 -s -I $remoteurl" };
		# if ($exitcode eq 0 && $output =~ /HTTP.*200/) {
			print "$remoteurl";
			exit (0);
		# } 
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
	if (!-e "/tmp/remoteconnect.log") {
		return;
	}
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

# Locate the cloudflared binary.
# The daemon comes from Cloudflare's apt repository and is installed to
# /usr/bin. Before that switch it was downloaded on demand to $lbsbindir, and
# some installations carry a manually placed binary in /usr/local/bin - so all
# known locations are probed instead of hardcoding a single path.
sub cloudflaredbin {
	foreach my $bin ("/usr/bin/cloudflared", "/usr/local/bin/cloudflared", "$lbsbindir/cloudflared") {
		return ($bin) if (-x $bin);
	}
	my $bin = `command -v cloudflared 2>/dev/null`;
	chomp ($bin);
	return ($bin) if ($bin && -x $bin);
	return;
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
