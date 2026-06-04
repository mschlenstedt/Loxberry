#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

LOGINF "Configuring LoxBerry XL - EXtended Logic";

LOGINF "Checking existance of XL samba share...";
use File::Samba;
my $create_flag = 0;
my $smbfile = "$LoxBerry::System::lbhomedir/system/samba/smb.conf";
my $smb = File::Samba->new("$smbfile");
if (!$smb) {
	LOGERR "Could not read your Samba configuration ($smbfile)";
	$create_flag = 0;
} else {
	my @sharelist = $smb->listShares;
	if( grep( /^$XL$/, @sharelist ) ) {
		LOGOK "XL share already exists. No need to create.";
		$create_flag = 0;
	} else {
		$create_flag = 1;
	}
}
LOGINF "Creating XL user directory...";
if ( -e $lbhomedir.'/webfrontend/html/XL/user' ) {
	LOGOK "User directory already exists. No need to create.";
} else {
	mkdir($lbhomedir.'/webfrontend/html/XL/user', 0700);
	`chown loxberry $lbhomedir/webfrontend/html/XL/user`;
	`chmod -c 700 $lbhomedir/webfrontend/html/XL/user`;
	`chmod -Rc 700 $lbhomedir/webfrontend/html/XL/user/*`;
	
	if ( ! -e $lbhomedir.'/webfrontend/html/XL/user' ) {
		LOGWARN "Could not create user directory.";
	} else {
		LOGOK "User directory created.";
	}
}

if ( $create_flag == 1 ) {
	my $tmp_filename = '/tmp/lb_smb_conf_' . int(rand(10000)) . '.tmp';
	LOGINF "Preparing share...";
	$smb->createShare('XL');
	$smb->sectionParameter('XL', 'comment', 'LoxBerry XL - EXtended Logic');
	$smb->sectionParameter('XL', 'create mask', '0700');
	$smb->sectionParameter('XL', 'directory mask', '0700');
	$smb->sectionParameter('XL', 'force create mode', '0700');
	$smb->sectionParameter('XL', 'follow symlinks', 'yes');
	$smb->sectionParameter('XL', 'guest ok', 'no');
	$smb->sectionParameter('XL', 'path', $lbhomedir.'/webfrontend/html/XL');
	$smb->sectionParameter('XL', 'read only', 'no');
	$smb->sectionParameter('XL', 'wide links', 'yes');
	
	$smb->save($tmp_filename);
	LOGINF "Testing new smb configuration...";
	my ($exitcode, $output) = execute("testparm -s --debuglevel=1 $tmp_filename 2>&1");
	if( $exitcode ) {
		LOGERR "New smb configuration seems to be invalid. Skipping share creation";
		LOGDEB "Failed smb.conf: $tmp_filename";
		LOGDEB $output;
	} else {
		$smb->save($smbfile);
		LOGINF "Enabling new Samba configuration...";
		`sudo /bin/systemctl reload smbd 2>&1 > /dev/null`; 
		LOGOK "New Samba configuration enabled.";
	}
}

## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
# reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
