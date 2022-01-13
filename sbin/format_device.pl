#!/usr/bin/perl
#use warnings;
#use strict;
use JSON;
use LoxBerry::System;
use LoxBerry::Log;
use Data::Dumper;
use LoxBerry::Storage;

my $version = "3.0.0";

# Create a logging object
my $log = LoxBerry::Log->new ( 
	package => 'core', 
	name => 'Format Device', 
	logdir => $lbslogdir, 
	stdout => 1 );

LOGSTART "Format Device";
LOGINF "Version of this script: $version";
my $destpath = $ARGV[0];

my $curruser = getpwuid($<);
LOGINF "Executing user is $curruser";
if( $curruser ne "root" ) {
	LOGCRIT "This script needs to be run as root.";
	LOGCRIT "Use su and root password to login as root.";
	exit(1);
}

my $lsblk = lsblk();
my $mount_root = findmnt('/');
my $mount_boot = findmnt('/boot');

if (!$mount_root) {
	LOGCRIT "Could not get / mount point.";
	exit(1);
}
if (!$mount_boot) {
	LOGINF "No /boot mount point found. This is ok. Maybe you have no seperate /boot partition.";
}

my $part_root = $mount_root->{filesystems}[0]->{source};
my $part_boot = $mount_boot->{filesystems}[0]->{source} if $mount_boot;

LOGINF "/     is on partition " . $part_root;
LOGINF "/boot is on partition " . $part_boot if $mount_boot;

if( ($part_root eq $destpath or $part_boot eq $destpath) && $destpath ne "" ) {
		LOGCRIT "Target $destpath is on your root/boot device. I cannot format this one.";
		exit(1);
}

# Find partitions in lsblk

my $targetdevice;

foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
	LOGDEB "Scanning Blockdevice " . $blockdevice->{name};
	if ("/dev/".$blockdevice->{name} eq $destpath) {
		$targetdevice->{target} = $blockdevice->{name};
		$targetdevice->{block} = $blockdevice->{name};
		$targetdevice->{isblock} = 1;
	}
	foreach my $partition ( @{$blockdevice->{children}} ) {
		# # next if ( $partition->{type} ne "part" );
		LOGDEB "Found Partition $partition->{name}";
		if( "/dev/".$partition->{name} eq $destpath ) {
			LOGDEB "This is the target partition.";
			$targetdevice->{target} = $partition->{name};
			$targetdevice->{block} = $blockdevice->{name};
			$targetdevice->{isblock} = 0;
		}
		if( "/dev/".$partition->{name} eq $part_boot ) {
			LOGDEB "This is the boot partition.";
			$targetdevice->{bootpart} = "/dev/".$partition->{name};
			$targetdevice->{bootdevice} = $blockdevice->{name};
                }
		if( "/dev/".$partition->{name} eq $part_root ) {
			LOGDEB "This is the root partition.";
			$targetdevice->{rootpart} = "/dev/".$partition->{name};
			$targetdevice->{rootdevice} = $blockdevice->{name};
                }
	}
}

#print Dumper $targetdevice;

if( !$targetdevice->{rootpart}) {
		LOGCRIT "Could not determine your root device.";
		exit(1);
}

if( $destpath && !$targetdevice->{block}) {
		LOGCRIT "Could not find your target $destpath to format.";
		exit(1);
}
	
LOGINF "Root device is $targetdevice->{rootpart} on $targetdevice->{rootdevice}";
LOGINF "Boot device is $targetdevice->{bootpart} on $targetdevice->{bootdevice}" if $targetdevice->{bootpart};

if( scalar @{$lsblk->{blockdevices}} <= 1 ) {
	LOGCRIT "No other device found. Connect another USB device.";
	exit(1);
}

