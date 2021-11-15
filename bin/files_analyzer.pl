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
		%fullresult = %{ $merger->merge( \%fullresult, $res ) };
		use Data::Dumper;
		# print Dumper( $res );
		# print Dumper( \%fullres );
		print "Number of elements: " . scalar (keys %fullresult) . "\n";
		
	}
	print Dumper( \%fullresult );
}

sub get_large_files
{
	use File::Find::Rule;
		
	# #!/usr/local/bin/perl -w

	# ($#ARGV == 0) or die "Usage: $0 [directory]\n"; 

	# use File::Find;
		
	# find(sub {$size{$File::Find::name} = -s if -f;}, @ARGV);
	# @sorted = sort {$size{$b} <=> $size{$a}} keys %size;
		
	# splice @sorted, 20 if @sorted > 20;
		
	# foreach (@sorted) 
	# {
		# printf "%10d %s\n", $size{$_}, $_;
	# }	
	
	
}