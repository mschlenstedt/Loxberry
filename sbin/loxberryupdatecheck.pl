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
use experimental 'smartmatch';
use CGI;
use JSON;
use version;
use File::Path;
use File::Copy qw(copy);
use LWP::UserAgent;
require HTTP::Request;

my $release_url;
my $oformat;
my %joutput;
my $download_path = '/tmp';
# Filter - everything above or below is possible - ignore others
my $min_version = "0.3.0";
my $max_version = "0.5.0";

# Read system language
my %SL = LoxBerry::Web::readlanguage();
# print STDERR "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}\n";

my $cgi = CGI->new;
# $cgi->import_names('R');

if (!$cgi->param) {
	$joutput{'error'} = "No parameters sent.";
	&err;
	exit (1);
}

if ($cgi->param('dryrun')) {
	$cgi->param('keepupdatefiles', 1);
}
	
my $formatjson;

$formatjson = $cgi->param('output') eq 'json' ? 1 : undef;

my $querytype = $cgi->param('querytype');

# DEBUG SET QUERYTYPE
# $querytype = 'release';

if ($querytype ne 'release' && $querytype ne 'prerelease' && $querytype ne 'testing') {
	$joutput{'error'} = "Wrong query type.";
	&err;
	exit(1);
}

my $lbversion;
if (!version->is_lax(LoxBerry::System::lbversion())) {
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
	my ($release_version, $release_url, $release_name, $release_body) = check_releases($querytype, $lbversion);
	if (! defined $release_url || $release_url eq "") {
		$joutput{'info'} = "No new version found.";
		&err;
		exit 0;
	}

	$joutput{'info'} = "New version found.";
	$joutput{'release_version'} = $release_version;
	$joutput{'release_zipurl'} = $release_url;
	$joutput{'release_name'} = $release_name;
	$joutput{'release_body'} = $release_body;
	
	if ($cgi->param('update')) {
		my $download_file = "$download_path/loxberry.$release_version.zip";
		my $filename = download($release_url, $download_file);
		if (!$filename) {
			print STDERR "Error downloading file.\n";
		} else {
			print STDERR "Download successfully stored in $filename.\n";
			my $unzipdir = unzip($filename, '/tmp/loxberryupdate');
			if (!defined $unzipdir) {
				print STDERR "Unzipping failed.\n";
				rm ($filename);
				exit(1);
			}
			my $updatedir = prepare_update($unzipdir);
			if (!$updatedir) {
				print STDERR "prepare update returned an error. Exiting.\n";
				exit(1);
			}
			# This is the place where we can hand over to the real update
			my $dryrun = $cgi->param('dryrun') ? "dryrun=1" : undef;
			exec($^X, "$lbhomedir/sbin/loxberryupdate.pl", "updatedir=$updatedir", "release=$release_version", "$dryrun");
			# exec never returns
			exit(0);
		}
	}
	# print STDERR "ZIP URL: $release_url\n";
	
	} else {
		print STDERR "Nothing to do. Exiting";
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
	print STDERR "Request: " . $request->as_string;

	my $response = $ua->request($request);
	if ($response->is_error) {
		print STDERR "Error fetching releases: " . $response->code . " " . $response->message . "\n";
		exit(1);
	}

	#print STDERR $response->decoded_content;
	#print STDERR "\n\n";

	my $releases = JSON->new->utf8(1)->allow_nonref->convert_blessed->decode($response->decoded_content);

	foreach my $release ( @$releases ) {
		$release_version = undef;
		if (!version::is_lax($release->{tag_name})) {
			print STDERR "check_releases: " . $release->{tag_name} . " seems not to be a correct version number. Skipping.\n";
			next;
		} else {
			$release_version = version->parse($release->{tag_name});
		}
		#split_version($release->{tag_name});
		print STDERR "RELEASE VERSION: $release_version\n";
		
		if ($release_version < $min_version || $release_version > $max_version) {
			print STDERR "    Release $release_version is outside min or max version ($min_version/$max_version)\n";
			next;
		}
		print STDERR "Filter check passed - continuing\n";
		
		# Check against current version
		print STDERR "Comparing versions:\n";
		print STDERR "  Current Version: $currversion\n";
		print STDERR "  Release Version: $release_version\n";
		if ($currversion == $release_version) {
			print STDERR "  Skipping - this is the same version.\n";  
			next;
		}
		if ($release_version < $currversion) {
			print STDERR "  Skipping  - the release is older than current version.\n";
			next;
		}
		
		# At this point we know that the version is newer
		print STDERR "This release is newer than current installation.\n";				
		if ($querytype eq 'release' and ($release->{prerelease} eq 1))
			{ print STDERR "  Skipping pre-release\n";
			  next;
		}
		return ($release_version, $release->{zipball_url}, $release->{name}, $release->{body});
	}
	#print STDERR "TAG_NAME: " . $releases->[1]->{tag_name} . "\n";
	#print STDERR $releases->[1]->{prerelease} eq 1 ? "This is a pre-release" : "This is a RELEASE";

}

