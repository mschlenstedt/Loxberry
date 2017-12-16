#!/usr/bin/perl
use LoxBerry::System;
use strict;
use warnings;
use experimental 'smartmatch';
use CGI;
use JSON;
use File::Path;
use File::Copy qw(copy);
use LWP::UserAgent;
require HTTP::Request;

my $release_url;
my $oformat;
my %joutput;
my $download_path = '/tmp';
# Command line options

my $cgi = CGI->new;
# $cgi->import_names('R');

if (!$cgi->param) {
	$joutput{'error'} = "No parameters sent.";
	&err;
	exit (1);
}
#######################################################
# Parameters
#	querytype
#		release
#		prerelease
#		testing (= latest commit of a branch)  not implemented
#
#	update
#		(key exists) Do an update
#		(not existing) Notify only
#
# 	output
#		(not existing) STDERR
#		json Return json with version and vers info
#
########################################################

	
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

my ($lbmajor, $lbminor, $lbbuild, $lbdev) = split_version(LoxBerry::System::lbversion());

if ($lbmajor eq "" || $lbminor eq "" || $lbbuild eq "") {
	$joutput{'error'} = "Cannot aquire current version. Exiting.";
	&err;
	exit(1);
}

my @filter_major = (0);
my @filter_minor = (3, 4);
my @filter_build = ();


if ($querytype eq 'release' or $querytype eq 'prerelease') {
	my ($major, $minor, $build, $dev, $release_url, $release_name, $release_body) = check_releases($querytype, $lbmajor, $lbminor, $lbbuild, $lbdev);
	if (! defined $release_url || $release_url eq "") {
		$joutput{'info'} = "No new version found.";
		&err;
		exit 0;
	}

	$joutput{'info'} = "New version found.";
	$joutput{'release_version'} = { vers_tag => "$major.$minor.$build", 
							vers_major => $major,
							vers_minor => $minor,
							vers_build => $build
							};
	$joutput{'release_zipurl'} = $release_url;
	$joutput{'release_name'} = $release_name;
	$joutput{'release_body'} = $release_body;
	
	if ($cgi->param('update')) {
		my $download_file = "$download_path/loxberry.$major.$minor.$build";
		$download_file = "$download_file-$dev" if (defined $dev);
		$download_file = "$download_file.zip";
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
			exec("perl $lbhomedir/sbin/loxberryupdate.pl updatedir=$updatedir");
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
# Check Releases List and return url 
##################################################
sub check_releases
{

	my ($querytype, $currmajor, $currminor, $currbuild, $currdev) = @_;
	my $endpoint = 'https://api.github.com';
	my $resource = '/repos/mschlenstedt/Loxberry/releases';
	#my $resource = '/repos/christianTF/LoxBerry-Plugin-SamplePlugin-V2-PHP/releases';

	my $major;
	my $minor;
	my $build;
	my $dev;

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

	print STDERR "Current LoxBerry Version: " . LoxBerry::System::lbversion() . "\n";
	foreach my $release ( @$releases ) {
		($major, $minor, $build, $dev) = undef;
		($major, $minor, $build, $dev) = split_version($release->{tag_name});
		print STDERR "RELEASE VERSION: $major.$minor.$build-$dev\n";
		#print STDERR "TAG_NAME: " . $release->{tag_name} . " || ";
		#print STDERR $release->{prerelease} eq 1 ? "This is a pre-release" : "This is a RELEASE";
		#print STDERR "\n";
		if (@filter_major and not $major ~~ @filter_major) {
			print STDERR "MAJOR filter not matched.\n";
			next;
		}
		if (@filter_minor and not $minor ~~ @filter_minor) {
			print STDERR "MINOR filter not matched.\n";
			next;
		}
		# if (@filter_build) { print STDERR "FILTER BUILD IS DEFINED\n"; }
		if (@filter_build and not $build ~~ @filter_build) {
			print STDERR "BUILD filter not matched.\n";
			next;
		}
		print STDERR "Filter check passed - continuing\n";
		
		# Check against current version
		print STDERR "Comparing versions:\n";
		print STDERR "  Current Version: $currmajor.$currminor.$currbuild-$currdev\n";
		print STDERR "  Release Version: $major.$minor.$build-$dev\n";
		if ($major == $currmajor && $minor == $currminor && $build == $currbuild && $dev eq $currdev) {
			# Skip the equal version
			next;
		}
		# Now skip every older version
		if ($major < $currmajor) 
			{ next; }
		if ($minor < $currminor)
			{ next; }
		if ($build < $currbuild)
			{ next; }
		
		# At this point we now that the version is newer
		print STDERR "This release is newer than current installation.";				
		if ($querytype eq 'release' and ($release->{prerelease} eq 1))
			{ print STDERR "Skipping pre-release\n";
			  next;
		}
		print STDERR "--> Version MATCH: $major.$minor.$build matches " . $release->{tag_name} . "\n";
		#print STDERR "URL: $release->{zipball_url})";
		return ($major, $minor, $build, $dev, $release->{zipball_url}, $release->{name}, $release->{body});
	}
	#print STDERR "TAG_NAME: " . $releases->[1]->{tag_name} . "\n";
	#print STDERR $releases->[1]->{prerelease} eq 1 ? "This is a pre-release" : "This is a RELEASE";

}


sub split_version 
{
	my ($fversion) = @_;
	if (!$fversion) {
		return undef;
	}
	
	# If first letter is a 'V', remove it
	my $firstletter = substr($fversion, 0, 1);
	if ($firstletter eq 'v' || $firstletter eq 'V') {
		$fversion = substr($fversion, 1);
	}
	my ($version, $dev) = split(/-/, $fversion);
	$dev = "" if (!$dev);
	my ($maj, $min, $build) = split(/\./, $version);
	
	if (defined $maj && defined $min && defined $build) {
		return ($maj, $min, $build, $dev);
	}
	return undef;
	
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
		print STDERR "Filesize does not match\n" &&
		return undef;
	}
	# print STDERR "Download saved successfully in $filename\n";
	return $filename;


# $link = 'http://www.domain.com/anyfile.zip';
# $header = GetFileSize($link);

# print "File size: " . $header->content_length . " bytes\n";
# print "Last moified: " . localtime($header->last_modified) . "\n";
# exit;



}

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
	my $exit_value  = $? >> 8;
	my $signal_num  = $? & 127;
	my $dumped_core = $? & 128;

	if ($exit_value > 0) {
		print STDERR unziperror($exit_value) . "\n";
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
	
	$updatedir = "$updatedir/$direntry";
	print STDERR "Real update directory $updatedir\n";
	
	if (-e "$updatedir/sbin/loxberryupdate.pl") {
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
		
	if (-e "$updatedir/config/system/update_exclude.system") {
		copy "$updatedir/config/system/update_exclude.system", "$lbhomedir/config/system/update_exclude.system";
	}
	if (! -e "$lbhomedir/config/system/update_exclude.system") {
		print STDERR "Missing ignore list $lbhomedir/config/system/update_exclude.system - Quitting.\n";
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
