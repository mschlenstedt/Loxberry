#!/usr/bin/perl

# Maintenance for Logfiles, Notifys and Log SQLite Database

use LoxBerry::System;
use LoxBerry::Log;
use CGI;
use strict;

#############################################################
# Read parameters
#############################################################

my $cgi = CGI->new;
$cgi->import_names('R');

if ($R::action eq "reduce_notifys") { reduce_notifys(); }
if ($R::action eq "reduce_logfiles") { reduce_logfiles(); }
if ($R::action eq "backup_logdb") { backup_logdb(); }

exit;


#############################################################
# Function reduce_notifys
#############################################################
sub reduce_notifys
{

	print STDERR "Notify maintenance: reduce_notifys called.\n";
	my @notifications = get_notifications();
	print STDERR "   Found " . scalar @notifications . " notifications in total\n";
	
	my %packagecount;
	
	for my $notification (@notifications) {
		next if ( $notification->{SEVERITY} != 3 && $notification->{SEVERITY} != 6);
		$packagecount{$notification->{PACKAGE}}++;
		if ($packagecount{$notification->{PACKAGE}} > 20) {
			print STDERR "   Deleting notification $notification->{PACKAGE} / $notification->{NAME} / Severity $notification->{SEVERITY} / $notification->{DATESTR}\n";
			delete_notification_key($notification->{KEY});
		}
	}
}

#############################################################
# Function reduce_logfiles
#############################################################
sub reduce_logfiles
{
	print STDERR "Logfile maintenance: reduce_logfiles called.\n";
	LoxBerry::Log::logfiles_cleanup();
	my @logs = LoxBerry::Log::get_logs();
	# Vacuum logdb 
	if (!-e "$lbhomedir/log/system_tmpfs/logs_sqlite.dat" && -e "$lbhomedir/log/system/logs_sqlite.dat.bkp") {
		qx { cp -f $lbhomedir/log/system/logs_sqlite.dat.bkp $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
		qx { chown loxberry:loxberry $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
		qx { chmod +rw $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
	}
	qx { echo "VACUUM;" | sqlite3 $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
	
}

#############################################################
# Function backup_logdb (every week)
#############################################################
sub backup_logdb
{
	print STDERR "Sleeping 20 seconds to not colidate with other jobs...\n";
	sleep 20;
	if (-e "$lbhomedir/log/system_tmpfs/logs_sqlite.dat") {
		qx { echo "VACUUM;" | sqlite3 $lbhomedir/log/system_tmpfs/logs_sqlite.dat };
		qx { cp -f $lbhomedir/log/system_tmpfs/logs_sqlite.dat $lbhomedir/log/system/logs_sqlite.dat.bkp };
	}
}
