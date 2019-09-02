#!/usr/bin/perl

# Maintenance for Logfiles, Notifys and Log SQLite Database

use LoxBerry::System;
use LoxBerry::Log;
use CGI;
use strict;
use File::Find::Rule;
use DBI;

# Global vars
my $deletefactor1;
my $deletefactor2;
my $bins = LoxBerry::System::get_binaries();

my $log = LoxBerry::Log->new (
    package => 'core',
	name => 'Log Maintenance',
	logdir => "$lbhomedir/log/system_tmpfs",
	loglevel => LoxBerry::System::systemloglevel(),
	addtime => 1,
	stdout => 1
);
LOGSTART;
my $curruser = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
LOGDEB "Executing user of log_maint.pl is $curruser";

#############################################################
# Read parameters
#############################################################

my $cgi = CGI->new;
$cgi->import_names('R');

# Default to reduce_logfiles
if (!$R::action) {
	$R::action = 'reduce_logfiles';
}

if ($R::action eq "reduce_notifys") { reduce_notifys(); }
elsif ($R::action eq "reduce_logfiles") { reduce_logfiles(); }
elsif ($R::action eq "backup_logdb") { backup_logdb(); }
else {
	LOGTITLE "Wrong or Missing parameters";
	LOGCRIT "Exiting - No Parameters";
	LOGINF "Action parameter was: '$R::action'. This parameter is unknown."; 
}
exit;


#############################################################
# Function reduce_notifys
#############################################################
sub reduce_notifys
{

	LOGTITLE "reduce_notifys";
	LOGINF "Notify maintenance: reduce_notifys called.";
	my @notifications = get_notifications();
	LOGINF "   Found " . scalar @notifications . " notifications in total";
	
	my %packagecount;
	my $delNotifyCount;
	
	for my $notification (@notifications) {
		next if ( $notification->{SEVERITY} != 3 && $notification->{SEVERITY} != 6);
		$packagecount{$notification->{PACKAGE}}++;
		if ($packagecount{$notification->{PACKAGE}} > 24) {
			LOGINF "   Deleting notification $notification->{PACKAGE} / $notification->{NAME} / Severity $notification->{SEVERITY} / $notification->{DATESTR}";
			delete_notification_key($notification->{KEY});
			$delNotifyCount++;
		}
	}
	LOGOK "Notification-Cleanup finished. $delNotifyCount cleared.";
}

#############################################################
# Function reduce_logfiles
#############################################################
sub reduce_logfiles
{
	LOGTITLE "reduce_logfiles";
	LOGINF "Logfile maintenance: reduce_logfiles called.";
	logfiles_cleanup();
	logdb_cleanup();
	
}

#############################################################
# logfiles_cleanup for all logfiles
#############################################################

