#!/usr/bin/perl
use LoxBerry::System;


print "hr           : " . currtime() . "\n";
print "hrtime       : " . currtime('hrtime') . "\n";
print "hrtimehires  : " . currtime('hrtimehires') . "\n";
print "file         : " . currtime('file') . "\n";
print "filehires    : " . currtime('filehires') . "\n";
print "iso          : " . currtime('iso') . "\n";

