#!/usr/bin/perl
#######################################################
# Parameters
#	querytype
#		release
#		prerelease
#		testing (= latest commit of a branch)  not implemented
#
#	update
#		1 	Do an update
#		(not existing) Notify only
#
# 	output
#		(not existing) STDERR
#		json Return json with version and vers info
#
#	keepupdatefiles
#		1	do not update loxberryupdate*.pl and exclude-Files
#		(not existing) update these files
#
#	dryrun
#		1	do not update loxberryupdate*.pl, exlude-file, and let rsync run dry
#
#######################################################

use LoxBerry::System;
use LoxBerry::Web;
use strict;
use warnings;
use CGI;
use JSON;
use version;
use File::Path;
use File::Copy qw(copy);
use LWP::UserAgent;
require HTTP::Request;

my $logfile ="$lbslogdir/loxberryupdate/logfile.log";
open ERR, '>', $logfile;

my $release_url;
my $oformat;
my %joutput;
my $cfg;
my $download_path = '/tmp';
# Filter - everything above or below is possible - ignore others
my $min_version = "0.3.0";
my $max_version = "0.5.0";

# Read system language
my %SL = LoxBerry::Web::readlanguage();
# print ERR "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}\n";

my $cgi = CGI->new;
# $cgi->import_names('R');

my %keywords = map { $_ => 1 } $cgi->keywords;

if (!$cgi->param) {
	$joutput{'error'} = "No parameters sent.";
	&err;
	exit (1);
}

if ($cgi->param('dryrun')) {
	$cgi->param('keepupdatefiles', 1);
}
	
my $formatjson;
my $cron;

if ($keywords{'cron'}) {
	$cron = 1;
}

$formatjson = $cgi->param('output') && $cgi->param('output') eq 'json' ? 1 : undef;

my $querytype = $cgi->param('querytype');

# We assume that if output is json, this is a web call
if ($formatjson || $cron ) {
	$cfg = new Config::Simple("$lbsconfigdir/general.cfg");
	$querytype = $cfg->param('UPDATE.RELEASETYPE');
}

if ($querytype ne 'release' && $querytype ne 'prerelease' && $querytype ne 'testing') {
	$joutput{'error'} = "Wrong query type.";
	&err;
	exit(1);
}

my $lbversion;
if (version::is_lax(LoxBerry::System::lbversion())) {
	$lbversion = version->parse(LoxBerry::System::lbversion());
} else {
	$joutput{'error'} = "Cannot read current version. Is this a real version string? Exiting.";
	&err;
	exit(1);
}

if (version::is_lax($min_version)) {
	$min_version = version->parse($min_version);
} else {
	$joutput{'error'} = "Minimal version min_version ($min_version) not a version. Is this a real version string? Exiting.";
	&err;
	exit(1);
}
if (version::is_lax($max_version)) {
	$max_version = version->parse($max_version);
} else {
	$joutput{'error'} = "Maximal version max_version ($max_version) not a version. Is this a real version string? Exiting.";
	&err;
	exit(1);
}

if ($querytype eq 'release' or $querytype eq 'prerelease') {
	my ($release_version, $release_url, $release_name, $release_body, $release_published) = check_releases($querytype, $lbversion);
	if (! defined $release_url || $release_url eq "") {
		$joutput{'info'} = "No new version found.";
		$joutput{'release_version'} = "$release_version";
		$joutput{'release_zipurl'} = "";
		$joutput{'release_name'} = $release_name;
		$joutput{'release_body'} = $release_body;
		$joutput{'published_at'} = $release_published;
		&err;
		exit 0;
	}

	$joutput{'info'} = "New version found.";
	$joutput{'release_version'} = "$release_version";
	$joutput{'release_zipurl'} = $release_url;
	$joutput{'release_name'} = $release_name;
	$joutput{'release_body'} = $release_body;
	$joutput{'published_at'} = $release_published;
	$joutput{'release_new'} = 1;
	
	if ($cgi->param('update')) {
		
		my $pids = `pidof loxberryupdate.pl`;
		print ERR "PIDOF LENGTH: " . length($pids) . "\n";
		if (length($pids) > 0) {
			$joutput{'info'} = "It seems that another update is currently running. Update request was stopped.";
			&err;
			exit(1);
		} 
					
		$joutput{'info'} = "Update to $release_version started. See logfile for details. Currently DRYRUN, hardcoded in ajax-config-handler.";
		&err;
		my $download_file = "$download_path/loxberry.$release_version.zip";
		my $filename = download($release_url, $download_file);
		if (!$filename) {
			print ERR "Error downloading file.\n";
		} else {
			print ERR "Download successfully stored in $filename.\n";
			my $unzipdir = unzip($filename, '/tmp/loxberryupdate');
			if (!defined $unzipdir) {
				print ERR "Unzipping failed.\n";
				rm ($filename);
				exit(1);
			}
			my $updatedir = prepare_update($unzipdir);
			if (!$updatedir) {
				print ERR "prepare update returned an error. Exiting.\n";
				exit(1);
			}
			# This is the place where we can hand over to the real update
			my $dryrun = $cgi->param('dryrun') ? "dryrun=1" : undef;
			
			my $pid = fork();
			if (not defined $pid) {
				print ERR "cannot fork\n";
			} 
			if (not $pid) {	
				print ERR "Calling the update from fork.\n";
				# exec never returns
				# exec("$lbhomedir/sbin/loxberryupdate.pl", "updatedir=$updatedir", "release=$release_version", "$dryrun 1>&2");
				exec("$lbhomedir/sbin/loxberryupdate.pl updatedir=$updatedir release=$release_version $dryrun");
				exit(0);
			} 
			exit(0);
		}
	}
	
	my $jsntext = to_json(\%joutput);
	print ERR "JSON: " . $jsntext . "\n";
	#print $cgi->header('application/json');
	print $jsntext;
	
	# print ERR "ZIP URL: $release_url\n";
	
	} else {
		print ERR "Nothing to do. Exiting";
		exit 0;
	}

