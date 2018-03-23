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

LOGINF "Disabling Apache2 PrivateTmp in systemd";

$output = qx { rm -fr /etc/systemd/system/apache2.service.d  };
$output = qx { mkdir /etc/systemd/system/apache2.service.d  };
LOGINF $output;
$output = qx { echo "[Service]\nPrivateTmp=no" > /etc/systemd/system/apache2.service.d/privatetmp.conf  };
LOGINF $output;

LOGINF "Adding PERL5LIB to Apache envvars";
#print "LBHOMEDIR $lbhomedir";
#$output = qx { awk -v s="export PERL5LIB=$LBHOMEDIR/libs/perllib" '/^export PERL5LIB=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOMEDIR/system/apache2/envvars };

my $filename = "$lbhomedir/system/apache2/envvars";
my $newfilestr;
my $foundstr;
eval {

	open(my $fh, '<', $filename)
	  or LOGERR "Could not open file for reading: '$filename' $!";
	  
	while (my $row = <$fh>) {
		if (begins_with($row, "export PERL5LIB=")) {
			LOGINF "Found string - rewriting it";
			$newfilestr .= "export PERL5LIB=$lbhomedir/libs/perllib\n";
			$foundstr = 1;
		} else {
			$newfilestr .= $row;
		}
	}
	close $fh;
	if (! $foundstr) {
		LOGINF "Adding missing envvar PERL5LIB";
		$newfilestr .= "export PERL5LIB=$lbhomedir/libs/perllib\n";
	}
	
	open(my $fh, '>', $filename)
		or LOGERR "Could not open file for writing: '$filename' $!";
	print $fh $newfilestr;
	close $fh;
	
};
if ($@) {
	LOGERR "Something failed writing the new entry to Apache envvars.";
	$errors++;
}


LOGINF $output;

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);

