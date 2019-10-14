#!/usr/bin/perl

#use CGI;
use LoxBerry::System;
use JSON;
use strict;
no strict 'refs';

my $version = "2.0.0.1";

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
push (@checks, "check_cputemp");
push (@checks, "check_voltage");
push (@checks, "check_readonlyrootfs");
push (@checks, "check_rootfssize");
push (@checks, "check_tmpfssize");
push (@checks, "check_logdb");
push (@checks, "check_notifydb");
push (@checks, "check_miniservers");
push (@checks, "check_reboot_required");
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
	
	# Disable checks by general.cfg config variables
	my $generalcfg = new Config::Simple("$lbsconfigdir/general.cfg");
	if(is_enabled($generalcfg->param('HEALTHCHECK.DISABLE_ALL'))) {
		print STDERR "Healthcheck: Healthcheck is globally disabled (general.cfg section [HEALTHCHECK])\n";
	}
		
	foreach (@checks) {
		if ($action eq "titles") {
			push (@results,	&{$_}('title') );
		} else {
			if(is_enabled($generalcfg->param('HEALTHCHECK.DISABLE_ALL'))) {
				my $result = &{$_}('title');
				$result->{status} = '4';
				$result->{result} = "All healthchecks are globally disabled in 
				general.cfg (section HEALTHCHECK)";
				delete $result->{url};
				push (@results,	$result );
				next;
			}
			if( is_enabled($generalcfg->param('HEALTHCHECK.DISABLE_'.uc($_))) ) {
				print STDERR "Healthcheck: Healthcheck $_ is disabled (general.cfg section [HEALTHCHECK])\n";
				my $result = &{$_}('title');
				$result->{status} = '4';
				$result->{result} = "This check is disabled in general.cfg (section HEALTHCHECK)";
				delete $result->{url};
				push (@results,	$result );
				next;
			}
			push (@results,	&{$_}() );
		}
	}
	return(@results);
}

# Sub: Output JSON
sub json {

	my @resultsout;
	my (@results) = @_;
	foreach my $check (@results) {
		if ($check->{logfile} && -e "$check->{logfile}" && -s "$check->{logfile}") {
			open(my $fh, '<:encoding(UTF-8)', "$check->{logfile}");
			while (my $row = <$fh>) {
				chomp $row;
				$check->{logfilecontent} .= "$row\n";
			}	
			close ($fh);
		}
		push (@resultsout, $check);
	}
	print JSON->new->utf8(0)->encode(\@resultsout);

}

# Sub: Output stdout
sub text {
	
	my $colors = 0;
	eval {
		require Term::ANSIColor;
		$colors = 1;
	};
	
	my (@results) = @_;
	foreach my $check (@results) {
		print "Sub: $check->{sub}\n";
		print "Title: $check->{title}\n";
		print "Status: ";
		if( ! $check->{status} ) {
			print Term::ANSIColor::color('bold red') if ($colors);
			print "UNKNOWN";
			print Term::ANSIColor::color('reset') if ($colors);
		} elsif ($check->{status} eq "3") {
			print Term::ANSIColor::color('bold red') if ($colors);
			print "ERROR (code 3)";
			print Term::ANSIColor::color('reset') if ($colors);
		} elsif ($check->{status} eq "4") {
			print Term::ANSIColor::color('bold yellow') if ($colors);
			print "WARNING (code 4)";
			print Term::ANSIColor::color('reset') if ($colors);
		} elsif ($check->{status} eq "5") {
			print Term::ANSIColor::color('bold green') if ($colors);
			print "OK (code 5)";
			print Term::ANSIColor::color('reset') if ($colors);
		} elsif ($check->{status} eq "6") {
			print Term::ANSIColor::color('bold blue') if ($colors);
			print "Info (code 6)";
			print Term::ANSIColor::color('reset') if ($colors);
		}
		print "\n";
		print "Desc: $check->{desc}\n";
		print "Result: $check->{result}\n";
		print "Logfile: $check->{logfile}\n";
		print "URL: $check->{url}\n\n";
	}

}

