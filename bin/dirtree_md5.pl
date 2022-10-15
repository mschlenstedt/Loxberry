#!/usr/bin/perl

# Creates an md5 hash of an directory tree

# Version of this script
my $version = "2.0.2.1";

use warnings;
use strict;
use LoxBerry::System;
use File::Find::Rule;
use Getopt::Long;
use Digest::MD5;

my $basepath = ".";
my $filename;
my $comparemd5;
my $verbose;

GetOptions (
	"path=s"   => \$basepath,      # string
	"file=s"	=> \$filename,
    "verbose"  => \$verbose,
	"compare=s"	=> \$comparemd5,
);

print STDERR "Script Version: $version\n" if $verbose;

my @files;
my @files_sorted;
my @hashes;

if ( $filename ) {
	
	print STDERR "file parameter: $filename\n" if $verbose;
	if ( ! -e $filename ) {
		print STDERR "File $filename not found\n";
		exit(2);
	}
	
	push @files_sorted, $filename;

} else {
	print STDERR "path parameter: $basepath\n" if $verbose;

	@files = File::Find::Rule->file()
	#			->name( '*' )
	#			->size( ">=$size" . "M" )
	#			->nonempty
					->in($basepath);
					
	print STDERR "Found " . scalar(@files) . " files\n" if $verbose;
	@files_sorted = sort @files;
	
	# print STDERR "Files (sorted):\n";
	# print STDERR join("\n", @files_sorted) if $verbose;
	# print STDERR "\n" if $verbose;

}

my $x = 0;

foreach( @files_sorted ) {
	my $data = LoxBerry::System::read_file($_);
	my $digest = Digest::MD5::md5_hex($data);
	print STDERR $_ . " - " . $digest . "\n" if ($verbose);
	push @hashes, $digest;
}

my $treemd5 = Digest::MD5::md5_hex(join '', @hashes);
print "$treemd5\n";

$comparemd5 = trim($comparemd5);
if( $comparemd5 ) {
	if( $treemd5 eq $comparemd5 ) {
		print STDERR "EQUAL: Checked $treemd5 is equal to $comparemd5\n";
		exit(0);
	} else {
		print STDERR "INVALID: Checked $treemd5 is NOT equal to $comparemd5\n";
		exit(1);
	}
}