sub logfiles_cleanup
{

	# Housekeeping Limits
	$deletefactor1 = 25; # in %
	$deletefactor2 = 5; # in %
	my $size = 1; # in MB
	my $logdays = 30; # in days
	my $gzdays = 60; # in days

	my $logmtime = time() - (60*60*24*$logdays);
	my $gzmtime = time() - (60*60*24*$gzdays);

	# Paths to check
	my @paths = ("$lbhomedir/log/plugins",
		"$lbhomedir/log/system",
		"$lbhomedir/log/system_tmpfs");

	# Check which disks must be cleaned
	LOGDEB "*** STAGE 1: Scanning for tmpfs disks... ***";

	# Pre-Logcleanup
	&prelogcleanup();

	foreach (@paths) {

		LOGDEB "Scanning $_ for LOG-Files >= $size MB and GZIP them...";

		my @files = File::Find::Rule->file()
			->name( '*.log' )
			->size( ">=$size" . "M" )
			->nonempty
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file (Size is: " . sprintf("%.1f",(-s "$file")/1000/1000) . " MB) will be GZIP'd.";
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$file");
			unlink ("$file\.gz") if (-e "$file");
			qx{yes | $bins->\{GZIP\} --keep --best "$file"};
			open( my $fh, '>', $file); print $fh "<INFO> Loxberry Log Maintenance cleaned up logfile " . currtime(); close($fh);
			unlink($file);
			chown $uid, $gid, "$file\.gz";
			chmod $mode, "$file\.gz";
		}	

		LOGDEB "Scanning $_ for LOG-Files >= " . $logdays . " days and GZIP them...";

		my @files = File::Find::Rule->file()
			->name( '*.log' )
			->mtime( "<=$logmtime")
			#->nonempty
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file (Age is: " . sprintf("%.1f",(-M "$file")) . " days) will be GZIP'd.";
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$file");
			unlink ("$file\.gz") if (-e "$file");
			qx{yes | $bins->\{GZIP\} --keep --best "$file"};
			open( my $fh, '>', $file); print $fh "<INFO> Loxberry Log Maintenance cleaned up logfile " . currtime(); close($fh);
			unlink($file);
			chown $uid, $gid, "$file\.gz";
			chmod $mode, "$file\.gz";
		}	

		LOGDEB "Scanning $_ for GZ-Files >= " . $gzdays . " days and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.log.gz' )
			->mtime( "<=$gzmtime")
			->nonempty
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file (Age is: " . sprintf("%.1f",(-M "$file")) . " days) will be DELETED.";
			my $delcount = unlink ("$file");
			if($delcount) {
				LOGDEB "$file DELETED.";
			} else {
				LOGDEB "$file COULD NOT BE DELETED.";
			}
		}	

	}
	
	# Post-Logcleanup
	&postlogcleanup();

	# Re-Check which disks must still be cleaned
	LOGDEB "*** STAGE 2: Scanning for tmpfs disks below $deletefactor1% free capacity... ***";
	my @emergpaths = &checkdisks(\@paths, 1);

	if (!@emergpaths) {
		LOGDEB "No emergency housekeeping for any disk needed.";
		return(2);
	}
	
	# Pre-Logcleanup
	&prelogcleanup();
	
	foreach (@emergpaths) {
		LOGDEB "Scanning $_ for GZ-Files >= " . $size . " MB and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.log.gz' )
			->size( ">=$size" . "M" )
			->nonempty
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file (Size is: " . sprintf("%.1f",(-s "$file")/1000/1000) . " MB) will be DELETED.";
			my $delcount = unlink ("$file");
			if($delcount) {
				LOGDEB "$file DELETED.";
			} else {
				LOGDEB "$file COULD NOT BE DELETED.";
			}
		}	
	}
	undef @emergpaths;
	
	# Post-Logcleanup
	&postlogcleanup();
	
	# Re-Check which disks must still be cleaned
	LOGDEB "*** STAGE 3: Re-Scanning for tmpfs disks below $deletefactor1% free capacity... ***";
	@emergpaths = &checkdisks(\@paths, 1);

	if (!@emergpaths) {
		LOGDEB "No emergency housekeeping for any disk needed.";
		return(3);
	}
	
	# Pre-Logcleanup
	&prelogcleanup();
	
	foreach (@emergpaths) {
		LOGDEB "Scanning $_ for any GZ-Files and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.log.gz' )
			->nonempty
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file will be DELETED.";
			my $delcount = unlink ("$file");
			if($delcount) {
				LOGDEB "$file DELETED.";
			} else {
				LOGDEB "$file COULD NOT BE DELETED.";
			}
		}	
	}
	undef @emergpaths;
	
	# Post-Logcleanup
	&postlogcleanup();
	
	# Re-Check which disks must still be cleaned
	LOGDEB "*** STAGE 4: Re-Scanning for tmpfs disks below $deletefactor2% free capacity... ***";
	@emergpaths = &checkdisks(\@paths, 2);

	if (!@emergpaths) {
		LOGDEB "No emergency housekeeping for any disk needed.";
		return(4);
	}
	
	# Pre-Logcleanup
	&prelogcleanup();
	
	foreach (@emergpaths) {
		LOGDEB "Scanning $_ for any LOG-Files and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.log' )
			->nonempty
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file will be DELETED.";
			open( my $fh, '>', $file); print $fh "<INFO> Loxberry Log Maintenance cleaned up logfile " .  currtime(); close($fh);
			my $delcount = unlink($file);
			if($delcount) {
				LOGDEB "$file DELETED.";
			} else {
				LOGDEB "$file COULD NOT BE DELETED.";
			}
		}	
	}
	undef(@emergpaths);
	
	# Post-Logcleanup
	&postlogcleanup();

}	

sub checkdisks {
	my @paths;
	my $spacefactor;
	my ($pathtc, $factor) = @_;

	if ($factor eq "2") {
		$spacefactor = $deletefactor2;
	} else {
		$spacefactor = $deletefactor1;
	}

	foreach my $disk (@$pathtc) {
		my %folderinfo = LoxBerry::System::diskspaceinfo($disk);
		LOGDEB "Checking $folderinfo{mountpoint} ($folderinfo{filesystem} - Available " . sprintf("%.1f",$folderinfo{available}/$folderinfo{size}*100) . "%)";
		next if( $folderinfo{size} eq "0" or ($folderinfo{available}/$folderinfo{size}*100) > $spacefactor );
		LOGWARN "--> $folderinfo{mountpoint} below limit of $spacefactor% AVAL $folderinfo{available} SIZE $folderinfo{size} - EMERGENCY housekeeping needed.";
		push(@paths, $disk);
	}
	return(@paths);
}

sub prelogcleanup {
	# Take care for Apache
	qx {$bins->\{SUDO\} -n /bin/systemctl daemon-reload >/dev/null};
	return();
}

