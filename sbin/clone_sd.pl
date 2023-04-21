#!/usr/bin/perl
use warnings;
use strict;
use JSON;
use LoxBerry::System;
use LoxBerry::Log;
use Data::Dumper;
use LoxBerry::Storage;

my $version = "3.0.0.3";

my $dest_bootpart_size = 256; # /boot partition in MB

my $notify = "";
my $error = undef;
my $rc = undef;

# Create a logging object
my $log = LoxBerry::Log->new ( 
	package => 'LoxBerry Backup', 
	name => 'Clone_SD', 
	logdir => $lbslogdir, 
	loglevel => LoxBerry::System::systemloglevel(),
	stdout => 1,
);

LOGSTART "Clone SD card";
LOGINF "Version of this script: $version";
my $destpath = $ARGV[0];
my $desttype = $ARGV[1];
my $compress = $ARGV[2];

LOGINF "Parameters: $destpath $desttype $compress";

# Lock
my $status = LoxBerry::System::lock(lockfile => 'backup');
if ($status) {
    LOGINF "Could not lock, prevented by $status";
    $error++;
    $notify .= " Could not lock, prevented by $status";
    exit(1);
} 


my $curruser = getpwuid($<);
LOGINF "Executing user is $curruser";
if( $curruser ne "root" ) {
	LOGCRIT "This script needs to be run as root.";
	LOGCRIT "Use su and root password to login as root.";
    	$error++;
    	$notify .= " This script needs to be run as root.";
	exit(1);
}

my $lsblk = lsblk();
my $mount_root = findmnt('/');
my $mount_boot = findmnt('/boot');

if (!$mount_root) {
	LOGCRIT "Could not get / mount point";
    	$error++;
    	$notify .= " Could not get / mount point";
	exit(1);
}
if (!$mount_boot) {
	LOGCRIT "Could not get /boot mount point";
    	$error++;
    	$notify .= " Could not get /boot mount point";
	exit(1);
}

my $part_root = $mount_root->{filesystems}[0]->{source};
my $part_boot = $mount_boot->{filesystems}[0]->{source};

LOGINF "/     is on partition " . $part_root;
LOGINF "/boot is on partition " . $part_boot;

# Cleaning apt cache
execute ( command => "apt-get clean" );

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
    		$error++;
    		$notify .= " Could not determine your boot device.";
		exit(1);
}
	
LOGINF "Boot device is $bootdevice";

if( $destpath eq "device" && scalar @{$lsblk->{blockdevices}} <= 1 ) {
	LOGCRIT "No other device found. Insert SD card and connect card reader.";
    	$error++;
    	$notify .= " No other device found. Insert SD card and connect card reader.";
	exit(1);
}

my $src_size;
my $src1_used;
my $src_ptuuid;

