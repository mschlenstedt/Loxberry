#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::Log;
use File::Find::Rule;

my $version = "3.0.0.0";
my $log;

# Tracks our own cloudflared instance, so start/stop/status never touch a
# tunnel started by anything else on the box (see issue #1558).
my $pidfile = "/dev/shm/remoteconnect.pid";
my $cfdlog  = "/dev/shm/remoteconnect.log";

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
	&stopcfd;
	unlink($cfdlog);
	my $url = "http://" . LoxBerry::System::get_localip() . ":" . LoxBerry::System::lbwebserverport();
	# Run through a shell that execs into cloudflared, so the PID the shell
	# writes to $pidfile stays valid for the daemon itself (exec replaces the
	# process image without allocating a new PID).
	my ($exitcode) = execute { command => "sh -c 'echo \$\$ > $pidfile; exec $cloudflared --url $url > $cfdlog 2>&1' &" };
	if ($exitcode != 0) {
		LOGERR "Could not start Cloudflare Daemon. Exitcode: $exitcode";
		&stopcfd;
		exit (1);
	}
	my $remoteurl = &remoteurl();
	if (!$remoteurl) {
		LOGERR "Could not get remote URL from Cloudflare. Giving up.";
		&stopcfd;
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
	&stopcfd;
	my $loxberryid = LoxBerry::System::read_file("$lbsconfigdir/loxberryid.cfg");
	my ($exitcode) = execute { command => "curl -k --connect-timeout 5 --max-time 5 --retry 2 -s -L \"https://www.loxberry.de/supportvpn/register.cgi?id=$loxberryid&do=unregister\"" };
	unlink($cfdlog);
	unlink("$lbslogdir/remote.autoconnect");
	exit (0);

}

#
# Check connection
#
if ($command eq "status") {

	my $remoteurl = &remoteurl();
	my $running = &trackedpid();

	if ($remoteurl && $running) {
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
	if (!-e $cfdlog) {
		return;
	}
	for(my $i = 1;$i <= 120;$i++) {
		# Match the URL itself, not its column - the column depends on the
		# box cloudflared draws around it (#1560)
		if (open(my $fh, '<', $cfdlog)) {
			while (my $line = <$fh>) {
				if ($line =~ m{(https://[a-z0-9-]+\.trycloudflare\.com)}) {
					$remoteurl = $1;
					last;
				}
			}
			close($fh);
		}
		last if $remoteurl;
		sleep (1);
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


# Returns the PID from $pidfile if it is still alive and is actually
# cloudflared, undef otherwise. A bare PID match is not enough - PIDs get
# reused, so a stale file could otherwise point at an unrelated process.
sub trackedpid {
	return unless -e $pidfile;
	my $pid = LoxBerry::System::read_file($pidfile);
	return unless defined $pid;
	$pid =~ s/\s+//g;
	return unless $pid =~ /^\d+$/;
	return unless -d "/proc/$pid";
	my $exe = readlink("/proc/$pid/exe");
	return unless defined $exe && $exe =~ m{(^|/)cloudflared$};
	return $pid;
}

# Stops only the cloudflared instance we started ourselves, identified via
# $pidfile. Never touches other cloudflared processes on the box (issue #1558).
# A missing or stale PID file is treated as "not running" - no pkill fallback.
sub stopcfd {
	my $pid = &trackedpid();
	if ($pid) {
		LOGINF "Sending SIGTERM to cloudflared PID $pid";
		kill 'TERM', $pid;
		# Poll up to 3 s for graceful exit (6 x 0.5 s)
		for (1..6) {
			last unless -d "/proc/$pid";
			select(undef, undef, undef, 0.5);
		}
		if (-d "/proc/$pid") {
			LOGWARN "cloudflared still alive after SIGTERM - sending SIGKILL to PID $pid";
			kill 'KILL', $pid;
		}
	}
	unlink($pidfile);
	unlink("$lbslogdir/remote.autoconnect");
	return();
}

# Always execute
END {
	LOGEND "Finished" if $log;
}
