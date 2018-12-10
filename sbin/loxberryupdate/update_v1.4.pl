#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::System;
use LoxBerry::Log;
use CGI;

my $cgi = CGI->new;
 

# Initialize logfile and parameters
my $logfilename;
if ($cgi->param('logfilename')) {
	$logfilename = $cgi->param('logfilename');
}
my $log = LoxBerry::Log->new(
		package => 'LoxBerry Update',
		name => 'update',
		filename => $logfilename,
		logdir => "$lbslogdir/loxberryupdate",
		loglevel => 7,
		stderr => 1,
		append => 1,
);
$logfilename = $log->filename;

if ($cgi->param('updatedir')) {
	$updatedir = $cgi->param('updatedir');
}
my $release = $cgi->param('release');

# Finished initializing
# Start program here
########################################################################

my $errors = 0;
LOGOK "Update script $0 started.";


## Commented, possibly re-use in 1.4? (from 1.2.5 updatescript)
# LOGINF "Clean up apt databases and update";
# my $output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -y autoremove };
# $output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -y clean };
# $output = qx { rm -r /var/lib/apt/lists/* };
# $output = qx { rm -r /var/cache/apt/archives/* };

# $output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/dpkg --configure -a };
# my $exitcode  = $? >> 8;
# if ($exitcode != 0) {
        # LOGERR "Error configuring dkpg with /usr/bin/dpkg --configure -a - Error $exitcode";
        # LOGDEB $output;
                # $errors++;
# } else {
        # LOGOK "Configuring dpkg successfully.";
# }
# $output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -q -y update };
# $exitcode  = $? >> 8;
# if ($exitcode != 0) {
        # LOGERR "Error updating apt database - Error $exitcode";
                # LOGDEB $output;
        # $errors++;
# } else {
        # LOGOK "Apt database updated successfully.";
# }

LOGINF "Converting mail.cfg to mail.json";

$oldmailfile = $lbsconfigdir . "/mail.cfg";
$newmailfile = $lbsconfigdir . "/mail.json";


if (! -e $oldmailfile) {
	LOGWARN "No mail configuration found to migrate - skipping migration";
} else { 
	
	unlink $newmailfile;
	
	require LoxBerry::JSON;
	
	LOGDEB "Loading mail.cfg";
	Config::Simple->import_from($oldmailfile, \%oldmcfg);
	LOGDEB "Creating mail.json";
	my $newmailobj = LoxBerry::JSON->new();
	my $newmcfg = $newmailobj->open(filename => $newmailfile);
	
	LOGDEB "Migrating settings...";
	
	foreach my $key (sort keys %oldmcfg) {
		my ($section, $param) = split('\.', $key, 2);
		#LOGDEB "ref $param is " . ref($oldmcfg{$key});
		if(ref($oldmcfg{$key}) eq 'ARRAY') {
			LOGWARN "Parameter $param had commas in it's field. Migration has tried to";
			LOGWARN "restore the value, but you should check the Mailserver widget settings and";
			LOGWARN "save it's settings again.";
			my $tmpfield = join(',', @{$oldmcfg{$key}});
			$oldmcfg{$key} = $tmpfield;
		}
		# LOGDEB "$section $param = " . $oldmcfg{$key};
		$newmcfg->{$section}->{$param} = %oldmcfg{$key};
		my $logline = index(lc($key), 'pass') != -1 ? "Migrated $section.$param = *****" : "Migrated $section.$param = $oldmcfg{$key}";
		LOGINF $logline;
	}
	
	if ( $newmcfg->{SMTP}->{EMAIL} and $newmcfg->{SMTP}->{SMTPSERVER} and $newmcfg->{SMTP}->{PORT} ) {
		# Enable mail by default if settings are made
		$newmcfg->{SMTP}->{ACTIVATE_MAIL} = "1";
	}
	
	$newmailobj->write();
	`chown loxberry:loxberry $newmailfile`;
	`chmod 0600 $newmailfile`;
	LOGINF "Deleting old mail settings file...";
	unlink $oldmailfile;
	LOGOK "Migrated your mail settings. Check your settings in the Mailserver widget.";
	
}

LOGINF "Installing jq (json parser for shell)...";

$output = qx { DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --no-install-recommends -q -y --fix-broken --reinstall install jq };
$exitcode  = $? >> 8;

if ($exitcode != 0) {
	LOGERR "Error installing jq - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
	LOGOK "jq package successfully installed";
}



	
	

## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);


sub delete_directory
{
	
	require File::Path;
	my $delfolder = shift;
	
	if (-d $delfolder) {   
		rmtree($delfolder, {error => \my $err});
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					LOGERR "     Delete folder: general error: $message";
				} else {
					LOGERR "     Delete folder: problem unlinking $file: $message";
				}
			}
		return undef;
		}
	}
	return 1;
}


####################################################################
# Copy a file or dir from updatedir to lbhomedir including error handling
# Parameter:
#	file/dir starting from ~ 
#   (without /opt/loxberry, with leading /)
####################################################################
sub copy_to_loxberry
{
	my ($destparam) = @_;
		
	my $destfile = $lbhomedir . $destparam;
	my $srcfile = $updatedir . $destparam;
		
	if (! -e $srcfile) {
		LOGINF "$srcfile does not exist - This file might have been removed in a later LoxBerry verion. No problem.";
		return;
	}
	
	my $output = qx { cp -rf $srcfile $destfile 2>&1 };
	my $exitcode  = $? >> 8;

	if ($exitcode != 0) {
		LOGERR "Error copying $destparam - Error $exitcode";
		LOGINF "Message: $output";
		$errors++;
	} else {
		LOGOK "$destparam installed.";
	}
}

