#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Errno qw(EINTR);
use Fcntl qw(O_RDONLY O_NOFOLLOW S_IFMT S_IFREG);
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

# PATH_INFO is deliberately restricted to one canonical plugin-managed user-theme file.
# No directory components, query-selected paths or symbolic links are accepted.
send_error('404 Not Found', 'Theme not found')
	if $filename !~ /\Atheme-user-[a-z0-9][a-z0-9_-]*\.css\z/;

my $theme_file = "$LoxBerry::System::lbhomedir/data/plugins/cssframework/themes/$filename";
sysopen(my $fh, $theme_file, O_RDONLY | O_NOFOLLOW)
	or send_error('404 Not Found', 'Theme not found');
binmode($fh, ':raw');

my @stat = stat($fh);
send_error('500 Internal Server Error', 'Could not inspect theme') if !@stat;
send_error('404 Not Found', 'Theme not found')
	if (($stat[2] & S_IFMT) != S_IFREG);

my $length = $stat[7] // 0;
my $modified = $stat[9] // 0;
my $etag = sprintf('"%x-%x"', $modified, $length);

# If-None-Match uses weak comparison for GET requests. Accept both the exact
# validator and its W/ form, as well as the wildcard for an existing file.
my $if_none_match = $ENV{HTTP_IF_NONE_MATCH} // '';
my $etag_matches = 0;
foreach my $validator (split /,/, $if_none_match) {
	$validator =~ s/^\s+|\s+$//g;
	$validator =~ s/^W\/\s*//i;
	if ($validator eq '*' || $validator eq $etag) {
		$etag_matches = 1;
		last;
	}
}

if ($etag_matches) {
	print $cgi->header(
		-status => '304 Not Modified',
		-Cache_Control => 'private, no-cache, max-age=0, must-revalidate',
		-ETag => $etag,
		-X_Content_Type_Options => 'nosniff',
	);
	close($fh);
	exit;
}

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
while (1) {
	my $bytes_read = read($fh, $buffer, 64 * 1024);
	if (!defined $bytes_read) {
		next if $! == EINTR;
		print STDERR "theme-file.cgi: Error while reading $filename: $!\n";
		last;
	}
	last if $bytes_read == 0;
	if (!print STDOUT $buffer) {
		print STDERR "theme-file.cgi: Error while sending $filename: $!\n";
		last;
	}
}
close($fh);

exit;
