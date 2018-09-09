#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Log;
use File::Find;
use List::Util;
use CGI;
use JSON;

my $scriptversion = "1.2.0.1";

my %keycount;
my @keys;
my $resulttype;
my $loglevel;

my $cgi = CGI->new;
$cgi->import_names('R');

if($R::loglevel) {
	$loglevel = $R::loglevel;
} else {
	$loglevel = 7;
}

# Skip files with that file extensions
my @excludefileext = ("log", "txt", "dummy", "tmp", "jpg", "png", "ico", "psd", "svg", "js", "css", "map", "gif", "zip", "7z", "sass", "ini", "dat", "cfg", "deb");

my $log = LoxBerry::Log->new (
        package => 'translate', 
        name => 'languagecheck',
        loglevel => $loglevel,
        #filename => "$lbslogdir/mylogfile.log",
        #append => 1,
		#stderr => 1,
		stdout => 1,
		nofile => 1,
);

LOGSTART "Language Key Check";



if ($R::resulttype && lc($R::resulttype) eq "used") {
	$resulttype = "used";
} elsif ($R::resulttype && lc($R::resulttype) eq "unused") {
	$resulttype = "unused";
} else {
	$resulttype = "all";
}



if ($R::plugin) {
	# Set plugin directories
	my $lbpplugindir = $R::plugin;
	@directories = (
		"$lbhomedir/webfrontend/htmlauth/plugins/$lbpplugindir",
		"$lbhomedir/webfrontend/html/plugins/$lbpplugindir",
		"$lbhomedir/templates/plugins/$lbpplugindir",
	#	"$lbhomedir/data/plugins/$lbpplugindir",
	#	"$lbhomedir/log/plugins/$lbpplugindir",
	# 	"$lbhomedir/config/plugins/$lbpplugindir",
		"$lbhomedir/sbin/plugins/$lbpplugindir",
		"$lbhomedir/bin/plugins/$lbpplugindir",
		$lbhomedir . "/system/daemons/plugins/$lbpplugindir",
	);

} else {
	# Set system directories
	@directories = (
		$lbshtmldir,
		$lbshtmlauthdir,
		$lbstemplatedir,
		$lbsdatadir,
		$lbsconfigdir,
		$lbssbindir,
		$lbsbindir,
		$lbhomedir . "/libs",
		$lbhomedir . "/system/cron",
		$lbhomedir . "/system/daemons/system",
	);
}




$LoxBerry::System::lang = "en";
readlang();

find (\&processfile, @directories);

# Summary
LOGOK "SUMMARY OF Translation Keys";
LOGOK "===========================";

foreach my $key (sort keys %keycount) {
	if ( $keycount{"$key"} > 0 && ($resulttype eq "used" || $resulttype eq "all") ) {
		LOGOK "$key: $keycount{$key} times used.";
	} elsif ($keycount{"$key"} == 0 && ($resulttype eq "unused" || $resulttype eq "all")){
		LOGWARN "$key: NEVER used.";
	}
}
exit;

sub readlang
{
	# Read System Language
	%L = LoxBerry::System::readlanguage(undef, undef, 1);
	@keys = sort keys %L;

	# Plugins have multiple language files
	# System also has help lang files
	# This needs to be considered for the reverse lookup of keys (keys in file available in language?)
	
	if ($log->loglevel == 7) {
		LOGDEB "Dumping all language keys";
		foreach my $key (@keys) {
			LOGDEB "   Key $key";
		}
	}
}

sub processfile
{

	my $filename = $_;
	my $fullname = $File::Find::name;
	
	# Skipping exluded file extensions
	my ($name, $ext) = $filename =~ /(.*)\.(.*)/;
	if ($ext && List::Util::any { /$ext/ } @excludefileext) {
		LOGDEB "Skipping $filename, file extension in excludelist";
		return 0;
	}

	LOGINF "Processing $fullname";
	
	# Reading full file
	open(my $fh, $fullname) or 
	do {
		LOGERR "Can't read file $fullname: [$!]";
		return;
	};
	local $/;
	my $document = <$fh>; 
	close ($fh);  
	# print $document;
	
	# Start the search
	foreach my $key (@keys) {
		# LOGDEB "   Test $key...";
		my $count;
		$count = () = $document =~ /$key/gi;
		# if ($filename eq "finish.html") {
			# LOGDEB "$key found $count times.";
		# }
		#LOGDEB "Count $count";
		$keycount{"$key"} = ($keycount{"$key"} + $count);
		#LOGDEB "File $filename: Found $key for $keycount[$key] times";
		
	}
}