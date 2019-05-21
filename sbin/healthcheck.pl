#!/usr/bin/perl

#use CGI;
use LoxBerry::System;
use JSON;
use strict;
no strict 'refs';

# Globals
my @results;
my @checks;

my %opts;

parse_options(@ARGV);

## Show parsed options (debugging)
# foreach (keys %opts) {
	# print STDERR "Option '$_' = '$opts{$_}'\n";
# }	

#############################################################
# Health Checks
#############################################################
push (@checks, "check_lbversion");
push (@checks, "check_kernel");
push (@checks, "check_arch");
push (@checks, "check_readonlyrootfs");
push (@checks, "check_rootfssize");
push (@checks, "check_tmpfssize");
push (@checks, "check_logdb");
push (@checks, "check_notifydb");
push (@checks, "check_loglevels");

# Default action is check
if (!$opts{action}) {
	$opts{action} = 'check';
}

# Default output is stdout
if (!$opts{output}) {
	$opts{output} = 'text';
}
if (!exists &{$opts{output}}) {
	print "The output method \"$opts{output}\" does not exist.\n";
	exit 1;
}

# Only one check is requested
if ($opts{check}) { 
	if (!exists &{$opts{check}}) {
		print "The healthcheck \"$opts{check}\" does not exist.\n";
		exit 1;
	}
	undef @checks;
	push (@checks, "$opts{check}"); 
}

# Only titles for WebIf without perfoming checks
if ($opts{action} eq "titles") {
	@results = &performchecks('titles');
}
# Perform checks
elsif ($opts{action} eq "check") {
	@results = &performchecks;
}

# Output
&{$opts{output}}(@results);

exit;


# Sub: Perform check
sub performchecks {
	my ($action) = @_;
	foreach (@checks) {
		if ($action eq "titles") {
			push (@results,	&{$_}('title') );
		} else {
			push (@results,	&{$_}() );
		}
	}
	return(@results);
}

# Sub: Output JSON
sub json {

	my (@results) = @_;
	print JSON->new->utf8(0)->encode(\@results);

}

# Sub: Output stdout
sub text {

	my (@results) = @_;
	foreach my $check (@results) {
		print "Sub: $check->{sub}\n";
		print "Title: $check->{title}\n";
		print "Desc: $check->{desc}\n";
		print "Result: $check->{result}\n";
		print "Status: $check->{status}\n";
		print "Logfile: $check->{logfile}\n";
		print "URL: $check->{url}\n\n";
	}

}

sub parse_options
{
	
	my @opts = @_;
	foreach my $opt (@opts) {
		my ($key, $value) = split /=/, $opt;
		if(begins_with($key, '--')) {
			$key = substr $key, 2;
		} elsif (begins_with($key, '-')) {
			$key = substr $key, 1;
		}
		$opts{$key} = $value;
	}
}



#############################################################
## Health Checks
##
## Response hash
## status:	3 => 'ERROR', 
##		4 => 'WARNING', 
##		5 => 'OK', 
##		6 => 'INFO', 
## title:	Name of the test
## desc:	Description of the test
## result:	Result (Text)
## url:		URL to a wiki page with help (opt.)
## logfile: 	Path to a logfile (opt.)
##############################################################

# Check if RootFS is mounted readonly
sub check_readonlyrootfs
{

	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_readonlyrootfs';
	$result{'title'} = 'RootFS';
	$result{'desc'} = 'Checks if the RootFS is mounted correctly';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	eval {
		system ("mount | grep -q -i -e 'on / type ext4 (rw'");
		if (!$?) {
			$result{'status'} = '5';
			$result{'result'} = 'RootFS is mounted ReadWrite. This is fine.';
		} else {
			$result{'status'} = '3';
			$result{'result'} = 'RootFS is not mounted ReadWrite. This is NOT fine.';
		}
	};
	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}

	return(\%result);

}

