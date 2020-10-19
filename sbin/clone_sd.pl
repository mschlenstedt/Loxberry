#!/usr/bin/perl
use warnings;
use strict;
use JSON;
use LoxBerry::System;
use LoxBerry::Log;
use Data::Dumper;

my $version = "2.2.0.3";

my $dest_bootpart_size = 256; # /boot partition in MB

# my %devicedata;
# my %bootdevice;
# my %otherdevices;

# $devicedata{bootdevice} = \%bootdevice;
# $devicedata{otherdevices} = \%otherdevices;

# Create a logging object
my $log = LoxBerry::Log->new ( package => 'core', name => 'daemon', logdir => $lbslogdir, stdout => 1 );

LOGSTART "Clone SD card";
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
	LOGCRIT "Could not get / mount point";
	exit(1);
}
if (!$mount_boot) {
	LOGCRIT "Could not get /boot mount point";
	exit(1);
}

my $part_root = $mount_root->{filesystems}[0]->{source};
my $part_boot = $mount_boot->{filesystems}[0]->{source};

LOGINF "/     is on partition " . $part_root;
LOGINF "/boot is on partition " . $part_boot;

# Find partitions in lsblk

my $bootdevice;

foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
	# LOGDEB "Blockdevice " . $blockdevice->{name} . "\n";
	foreach my $partition ( @{$blockdevice->{children}} ) {
		# # next if ( $partition->{type} ne "part" );
		# LOGDEB "Partition $partition->{name}";
		if( "/dev/".$partition->{name} eq $part_root or "/dev/".$partition->{name} eq $part_boot ) {
			$bootdevice = $blockdevice->{name};
			$blockdevice->{isboot} = 1;
			last;
		}
	}
}

if( !$bootdevice) {
		LOGCRIT "Could not determine your boot device.";
		exit(1);
}
	
LOGINF "Boot device is $bootdevice";

if( scalar @{$lsblk->{blockdevices}} <= 1 ) {
	LOGCRIT "No other device found. Insert SD card and connect card reader.";
	exit(1);
}

my $src_size;
my $src1_used;
my $src_ptuuid;

print "================================================================================\n";
print "Your boot device (SOURCE of clone):\n";
foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
	next if (!$blockdevice->{isboot});
	$src_size = $blockdevice->{size};
	$src_ptuuid = $blockdevice->{ptuuid};
	print "/dev/$blockdevice->{name} Type $blockdevice->{type} Size " . LoxBerry::System::bytes_humanreadable($blockdevice->{size}) ."\n";
	foreach my $partition ( @{$blockdevice->{children}} ) {
		# next if ( $partition->{type} ne "part" );
		print "   -> Partition $partition->{name} Size " . LoxBerry::System::bytes_humanreadable($partition->{size}) ." " . uc($partition->{fstype}) . "\n";
		if ($partition->{fstype} ne 'vfat') {
			$src1_used = $partition->{fsused};
		}
	}
}
print "\n";
if (!$destpath) {
	print "Your possible clone devices (DESTINATION of clone):\n";
	foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
		next if ($blockdevice->{isboot});
		print "/dev/$blockdevice->{name} Type $blockdevice->{type} Size " . LoxBerry::System::bytes_humanreadable($blockdevice->{size}) ."\n";
		foreach my $partition ( @{$blockdevice->{children}} ) {
			# next if ( $partition->{type} ne "part" );
			print "   -> Partition $partition->{name} Size " . LoxBerry::System::bytes_humanreadable($partition->{size}) ." " . uc($partition->{fstype}) . "\n";;
		}
	}
	print "\nThe process will COMPLETELY DELETE your selected destination device. Mind your step.\n";
	print "\n";
	print "To start the clone, use the DESTINATION device as parameter.\n";
	print "Example: $0 /dev/sdc\n";
	if ( ! -e "$lbsconfigdir/is_raspberry.cfg" ) {
		print " DANGER!! This not the original LoxBerry image (not on a Raspberry).\n";
		print "          No idea what happens on a Non-Raspberry installation.\n";
	}
	exit(0);
}

