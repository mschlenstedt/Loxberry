#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use LoxBerry::System;

my $cgi = CGI->new;
my $filename = $cgi->path_info() // '';
$filename =~ s{^/+}{};

sub send_error
{
	my ($status, $message) = @_;
	print $cgi->header(
		-status => $status,
		-type => 'text/plain',
		-charset => 'UTF-8',
		-Cache_Control => 'no-store',
		-X_Content_Type_Options => 'nosniff',
	);
	print "$message\n";
	exit;
}

# PATH_INFO is deliberately restricted to one canonical Core user-theme file.
# No directory components, query-selected paths or symbolic links are accepted.
send_error('404 Not Found', 'Theme not found')
	if $filename !~ /\Atheme-user-[a-z0-9][a-z0-9_-]*\.css\z/;

my $theme_file = "$LoxBerry::System::lbsthemedir/$filename";
send_error('404 Not Found', 'Theme not found')
	if !-f $theme_file || -l $theme_file;

open(my $fh, '<:raw', $theme_file)
	or send_error('500 Internal Server Error', 'Could not read theme');

my @stat = stat($fh);
my $length = $stat[7] // 0;
my $modified = $stat[9] // 0;
my $etag = sprintf('"%x-%x"', $modified, $length);

print $cgi->header(
	-type => 'text/css',
	-charset => 'UTF-8',
	-Cache_Control => 'private, no-cache, max-age=0, must-revalidate',
	-ETag => $etag,
	-X_Content_Type_Options => 'nosniff',
	-Content_Length => $length,
);

binmode STDOUT, ':raw';
my $buffer;
while (read($fh, $buffer, 64 * 1024)) {
	print $buffer;
}
close($fh);

exit;