# Check if logdb is healthy
sub check_logdb
{
	
	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_logdb';
	$result{'title'} = 'Log Database';
	$result{'desc'} = 'Checks the consistence of the Logfile Database';
	$result{'url'} = 'https://www.loxwiki.eu/x/oIMKAw';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	
	eval {
		require DBI;
		require LoxBerry::Log;
		my $dbh = LoxBerry::Log::log_db_init_database();
		if (! $dbh) {
			$result{result} = 'Could not init logfile database.';
			$result{status} = '3';
		} else {
			$result{result} = 'Init logfile database is ok. ';
			#$result{status} = '5';
		}
		local $dbh->{RaiseError} = 1;
		my $qu = "SELECT COUNT(*) FROM logs;"; 
		my ($logcount) = $dbh->selectrow_array($qu);
		my $qu = "SELECT COUNT(*) FROM logs_attr;"; 
		my ($attrcount) = $dbh->selectrow_array($qu);
		my $qu = "SELECT COUNT (DISTINCT FILENAME) FROM logs;";
		my ($filecount) = $dbh->selectrow_array($qu);

		$result{result} .= "$logcount log sessions with $attrcount attributes stored. $filecount logfiles are managed. ";
		
		my $filesize = -s $dbh->sqlite_db_filename();
		$result{result} .= "Database size is " . LoxBerry::System::bytes_humanreadable($filesize) . ". ";
		if ($filesize > 52428800) {
			$result{result} .= "This is exceptionally BIG! ";
			$result{status} = 4;
		}
	
	};
	if ($@) {
		$result{status} = '3';
		$result{result} .= "Error executing the test: <$@> ";
	} 
	
	if(!$result{status}) {
		$result{status} = '5';
	}
	return (\%result);

}

# Check if notification database is healthy
sub check_notifydb
{
	
	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_notifydb';
	$result{'title'} = 'Notification Database';
	$result{'desc'} = 'Checks the consistence of the Notification Database';
	# $result{'url'} = 'https://www.loxwiki.eu/x/oIMKAw';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	
	eval {
		require DBI;
		require LoxBerry::Log;
		my $dbh = LoxBerry::Log::notify_init_database();
		if (! $dbh) {
			$result{result} = 'Could not init notification database.';
			$result{status} = '3';
		} else {
			$result{result} = 'Init notification database is ok. ';
			#$result{status} = '5';
		}
		local $dbh->{RaiseError} = 1;
		my $qu = "SELECT COUNT(*) FROM notifications;"; 
		my ($notcount) = $dbh->selectrow_array($qu);
		my $qu = "SELECT COUNT(*) FROM notifications_attr;"; 
		my ($attrcount) = $dbh->selectrow_array($qu);
		my $qu = "SELECT COUNT (*) FROM notifications WHERE SEVERITY = 3;";
		my ($errorcount) = $dbh->selectrow_array($qu);
		my $qu = "SELECT COUNT (*) FROM notifications WHERE SEVERITY = 6;";
		my ($infocount) = $dbh->selectrow_array($qu);

		$result{result} .= "$notcount notifications with $attrcount attributes stored. It contains $infocount info and $errorcount error notifications.";
		
		my $filesize = -s $dbh->sqlite_db_filename();
		$result{result} .= "Database size is " . LoxBerry::System::bytes_humanreadable($filesize) . ". ";
		if ($filesize > 52428800) {
			$result{result} .= "This is exceptionally BIG! ";
			$result{status} = 4;
		}

		
	};
	if ($@) {
		$result{status} = '3';
		$result{result} .= "Error executing the test: <$@> ";
	} 
	
	if(!$result{status}) {
		$result{status} = '5';
	}
	
	return (\%result);

}


# Check the Linux Kernel
sub check_kernel
{

	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_kernel';
	$result{'title'} = 'Linux Kernel';
	$result{'desc'} = 'Checks the current installed Linux Kernel';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	eval {

		my $output = qx(uname -a);
		chomp $output;
		$result{'status'} = '6';
		$result{'result'} = "$output";

	};
	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}

	return(\%result);

}

