#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Cwd qw(abs_path);
use Errno qw(EINTR);
use Fcntl qw(O_RDONLY O_NOFOLLOW S_IFMT S_IFREG);
use File::Basename qw(dirname);
use POSIX qw(strftime);
use LoxBerry::System;

my $cgi = CGI->new;

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

sub mime_type
{
	my ($file) = @_;
	return 'text/css'       if $file =~ /\.css\z/i;
	return 'image/png'      if $file =~ /\.png\z/i;
	return 'image/jpeg'     if $file =~ /\.jpe?g\z/i;
	return 'image/gif'      if $file =~ /\.gif\z/i;
	return 'image/webp'     if $file =~ /\.webp\z/i;
	return 'image/svg+xml'  if $file =~ /\.svg\z/i;
	return 'image/x-icon'   if $file =~ /\.ico\z/i;
	return 'font/woff'      if $file =~ /\.woff\z/i;
	return 'font/woff2'     if $file =~ /\.woff2\z/i;
	return 'font/ttf'       if $file =~ /\.ttf\z/i;
	return 'font/otf'       if $file =~ /\.otf\z/i;
	return '';
}

sub allowed_file
{
	my ($file) = @_;
	return 0 if !defined $file || $file eq '';
	return 0 if $file =~ /\0/;
	return 0 if $file =~ m{\A/};
	return 0 if $file =~ /\\/;
	return 0 if $file =~ m{//};
	return 0 if $file !~ /\A[A-Za-z0-9_.\/-]+\z/;
	return 0 if $file =~ m{(?:\A|/)\.};

	# User-theme CSS remains the canonical Core entry point.
	return 1 if $file =~ /\Atheme-user-[a-z0-9][a-z0-9_-]*\.css\z/;

	# Plugin-managed theme assets are intentionally read-only from Core.
	# Only browser-safe image/font asset types are exposed; scripts, HTML,
	# JSON, arbitrary CSS and executable files are never served from assets/.
	return 1 if $file =~ m{\Aassets/[A-Za-z0-9_.\/-]+\.(?:png|jpe?g|gif|webp|svg|ico|woff2?|ttf|otf)\z}i;

	return 0;
}

# Prefer the explicit file parameter for generated CSS asset URLs. PATH_INFO
# remains the canonical form for THEME_URL, e.g.
#   /admin/system/theme-file.cgi/theme-user-example.css
# Supporting ?file=... also keeps already generated Studio themes working:
# their historical relative asset URL can resolve to
# /admin/system/theme-file.cgi/theme-file.cgi?file=assets/... and the query
# parameter still identifies the canonical asset safely.
my $file = $cgi->param('file');
if (!defined $file || $file eq '') {
	$file = $cgi->path_info() // '';
	$file =~ s{^/+}{};
}
$file = '' if !defined $file;
$file =~ s/^\s+|\s+$//g;

send_error('404 Not Found', 'Theme file not found') if !allowed_file($file);

my $theme_dir = "$LoxBerry::System::lbhomedir/data/plugins/cssframework/themes";
my $root_abs = abs_path($theme_dir);
send_error('404 Not Found', 'Theme data folder not found') if !$root_abs || !-d $root_abs;

my $path = "$theme_dir/$file";
my $parent = dirname($path);
my $parent_abs = abs_path($parent);
send_error('404 Not Found', 'Theme file not found') if !$parent_abs;
send_error('403 Forbidden', 'Forbidden')
	if $parent_abs ne $root_abs && index($parent_abs, "$root_abs/") != 0;

# Reject symbolic links in every path component below the trusted theme root.
# O_NOFOLLOW below additionally protects the final file itself.
my $cursor = $theme_dir;
my @parts = split m{/}, $file;
pop @parts;
foreach my $part (@parts) {
	$cursor .= "/$part";
	send_error('404 Not Found', 'Theme file not found') if -l $cursor || !-d $cursor;
}

sysopen(my $fh, $path, O_RDONLY | O_NOFOLLOW)
	or send_error('404 Not Found', 'Theme file not found');
binmode($fh, ':raw');

my @stat = stat($fh);
send_error('500 Internal Server Error', 'Could not inspect theme file') if !@stat;
send_error('404 Not Found', 'Theme file not found')
	if (($stat[2] & S_IFMT) != S_IFREG);

my $mime = mime_type($file);
send_error('404 Not Found', 'Theme file not found') if $mime eq '';

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

my $is_css = ($file =~ /\.css\z/i) ? 1 : 0;
my $cache_control = $is_css
	? 'private, no-cache, max-age=0, must-revalidate'
	: 'private, max-age=300, must-revalidate';

if ($etag_matches) {
	print $cgi->header(
		-status => '304 Not Modified',
		-Cache_Control => $cache_control,
		-ETag => $etag,
		-X_Content_Type_Options => 'nosniff',
	);
	close($fh);
	exit;
}

my %header = (
	-type => $mime,
	-Cache_Control => $cache_control,
	-ETag => $etag,
	-Last_Modified => strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime($modified)),
	-X_Content_Type_Options => 'nosniff',
	-Content_Length => $length,
);
$header{-charset} = 'UTF-8' if $is_css || $mime eq 'image/svg+xml';
print $cgi->header(%header);

binmode STDOUT, ':raw';
my $buffer;
while (1) {
	my $bytes_read = read($fh, $buffer, 64 * 1024);
	if (!defined $bytes_read) {
		next if $! == EINTR;
		print STDERR "theme-file.cgi: Error while reading $file: $!\n";
		last;
	}
	last if $bytes_read == 0;
	if (!print STDOUT $buffer) {
		print STDERR "theme-file.cgi: Error while sending $file: $!\n";
		last;
	}
}
close($fh);

exit;
