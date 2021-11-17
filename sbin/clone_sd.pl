#!/usr/bin/perl
use warnings;
use strict;
use JSON;
use LoxBerry::System;
use LoxBerry::Log;
use Data::Dumper;
use LoxBerry::Storage;

my $version = "3.0.0";

my $dest_bootpart_size = 256; # /boot partition in MB

# my %devicedata;
# my %bootdevice;
# my %otherdevices;

# $devicedata{bootdevice} = \%bootdevice;
# $devicedata{otherdevices} = \%otherdevices;

# Create a logging object
my $log = LoxBerry::Log->new ( 
	package => 'core', 
	name => 'Clone_SD', 
	logdir => $lbslogdir, 
	stdout => 1 );

LOGSTART "Clone SD card";
LOGINF "Version of this script: $version";
my $destpath = $ARGV[0];
my $desttype = $ARGV[1];

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
if ( !$destpath || !$desttype || ($desttype ne "device" && $desttype ne "path") ) {
	print "You can clone directly onto a new device (like a SDCard) or into an imagefile saved into an external path (usb or netshare), which then has do be flashed onto a SDcard.\n\n";
	print "Your possible clone \033[1mdevices\033[0m (DESTINATION of clone, type device):\n";
	foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
		next if ($blockdevice->{isboot});
		print "/dev/$blockdevice->{name} Type $blockdevice->{type} Size " . LoxBerry::System::bytes_humanreadable($blockdevice->{size}) ."\n";
		foreach my $partition ( @{$blockdevice->{children}} ) {
			# next if ( $partition->{type} ne "part" );
			print "   -> Partition $partition->{name} Size " . LoxBerry::System::bytes_humanreadable($partition->{size}) ." " . uc($partition->{fstype}) . "\n";;
		}
	}
	print "\nIf you use type device as destination, the process will \033[1mCOMPLETELY DELETE\033[0m your selected destination device. Double check before starting!\n";
	print "\n";

	print "Your possible clone \033[1mpathes\033[0m (DESTINATION of clone, type path):\n";

	my @storages = LoxBerry::Storage::get_storage(1);
	foreach my $path ( @storages ) {
		next if $path->{TYPE} eq "local";
		print "$path->{NAME}: $path->{PATH} Type $path->{GROUP}/$path->{TYPE} Available space " . LoxBerry::System::bytes_humanreadable($path->{AVAILABLE}*1024) . "\n";
	}
	print "\nIf you use type path as destination, the storage path must have enough free disc space (\033[1mtwice\033[0m as the size of your SDcard!).\n";

	print "\nTo start the clone, use the DESTINATION device/path as first parameter and the device type [device|path] as second parameter.\n";
	print "Examples: $0 /dev/sdc device\n";
	print "          $0 /opt/loxberry/system/storage/usb/31816dac-01 path\n";
	if ( ! -e "$lbsconfigdir/is_raspberry.cfg" ) {
		print "\n \033[1mDANGER!!\033[0m This not the original LoxBerry image (not on a Raspberry).\n";
		print "          No idea what happens on a Non-Raspberry installation.\n";
	}
	exit(0);
}

########################
# User input validation
########################

my $destdevice;
my $destpath_found = 0;
my $destdevice_index = 0;
my $required_space;

# Check if $destpath exists and is not boot
if ( $desttype eq "device" ) {
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
	$destdevice = $lsblk->{blockdevices}[$destdevice_index];

	print "Destination device is $destdevice->{name} ($destdevice->{path}) size " . LoxBerry::System::bytes_humanreadable($destdevice->{size}) . "\n";

	# Size check (used size + $dest_bootpart_size plus 20%)
	$required_space = ($src1_used + $dest_bootpart_size*1024*1024)*1.2;
	if( $destdevice->{size} < $required_space ) {
		LOGCRIT "$destpath (" . LoxBerry::System::bytes_humanreadable($destdevice->{size}) . ") is smaller that required space (" . LoxBerry::System::bytes_humanreadable($required_space) . ")";
		exit(1);
	}
}