print "\n================================================================================\n\n";
LOGINF "Your boot device (SOURCE of clone):";
foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
	next if (!$blockdevice->{isboot});
	$src_size = $blockdevice->{size};
	$src_ptuuid = $blockdevice->{ptuuid};
	print "/dev/$blockdevice->{name} Type $blockdevice->{type} Size " . LoxBerry::System::bytes_humanreadable($blockdevice->{size}) ."\n";
	foreach my $partition ( @{$blockdevice->{children}} ) {
		# next if ( $partition->{type} ne "part" );
		LOGINF "   -> Partition $partition->{name} Size " . LoxBerry::System::bytes_humanreadable($partition->{size}) ." " . uc($partition->{fstype});
		if ($partition->{fstype} ne 'vfat') {
			$src1_used = $partition->{fsused};
		}
	}
}
print "\n";
if ( !$destpath || !$desttype || ($desttype ne "device" && $desttype ne "path") ) {
	LOGINF "You can clone directly onto a new device (like a SDCard) or into an imagefile saved into an external path (usb or netshare), which then has do be flashed onto a SDcard.";
	print "\n";
	LOGINF "Your possible clone \033[1mdevices\033[0m (DESTINATION of clone, type device):";
	foreach my $blockdevice ( @{$lsblk->{blockdevices}} ) {
		next if ($blockdevice->{isboot});
		LOGINF "/dev/$blockdevice->{name} Type $blockdevice->{type} Size " . LoxBerry::System::bytes_humanreadable($blockdevice->{size});
		foreach my $partition ( @{$blockdevice->{children}} ) {
			# next if ( $partition->{type} ne "part" );
			LOGINF "   -> Partition $partition->{name} Size " . LoxBerry::System::bytes_humanreadable($partition->{size}) ." " . uc($partition->{fstype});
		}
	}
	print "\n";
	LOGINF "If you use type device as destination, the process will \033[1mCOMPLETELY DELETE\033[0m your selected destination device. Double check before starting!";
	print "\n";

	LOGINF "Your possible clone \033[1mpathes\033[0m (DESTINATION of clone, type path):";

	my @storages = LoxBerry::Storage::get_storage(1);
	foreach my $path ( @storages ) {
		next if $path->{TYPE} eq "local";
		LOGINF "$path->{NAME}: $path->{PATH} Type $path->{GROUP}/$path->{TYPE} Available space " . LoxBerry::System::bytes_humanreadable($path->{AVAILABLE}*1024);
	}
	print "\n";
	LOGINF "If you use type path as destination, the storage path must have enough free disc space (\033[1mtwice\033[0m as the size of your SDcard!).";
	print "\n";
	LOGINF "To start the clone, use the DESTINATION device/path as first parameter and the device type [device|path] as second parameter.";
	print "\n";
	LOGINF "If you would like to compress your image (when using path), use compression method [7z|gzip|zip|xz] as third parameter.";
	print "\n";
	LOGINF "Examples: $0 /dev/sdc device";
	LOGINF "          $0 /opt/loxberry/system/storage/usb/31816dac-01 path 7z";
	if ( ! -e "$lbsconfigdir/is_raspberry.cfg" ) {
		print "\n";
		LOGINF " \033[1mDANGER!!\033[0m This not the original LoxBerry image (not on a Raspberry).";
		LOGINF "          No idea what happens on a Non-Raspberry installation.";
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
    				$error++;
    				$notify .= " Your entered DESTINATION path $destpath is the boot device!";
				exit(1);
			}
			last;
		}
		$destdevice_index++;
	}
	if (!$destpath_found) {
		LOGCRIT "Your entered DESTINATION path $destpath does not exist.";
    		$error++;
    		$notify .= " Your entered DESTINATION path $destpath does not exist.";
		exit(1);
	}

	# For easiness, set $destdevice to the destination sevice of the lsblk array
	$destdevice = $lsblk->{blockdevices}[$destdevice_index];

	LOGINF "Destination device is $destdevice->{name} ($destdevice->{path}) size " . LoxBerry::System::bytes_humanreadable($destdevice->{size});

	# Size check (used size - swap + $dest_bootpart_size plus 10%)
	my $swapsize = 0;
	$swapsize = -s "/var/swap" if -e "/var/swap";
	$required_space = ($src1_used - $swapsize + $dest_bootpart_size*1024*1024)*1.10;
	if( $destdevice->{size} < $required_space ) {
		LOGCRIT "$destpath (" . LoxBerry::System::bytes_humanreadable($destdevice->{size}) . ") is smaller than required space (" . LoxBerry::System::bytes_humanreadable($required_space) . ")";
    		$error++;
    		$notify .= " $destpath (" . LoxBerry::System::bytes_humanreadable($destdevice->{size}) . ") is smaller than required space (" . LoxBerry::System::bytes_humanreadable($required_space) . ")";
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
			if ($path->{TYPE} eq "vfat") {
				LOGCRIT "$destpath is stored on a vfat filesystem. This is not supported because vfat does not support files larger than 2 GB. Format your device with EXT4, exFAT or NTFS.";
		    		$error++;
    				$notify .= "$destpath is stored on a vfat filesystem. This is not supported because vfat does not support files larger than 2 GB. Format your device with EXT4, exFAT or NTFS.";
				exit(1);
			}
			$destpath_found = 1;
			$destdevice_index--;
			last;
		}
	}
	execute ( command => "sudo -u loxberry mkdir -p $destpath");
	#execute ( command => "chown loxberry:loxberry $destpath");
	$destpath_found = 0 if ( !-e $destpath);

	if (!$destpath_found) {
		LOGCRIT "Your entered DESTINATION path $destpath does not exist or isn't writeable.";
    		$error++;
    		$notify .= " Your entered DESTINATION path $destpath does not exist or isn't writeable.";
		exit(1);
	}

	# For easiness, set $destdevice to the destination sevice of the lsblk array
	$destdevice = $storages[$destdevice_index];

	LOGINF "Destination device is $destdevice->{NAME} ($destdevice->{PATH}) available space " . LoxBerry::System::bytes_humanreadable($destdevice->{AVAILABLE}*1024);

	# Size check (used size - swap + $dest_bootpart_size plus 10%)
	my $swapsize = 0;
	$swapsize = -s "/var/swap" if -e "/var/swap";
	$required_space = ($src1_used - $swapsize + $dest_bootpart_size*1024*1024)*1.10;
	if( $destdevice->{AVAILABLE}*1024 < $required_space ) {
		LOGCRIT "$destpath (" . LoxBerry::System::bytes_humanreadable($destdevice->{AVAILABLE}*1024) . ") is smaller than required space (" . LoxBerry::System::bytes_humanreadable($required_space) . ")";
    		$error++;
    		$notify .= " $destpath (" . LoxBerry::System::bytes_humanreadable($destdevice->{AVAILABLE}*1024) . ") is smaller than required space (" . LoxBerry::System::bytes_humanreadable($required_space) . ")";
		exit(1);
	}
}