exit;

##################################################
# Check Releases List
# Parameters
#		1. querytype ('release' or 'prerelease')
#		2. Version object of current version
# Returns
#		1. $release_version (version object)
#		2. $release->{zipball_url} (URL to the ZIP)
#		3. $release->{name} (Name of the release)
#		4. $release->{body}) (Description of the release)
#		Returns undef if no new version found
##################################################
sub check_releases
{

	my ($querytype, $currversion) = @_;
	my $endpoint = 'https://api.github.com';
	my $resource = '/repos/mschlenstedt/Loxberry/releases';
	#my $resource = '/repos/christianTF/LoxBerry-Plugin-SamplePlugin-V2-PHP/releases';

	my $release_version;

	my $ua = LWP::UserAgent->new;
	my $request = HTTP::Request->new(GET => $endpoint . $resource);
	$request->header('Accept' => 'application/vnd.github.v3+json');
	print ERR "Request: " . $request->as_string;

	my $response = $ua->request($request);
	if ($response->is_error) {
		$joutput{'error'} = "Error fetching releases: " . $response->code . " " . $response->message;
		&err;
		exit(1);
	}

	#print ERR $response->decoded_content;
	#print ERR "\n\n";

	my $releases = JSON->new->utf8(1)->allow_nonref->convert_blessed->decode($response->decoded_content);

	my $release_safe; # this was thought to be safe, not save!
	
	foreach my $release ( @$releases ) {
		$release_version = undef;
		if (!version::is_lax($release->{tag_name})) {
			print ERR "check_releases: " . $release->{tag_name} . " seems not to be a correct version number. Skipping.\n";
			next;
		} else {
			$release_version = version->parse($release->{tag_name});
		}
		#split_version($release->{tag_name});
		print ERR "RELEASE VERSION: $release_version\n";
		
		if ($release_version < $min_version || $release_version > $max_version) {
			print ERR "    Release $release_version is outside min or max version ($min_version/$max_version)\n";
			next;
		}
		print ERR "Filter check passed - continuing\n";
		
		if ($querytype eq 'release' and ($release->{prerelease} eq 1))
			{ print ERR "  Skipping pre-release\n";
			  next;
		}
		
		if (! $release_safe || version->parse($release_version) > version->parse($release_safe)) {
			$release_safe = $release;
		}
		
		# Check against current version
		print ERR "Comparing versions:\n";
		print ERR "  Current Version: $currversion\n";
		print ERR "  Release Version: $release_version\n";
		if ($currversion == $release_version) {
			print ERR "  Skipping - this is the same version.\n";  
			next;
		}
		if ($release_version < $currversion) {
			print ERR "  Skipping  - the release is older than current version.\n";
			next;
		}
		
		# At this point we know that the version is newer
		print ERR "This release is newer than current installation.\n";				

		return ($release_version, $release->{zipball_url}, $release->{name}, $release->{body}, $release->{published_at});
	}
	#print ERR "TAG_NAME: " . $releases->[1]->{tag_name} . "\n";
	#print ERR $releases->[1]->{prerelease} eq 1 ? "This is a pre-release" : "This is a RELEASE";
	print ERR "No new version found: Latest version is " . $release_safe->{tag_name} . "\n";
	return ($release_safe->{tag_name}, undef, $release_safe->{name}, $release_safe->{body}, $release_safe->{published_at});
}