# Check if $destpath exists and is not local
my $now;
if ( $desttype eq "path" ) {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$now = sprintf("%04d%02d%02d_%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);

	my $destpath_found = 0;
	my $destdevice_index = 0;
	my @storages = LoxBerry::Storage::get_storage(1);
	foreach my $path ( @storages ) {
		$destdevice_index++;
		next if $path->{TYPE} eq "local";
		if ( $destpath =~ /^$path->{PATH}/ ) { 
			$destpath_found = 1;
			$destdevice_index--;
			last;
		}
	}
	execute ( command => "mkdir -p $destpath");
	execute ( command => "chown loxberry:loxberry $destpath");
	$destpath_found = 0 if ( !-e $destpath);

	if (!$destpath_found) {
		LOGCRIT "Your entered DESTINATION path $destpath does not exist or isn't writeable.";
		exit(1);
	}

	# For easiness, set $destdevice to the destination sevice of the lsblk array
	$destdevice = $storages[$destdevice_index];

	print "Destination device is $destdevice->{NAME} ($destdevice->{PATH}) available space " . LoxBerry::System::bytes_humanreadable($destdevice->{AVAILABLE}*1024) . "\n";

	# Size check (used size + $dest_bootpart_size plus 20%)
	$required_space = ($src1_used + $dest_bootpart_size*1024*1024)*1.2;
	if( $destdevice->{AVAILABLE}*1024 < $required_space ) {
		LOGCRIT "$destpath (" . LoxBerry::System::bytes_humanreadable($destdevice->{AVAILABLE}*1024) . ") is smaller than required space (" . LoxBerry::System::bytes_humanreadable($required_space) . ")";
		exit(1);
	}
}

print "\n\033[1mPress Ctrl-C now, if you have changed your mind\033[0m (I will wait 5sec and then continue automatically).\n";
sleep(5);

##################################
# Start
##################################
print "Too late - let the game begin!\n\n";

# Stop autofs
LOGINF "Stopping autofs service";
execute( command => "systemctl stop autofs", log => $log );

# Unmount mounted destination partitions
if ($desttype eq "device") {
	for my $i ( 1..3) {
		LOGINF "Unmount Try $i";
		foreach my $partition ( @{$destdevice->{children}} ) {
			LOGDEB "umount ".$partition->{path};
			my ($rc) = execute( command => "umount -q -A ".$partition->{path} );
		}
		sleep 1;
	}
}

my @helperdirs = (
	'/media/src1',
	'/media/src2',
	'/media/dst1',
	'/media/dst2'
);

foreach my $helperdir ( @helperdirs ) {
	# Unmount helper directories
	execute( command => "umount -q $helperdir" );

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

if ($desttype eq "device") {
	LOGINF "Deleting old partitions on your destination";
	execute( command => "wipefs -a $destpath", log => $log );
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
}

if ($desttype eq "path") {
	LOGINF "Creating destination image file, size " . LoxBerry::System::bytes_humanreadable($required_space);
	$destpath = $destpath . "/" . LoxBerry::System::lbhostname() . "_image_$now.img";
	if ( -e $destpath ) {
		LOGCRIT "$destpath already exists.";
		exit (1);
	}
	my $targetsize_mb = int( ($required_space / 1024 / 1024) + 0.5 ); # rounded
	print "Targetsize is: $targetsize_mb\n";
	execute ( command => "dd if=/dev/zero of=$destpath bs=1 count=0 seek=" . $targetsize_mb . "MB", log => $log );
	execute ( command => "chown loxberry:loxberry $destpath");
}

LOGINF "Creating partiton table";
execute( command => "parted -s $destpath mklabel msdos", log => $log );

LOGINF "Creating new /boot partition";
execute( command => "parted -s $destpath mkpart primary fat32 4MiB ". $dest_bootpart_size . "MiB", log => $log );
LOGINF "Creating new / partition";
execute( command => "parted -s $destpath mkpart primary ext4 ". $dest_bootpart_size . "MiB 100%", log => $log );

sleep (1);

my $destpath1;
my $destpath2;
my $loop;

# If partitions got re-mounted, unmount again
# Unmount mounted destination partitions
if ($desttype eq "device") {
	$destpath1 = $destpath."1";
	$destpath2 = $destpath."2";
	for my $i ( 1..3 ) {
		LOGINF "Unmount Try $i";
		foreach my $partition ( @{$destdevice->{children}} ) {
			LOGDEB "umount ".$partition->{path};
			my ($rc) = execute( command => "umount -q -A ".$partition->{path} );
		}
		sleep 1;
	}
}

# Create devices fronm image file for each partition
if ($desttype eq "path") {
	LOGINF "Create loop devices for all partitions in image file $destpath";
	execute( command => "losetup -f --show -P $destpath", log => $log );
	$loop = execute( command => "losetup -j $destpath | cut -d: -f1" );
	chomp ($loop);
	if ( $loop !~ /^\/dev\/loop\d+/ ) {
		LOGCRIT "Could not create loop device.";
		exit (1);
	}
	$destpath1 = $loop."p1";
	$destpath2 = $loop."p2";
}

LOGINF "Formatting fat32 boot partition (takes a second)";
execute( command => "mkfs.vfat -F 32 ".$destpath1, log => $log );
LOGINF "Formatting ext4 data partition (takes a minute or two)";
execute( command => "mkfs.ext4 ".$destpath2, log => $log );

# If partitions got re-mounted, unmount again
# Unmount mounted destination partitions

if ($desttype eq "device") {
	for my $i ( 1..3) {
		LOGINF "Unmount Try $i";
		foreach my $partition ( @{$destdevice->{children}} ) {
			LOGDEB "umount ".$partition->{path};
			my ($rc) = execute( command => "umount -q -A ".$partition->{path} );
		}
		sleep 1;
	}
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
		execute( command => "mount $chk_mounts{$mountpoint} $mountpoint", log => $log );
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
execute( command => "cd /media/src1 && tar cSp --numeric-owner --warning='no-file-ignored' -f - . | (cd /media/dst1 && tar xSpvf - )", log => $log );
LOGINF "Copy data of / partition (this may take an hour...)";
execute( command => "cd /media/src2 && tar cSp --numeric-owner --warning='no-file-ignored' -f - . | (cd /media/dst2 && tar xSpvf - )", log => $log );

# Delete not needed swap file - this is normally quite big
if (-e "/media/dst2/var/swap") {
	unlink ("/media/dst2/var/swap");
}

# if we clone into an imagefile, we want to resize the SDcard after first booting
if ($desttype eq "path") {
	LOGINF "Resize SDcard after first boot again";
	unlink ("/media/dst1/rootfsresized");
	open(F,">/media/dst2$lbhomedir/system/daemons/system/98-resizerootfs");
	print F <<EOF;
#!/bin/bash
$lbssbindir/resize_rootfs > $lbslogdir/rootfsresized.log 2>&1
rm $lbhomedir/system/daemons/system/98-resizerootfs
reboot
EOF
	close (F);
	execute ( command => "chmod +x /media/dst2$lbhomedir/system/daemons/system/98-resizerootfs" );
}

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
	if ( $destpath eq $blockdevice->{path} || $loop eq $blockdevice->{path} ) {
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

foreach my $mountpoint ( keys %chk_mounts ) {
	LOGINF "Mounting $mountpoint to $chk_mounts{$mountpoint}";
	execute( command => "mount $chk_mounts{$mountpoint} $mountpoint", log => $log );
	LOGDEB "Find mountpoint $mountpoint";
	my $mnt = findmnt($mountpoint);
	if ( !defined $mnt or $mnt->{filesystems}[0]->{target} ne $mountpoint ) {
		LOGDEB "Mount $mountpoint not ready at mountpoint " . $chk_mounts{$mountpoint};
		$mountsok = 0;
	}
}

# Loop devices gives not back correct partuuid - so overwrite here
if ($desttype eq "path") {
	$newdst_ptuuid = execute ( command => "fdisk -l $destpath | grep 'Disk identifier' | cut -d: -f2 | cut -dx -f2");
	chomp ($newdst_ptuuid);
}

if (!$newdst_ptuuid or $newdst_ptuuid ne $src_ptuuid) {
	LOGERR "Source PTUUID is $src_ptuuid, Dest PTUUID is $newdst_ptuuid - They are not equal. The new SD may fail to boot!";
} else {
	LOGOK "Possibly it worked! ;-)";
}

# Additional hints and cleaning up
foreach my $mountpoint ( keys %chk_mounts ) {
	rmdir "$destpath2".$mountpoint;
}
use File::Copy;
copy( $log->filename(), "$destpath2".$log->filename() );
foreach my $mountpoint ( keys %chk_mounts ) {
	execute( command => "umount $mountpoint" );
	rmdir "$mountpoint";
}
if ($desttype eq "device") {
	LOGWARN "Shutdown LoxBerry, put the new card into the Raspberry SD slot and start over!";
	LOGWARN "If it fails to boot, connect a display to Raspberry to check what happens.";
	LOGEND "Finished";
	reboot_required("After clone_sd.pl usage you need to reboot LoxBerry.");
}

if ($desttype eq "path") {
	LOGINF "Starting autofs service";
	execute( command => "systemctl start autofs", log => $log );
	LOGINF "You have to flash the created image onto an empty SDcard!";
	LOGINF "If it fails to boot, connect a display to Raspberry to check what happens.";
	LOGEND "Finished";
	execute ( command => "losetup -d $loop" );
}

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