# Check Architecture
sub check_arch
{

	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_arch';
	$result{'title'} = 'System Architecture';
	$result{'desc'} = 'Checks the system architecture';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	eval {

	        my $architecture;
		$architecture = "ARM" if (-e "$lbsconfigdir/is_raspberry.cfg");
		$architecture = "x86" if (-e "$lbsconfigdir/is_x86.cfg");
		$architecture = "x64" if (-e "$lbsconfigdir/is_x64.cfg");
		$architecture = "Virtuozzo" if (-e "$lbsconfigdir/is_virtuozzo.cfg");
		$architecture = "Odroid" if (-e "$lbsconfigdir/is_odroidxu3xu4.cfg");	
		if (!$architecture) {
			$architecture = "Unknown";
		}
		if ($architecture eq "ARM") {
			my $output = qx($lbsbindir/showpitype);
			chomp $output;
			$architecture .= " / Raspberry $output";
		}
		$result{'status'} = '6';
		$result{'result'} = "$architecture";
	};
	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}

	return(\%result);

}

# Check LoxBerry Version
sub check_lbversion
{

	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_lbversion';
	$result{'title'} = 'LoxBerry Version';
	$result{'desc'} = 'Checks the LoxBerry Version';
	$result{'url'} = 'https://www.loxwiki.eu/x/b4WdAQ';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	eval {

		use LWP::UserAgent;
		use Time::HiRes qw(usleep);
		use version;

		my $cfg      = new Config::Simple("$lbsconfigdir/general.cfg");
		my $currversion  = $cfg->param("BASE.VERSION");

		my $endpoint = 'https://api.github.com';
		my $resource = '/repos/mschlenstedt/Loxberry/releases';

		my $release_version;

		my $ua = LWP::UserAgent->new;
		my $request = HTTP::Request->new(GET => $endpoint . $resource);
		$request->header('Accept' => 'application/vnd.github.v3+json', 'Accept-Charset' => 'utf-8');
		my $response;
		for (my $x=1; $x<=5; $x++) {
			$response = $ua->request($request);
			last if ($response->is_success);
			usleep (100*1000);
		}

		my $newrelease;
		if ($response->is_error) {
			$result{'status'} = '4';
			$result{'result'} = "Current Version: $currversion / Could not get latest available Version.";
    		} else {
			my $releases = JSON->new->allow_nonref->convert_blessed->decode($response->decoded_content);
			foreach my $release ( @$releases ) {
				$release_version = undef;
				if (!version::is_lax(vers_tag($release->{tag_name}))) {
        				next;
				} else {
					$release_version = version->parse(vers_tag($release->{tag_name}));
				}
				if ($release->{prerelease} eq 1) {
					next;
				}
				if ($currversion == $release_version) {
					next;
				}
				if ($release_version < $currversion) {
					next;
				}
				# Releaseversion is newer than current
				$newrelease = $release_version;
			}
		}

		if ($newrelease) {
			$result{'status'} = '3';
			$result{'result'} = "Current Version: $currversion / New Release is available: $newrelease";
		} 
		elsif (!$result{'result'}) {
			$result{'status'} = '5';
			$result{'result'} = "Current Version: $currversion / No newer Release available.";
		}

	};
	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}

	return(\%result);

}

