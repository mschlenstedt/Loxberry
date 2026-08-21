#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::Log;
use File::Find::Rule;

my $version = "3.0.0.3";

# Create a logging object
my $log = LoxBerry::Log->new ( 
	package => 'LoxBerry Backup', 
	name => 'Clone_SD_Cronjob', 
	logdir => $lbslogdir, 
	stdout => 1,
);

LOGSTART "Clone SD card Cronjob";
LOGINF "Version of this script: $version";


# Read config
my $cfgfile = $lbsconfigdir."/general.json";
 
my $jsonobj = LoxBerry::JSON->new();
my $cfg = $jsonobj->open(filename => $cfgfile);

# "Every n weeks": skip this run unless the current week is due (issue #1543).
# The crontab only carries the weekday(s) and time now; counting whole weeks
# is done here so that every selected weekday of a due week fires - the old
# day-modulo prefix in the crontab could never work (see ajax-backup.cgi).
if ( !week_is_due( $cfg->{'Backup'}->{'Schedule'}->{'Since'},
                   $cfg->{'Backup'}->{'Schedule'}->{'Repeat'} ) ) {
	LOGINF "This week is not due for the 'every n weeks' schedule - skipping.";
	exit(0);
}

if (!$cfg->{'Backup'}->{'Storagepath'}) {
	LOGCRIT "Could not find storage path.";
	exit(1);
}
my $storagepath = $cfg->{'Backup'}->{'Storagepath'};
my $compression = $cfg->{'Backup'}->{'Compression'};

# Create new backup
LOGINF "Wating for Destination $storagepath... (in case a netshare must be woken up)";
execute ( command => "ls -l $storagepath" ); # Wake up network shares...
sleep 1;
for (my $i = 0; $i < 60; $i++) {
	if (-d $storagepath) {
		last;
	} else {
		LOGDEB "Wait one more second...";
		sleep 1;
	}
}
if (!-d $storagepath) {
	LOGCRIT "The Destination $storagepath does not exist. Maybe netshare not available anymore?).";
	exit (1);
}

LOGINF "Starting Backup. Please be patient.";
my ($exitcode) = execute { command => "sudo $lbhomedir/sbin/clone_sd.pl $storagepath path $compression > /dev/null 2>&1" };

if ($exitcode < 1) {
	LOGOK "Backup successfully created.";
} else {
	LOGERR "An error occurred while creating the backup. Check logfile of Clone_SD.";
}

# Clean old backups
if ($cfg->{'Backup'}->{'Keep_archives'}) {
	LOGINF "Cleaning. Keep in total " . $cfg->{'Backup'}->{'Keep_archives'} . " archives.";
	my $lbhostname = LoxBerry::System::lbhostname();
	my @files = File::Find::Rule->file()
		->name( $lbhostname . '_image_*.img*' )
		->nonempty
        	->in( $storagepath );

	my $i = 0;
	foreach my $file ( sort { $b cmp $a } @files ) { # sort from new to old
		$i++;
		if ($i <= $cfg->{'Backup'}->{'Keep_archives'}) {
			LOGINF "Keeping archive $file";
			next;
		}
		LOGINF "Deleting archive $file";
		unlink ($file);
	}	
}

exit(0);

# "Every n weeks", counted in whole weeks, not in days (issue #1543).
#
# The obvious "days since anchor modulo n*7" only hits a single day every n*7
# days - with two selected weekdays one of them would never fire. Counted in
# whole weeks, every selected weekday of a due week is due.
sub week_is_due
{
	my ($since, $repeat) = @_;
	return 1 if( !$repeat or $repeat < 2 );
	my ($y, $m, $d) = ( $since // '' ) =~ /^(\d{4})-(\d{2})-(\d{2})$/;
	return 1 if( !$y );

	require Time::Local;

	# Day number of a date, anchored at 12:00 so that the DST switch - it moves
	# the clock by an hour - cannot shift a date into the neighbouring day.
	my $daynum = sub {
		my ($yy, $mm, $dd) = @_;
		my $t = eval { Time::Local::timelocal( 0, 0, 12, $dd, $mm - 1, $yy ) };
		return defined $t ? int( $t / 86400 ) : undef;
	};

	my $refday = $daynum->( $y, $m, $d );
	my @now = localtime( time() );
	my $today = $daynum->( $now[5] + 1900, $now[4] + 1, $now[3] );
	return 1 if( !defined $refday or !defined $today );

	# Pull both days back to the Monday of their week, then the difference is a
	# whole number of weeks regardless of which weekday they fall on. 1970-01-01
	# was a Thursday, hence +3.
	my $back = sub {
		my ($dayno) = @_;
		return $dayno - ( ( $dayno + 3 ) % 7 );
	};

	my $weeks = ( $back->($today) - $back->($refday) ) / 7;
	return ( $weeks % $repeat == 0 ) ? 1 : 0;
}

END {
	LOGEND if($log);
}