############################################
# Downloads a file
# Parameters: URL, Filename where so store
# Returns filename of ok, undef if failed
############################################
sub download
{
	
	my ($url, $filename) = @_;
	print STDERR "--> Download. URL: $url Filename: $filename\n";
	
	my $download_size;
	my $rel_header;
	for (my $x=1; $x<=3; $x++) {
		$rel_header = GetFileSize($url);
		$download_size = $rel_header->content_length;
		last if (defined $download_size && $download_size > 0);
	}
	return undef if (!defined $download_size || $download_size == 0); 
	print STDERR "    Expected download size: $download_size\n";
	
	# print STDERR "    Header check passed.\n";
	
	my $ua = LWP::UserAgent->new;
	my $res;
	for (my $x = 1; $x < 5; $x++) { 
			print STDERR "Download try $x\n";
			$res = $ua->mirror( $url, $filename );
			last if ($res->is_success);
			sleep (1);
	}
	return undef if (!$res->is_success);
	my $file_size = -s $filename;
	if ($file_size != $download_size) { 
		print STDERR "Filesize does not match\n";
		return undef;
	}
	# print STDERR "Download saved successfully in $filename\n";
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
		print STDERR "--> GetFileSize check failed: " . $res->code . " " . $res->message . "\n";
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
	print STDERR "--> Running unzip\n";
	my ($unzipfile, $unzipfolder) = @_;
	if (! -f $unzipfile) {
		print STDERR "    No unzip file.\n";
		return undef;
	}
	
	if (-d $unzipfolder) {   
		delete_directory($unzipfolder);
	}
	
	if (-d $unzipfolder) {   
		print STDERR "    Unzip preparation: Could not clean $unzipfolder.\n";
		return undef;
	}
	
	my $bins = LoxBerry::System::get_binaries();
	print STDERR "    Extracting ZIP file\n";
	system("$bins->{UNZIP} -q -a -d $unzipfolder $unzipfile");
	my $exitcode  = $? >> 8;
	my $signal_num  = $? & 127;
	my $dumped_core = $? & 128;

	if ($exitcode > 0) {
		print STDERR unziperror($exitcode) . "\n";
		print STDERR "Cleaning up.\n";
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
					print STDERR "Delete folder: general error: $message\n";
				} else {
					print STDERR "Delete folder: problem unlinking $file: $message\n";
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
		print STDERR "prepare_update failed. Directory $updatedir does not exist.\n";
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
		print STDERR "Found unclear number of directories ($dircount) in update directory.\n";
		return undef;
	}
	
	system("chown -R loxberry:loxberry $updatedir");
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
	print STDERR "Changing owner of updatedir $updatedir returned errors. This may lead to further permission problems. Exiting.\n";
	return undef;
}

	
	if ($cgi->param('keepupdatefiles')) {
		print STDERR "keepupdatefiles is set - no files are copied.\n";
	}
	
	$updatedir = "$updatedir/$direntry";
	print STDERR "Real update directory $updatedir\n";
	
	if (-e "$updatedir/sbin/loxberryupdatecheck.pl" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/sbin/loxberryupdatecheck.pl", "$lbhomedir/sbin/loxberryupdatecheck.pl";
		if (! $?) {
			print STDERR "Error copying loxberryupdatecheck to $lbhomedir/sbin/loxberryupdatecheck.pl: $!\n";
			return undef;
		}
	}
	if (! -x "$lbhomedir/sbin/loxberryupdatecheck.pl") {
		chmod 0774, "$lbhomedir/sbin/loxberryupdatecheck.pl";
	}
	
	if (-e "$updatedir/sbin/loxberryupdate.pl" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/sbin/loxberryupdate.pl", "$lbhomedir/sbin/loxberryupdate.pl";
		if (! $?) {
			print STDERR "Error copying loxberryupdate to $lbhomedir/sbin/loxberryupdate.pl: $!\n";
			return undef;
		}
	}
	if (! -e "$lbhomedir/sbin/loxberryupdate.pl") {
		print STDERR "Cannot find part two of update, $lbhomedir/sbin/loxberryupdate.pl - Quitting.\n";
		return undef;
	}
		
	if (-e "$updatedir/config/system/update-exclude.system" && !$cgi->param('keepupdatefiles')) {
		copy "$updatedir/config/system/update-exclude.system", "$lbhomedir/config/system/update-exclude.system";
	}
	if (! -e "$lbhomedir/config/system/update-exclude.system") {
		print STDERR "Missing ignore list $lbhomedir/config/system/update-exclude.system - Quitting.\n";
		return undef;
	}
	if (! -x "$lbhomedir/sbin/loxberryupdate.pl") {
		chmod 0774, "$lbhomedir/sbin/loxberryupdate.pl";
	}
	if (! -x "$lbhomedir/sbin/loxberryupdate.pl") {
		print STDERR "Cannot set executable $lbhomedir/sbin/loxberryupdate.pl - Quitting.\n";
		exit(1);
	}
	
	print STDERR "Update checked and prepared successfully.\n";
	return $updatedir;
}

sub err
{
	if ($joutput{'error'}) {
		print STDERR "ERROR: " . $joutput{'error'} . "\n";
	} elsif ($joutput{'info'}) {
		print STDERR "INFO: " . $joutput{'info'} . "\n";
	}
}

#my $jsn = JSON->new->utf8()->pretty->encode(\%joutput);
#my $jsn = encode_json \%joutput;
#print $jsn;
#exit;