sub notification
{
	require LoxBerry::Log;
	
	my %respobj;
	my $not_widget = "myloxberry";
	my $not_group = "Healthcheck";
	my $not_helper = "Healthcheck Helper";
	my $not_prefix = "lastnotified";
	my $resend_interval = 7*24*60*60; # 7 days
	
	my (@results) = @_;
	
	$respobj{'unknown'} = 0;
	$respobj{'errors'} = 0;
	$respobj{'warnings'} = 0;
	$respobj{'ok'} = 0;
	$respobj{'infos'} = 0;
		
	# Loop the checks and check if a notification exists
	foreach my $element (@results) {
		#print STDERR $element->{status} . "\n";
		if(! $element->{status}) {
			$respobj{'errors'}++;
			$respobj{'unknown'}++;
		} elsif ( $element->{status} eq "3" ) {
			$respobj{'errors'}++;
			$respobj{'errorstrings'} .= " " . $element->{result};
		} elsif ( $element->{status} eq "4" ) {
			$respobj{'warnings'}++;
		} elsif ( $element->{status} eq "5" ) {
			$respobj{'ok'}++;
		} elsif ( $element->{status} eq "6" ) {
			$respobj{'infos'}++;
		} else {
			$respobj{'errors'}++;
			$respobj{'unknown'}++;
		}
	}	
	
	# Get last notification of the widget $not_helper
	my %notif;
	my @notifications = LoxBerry::Log::get_notifications( $not_helper, $not_prefix );
	if ( $notifications[0] ) {
		my $lastnot = $notifications[0];
		$notif{errors} = $lastnot->{errors};
		$notif{warnings} = $lastnot->{warnings};
		$notif{infos} = $lastnot->{infos};
		$notif{ok} = $lastnot->{ok};
		$notif{unknown} = $lastnot->{unknown};
		$notif{lastnotify} = $lastnot->{lastnotify};
	} else {
		$notif{errors} = 0;
		$notif{warnings} = 0;
		$notif{infos} = 0;
		$notif{ok} = 0;
		$notif{unknown} = 0;
		$notif{lastnotify} = 0;
	}
	
	## Debugging
	# $respobj{errors} = int(rand(10));
	# $respobj{errors} = 2;
	
	# Add special variables for heartbeat
	$respobj{timeepoch} = time;
	$respobj{timestr} = localtime;
	$respobj{timelox} = epoch2lox($respobj{timeepoch});
	$respobj{warnings_and_errors} = $respobj{errors} + $respobj{warnings};
	
	
	# Write json file to ram disk
	my $jsonfile = '/dev/shm/healthcheck.json';
	my $jsonfile_fallback = $lbhomedir.'/log/system/healthcheck.json';

	
	eval {
		open(my $fh, '>', $jsonfile);
		print $fh JSON->new->utf8(0)->encode(\%respobj);
		close $fh;
	};
	if ($@) {
		eval {
			print STDERR "healthcheck.pl: Error writing json to /dev/shm";
			open(my $fh, '>', $jsonfile_fallback);
			print $fh JSON->new->utf8(0)->encode(\%respobj);
			close $fh;
		};
	};
	
	# Compare errors with last notification for public notify
	if ( 
		( $respobj{errors} ne $notif{errors} or 
		  $notif{lastnotify} < (time-$resend_interval) ) and $respobj{errors} != 0 
		) {

		print STDERR "healthcheck.pl: Detected a change of ERROR results (and not 0) - sending public notification\n";
		
		# Errors changed and are not 0 --> Public notify
		my %public_not = (
			PACKAGE => $not_widget,
			NAME => $not_group,
			SEVERITY => 3,
			MESSAGE => "Healthcheck reports $respobj{errors} errors. Please run Healthcheck for details.\nCurrent errors:\n$respobj{errorstrings}",
			LINK => 'http://' . LoxBerry::System::lbhostname() . ':' . LoxBerry::System::lbwebserverport() .'/admin/system/healthcheck.cgi',
			timeepoch => time,
			timelox => epoch2lox(time)
		);
		LoxBerry::Log::notify_ext ( \%public_not );
		# Save the time of public notify in private notify
		$respobj{lastnotify} = time;
	}

	# Compare all results for private notify
	if ( $respobj{errors} ne $notif{errors} or
		 $respobj{warnings} ne $notif{warnings} or
		 $respobj{infos} ne $notif{infos} or
		 $respobj{ok} ne $notif{ok} or
		 $respobj{unknown} ne $notif{unknown} or
		 $respobj{lastnotify} ) {
		
		# Any result has changed, create/update private helper notification
				
		print STDERR "healthcheck.pl: Detected a change of check results - saving to private notification\n";
		LoxBerry::Log::delete_notifications($not_helper, $not_prefix);
		$respobj{PACKAGE} = $not_helper;
		$respobj{NAME} = $not_prefix;
		$respobj{MESSAGE} = "This helper notification keeps track of last notified healthcheck errors";
		$respobj{SEVERITY} = 7;
		$respobj{timeepoch} = time;
		$respobj{timelox} = epoch2lox($respobj{timeepoch});
		$respobj{warnings_and_errors} = $respobj{errors} + $respobj{warnings};
		
		LoxBerry::Log::notify_ext( \%respobj );
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
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
		if ($filesize > 20971520) {
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
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
		if ($filesize > 20971520) {
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
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
			my $output = qx(cat /sys/firmware/devicetree/base/model);
			chomp $output;
			$architecture .= " / $output";
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
	$result{'title'} = 'LoxBerry Version';
	$result{'desc'} = 'Checks the LoxBerry Version';
	$result{'url'} = 'https://www.loxwiki.eu/x/b4WdAQ';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	require Time::HiRes;
	require version;
	require LWP::UserAgent;
	
	# Perform check
	eval {
		
		my $cfg      = new Config::Simple("$lbsconfigdir/general.cfg");
		my $currversion  = $cfg->param("BASE.VERSION");
		my $failedscript = $cfg->param("UPDATE.FAILED_SCRIPT");
		
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
			Time::HiRes::usleep (100*1000);
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
			$result{'status'} = '4';
			$result{'result'} = "Current Version: $currversion / New Release is available: $newrelease";
		} 
		elsif (!$result{'result'}) {
			$result{'status'} = '5';
			$result{'result'} = "Current Version: $currversion / No newer Release available.";
		}
		
		if($failedscript) {
			$result{'status'} = '3';
			$result{'result'} .= " LoxBerry Update recognized a failed update script (Version $failedscript). Your LoxBerry is in an inconsistent state. Please manually retry the installation in LoxBerry Update, and check the update logfiles for errors.";
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
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
			$result{result} .= "Plugins in DEBUG loglevel: " . join(', ', @debugplugins) . ". DEBUG loglevel leads to excessive logging/performance impact. Use only during troubleshooting.";
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
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
				$result{result} = "$folderinfo{mountpoint} is below limit of 25% discspace (AVAL " .LoxBerry::System::bytes_humanreadable($folderinfo{available}, "K")."/SIZE ".LoxBerry::System::bytes_humanreadable($folderinfo{size}, "K")."). Please reboot your LoxBerry.";
				$result{status} = '4';
			} else {
				$result{result} = "$folderinfo{mountpoint} is below limit of 5% discspace (AVAL ".LoxBerry::System::bytes_humanreadable($folderinfo{available}, "K")."/SIZE ".LoxBerry::System::bytes_humanreadable($folderinfo{size}, "K")."). Please reboot your LoxBerry.";
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

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
	$result{'title'} = 'RootFS free space';
	$result{'desc'} = 'Checks the rootfs for available space';
	#$result{'url'} = 'https://www.loxwiki.eu/x/QINYAg';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	eval {

		my %folderinfo = LoxBerry::System::diskspaceinfo($lbhomedir);
		if ( $folderinfo{available}/$folderinfo{size}*100 > 10 ) {
			$result{result} = "LoxBerry's RootFS has more than 10% free discspace (AVAL ".LoxBerry::System::bytes_humanreadable($folderinfo{available}, "K")."/SIZE ".LoxBerry::System::bytes_humanreadable($folderinfo{size}, "K").").";
			$result{status} = '5';
		}
		elsif ( $folderinfo{available}/$folderinfo{size}*100 <= 5 ) {
			$result{result} = "$folderinfo{mountpoint} is below limit of 5% discspace (AVAL ".LoxBerry::System::bytes_humanreadable($folderinfo{available}, "K")."/SIZE ".LoxBerry::System::bytes_humanreadable($folderinfo{size}, "K")."). Please reboot your LoxBerry.";
			$result{status} = '3';
		} else {
			$result{result} = "$folderinfo{mountpoint} is below limit of 10% discspace (AVAL ".LoxBerry::System::bytes_humanreadable($folderinfo{available}, "K")."/SIZE ".LoxBerry::System::bytes_humanreadable($folderinfo{size}, "K")."). Please reboot your LoxBerry.";
			$result{status} = '4';
		}

	};
	if ($@) {
		$result{status} = '3';
		$result{result} .= "Error executing the test: <$@> ";
	} 
	
	return (\%result);

}

# Check CPU Temperature
sub check_cputemp
{

	my %result;
	my ($action) = @_;

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
	$result{'title'} = 'CPU Temperature';
	$result{'desc'} = 'Checks maximum CPU Temperature';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	eval {

		my $message;
		my $getthrottled;
		my $current;
		if (-e "/sys/devices/platform/soc/soc:firmware/get_throttled") {
			$getthrottled = 1;
			my $output = qx(cat /sys/devices/platform/soc/soc:firmware/get_throttled);
			chomp $output;
			
			## DEBUG
			# $output = "10005";
			# $output = "10003";
			# $output = "5";
			
			my $byte1 = length($output)>0 ? substr( $output, -2 ) : 0 ;
			my $byte2 = length($output)>=3 ? substr( $output, -4, 2 ) : 0;
			my $byte3 = length($output)>=5 ? substr( $output, -6, 2 ) : 0;
					
			# print STDERR "Byte3 | Byte2 | Byte1\n";
			# print STDERR "  $byte3  |  $byte2  |  $byte1\n";
			
			my @bits;
			# See https://github.com/mschlenstedt/Loxberry/issues/952
			$bits[0] = ($byte1 >> 0) & 0x01;
			$bits[1] = ($byte1 >> 1) & 0x01;
			$bits[2] = ($byte1 >> 2) & 0x01;
			$bits[3] = ($byte1 >> 3) & 0x01;
			$bits[16] = ($byte3 >> 0) & 0x01;
			$bits[17] = ($byte3 >> 1) & 0x01;
			$bits[18] = ($byte3 >> 2) & 0x01;
			$bits[19] = ($byte3 >> 3) & 0x01;

			if($bits[19]) {
				$result{'status'} = '4';
				$message = "(19) Since last reboot one or more times the cpu reached Raspberry's soft temperature limit (this normally means 60 C). ";
			}
		} else {
			$message = "No history data (only available on Raspberrys). ";
		}

		require LoxBerry::JSON;
		my $cfgfilejson = "$lbsconfigdir/general.json";
		my $jsonobj = LoxBerry::JSON->new();
		my $cfgjson = $jsonobj->open(filename => $cfgfilejson);

		my $sensor = $cfgjson->{Watchdog}->{Tempsensor};
		if ( !$sensor ) {
			$sensor = "/sys/class/thermal/thermal_zone0/temp";
		}

		if (-e "$sensor") {
			$current = 1;
			my $temp = qx(cat $sensor);
			chomp $temp;
			$temp = sprintf("%.1f", $temp/1000);
			$message .= "Current CPU Temperature is $temp°C. ";
			
			if($cfgjson->{Watchdog}->{Maxtemp}) {
				my $errlimit = $cfgjson->{Watchdog}->{Maxtemp} * 0.90;
				if ($temp > $errlimit) {
					$message .= "This reaches or nearly reaches your configured watchdog limit of $cfgjson->{Watchdog}->{Maxtemp}°C. This is NOT fine. ";
					$result{'status'} = '3';
				}
			}
		} else {
			$message .= "Cannot read current cpu temperature. ";
		}

		if ($getthrottled) {
			$message .= "Since last reboot the cpu never reached Raspberry's soft or critical temperature limit. This is fine.";
			$result{'status'} = '5' if (!$result{'status'});
		}
		elsif (!$result{'status'}) {
			$message .= "Current cpu temperature is fine.";
			$result{'status'} = '5';
		}
		else {
			$message .= "No data available.";
			$result{'status'} = '6';
		}

		$result{'result'} = $message;

	};

	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}

	# If there's a logfile from watchdog Widget, show it here:
	if (-e "$lbslogdir/watchdogdata.log") {
		$result{'logfile'} = "$lbslogdir/watchdogdata.log";
	}

	return(\%result);

}

# Check Power Supply
sub check_voltage
{

	my %result;
	my ($action) = @_;

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
	$result{'title'} = 'Voltage';
	$result{'desc'} = 'Checks the voltage of the power supply';
	$result{'url'} = 'https://www.loxwiki.eu/display/LOXBERRY/Hardware#Hardware-Netzteil';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	# Perform check
	eval {

		my $message;
		my $getthrottled;
		if (-e "/sys/devices/platform/soc/soc:firmware/get_throttled") {
			$getthrottled = 1;
			my $output = qx(cat /sys/devices/platform/soc/soc:firmware/get_throttled);
			chomp $output;
			
			## DEBUG
			# $output = "10005";
			# $output = "10003";
			# $output = "5";
			
			my $byte1 = substr( $output, -2 );
			my $byte2 = substr( $output, -4, 2 );
			my $byte3 = substr( $output, -6, 2 );
					
			# print STDERR "Byte3 | Byte2 | Byte1\n";
			# print STDERR "  $byte3  |  $byte2  |  $byte1\n";
			
			my @bits;
			# See https://github.com/mschlenstedt/Loxberry/issues/952
			$bits[0] = ($byte1 >> 0) & 0x01;
			$bits[1] = ($byte1 >> 1) & 0x01;
			$bits[2] = ($byte1 >> 2) & 0x01;
			$bits[3] = ($byte1 >> 3) & 0x01;
			$bits[16] = ($byte3 >> 0) & 0x01;
			$bits[17] = ($byte3 >> 1) & 0x01;
			$bits[18] = ($byte3 >> 2) & 0x01;
			$bits[19] = ($byte3 >> 3) & 0x01;

			if($bits[0]) {
				$result{'status'} = '3';
				$message .="(0) Currently under-voltage detected! ";
			}
			if($bits[1]) {
				$result{'status'} = '3';
				$message .= "(1) Currently ARM frequency is capped! ";
			}
			if($bits[2]) {
				$result{'status'} = '3';
				$message .= "(2) Currently system is throttled! ";
			}
			if($bits[16] && !$bits[0]) {
				$result{'status'} = '3';
				$message .="(16) Since last reboot one or more times under-voltage detected! ";
			}
			if($bits[17] && !$bits[1]) {
				$result{'status'} = '3';
				$message .= "(17) Since last reboot one or more times ARM frequency was capped! ";
			}
			if($bits[18] && !$bits[2]) {
				$result{'status'} = '3';
				$message .= "(18) Since last reboot one or more times system was throttled! ";
			}
		}

		if (!$result{'status'} && $getthrottled) {
			$message = "No under-voltage nor system throttling nor capped ARM frequency detected. This is fine.";
			$result{'status'} = '5';
		} elsif ($result{'status'} && $getthrottled) {
			$message .= "This is NOT fine. Check your power supply.";
		} elsif (!$getthrottled) {
			$message = "Cannot determine voltage status (only available on Raspberrys).";
			$result{'status'} = '6';
		}

		$result{'result'} = $message;

	};

	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}

	return(\%result);

}

sub check_miniservers
{

	my %result;
	my ($action) = @_;
		
	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
	$result{'title'} = 'Miniserver Access';
	$result{'desc'} = 'Checks access to your Miniservers';
	$result{'url'} = 'https://www.loxwiki.eu/x/QYgKAw';

	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}

	eval {
		# print STDERR "get_miniservers\n";
		my %mslist = LoxBerry::System::get_miniservers();
  
		if (! %mslist) {
			# print STDERR "No Miniservers\n";
			$result{'status'} = '4';
			$result{'result'} = 'No Miniservers configured, or Miniserver configuration not complete.';
			return(\%result);
		}
		
		# print STDERR "Init LWP::UserAgent\n";
		require LWP::UserAgent;
		my $ua = LWP::UserAgent->new;
		my $checkurl = 'http://localhost:' . lbwebserverport() . '/admin/system/tools/ajax-check-miniserver.cgi';
		
		$result{status} = "5";
		my @results;
		
		# print STDERR "Start loop\n";
		foreach my $ms (sort keys %mslist) {
			
			# print STDERR "Miniserver Nr. $ms: $mslist{$ms}{Name} IP $mslist{$ms}{IPAddress}.";
			my %post = (
				"ip" => $mslist{$ms}{IPAddress},
				"port" => $mslist{$ms}{Port},
				"user" => $mslist{$ms}{Admin_RAW},
				"pass" => $mslist{$ms}{Pass_RAW}
			);
			my $response = $ua->post( $checkurl, \%post );
			if ($response->is_error) {
				die("Could not query data (stopped at MS $mslist{$ms}{Name}: $response->status_line");
			}
			my $data = decode_json($response->decoded_content);
			if($data->{success} eq "1") {
				push @results, "$mslist{$ms}{Name} OK";
				push @results, "(admin user)." if ($data->{isadmin} eq "1");
				push @results, "(no admin user)." if ($data->{isnonadmin} eq "1"); 
			} else {
				push @results, "Miniserver $mslist{$ms}{Name} NOT ACCESSIBLE.";
				$result{status} = 3;
			}
		}
		
		$result{result} = join " ", @results;
		
	};
	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}
	
	return(\%result); 
}

# Check if reboot_required is set
sub check_reboot_required
{

	my %result;
	my ($action) = @_;

	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	$result{'sub'} = "$sub_name";
	$result{'title'} = 'Reboot required';
	$result{'desc'} = 'Checks if LoxBerry or a plugin requests a reboot';
	$result{'url'} = 'https://www.loxwiki.eu/x/fogKAw';
	
	# Only return Title/Desc for Webif without check
	if ($action eq "title") {
		return(\%result);
	}
	
	$result{status} = '5';
	$result{result} = "LoxBerry and plugins do not require a reboot of your LoxBerry.";
	
	eval {
		if (-e $LoxBerry::System::reboot_required_file) {
			$result{status} = '3';
			$result{result} = "LoxBerry requires a reboot to finish configuration.";
					
			my $content = LoxBerry::System::read_file($LoxBerry::System::reboot_required_file);
			if($content) {
				$result{result} .= " Reboot request information: " . $content;
			}
		}
	};
	if ($@) {
		$result{status} = '3';
		$result{result} = "Error executing the test: $@";
	}
	return(\%result); 
}
