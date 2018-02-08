#!/usr/bin/perl

use LoxBerry::System;

print "Current Time        : " . currtime() . "\n";
print "Current Time (File) : " . currtime('file') . "\n";
print "Current Time (ISO)  : " . currtime('iso') . "\n";

print "\nDiskspaceinfo with path\n";
my %folderinfo = LoxBerry::System::diskspaceinfo('/opt/loxberry/config/system');

print "Mountpoint: $folderinfo{filesystem} | $folderinfo{size} | $folderinfo{used} | $folderinfo{available} | $folderinfo{usedpercent} | $folderinfo{mountpoint}\n";

print "\nDiskspaceinfo without path (full list)\n";
my %disks = LoxBerry::System::diskspaceinfo();

foreach my $disk (keys %disks) {
	print "Mountpoint: $disks{$disk}{filesystem} | $disks{$disk}{size} | $disks{$disk}{used} | $disks{$disk}{available} | $disks{$disk}{usedpercent} | $disks{$disk}{mountpoint}\n";
}