print "\n";
if ( !$destpath  ) {
	print "You can format a whole device (like an USB stick): in this case all\n";
	print "existing partitions on this device will be deleted and one partition\n";
	print "with the size of the whole device will be created. You will loose all\n";
	print "data on this device!\n\n";
	print "Or you can just format a single (existing) partition on a device: In\n";
	print "this case only the partition will be formated. You will loose all data\n";
	print "on this partition only.\n\n";
	print "For security reasons you cannot format any partitions on your boot/root\n";
	print "device. Existing devices and partitions which can be formated:\n\n";
	foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
		next if ($blockdevice->{name} eq $targetdevice->{bootdevice} || $blockdevice->{name} eq $targetdevice->{rootdevice});
		print "/dev/$blockdevice->{name} Type $blockdevice->{type} Size " . LoxBerry::System::bytes_humanreadable($blockdevice->{size}) ."\n";
		foreach my $partition ( @{$blockdevice->{children}} ) {
			# next if ( $partition->{type} ne "part" );
			print "   -> Partition $partition->{name} Size " . LoxBerry::System::bytes_humanreadable($partition->{size}) ." " . uc($partition->{fstype}) . "\n";;
		}
	}
	print "\nWARNING! The process will \033[1mCOMPLETELY DELETE\033[0m your selected target device\n";
	print "or partition. Double check before starting!\n";
	print "\n";

	exit(0);
}

if( $targetdevice->{block} eq $targetdevice->{bootdevice} || $targetdevice->{block} eq $targetdevice->{rootdevice} ) {
		LOGCRIT "Target $destpath is on your root/boot device. I cannot format this one.";
		exit(1);
}

foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
	if ( $blockdevice->{name} eq $targetdevice->{block} ) {
		$targetdevice->{blocktype} = $blockdevice->{type};
		$targetdevice->{blocksize} = LoxBerry::System::bytes_humanreadable($blockdevice->{size});
		$targetdevice->{blockchildren} = $blockdevice->{children};
	}
	foreach my $partition ( @{$blockdevice->{children}} ) {
		if ( $partition->{name} eq $targetdevice->{target} ) {
			$targetdevice->{partname} = $partition->{name};
			$targetdevice->{partsize} = LoxBerry::System::bytes_humanreadable($partition->{size});
			$targetdevice->{parttype} = uc($partition->{fstype});
		}
	}
}

LOGINF "Your target to format is: $destpath";
LOGINF "This is a block device. All partitions on this device will be deleted!" if $targetdevice->{isblock};
LOGINF "/dev/$targetdevice->{block} Type $targetdevice->{blocktype} Size " . LoxBerry::System::bytes_humanreadable($targetdevice->{blocksize});
LOGINF "-> Partition /dev/$targetdevice->{partname} Size " . LoxBerry::System::bytes_humanreadable($targetdevice->{partsize}) ." " . uc($targetdevice->{parttype}) if !$targetdevice->{isblock};

print "\n\033[1mPress Ctrl-C now, if you have changed your mind\033[0m (I will wait 15 sec and then\n";
print "continue automatically).\n";
sleep(15);

##################################
# Start
##################################
print "Too late - let the game begin!\n\n";

# Stop autofs
LOGINF "Stopping autofs service";
execute( command => "/bin/systemctl stop autofs", log => $log );

# Unmount mounted destination partitions
for my $i (1..3) {
	LOGINF "Unmount Try $i";
	if ($targetdevice->{isblock}) {
		foreach my $partition ( @{$targetdevice->{blockchildren}} ) {
			LOGDEB "umount ".$partition->{path};
			my ($rc) = execute( command => "/bin/umount -q -f -A ".$partition->{path} );
		}
	} else {
		LOGDEB "umount /dev/".$targetdevice->{target};
		my ($rc) = execute( command => "/bin/umount -q -f -A /dev/".$targetdevice->{target} );
	}
	sleep 1;
}

