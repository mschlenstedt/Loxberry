#!/usr/bin/perl

# network-interfaces-write.pl
# Writes new content directly to /etc/network/interfaces as root.
# New content is read from STDIN.
# Called via: sudo /opt/loxberry/sbin/network-interfaces-write.pl
#
# /etc/network/interfaces is a regular file (Debian default). The old LoxBerry
# layout (symlink /etc/network/interfaces -> /opt/loxberry/system/network/interfaces)
# is removed by update_v4.0.0.4.pl.

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

# Backup existing file before overwriting
if (-e $interfaces_file) {
    system("cp '$interfaces_file' '${interfaces_file}.bak'") == 0
        or print STDERR "Warning: could not create backup ${interfaces_file}.bak\n";
}

# Write new content
open(my $fh, '>', $interfaces_file)
    or do { print STDERR "Cannot write $interfaces_file: $!\n"; exit 1; };
print $fh $new_content;
close($fh);

# Set permissions: root:root 644
chown(0, 0, $interfaces_file);
chmod(0644, $interfaces_file);

print STDERR "OK\n";
exit 0;