# Check loglevel of plugins
sub check_loglevels
{

	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_loglevels';
	$result{'title'} = 'Plugin Loglevels';
	$result{'desc'} = 'Checks for debug loglevel';
	#$result{'url'} = 'https://www.loxwiki.eu/x/b4WdAQ';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	eval {
		my @debugplugins;
		my @plugins = LoxBerry::System::get_plugins();
		foreach my $plugin (@plugins) {
			#print STDERR "$plugin->{PLUGINDB_NO} $plugin->{PLUGINDB_TITLE} $plugin->{PLUGINDB_VERSION}\n";
			if( $plugin->{PLUGINDB_LOGLEVEL} eq "7" ) {
				push( @debugplugins, $plugin->{PLUGINDB_TITLE} );
			}
		}
	
		if (@debugplugins) {
			$result{result} .= "Plugins in DEBUG loglevel: " . join(', ', @debugplugins) . ". DEBUG loglevel leads to accessive logging/performance impact. Use only during troubleshooting.";
			$result{status} = 4;
		}
	};
	if ($@) {
		$result{status} = '3';
		$result{result} .= "Error executing the test: <$@> ";
	} 
	
	if(!$result{status}) {
		$result{result} = "No plugin is configured for loglevel DEBUG. (Some plugins may have it's own setting)";
		$result{status} = '5';
	}
	
	return (\%result);

}

# Check tmpfs
sub check_tmpfssize
{

	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_tmpfssize';
	$result{'title'} = 'RAMDiscs free space';
	$result{'desc'} = 'Checks the ramdiscs for available space';
	$result{'url'} = 'https://www.loxwiki.eu/x/QINYAg';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	eval {

		# Paths to check
		my @pathtc = ("$lbhomedir/log/plugins", "$lbhomedir/log/system_tmpfs");

		foreach my $disk (@pathtc) {
			my %folderinfo = LoxBerry::System::diskspaceinfo($disk);
			next if( $folderinfo{size} eq "0" or ($folderinfo{available}/$folderinfo{size}*100) > 25 );
			if ( $folderinfo{available}/$folderinfo{size}*100 > 5 ) {
				$result{result} = "$folderinfo{mountpoint} is below limit of 25% discspace (AVAL $folderinfo{available}/SIZE $folderinfo{size}). Please reboot your LoxBerry.";
				$result{status} = '4';
			} else {
				$result{result} = "$folderinfo{mountpoint} is below limit of 5% discspace (AVAL $folderinfo{available}/SIZE $folderinfo{size}). Please reboot your LoxBerry.";
				$result{status} = '3';
			}
		}

	};
	if ($@) {
		$result{status} = '3';
		$result{result} .= "Error executing the test: <$@> ";
	} 
	
	if(!$result{status}) {
		$result{result} = "All ramdiscs have more than 25% free discspace.";
		$result{status} = '5';
	}
	
	return (\%result);

}

# Check rootfs
sub check_rootfssize
{

	my %result;
	my ($action) = @_;

	$result{'sub'} = 'check_rootfssize';
	$result{'title'} = 'RootFS free space';
	$result{'desc'} = 'Checks the rootfs for available space';
	#$result{'url'} = 'https://www.loxwiki.eu/x/QINYAg';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	eval {

		# Paths to check
		my @pathtc = ("$lbhomedir");

		foreach my $disk (@pathtc) {
			my %folderinfo = LoxBerry::System::diskspaceinfo($disk);
			next if( $folderinfo{size} eq "0" or ($folderinfo{available}/$folderinfo{size}*100) > 10 );
			if ( $folderinfo{available}/$folderinfo{size}*100 > 5 ) {
				$result{result} = "$folderinfo{mountpoint} is below limit of 25% discspace (AVAL $folderinfo{available}/SIZE $folderinfo{size}). Please reboot your LoxBerry.";
				$result{status} = '4';
			} else {
				$result{result} = "$folderinfo{mountpoint} is below limit of 5% discspace (AVAL $folderinfo{available}/SIZE $folderinfo{size}). Please reboot your LoxBerry.";
				$result{status} = '3';
			}
		}

	};
	if ($@) {
		$result{status} = '3';
		$result{result} .= "Error executing the test: <$@> ";
	} 
	
	if(!$result{status}) {
		$result{result} = "LoxBerry's RootFS has more than 10% free discspace.";
		$result{status} = '5';
	}
	
	return (\%result);

}