############################################
# Downloads a file
# Parameters: URL, Filename where so store
# Returns filename of ok, undef if failed
############################################
sub download
{
	
	my ($url, $filename) = @_;
	print ERR "--> Download. URL: $url Filename: $filename\n";
	
	my $download_size;
	my $rel_header;
	for (my $x=1; $x<=3; $x++) {
		$rel_header = GetFileSize($url);
		$download_size = $rel_header->content_length;
		last if (defined $download_size && $download_size > 0);
	}
	return undef if (!defined $download_size || $download_size == 0); 
	print ERR "    Expected download size: $download_size\n";
	
	# print ERR "    Header check passed.\n";
	
	my $ua = LWP::UserAgent->new;
	my $res;
	for (my $x = 1; $x < 5; $x++) { 
			print ERR "Download try $x\n";
			$res = $ua->mirror( $url, $filename );
			last if ($res->is_success);
			sleep (1);
	}
	return undef if (!$res->is_success);
	my $file_size = -s $filename;
	if ($file_size != $download_size) { 
		print ERR "Filesize does not match\n";
		return undef;
	}
	# print ERR "Download saved successfully in $filename\n";
	return $filename;

}
#############################################################
# Checks the file size before the download
# Parameter is the download url
# Returns the $header object of the request
#############################################################
sub GetFileSize
{
    my ($url) = @_;
    my $ua = new LWP::UserAgent;
    $ua->agent("Mozilla/5.0");
    my $req = new HTTP::Request 'HEAD' => $url;
   #$req->header('Accept' => 'text/html');
    for (my $x=1; $x<3; $x++) {
		my $res = $ua->request($req);
		if ($res->is_success && defined $res->headers) {
			my $headers = $res->headers;
			return $headers;
		} else {
		print ERR "--> GetFileSize check failed: " . $res->code . " " . $res->message . "\n";
		sleep (1);
		}
	}
    return 0;
}

############################################################
# Unzips a file
# Parameters are the ZIP file and destination folder
# Returning:

#############################################################
sub unzip
{
	print ERR "--> Running unzip\n";
	my ($unzipfile, $unzipfolder) = @_;
	if (! -f $unzipfile) {
		print ERR "    No unzip file.\n";
		return undef;
	}
	
	if (-d $unzipfolder) {   
		delete_directory($unzipfolder);
	}
	
	if (-d $unzipfolder) {   
		print ERR "    Unzip preparation: Could not clean $unzipfolder.\n";
		return undef;
	}
	
	my $bins = LoxBerry::System::get_binaries();
	print ERR "    Extracting ZIP file\n";
	system("$bins->{UNZIP} -q -a -d $unzipfolder $unzipfile");
	my $exitcode  = $? >> 8;
	my $signal_num  = $? & 127;
	my $dumped_core = $? & 128;

	if ($exitcode > 0) {
		print ERR unziperror($exitcode) . "\n";
		print ERR "Cleaning up.\n";
		delete_directory($unzipfile);
		# rm($unzipfile);
		return undef;
	}
	return $unzipfolder;
}

sub unziperror
{
	my $errorcode = shift;
	my %err;
	$err{0} = 'Normal; no errors or warnings detected.';
	$err{1} = 'One or more warning errors were encountered, but processing completed successfully anyway.  This includes zipfiles where one or more files was skipped due to unsupported compression method or encryption with an unknown password.';
	$err{2} = 'A generic error in the zipfile format was detected.  Processing may have completed successfully anyway; some broken zipfiles created by other archivers have simple work-arounds.';
	$err{3} = 'A severe error in the zipfile format was detected.  Processing probably failed immediately.';
	$err{4} = 'Unzip was unable to allocate memory for one or more buffers during program initialization.';
	$err{5} = 'Unzip was unable to allocate memory or unable to obtain a tty to read the decryption password(s).';
	$err{6} = 'Unzip was unable to allocate memory during decompression to disk.';
	$err{7} = 'Unzip was unable to allocate memory during in-memory decompression.';
	$err{8} = '[currently not used]';
	$err{9} = 'The specified zipfiles were not found.';
	$err{10} = 'Invalid options were specified on the command line.';
	$err{11} = 'No matching files were found.';
	$err{50} = 'The disk is (or was) full during extraction.';
	$err{51} = 'The end of the ZIP archive was encountered prematurely.';
	$err{80} = 'The user aborted unzip prematurely with control-C (or similar)';
	$err{81} = 'Testing or extraction of one or more files failed due to unsupported compression methods or unsupported decryption.';
	$err{82} = 'No files were found due to bad decryption password(s).  (If even one file is successfully processed, however, the exit status is 1.)';
	
	if (defined $err{$errorcode}) {
		return "Unzip error: " . $err{$errorcode};
	} 
	return "Unzip error: Undefined zip error.";
}

