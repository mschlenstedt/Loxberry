#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;
use LoxBerry::JSON;

init();

apt_update("update");

LOGINF "Removing obsolete ssmtp package...";
$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --purge -q -y remove ssmtp bsd-mailx };
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error removing ssmtp and bsd-mailx - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "ssmtp and bsd-mailx packages successfully removed.";
}

LOGINF "Installing msmtp package and replacing ssmtp...";
copy_to_loxberry("/system/msmtp");
apt_install("msmtp msmtp-mta bsd-mailx");

#
# Migrating ssmtp config to msmtp
#
if (-e "$lbhomedir/system/ssmtp/ssmtp.conf" ) {

	my $mailfile = $lbsconfigdir . "$lbhomedir/config/system/mail.json";
	my $msmtprcfile = $lbhomedir . "$lbhomedir/system/msmtp/msmtprc";
	
	$mailobj = LoxBerry::JSON->new();
	$mcfg = $mailobj->open(filename => $mailfile);
	
	if ( is_enabled ($mcfg->{SMTP}->{ACTIVATE_MAIL}) ) {
		LOGINF "Migrating ssmtp configuration to msmtp...";
		my $error;
		open(F,">$msmtprcfile") || $error++;
		flock(F,2);
		print F "aliases $lbhomedir/system/msmtp/aliases\n";
		print F "logfile $lbhomedir/log/system_tmpfs/mail.log\n";
		print F "from $mcfg->{SMTP}->{EMAIL}\n";
		print F "host $mcfg->{SMTP}->{SMTPSERVER}\n";
		print F "port $mcfg->{SMTP}->{PORT}\n";
		if ( is_enabled($mcfg->{SMTP}->{AUTH}) ) {
			print F "auth on\n";
			print F "user $mcfg->{SMTP}->{SMTPUSER}\n";
			print F "password $mcfg->{SMTP}->{SMTPPASS}\n";
		} else {
			print F "auth off\n";
		}
		if ( is_enabled($mcfg->{SMTP}->{CRYPT}) ) {
			print F "tls on\n";
			print F "tls_trust_file /etc/ssl/certs/ca-certificates.crt\n"
		} else {
			print F "tls off\n";
		}
		flock(F,8);
		close(F);
		if ($error) {
			LOGWARN "Could not migrate config file from ssmtp to msmtp. Please configure the Mailserver Widget manually!";
		} else {
			LOGOK "Created new msmtp config successfully.";
			my $email = $mcfg->{SMTP}->{EMAIL}
			LOGINF "Cleaning mail.json due to previously saved credentials in that config file"
			delete $mcfg->{SMTP};
			$mcfg->{SMTP}->{ACTIVATE_MAIL} = "1";
			$mcfg->{SMTP}->{ISCONFIGURED} = "1";
			$mcfg->{SMTP}->{EMAIL} = "$email";
			$mailobj->write();
			LOGINF "Activating new msmtp configuration...";
			system( "ln -s $lbhomedir/system/msmtp/msmtprc $lbhomedir/.msmtprc" );
		}

	}

}	

LOGINF "Removing old ssmtp configuration...";
delete_directory ("/system/ssmtp";

## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

apt_update("clean");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);


