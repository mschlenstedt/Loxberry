#!/usr/bin/perl
use LoxBerry::System;

#my ($exitcode) = execute( "npm install primevue@^3.9.1 --save" );
#if ($exitcode ne 0) {
#	print "Could not execute npm install primevue@^3.9.1 --save: $exitcode\n";
#	exit 1;
#}
#
#my ($exitcode) = execute( "mv node_modules/primevue ." );
#if ($exitcode ne 0) {
#	print "Could not move primevue folder: $exitcode\n";
#	exit 1;
#}
#
#my ($exitcode) = execute( "rm -r node_modules package-lock.json" );
#if ($exitcode ne 0) {
#	print "Could not remove temp folders: $exitcode\n";
#	exit 1;
#}

my ($exitcode, $output) = execute( "find primevue \\( -name \"*.min.js\" -not -name \"*.cjs.min.js\" -not -name \"*.esm.min.js\" \\)" );
if ($exitcode ne 0) {
	print "Could not find js-files: $exitcode\n";
	exit 1;
}

my @files = split(/\n/, $output);

foreach ( @files ) {
	print "<script src=\"/system/scripts/vue3/$_\"></script>\n";
}

exit;

