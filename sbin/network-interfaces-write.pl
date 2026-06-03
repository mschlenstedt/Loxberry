#!/usr/bin/perl

# network-interfaces-write.pl
# Writes new content to /etc/network/interfaces as root.
# Handles symlink migration: if /etc/network/interfaces is a symlink to
# /opt/loxberry/system/network/interfaces, the symlink is removed and
# replaced with a real file before writing.
# New content is read from STDIN.
# Called via: sudo /opt/loxberry/sbin/network-interfaces-write.pl

use strict;
use warnings;

my $interfaces_file = '/etc/network/interfaces';

# Read new content from STDIN
local $/;
my $new_content = <STDIN>;

unless (defined $new_content && length($new_content) > 0) {
    print STDERR "network-interfaces-write.pl: No content received on STDIN\n";
    exit 1;
}

# Symlink migration: if /etc/network/interfaces is a symlink (regardless of target),
# remove it so the subsequent open() creates a real file instead of writing through it.
if (-l $interfaces_file) {
    unlink($interfaces_file)
        or do { print STDERR "Cannot remove symlink $interfaces_file: $!\n"; exit 1; };
}

# Write new content to /etc/network/interfaces
open(my $fh, '>', $interfaces_file)
    or do { print STDERR "Cannot write $interfaces_file: $!\n"; exit 1; };
print $fh $new_content;
close($fh);

# Set permissions: root:root 644
chown(0, 0, $interfaces_file);
chmod(0644, $interfaces_file);

print STDERR "OK\n";
exit 0;
