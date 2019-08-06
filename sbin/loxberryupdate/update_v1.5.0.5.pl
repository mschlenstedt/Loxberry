#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

$LoxBerry::System::DEBUG = 1;

init();

LOGINF "Updating PHP 7.x configuration";
LOGINF "Deleting ~/system/php...";
delete_directory("$lbhomedir/system/php");
LOGINF "Re-creating directory ~/system/php...";
mkdir "$lbhomedir/system/php" or do { LOGERR "Could not create dir $lbhomedir/system/php"; $errors++; };
LOGINF "Copying LoxBerry PHP config...";
copy_to_loxberry("/system/php/loxberry-apache.ini");
copy_to_loxberry("/system/php/loxberry-cli.ini");

LOGINF "Deleting old LoxBerry PHP config...";
my @phpfiles = ( 
	'/etc/php/7.0/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.0/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.0/cli/conf.d/20-loxberry.ini', 
	'/etc/php/7.1/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.1/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.1/cli/conf.d/20-loxberry.ini', 
	'/etc/php/7.2/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.2/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.2/cli/conf.d/20-loxberry.ini', 
	'/etc/php/7.3/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.3/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.3/cli/conf.d/20-loxberry.ini', 
);
foreach (@phpfiles) {
	if (-e "$_") { 
		unlink "$_" or do { LOGERR "Could not delete $_"; $errors++; }; 
	}
}

LOGINF "Creating symlinks to new configuration....";

if ( -e "/etc/php/7.0" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.0/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.0/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.0/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.1" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.1/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.1/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.1/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.2" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.2/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.2/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.2/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
};
if ( -e "/etc/php/7.3" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.3/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.3/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.3/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
};

LOGOK "PHP logging settings changed.";


## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);


