#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use Sys::Filesystem;
use Unix::Lsof;
use Hash::Merge;

# Mountpoint list of "nodev" devices
my @nodev_mounts;
my %fullresult;


get_nodev_devices();
get_open_files();


# print "===============\n";
# foreach( @nodev_mounts ) 
# {
	# print $_ . "\n" if( $_ );
# }


sub get_nodev_devices
{

	my $fs = Sys::Filesystem->new();
	my @filesystems = $fs->filesystems( mounted => 1 );
	
	@nodev_mounts = undef;
	
	for (@filesystems)
	{
		next if ( !$_ ); 
		my @options = split(',', $fs->options($_) );
		next if !( grep( /^nodev$/, @options ) );
		
		# printf("%s Format %s device %s Options: %s\n",
			# $fs->mount_point($_),
			# $fs->type($_),
			# $fs->device($_),
			# $fs->options($_)
	   # );
		push @nodev_mounts, $fs->mount_point($_);
	}
 
	return @nodev_mounts;


}


sub get_open_files
{
	
	
	my %options;
	
	%fullresult = undef;
	
	my $merger = Hash::Merge->new('LEFT_PRECEDENT');
	
	foreach my $nodev ( @nodev_mounts )
	{
		next if (!$nodev);
		print "lsof: $nodev\n";
		my @lsof_arguments = ( $nodev );
		my ($res, $error) = lsof ( @lsof_arguments, \%options );
		%fullres = %{ $merger->merge( \%fullres, $res ) };
		use Data::Dumper;
		# print Dumper( $res );
		# print Dumper( \%fullres );
		print "Number of elements: " . scalar (keys %fullres) . "\n";
		
	}
	# print Dumper( \%fullres );
}