print "\n================================================================================\n\n";

LOGINF "Waiting 15s in case you changed your mind...";
print "\n\033[1mPress Ctrl-C now, if you have changed your mind\033[0m (I will wait 15 sec and then continue automatically).\n";
sleep(15);

##################################
# Start
##################################
print "\n";
LOGINF "Too late - let the game begin!";
print "\n";

# Stop autofs
# Unmount mounted destination partitions
if ( $desttype eq "device" ) {
	LOGINF "Stopping autofs service";
	execute( command => "systemctl stop autofs", log => $log );
	for my $i ( 1..3) {
		LOGINF "Unmount Try $i";
		foreach my $partition ( @{$destdevice->{children}} ) {
			LOGDEB "umount ".$partition->{path};
			execute( command => "umount -q -A ".$partition->{path} );
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
    		$error++;
    		$notify .= " Directory $helperdir could not be created.";
		exit(1);
	}
	if( !is_folder_empty($helperdir) ) {
		LOGCRIT "Directory $helperdir is not empty.";
    		$error++;
    		$notify .= " Directory $helperdir is not empty.";
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
    		$error++;
    		$notify .= " Could not find $destpath anymore after wiping partitions.";
		exit(1);
	}

	if ( defined $checklsblk->{blockdevices}[$destdevice_index]->{children} and scalar @{$checklsblk->{blockdevices}[$destdevice_index]->{children}} != 0 ) {
		LOGCRIT "Not all partitons could be deleted on destination $destpath.";
    		$error++;
    		$notify .= " Not all partitons could be deleted on destination $destpath.";
		exit(1);
	}
}

my $targetsize_mb;
my $targetsize_b;
if ($desttype eq "path") {
	execute ( command => "ls -l $destpath" ); # Wake up network shares...
	sleep 1;
	LOGINF ("Wating for Destination $destpath... (in case a netshare must be woken up)";
	for (my $i = 0; $i < 60; $i++) {
		if (-d $destpath) {
			last;
		} else {
			LOGDEB "Wait one more second...";
			sleep 1;
		}
	}
	if (!-d $destpath) {
		LOGCRIT "The Destination $destpath does not exist. Maybe netshare not available anymore?)."
		$error++;
		$notify .= " The Destination $destpath does not exist. Maybe netshare not available anymore?).";
		exit (1);
	}

	LOGINF "Creating destination image file, size " . LoxBerry::System::bytes_humanreadable($required_space);
	$destpath = $destpath . "/" . LoxBerry::System::lbhostname() . "_image_$now.img";
	if ( -e $destpath ) {
		LOGCRIT "$destpath already exists.";
		$error++;
		$notify .= " $destpath already exists.";
		exit (1);
	}
	$targetsize_mb = int( ($required_space / 1024 / 1024) + 0.5 ); # rounded
	$targetsize_b = int( ($required_space / 512) + 0.5 ) * 512; # rounded minus 1 byte and multiple of 512
	#execute ( command => "dd if=/dev/zero of=$destpath bs=1 count=0 seek=" . $targetsize_mb . "MB", log => $log );
	($rc) = execute ( command => "sudo -u loxberry dd if=/dev/zero of=$destpath bs=1 count=0 seek=" . $targetsize_b, log => $log );
	if ($rc ne "0") {
		LOGCRIT "Could not create Imagefile.";
    		$error++;
		$notify .= " Could not create Imagefile.";
		exit (1);
	}
	#execute ( command => "chown loxberry:loxberry $destpath");
}

LOGINF "Creating partiton table";
execute( command => "parted -s $destpath mklabel msdos", log => $log );

LOGINF "Creating new boot partition";
execute( command => "parted -s $destpath mkpart primary fat32 4MiB ". $dest_bootpart_size . "MiB", log => $log );

LOGINF "Creating new root partition";
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
			execute( command => "umount -q -A ".$partition->{path} );
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
    		$error++;
    		$notify .= " Could not create loop device.";
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
			execute( command => "umount -q -A ".$partition->{path} );
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
    	$error++;
    	$notify .= " Not all of source and destination mounts are available.";
	exit(1);
}

LOGINF "Copy data of boot partition (this will take some seconds only)";
($rc) = execute( command => "cd /media/src1 && tar cSp --numeric-owner --warning='no-file-ignored' --exclude='swap' -f - . | (cd /media/dst1 && tar xSpf - )", log => $log );
if ($rc ne "0") {
	LOGERR "Copying the files from your boot partition seems to failed. Your image/backup may be broken!";
    	$error++;
	$notify .= " Copying the files from your boot partition seems to failed. Your image/backup may be broken!";
}

LOGINF "Copy data of root partition (this may take a long time... Please be patient.)";
($rc) = execute( command => "cd /media/src2 && tar cSp --numeric-owner --warning='no-file-ignored' --exclude='swap' -f - . | (cd /media/dst2 && tar xSpf - )", log => $log );
if ($rc ne "0") {
	LOGERR "Copying the files from your root partition seems to failed. Your image/backup may be broken!";
    	$error++;
	$notify .= " Copying the files from your root partition seems to failed. Your image/backup may be broken!";
}

# Delete not needed swap file - this is normally quite big. Wa excluded above, just in case...
if (-e "/media/dst2/var/swap") {
	unlink ("/media/dst2/var/swap");
}

# if we clone into an imagefile, we want to resize the SDcard after first booting
if ($desttype eq "path") {
	LOGINF "Resize SDcard after first boot again";
	unlink ("/media/dst1/rootfsresized");
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

LOGINF "Checking the clone...";

# Check destination device
LOGINF "Checking if your destination device/path still exists.";
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
	LOGERR "Your DESTINATION device $destpath does not exist (anymore?).";
	$error++;
	$notify .= " Your DESTINATION device $destpath does not exist (anymore?).";
} else {
	LOGOK "That looks good.";
}

# Check mountpoints
LOGINF "Checking if all destination mountpoints still exist.";
foreach my $mountpoint ( keys %chk_mounts ) {
	#LOGINF "Mounting $mountpoint to $chk_mounts{$mountpoint}";
	#execute( command => "mount $chk_mounts{$mountpoint} $mountpoint", log => $log );
	LOGINF "Find mountpoint $mountpoint";
	my $mnt = findmnt($mountpoint);
	if ( !defined $mnt or $mnt->{filesystems}[0]->{target} ne $mountpoint ) {
		LOGERR "Mount $mountpoint not ready at mountpoint " . $chk_mounts{$mountpoint};
		$error++;
		$notify .= " Mount $mountpoint not ready at mountpoint " . $chk_mounts{$mountpoint};
		$mountsok = 0;
	}
}
if ($mountsok) {
	LOGOK "That looks good.";
}

# Check size of image file
if ($desttype eq "path") {
        my $imagefilesize = -s $destpath;
        LOGINF "Checking image size: $imagefilesize Bytes, target was $targetsize_b Bytes.";
        # Check size and use tolerance of +/- 5 bytes
        if ($imagefilesize < $targetsize_b - 5 || $imagefilesize > $targetsize_b + 5) {
		LOGERR "The created image file has a strange size. Maybe something went wrong. Target was: " . \
		LoxBerry::System::bytes_humanreadable($targetsize_b) . " Current is: " . \
		LoxBerry::System::bytes_humanreadable($imagefilesize);
		$error++;
		$notify .= " The created image file has a strange size. Maybe something went wrong. Target was: " . \
		LoxBerry::System::bytes_humanreadable($targetsize_b) . " Current is: " . \
		LoxBerry::System::bytes_humanreadable($imagefilesize);
	} else {
		LOGOK "That looks good.";
	}
}


# Check correct PartUUID
LOGINF "Checking correct PTUUID.";
if ($desttype eq "path") { # Loop devices gives not back correct partuuid - so overwrite here
	$newdst_ptuuid = execute ( command => "fdisk -l $destpath | grep 'Disk identifier' | cut -d: -f2 | cut -dx -f2");
	chomp ($newdst_ptuuid);
}
if (!$newdst_ptuuid or $newdst_ptuuid ne $src_ptuuid) {
	LOGERR "Source PTUUID is $src_ptuuid, Dest PTUUID is $newdst_ptuuid - They are not equal. The new SD may fail to boot!";
	$error++;
	$notify .= " Source PTUUID is $src_ptuuid, Dest PTUUID is $newdst_ptuuid - They are not equal. The new SD may fail to boot!";
} else {
		LOGOK "That looks good.";
}

# Clean up
use File::Copy;
copy( $log->filename(), "$destpath2".$log->filename() );
foreach my $mountpoint ( keys %chk_mounts ) {
	execute( command => "umount $mountpoint" );
	rmdir "$mountpoint";
}
foreach my $mountpoint ( keys %chk_mounts ) {
	rmdir "$destpath2".$mountpoint;
}

# Try to remount partitions in image file
if ($desttype eq "path") { 
	LOGINF "Try to remount boot partition in image.";
	execute( command => "mkdir -p /media/test_loxberrybackup", log => $log );
	($rc) = execute( command => "mount $destpath1 /media/test_loxberrybackup", log => $log );
	if ($rc ne "0"){
		LOGERR "Could not remount boot partition in image. Maybe the image is broken.";
		$error++;
		$notify .= " Could not remount boot partition in image. Maybe the image is broken.";
	} else {
		LOGOK "That looks good.";
	}
	execute( command => "umount -f /media/test_loxberrybackup", log => $log );
	LOGINF "Try to remount root partition in image.";
	($rc) = execute( command => "mount $destpath2 /media/test_loxberrybackup", log => $log );
	if ($rc ne "0"){
		LOGERR "Could not remount root partition in image. Maybe the image is broken.";
		$error++;
		$notify .= " Could not remount root partition in image. Maybe the image is broken.";
	} else {
		LOGOK "That looks good.";
	}
	execute( command => "umount -f /media/test_loxberrybackup", log => $log );
	rmdir "/media/test_loxberrybackup";
}

# Compress image
if ( $desttype eq "path" && $compress ne "none" && $compress ne "" ) { 
	my %imagedisk = LoxBerry::System::diskspaceinfo($destpath);
	my $required_compress = -s $destpath * 0.4; # Asuming 60% compression
	if ($imagedisk{available}*1024 < $required_compress) {
		LOGERR "Available space is too small for compressing the image. Skipping the compression.";
		$error++;
		$notify .= " Available space is too small for compressing the image. Skipping the compression.";
	} else {
		LOGINF "Compressing your image. This may take a long time... Please be patient.";
		if ($compress eq "7z") {
			($rc) = execute( command => "sudo -u loxberry 7z a " . $destpath . ".7z $destpath -mx3", log => $log );
		} elsif ($compress eq "gzip") {
			($rc) = execute( command => "sudo -u loxberry gzip -3 " . $destpath, log => $log );
		} elsif ($compress eq "xz") {
			($rc) = execute( command => "sudo -u loxberry xz -z -3 " . $destpath, log => $log );
		} elsif ($compress eq "zip") {
			($rc) = execute( command => "sudo -u loxberry zip -j -m -3 " . $destpath . ".zip " . $destpath, log => $log );
		} else {
			LOGWARN "Unknown compression method. Compression may fail.";
			$rc = 1;
		}
		if ($rc eq "0") {
			LOGOK "Compressed your image successfully.";
			unlink ($destpath);
		} else {
			LOGERR "Something went wrong while compressing the image. I keep the uncompressed image.";
			$notify .= " Something went wrong while compressing the image. I keep the uncompressed image.";
			$error++;
			unlink ($destpath . ".7z");
			unlink ($destpath . ".gz");
			unlink ($destpath . ".xz");
			unlink ($destpath . ".zip");
		}
	}
}

# Additional hints
if (!$error) {
	LOGOK "Successfully created your backup - I haven't found any errors. Maybe it worked ;-)";
	$notify .= " Successfully created your backup - I haven't found any errors. Maybe it worked! ;-)";
}
if ($desttype eq "device") {
	LOGWARN "Shutdown LoxBerry, put the new card into the Raspberry SD slot and start over!";
	LOGWARN "If it fails to boot, connect a display to Raspberry to check what happens.";
	reboot_required("After clone_sd.pl usage you need to reboot LoxBerry.");
}
if ($desttype eq "path") {
	LOGINF "You have to flash the created image onto an empty SDcard!";
	LOGINF "If it fails to boot, connect a display to Raspberry to check what happens.";
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
		LOGINF "Could not read mountlist (findmnt $dev)";
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

# Always execute
END {
	notify('backup', 'clone_sd', $notify, $error) if ($notify);
	LOGEND "Finished" if $log;
}