sub delete_directory
{
	my $delfolder = shift;
	
	if (-d $delfolder) {   
		rmtree($delfolder, {error => \my $err});
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					print ERR "Delete folder: general error: $message\n";
				} else {
					print ERR "Delete folder: problem unlinking $file: $message\n";
				}
			}
		return undef;
		}
	}
	return 1;
}

sub prepare_update
{
	my $updatedir = shift;
	if (! -d $updatedir) {
		print ERR "prepare_update failed. Directory $updatedir does not exist.\n";
		return undef;
	}
	
	opendir( my $DIR, $updatedir );
	my $direntry;
	my $dircount;
	while ( $direntry = readdir $DIR ) {
		next unless -d $updatedir . '/' . $direntry;
		next if $direntry eq '.' or $direntry eq '..';
		$dircount++;
		last;
	}
	closedir $DIR;
	if ($dircount != 1) {
		print ERR "Found unclear number of directories ($dircount) in update directory.\n";
		return undef;
	}
	
	# system("chown -R loxberry:loxberry $updatedir");
	# my $exitcode  = $? >> 8;
	# if ($exitcode != 0) {
	# print ERR "Changing owner of updatedir $updatedir returned errors (errorcode: $exitcode). This may lead to further permission problems. Exiting.\n";
	# return undef;
	# }

	
	if ($cgi->param('keepupdatefiles')) {
		print ERR "keepupdatefiles is set - no files are copied.\n";
	}
	
	$updatedir = "$updatedir/$direntry";
	print ERR "Real update directory $updatedir\n";
	
	if (-e "$updatedir/sbin/loxberryupdatecheck.pl" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/sbin/loxberryupdatecheck.pl", "$lbhomedir/sbin/loxberryupdatecheck.pl";
		if (! $?) {
			print ERR "Error copying loxberryupdatecheck to $lbhomedir/sbin/loxberryupdatecheck.pl: $!\n";
			return undef;
		}
	}
	if (! -x "$lbhomedir/sbin/loxberryupdatecheck.pl") {
		chmod 0774, "$lbhomedir/sbin/loxberryupdatecheck.pl";
	}
	
	if (-e "$updatedir/sbin/loxberryupdate.pl" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/sbin/loxberryupdate.pl", "$lbhomedir/sbin/loxberryupdate.pl";
		if (! $?) {
			print ERR "Error copying loxberryupdate to $lbhomedir/sbin/loxberryupdate.pl: $!\n";
			return undef;
		}
	}
	if (! -e "$lbhomedir/sbin/loxberryupdate.pl") {
		print ERR "Cannot find part two of update, $lbhomedir/sbin/loxberryupdate.pl - Quitting.\n";
		return undef;
	}
		
	if (-e "$updatedir/config/system/update-exclude.system" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/config/system/update-exclude.system", "$lbhomedir/config/system/update-exclude.system";
	}
	if (! -e "$lbhomedir/config/system/update-exclude.system") {
		print ERR "Missing ignore list $lbhomedir/config/system/update-exclude.system - Quitting.\n";
		return undef;
	}
	if (! -x "$lbhomedir/sbin/loxberryupdate.pl") {
		chmod 0774, "$lbhomedir/sbin/loxberryupdate.pl";
	}
	if (! -x "$lbhomedir/sbin/loxberryupdate.pl") {
		print ERR "Cannot set executable $lbhomedir/sbin/loxberryupdate.pl - Quitting.\n";
		exit(1);
	}
	
	print ERR "Update checked and prepared successfully.\n";
	return $updatedir;
}

sub err
{
	if ($joutput{'error'}) {
		print ERR "ERROR: " . $joutput{'error'} . "\n";
		
	} elsif ($joutput{'info'}) {
		print ERR "INFO: " . $joutput{'info'} . "\n";
	}
	if ($formatjson) {
		my $jsntext = to_json(\%joutput);
		print ERR "JSON: " . $jsntext . "\n";
		print $jsntext;

	}
}

