#!/usr/bin/perl
use version;
use LoxBerry::System;

$vers1 = "1.1";
$vers2 = "1.1.1";
print vers_tag($vers) . "\n";
print "$vers1 not a version\n" if (!version::is_strict(vers_tag($vers1)));
print "$vers1 is a version\n" if (version::is_strict(vers_tag($vers1)));
print "$vers1 is greater $vers2\n" if (version->parse(vers_tag($vers1)) > version->parse(vers_tag($vers2)) );
print "$vers2 is greater $vers1\n" if (version->parse(vers_tag($vers2)) > version->parse(vers_tag($vers1)) );