if ($targetdevice->{isblock}) {
	LOGINF "Deleting old partitions on your target blockdevice";
	execute( command => "/sbin/wipefs -a $destpath", log => $log );
	sleep(1);

	# Re-read lsblk
	LOGINF "Re-checking target blockdevice";
	my $checklsblk = lsblk();
	$destblock_found = 0;
	$destdevice_index = 0;
	$destpart_found = 0;

	foreach my $blkdevice ( @{$checklsblk->{blockdevices}} ) {
		if( $blkdevice->{path} eq $destpath ) {
			$destpath_found = 1;
			last;
		}
		$destdevice_index++;
	}
	if ( !$destpath_found ) {
		LOGCRIT "Could not find target blockdevice $targetdevice->{block} anymore after wiping partitions.";
		exit(1);
	}
	if ( defined $checklsblk->{blockdevices}[$destdevice_index]->{children} and scalar @{$checklsblk->{blockdevices}[$destdevice_index]->{children}} != 0 ) {
		LOGCRIT "Not all partitons could be deleted on target blockdevice $targetdevice->{block}.";
		exit(1);
	}

	LOGINF "Creating partiton table";
	execute( command => "/sbin/parted -s $destpath mklabel msdos", log => $log );

	LOGINF "Creating new partition";
	execute( command => "/sbin/parted -a optimal -s $destpath mkpart primary ext4 0% 100%", log => $log );

	sleep (1);
	
	# Re-read lsblk
	LOGINF "Re-checking target blockdevice";
	my $checklsblk = lsblk();
	$destblock_found = 0;
	$destdevice_index = 0;
	$destpart_found = 0;

	foreach my $blkdevice ( @{$checklsblk->{blockdevices}} ) {
		if( $blkdevice->{path} eq $destpath ) {
			$destpath_found = 1;
			last;
		}
		$destdevice_index++;
	}
	if ( !$destpath_found ) {
		LOGCRIT "Could not find target blockdevice $targetdevice->{block} anymore after creating partition.";
		exit(1);
	}
	if ( defined $checklsblk->{blockdevices}[$destdevice_index]->{children} and scalar @{$checklsblk->{blockdevices}[$destdevice_index]->{children}} != 1 ) {
		LOGCRIT "Expecting exactly 1 partition on target blockdevice, but there are " . scalar @{$checklsblk->{blockdevices}[$destdevice_index]->{children}} . " partitions on target blockdevice $targetdevice->{block}.";
		exit(1);
	}
	LOGINF "New target partition is " . $checklsblk->{blockdevices}[$destdevice_index]->{children}[0]->{path};
	$destpath = $checklsblk->{blockdevices}[$destdevice_index]->{children}[0]->{path};
}

# Re-read lsblk
LOGINF "Re-checking target blockdevice";
my $checklsblk = lsblk();
$destblock_found = 0;
$destdevice_index = 0;
$destpart_found = 0;

foreach my $blkdevice ( @{$checklsblk->{blockdevices}} ) {
	if( $blkdevice->{path} eq "/dev/".$targetdevice->{block} ) {
		$destpath_found = 1;
		last;
	}
	$destdevice_index++;
}
if ( !$destpath_found ) {
	LOGCRIT "Could not find target blockdevice $targetdevice->{block} anymore.";
	exit(1);
}
my $totalpartitions = scalar @{$checklsblk->{blockdevices}[$destdevice_index]->{children}};
LOGINF "Your target device has a total of $totalpartitions partitions.";

my ($partno) = $destpath =~ m/(\d+)$/;
if ( !$partno ) {
	LOGCRIT "Could not find the target's ($destpath) partition number.";
	exit(1);
}

LOGINF "Change the Partition type to 83 (Linux)";
if ($totalpartitions eq "1") {
`fdisk /dev/$targetdevice->{block} <<EOF > /dev/null
t
83
w
EOF
`;
} else {
`fdisk /dev/$targetdevice->{block} <<EOF > /dev/null
t
$partno
83
w
EOF
`;
};

LOGINF "Formatting ext4 data partition $destpath (takes a minute or two)";
execute( command => "mkfs.ext4 ".$destpath, log => $log );

# Re-Stop autofs
LOGINF "Starting autofs service";
execute( command => "/bin/systemctl start autofs", log => $log );

LOGOK "We are finished. Hopefully everything went fine. You may have to dis- and reconnect your external device so that LoxBerry can detect it cleanly.";

exit (0);
	
##########
# Subs 
##########

# Block devices
sub lsblk
{
	# Read lsblk 
	my ($rc, $output) = execute( command => "lsblk -b -O -J", log => $log );
	my $lsblk = decode_json( $output );
	if( $rc != 0 or ! $lsblk ) {
		exception("Could not read lsblk");
	}
#	print STDERR $output . "\n";
	return $lsblk;
}

# Mounts
# Optional parameter is folder
sub findmnt
{
	my $dev = shift;
	# Read lsblk 
	my ($rc, $output) = execute( command => "findmnt $dev -b -J", log => $log );
	my $findmnt;
	eval {
		$findmnt = decode_json( $output );
	};
	if( $rc != 0 or ! $findmnt ) {
		LOGERR "Could not read mountlist (findmnt $dev)";
	}
#	print STDERR $output . "\n";

	return $findmnt;
}

# Check if folder is empty
sub is_folder_empty {
    my $dirname = shift;
    opendir(my $dh, $dirname) or die "Not a directory";
    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
}



sub exception
{
	print STDERR "$_\n";
	exit(1);
}

sub log
{ 
	print STDERR "$_\n";
}