########################
# User input validation
########################

# Check if $destpath exists and is not boot
my $destpath_found = 0;
my $destdevice_index = 0;
foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
	if ( $destpath eq $blockdevice->{path} ) {
		$destpath_found = 1;
		
		if( $blockdevice->{isboot} ) {
			LOGCRIT "Your entered DESTINATION path $destpath is the boot device!";
			exit(1);
		}
		last;
	}
	$destdevice_index++;
}
if (!$destpath_found) {
	LOGCRIT "Your entered DESTINATION path $destpath does not exist.";
	exit(1);
}

# For easiness, set $destdevice to the destination sevice of the lsblk array
my $destdevice = $lsblk->{blockdevices}[$destdevice_index];

print "Destination device is $destdevice->{name} ($destdevice->{path}) size " . LoxBerry::System::bytes_humanreadable($destdevice->{size}) . "\n";

# Size check (used size + $dest_bootpart_size plus 20%)
my $required_space = ($src1_used + $dest_bootpart_size*1024*1024)*1.2;
if( $destdevice->{size} < $required_space ) {
	LOGCRIT "$destpath (" . LoxBerry::System::bytes_humanreadable($destdevice->{size}) . ") is smaller that required space (" . LoxBerry::System::bytes_humanreadable($required_space) . ")";
	exit(1);
}

print "\nPress Ctrl-C now, if you have changed your mind\n";
sleep(5);
##################################
# Start
##################################
print "Too late - let the game begin!\n\n";

# Stop autofs
execute( "systemctl stop autofs" );

# Unmount mounted destination partitions

for my $i ( 1..3) {
	LOGINF "Unmount Try $i";
	foreach my $partition ( @{$destdevice->{children}} ) {
		LOGDEB "umount ".$partition->{path};
		my ($rc) = execute( "umount -q -A ".$partition->{path} );
	}
	sleep 1;
}

my @helperdirs = (
	'/media/src1',
	'/media/src2',
	'/media/dst1',
	'/media/dst2'
);

foreach my $helperdir ( @helperdirs ) {
	# Unmount helper directories
	execute( "umount -q $helperdir");

	# Create helper directories
	mkdir($helperdir);

	if( ! -e $helperdir ) {
		LOGCRIT "Directory $helperdir could not be created.";
		exit(1);
	}
	
	if( !is_folder_empty($helperdir) ) {
		LOGCRIT "Directory $helperdir is not empty.";
		exit(1);
	}
}

LOGINF "Deleting old partitions on your destination";
execute ( "wipefs -a $destpath");
sleep(1);

# Re-read lsblk
LOGINF "Re-checking destination sd card";
my $checklsblk = lsblk();
$destpath_found = 0;
$destdevice_index = 0;

foreach my $blkdevice ( @{$checklsblk->{blockdevices}} ) {
	if( $blkdevice->{path} eq $destpath ) {
		$destpath_found = 1;
		last;
	}
	$destdevice_index++;
}
if ( !$destpath_found ) {
	LOGCRIT "Could not find $destpath anymore after wiping partitions.";
	exit(1);
}

if ( defined $checklsblk->{blockdevices}[$destdevice_index]->{children} and scalar @{$checklsblk->{blockdevices}[$destdevice_index]->{children}} != 0 ) {
	LOGCRIT "Not all partitons could be deleted on destination $destpath.";
	exit(1);
}

LOGINF "Creating partiton table";
execute( "parted -s $destpath mklabel msdos" );

LOGINF "Creating new /boot partition";
execute( "parted -s $destpath mkpart primary fat32 4MiB ". $dest_bootpart_size . "MiB" );
LOGINF "Creating new / partition";
execute( "parted -s $destpath mkpart primary ext4 ". $dest_bootpart_size . "MiB 100%" );

sleep (1);

my $destpath1 = $destpath."1";
my $destpath2 = $destpath."2";

# If partitions got re-mounted, unmount again
# Unmount mounted destination partitions

