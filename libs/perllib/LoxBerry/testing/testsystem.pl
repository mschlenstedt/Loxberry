#!/usr/bin/perl

use LoxBerry::System;

print "Current Time        : " . currtime() . "\n";
print "Current Time (File) : " . currtime('file') . "\n";
print "Current Time (ISO)  : " . currtime('iso') . "\n";
