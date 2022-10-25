#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::Log;
use File::Find::Rule;

my $version = "3.0.0";

# Create a logging object
my $log = LoxBerry::Log->new ( 
	package => 'LoxBerry Backup', 
	name => 'Clone_SD Cronjob', 
	logdir => $lbslogdir, 
	stdout => 1,
);

LOGSTART "Clone SD card Cronjob";
LOGINF "Version of this script: $version";


# Read config
my $cfgfile = $lbsconfigdir."/general.json";
 
my $jsonobj = LoxBerry::JSON->new();
my $cfg = $jsonobj->open(filename => $cfgfile);

if (!$cfg->{'Backup'}->{'Storagepath'}) {
	LOGCRIT "Could not find storage path.";
	exit(1);
}


# Create new backup
LOGINF "Starting Backup. Please be patient.";
my $storagepath = $cfg->{'Backup'}->{'Storagepath'};
my ($exitcode) = execute { command => "sudo $lbhomedir/sbin/clone_sd.pl $storagepath path 7z > /dev/null 2>&1" };

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
		->name( $lbhostname . '_image_*.img' )
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

END {
	LOGEND if($log);
}