for my $i ( 1..3 ) {
	LOGINF "Unmount Try $i";
	foreach my $partition ( @{$destdevice->{children}} ) {
		LOGDEB "umount ".$partition->{path};
		my ($rc) = execute( "umount -q -A ".$partition->{path} );
	}
	sleep 1;
}

LOGINF "Formatting fat32 boot partition (takes a second)";
execute( "mkfs.vfat -F 32 ".$destpath1 );
LOGINF "Formatting ext4 data partition (takes a minute or two)";
execute( "mkfs.ext4 ".$destpath2 );

# If partitions got re-mounted, unmount again
# Unmount mounted destination partitions

for my $i ( 1..3) {
	LOGINF "Unmount Try $i";
	foreach my $partition ( @{$destdevice->{children}} ) {
		LOGDEB "umount ".$partition->{path};
		my ($rc) = execute( "umount -q -A ".$partition->{path} );
	}
	sleep 1;
}

# Mounting and checking all mounts
my %chk_mounts = (
	'/media/src1' => $part_boot,
	'/media/src2' => $part_root,
	'/media/dst1' => $destpath1,
	'/media/dst2' => $destpath2
);

LOGINF "Creating temporary mounts for copying the data";
my $mountsok;
for my $i ( 1..10 ) {
	$mountsok = 1;
	LOGINF "Checking mounts (try $i)";
	foreach my $mountpoint ( keys %chk_mounts ) {
		LOGINF "Mounting $mountpoint to $chk_mounts{$mountpoint}";
		execute( "mount $chk_mounts{$mountpoint} $mountpoint" );
		LOGDEB "Find mountpoint $mountpoint";
		my $mnt = findmnt($mountpoint);
		if ( !defined $mnt or $mnt->{filesystems}[0]->{target} ne $mountpoint ) {
			LOGDEB "Mount $mountpoint not ready at mountpoint " . $chk_mounts{$mountpoint};
			$mountsok = 0;
		}
	}
	if( $mountsok ) {
		last;
	}
	sleep(2);

}

if (!$mountsok) {
	LOGCRIT "Not all of source and destination mounts are available.";
	exit(1);
}


LOGINF "Copy data of /boot partition (this will take some seconds)";
execute( "cd /media/src1 && tar cSp --numeric-owner --warning='no-file-ignored' -f - . | (cd /media/dst1 && tar xSpvf - )" );
LOGINF "Copy data of / partition (this may take an hour...)";
execute( "cd /media/src2 && tar cSp --numeric-owner --warning='no-file-ignored' -f - . | (cd /media/dst2 && tar xSpvf - )" );


LOGINF "Change the PTUUID of destination card to $src_ptuuid";
`fdisk $destpath <<EOF > /dev/null
p
x
i
0x$src_ptuuid
r
p
w
EOF
`;

LOGINF "Checking the clone";
my $newlsblk = lsblk();

my $newdestpath_found = 0;
my $newdestdevice_index = 0;
my $newdst_ptuuid;
foreach my $blockdevice ( @{$newlsblk->{blockdevices}} ) {
	if ( $destpath eq $blockdevice->{path} ) {
		$destpath_found = 1;
		$newdst_ptuuid = $blockdevice->{ptuuid};
		last;
	}
	$destdevice_index++;
}
if (!$destpath_found) {
	LOGCRIT "Your DESTINATION device $destpath does not exist (anymore?).";
	exit(1);
}

if (!$newdst_ptuuid or $newdst_ptuuid ne $src_ptuuid) {
	LOGERR "Source PTUUID is $src_ptuuid, Dest PTUUID is $newdst_ptuuid - They are not equal. The new SD may fail to boot!";
} else {
	LOGOK "Possibly it worked! ;-)";
}
LOGWARN "Shutdown LoxBerry, put the new card into the Raspberry SD slot and start over!";
LOGWARN "If it fails to boot, connect a display to Raspberry to check what happens.";
LOGEND "Finished";


	
##########
# Subs 
##########

# Block devices
sub lsblk
{
	# Read lsblk 
	my ($rc, $output) = execute("lsblk -b -O -J");
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
	my ($rc, $output) = execute("findmnt $dev -b -J");
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