sub postlogcleanup {
	# Take care for Apache
	qx {$bins->\{SUDO\} -n /etc/init.d/apache2 status >/dev/null};
	if ($? eq "0") {
		qx {$bins->\{SUDO\} -n /etc/init.d/apache2 reload > /dev/null};
	}
	return();
}

######################################################
# logdb_cleanup
######################################################

sub logdb_cleanup
{

	my $maxage_days = 60; # 60 days
	
	LOGINF "Logfile maintenance: logdb_cleanup called.";

	my @logs = LoxBerry::Log::get_logs(undef, undef, 'nofilter');
	my @keystodelete;
	my %logcount;
	
	for my $key (@logs) {
		#LOGDEB "Processing key $key->{KEY} from $key->{PACKAGE}/$key->{NAME} (file $key->{FILENAME})";
		
		# Delete entries that have a logstart event but no file
		if ($key->{'LOGSTARTSTR'} and ! -e "$key->{'FILENAME'}") {
			LOGINF "$key->{'FILENAME'} does not exist - dbkey added to delete list";
			push @keystodelete, $key->{'KEY'};
			# log_db_delete_logkey($dbh, $key->{'LOGKEY'});
			next;
		}
		
		next if ($key->{PACKAGE} eq "Plugin Installation");
		next if ($key->{PACKAGE} eq "LoxBerry Update" and $key->{NAME} eq "update");
		
		# Delete plugin entries older than $max_age (60) days
		
		# if ( $key->{'_ISPLUGIN'} ) {
			my $starttime_epoch;
			my $endtime_epoch;
			
			eval {
				$starttime_epoch = Time::Piece->strptime($key->{'LOGSTARTISO'}, "%Y-%m-%dT%H:%M:%S");
				$endtime_epoch = Time::Piece->strptime($key->{'LOGENDISO'}, "%Y-%m-%dT%H:%M:%S");
			}; 
			if ( $endtime_epoch != 0 and $endtime_epoch < (time-$maxage_days*24*60*60) ) {
				# LOGDEB "$key->{'FILENAME'} $starttime_epoch";
				LOGINF "Session $key->{PACKAGE}/$key->{NAME} '$key->{'LOGSTARTMESSAGE'}' (" . $starttime_epoch->dmy(".") . "-" . $endtime_epoch->dmy(".") . ") too old - dbkey added to delete list";
				push @keystodelete, $key->{'KEY'};
				next;
			}
		# }
		
		# Count and delete (more than 24 per package)
		$logcount{$key->{'PACKAGE'}}{$key->{'NAME'}}++;
		if ($logcount{$key->{'PACKAGE'}}{$key->{'NAME'}} > 24) {
			LOGDEB "Filename $key->{FILENAME} will be deleted, it is more than 24 in $key->{'PACKAGE'}/$key->{'NAME'}";
			open( my $fh, '>', $key->{'FILENAME'}); print $fh "<INFO> Loxberry Log Maintenance cleaned up logfile " .  currtime(); close($fh);
			unlink ($key->{'FILENAME'}) or 
			do {
				if (-e $key->{'FILENAME'}) {
					LOGWARN "  File $key->{'FILENAME'} NOT deleted: $!";
					next;
				}
			};
			push @keystodelete, $key->{'KEY'};
			# log_db_delete_logkey($dbh, $key->{'LOGKEY'});
			next;
		}
	}
	
	LOGINF "Init database for deletion of logkeys";
	my $dbh = LoxBerry::Log::log_db_init_database();
	LOGERR "logdb_cleanup: Could not init database - returning" if (! $dbh);
	return undef if (! $dbh);
	LOGINF "logdb_cleanup: Deleting obsolete logdb entries...";
	LoxBerry::Log::log_db_bulk_delete_logkey($dbh, @keystodelete);
	LOGINF "logdb_cleanup: Running VACUUM of logdb on ramdisk...";
	qx { echo "VACUUM;" | sqlite3 $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
	LOGOK "Finished logdb_cleanup.";

}

#############################################################
# Function backup_logdb (every week)
#############################################################
sub backup_logdb
{
	LOGTITLE "backup_logdb";
	LOGINF "Sleeping 20 seconds to not colidate with other jobs...";
	sleep 20;
	if (-e "$lbhomedir/log/system_tmpfs/logs_sqlite.dat") {
		qx { echo "VACUUM;" | sqlite3 $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
		# qx { cp -f $lbhomedir/log/system_tmpfs/logs_sqlite.dat $lbhomedir/log/system/logs_sqlite.dat.bkp };
		qx { sqlite3 $lbhomedir/log/system_tmpfs/logs_sqlite.dat ".backup '$lbhomedir/log/system/logs_sqlite.dat.bkp'" };
		LOGOK "LogDB backed up on SDCard.";
	} else {
		LOGWARN "LogDB does not exist - no backup could be made.";
	}
}

END
{
LOGEND;
}
