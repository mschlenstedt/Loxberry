#!/usr/bin/perl

# Maintenance for Logfiles, Notifys and Log SQLite Database

use LoxBerry::System;
use LoxBerry::Log;
use CGI;
use strict;

# Global vars
our $deletefactor;
our %disks = LoxBerry::System::diskspaceinfo();

my $log = LoxBerry::Log->new (
    package => 'core',
	name => 'Log Maintenance',
	logdir => "$lbhomedir/log/system_tmpfs",
	#loglevel => LoxBerry::System::systemloglevel(),
	loglevel => 7,
	stdout => 1
);
LOGSTART;

#############################################################
# Read parameters
#############################################################

my $cgi = CGI->new;
$cgi->import_names('R');

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
	
	for my $notification (@notifications) {
		next if ( $notification->{SEVERITY} != 3 && $notification->{SEVERITY} != 6);
		$packagecount{$notification->{PACKAGE}}++;
		if ($packagecount{$notification->{PACKAGE}} > 20) {
			LOGINF "   Deleting notification $notification->{PACKAGE} / $notification->{NAME} / Severity $notification->{SEVERITY} / $notification->{DATESTR}";
			delete_notification_key($notification->{KEY});
		}
	}
}

#############################################################
# Function reduce_logfiles
#############################################################
sub reduce_logfiles
{
	LOGTITLE "reduce_logfiles";
	LOGINF "Logfile maintenance: reduce_logfiles called.";
	logfiles_cleanup();
	# Vacuum logdb 
	if (!-e "$lbhomedir/log/system_tmpfs/logs_sqlite.dat" && -e "$lbhomedir/log/system/logs_sqlite.dat.bkp") {
		qx { cp -f $lbhomedir/log/system/logs_sqlite.dat.bkp $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
		qx { chown loxberry:loxberry $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
		qx { chmod +rw $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
	}
	qx { echo "VACUUM;" | sqlite3 $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
	
}

#############################################################
# logfiles_cleanup for all logfiles
#############################################################

sub logfiles_cleanup
{

	# Housekeeping Limits
	$deletefactor = 25; # in %
	my $size = 1; # in MB
	my $logdays = 30; # in days
	my $gzdays = 60; # in days

	my $logmtime = time() - (60*60*24*$logdays);
	my $gzmtime = time() - (60*60*24*$gzdays);
	my @paths;

	# Check which disks must be cleaned
	LOGDEB "*** STAGE 1: Scanning for tmpfs disks... ***";
	@paths = &checkdisks();

	if (!@paths) {
		LOGDEB "No tmpfs disk available.";
		exit(0);
	}
	
	require File::Find::Rule;
	my $bins = LoxBerry::System::get_binaries();

	foreach (@paths) {

		LOGDEB "Scanning $_ for LOG-Files >= $size MB and GZIP them...";

		my @files = File::Find::Rule->file()
			->name( '*.log' )
			->size( ">=$size" . "M" )
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file (Size is: " . sprintf("%.1f",(-s "$file")/1000/1000) . " MB) will be GZIP'd.";
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$file");
			unlink ("$file\.gz") if (-e "$file");
			qx{yes | $bins->\{GZIP\} --best "$file"};
			chown $uid, $gid, "$file\.gz";
			chmod $mode, "$file\.gz";
		}	

		LOGDEB "Scanning $_ for LOG-Files >= " . $logdays . " days and GZIP them...";

		my @files = File::Find::Rule->file()
			->name( '*.log' )
			->mtime( "<=$logmtime")
        		->in($_);

		for my $file (@files){
			LOGDEB "--> $file (Age is: " . sprintf("%.1f",(-M "$file")) . " days) will be GZIP'd.";
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$file");
			unlink ("$file\.gz") if (-e "$file");
			qx{yes | $bins->\{GZIP\} --best "$file"};
			chown $uid, $gid, "$file\.gz";
			chmod $mode, "$file\.gz";
		}	

		LOGDEB "Scanning $_ for GZ-Files >= " . $gzdays . " days and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.gz' )
			->mtime( "<=$gzmtime")
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
	undef @paths;

	# Re-Check which disks must still be cleaned
	LOGDEB "*** STAGE 2: Scanning for tmpfs disks below $deletefactor% free capacity... ***";
	@paths = &checkdisks_emerg();

	if (!@paths) {
		LOGDEB "No emergency housekeeping for any disk needed.";
		exit(0);
	}
	
	foreach (@paths) {
		LOGDEB "Scanning $_ for GZ-Files >= " . $size . " MB and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.gz' )
			->size( ">=$size" . "M" )
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
	undef @paths;
	
	# Re-Check which disks must still be cleaned
	LOGDEB "*** STAGE 3: Re-Scanning for tmpfs disks below $deletefactor% free capacity... ***";
	@paths = &checkdisks_emerg();

	if (!@paths) {
		LOGDEB "No emergency housekeeping for any disk needed.";
		exit(0);
	}
	
	foreach (@paths) {
		LOGDEB "Scanning $_ for any GZ-Files and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.gz' )
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
	undef @paths;
	
	# Re-Check which disks must still be cleaned
	LOGDEB "*** STAGE 4: Re-Scanning for tmpfs disks below $deletefactor% free capacity... ***";
	@paths = &checkdisks_emerg();

	if (!@paths) {
		LOGDEB "No emergency housekeeping for any disk needed.";
		exit(0);
	}
	
	foreach (@paths) {
		LOGDEB "Scanning $_ for any LOG-Files and DELETE them...";

		my @files = File::Find::Rule->file()
			->name( '*.log' )
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
	
	# If less than this percent is free, start housekeeping
	#our $deletefactor = 25;
	
	#my %disks = LoxBerry::System::diskspaceinfo();
	#foreach my $disk (keys %disks) {
	#	LOGDEB "Checking $disks{$disk}{mountpoint} ($disks{$disk}{filesystem} - Available " . $disks{$disk}{available}/$disks{$disk}{size}*100;
	#	next if($disks{$disk}{filesystem} ne "tmpfs");
	#	next if( $disks{$disk}{size} eq "0" or ($disks{$disk}{available}/$disks{$disk}{size}*100) > $deletefactor );
	#	LOGDEB "--> $disks{$disk}{mountpoint} below limit AVAL $disks{$disk}{available} SIZE $disks{$disk}{size} - housekeeping...";
	#	
	#	our $diskavailable = $disks{$disk}{available};
	#	our $disksize = $disks{$disk}{size};
	#	
	#	require File::Find;
	#	File::Find::find ( { preprocess => \&logfiles_orderbydate, wanted => \&logfiles_delete }, $disks{$disk}{mountpoint} );
	#
	#	undef $diskavailable;
	#	undef $disksize;
	#}
}	

sub checkdisks {
	my @paths;
	foreach my $disk (keys %disks) {
		LOGDEB "Checking $disks{$disk}{mountpoint} ($disks{$disk}{filesystem})";
		next if($disks{$disk}{filesystem} ne "tmpfs");
		next if( $disks{$disk}{size} eq "0" );
		LOGDEB "--> $disks{$disk}{mountpoint} - housekeeping needed.";
		push(@paths, $disks{$disk}{mountpoint});
	}
	return(@paths);
}

sub checkdisks_emerg {
	my @paths;
	foreach my $disk (keys %disks) {
		LOGDEB "Checking $disks{$disk}{mountpoint} ($disks{$disk}{filesystem} - Available " . sprintf("%.1f",$disks{$disk}{available}/$disks{$disk}{size}*100) . "%)";
		next if($disks{$disk}{filesystem} ne "tmpfs");
		next if( $disks{$disk}{size} eq "0" or ($disks{$disk}{available}/$disks{$disk}{size}*100) > $deletefactor );
		LOGDEB "--> $disks{$disk}{mountpoint} below limit AVAL $disks{$disk}{available} SIZE $disks{$disk}{size} - EMERGENCY housekeeping needed.";
		push(@paths, $disks{$disk}{mountpoint});
	}
	return(@paths);
}

#sub logfiles_orderbydate
#{
#	my @files = @_;
#	my @filesnew;
#	
#	LOGDEB "logfiles_orderbydate called for folder $File::Find::dir";
#	
#	foreach my $filename (@files) {
#		next if ($filename eq ".");
#		next if ($filename eq "..");
#		push(@filesnew, $filename);
#	}
#	
#	@filesnew = sort {(stat $a)[10] <=> (stat $b)[10]} @filesnew;
#
#	return @filesnew;
#}

#sub logfiles_delete
#{
#	
#	return if (-d $File::Find::name);
#	return if (index($_, ".log") == -1);
#	return if (! $LoxBerry::Log::deletefactor or ($LoxBerry::Log::diskavailable / $LoxBerry::Log::disksize * 100) > ($LoxBerry::Log::deletefactor+3));
#	my $size = (stat $File::Find::name)[7] / 1024;
#	LOGDEB "logfiles_delete called with $File::Find::name (SIZE $size KB, Available: $LoxBerry::Log::diskavailable KB)";
#	# Unlink
#	my $delcount = unlink $File::Find::name;
#	if($delcount) {
#		LOGDEB "   DELETED $_";
#		$LoxBerry::Log::diskavailable += $size;
#	} else {
#		LOGDEB "   COULD NOT DELETE $_";
#	}
#	return;
#
#}

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
		qx { cp -f $lbhomedir/log/system_tmpfs/logs_sqlite.dat $lbhomedir/log/system/logs_sqlite.dat.bkp };
	}
}

END
{
LOGEND;
}
