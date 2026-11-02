package LoxBerry::PluginDownload;

use strict;
use warnings;
use Exporter 'import';
use IPC::Open3;
use Symbol qw(gensym);

our @EXPORT_OK = qw(download_plugin_archive);
our $VERSION = '1.01';

my %curl_errors = (
	1 => 'The URL uses a protocol that this curl installation does not support. Check the download URL.',
	3 => 'The download URL is malformed. Check that the complete archive URL was entered correctly.',
	5 => 'The proxy hostname could not be resolved. Check the proxy and DNS settings.',
	6 => 'The server hostname could not be resolved. Check the URL, DNS settings and network connection.',
	7 => 'Could not connect to the server or proxy. Check network connectivity, firewall rules and server availability.',
	18 => 'The transfer ended before the expected amount of data was received. The archive is incomplete. Retry and check the connection and server.',
	22 => 'The server returned an HTTP error (for example 403, 404 or 500). Check the original curl message, archive URL, access permissions and server availability.',
	23 => 'curl cannot write the downloaded data to the destination file. Possible causes: no free disk space, write access denied, a read-only filesystem, a storage device defect, an unstable power supply or an MMC/driver problem. Please investigate the cause!',
	26 => 'curl could not read local input data. Check local file access and storage health.',
	27 => 'curl could not allocate enough memory. Check available RAM and other running processes.',
	28 => 'The connection or transfer timed out, or the transfer stayed below the minimum download speed. Check the network connection and server, then retry.',
	35 => 'The TLS handshake failed. Check the server, proxy and supported TLS versions.',
	47 => 'The server returned too many redirects. Check the URL and server redirect configuration.',
	52 => 'The server closed the connection without sending a response. Check the server or proxy and retry.',
	55 => 'Sending network data failed. Check the network connection and proxy, then retry.',
	56 => 'Receiving network data failed. Check the network connection, proxy and server, then retry.',
	60 => 'The server certificate could not be verified. Check the system clock and trusted CA certificates; do not disable certificate verification as a workaround.',
	63 => 'The download exceeded the configured maximum file size. Check the archive size and download limits.',
	77 => 'curl could not read the CA certificate file. Check the CA certificate installation and file permissions.',
	92 => 'An HTTP/2 stream error interrupted the download. Check the server or proxy and retry.',
);

sub download_plugin_archive {
	my ($curl, $url, $destination) = @_;
	my $partial = "$destination.part";
	my $output = gensym;
	my ($input, $pid);
	my $error;

	# Capture diagnostics, not the archive, and never pass the URL through a shell.
	eval {
		$pid = open3($input, $output, $output,
			$curl, '-q', '-fsSLk',
			'--connect-timeout', '20', '--max-time', '1800',
			'--speed-limit', '1024', '--speed-time', '60',
			'--retry', '2', '-o', $partial, '--', $url);
		1;
	} or $error = "Could not start curl: $@";

	if (defined $pid) {
		close $input;
		my $diagnostics = do { local $/; <$output> };
		close $output;
		my $waited = waitpid($pid, 0);
		my $status = $?;
		if ($waited == -1) {
			$error = "Could not wait for curl: $!";
		} elsif ($status != 0) {
			$error = ($status & 127)
				? "curl terminated by signal " . ($status & 127)
				: "curl exited with code " . ($status >> 8);
			$error .= ": $diagnostics" if defined $diagnostics && length $diagnostics;
			if (!($status & 127) && exists $curl_errors{$status >> 8}) {
				$error =~ s/\s+\z//;
				$error .= ". " . $curl_errors{$status >> 8};
			}
		} elsif (!-s $partial) {
			$error = "Downloaded archive is empty or missing";
		} elsif (!rename($partial, $destination)) {
			$error = "Could not rename downloaded archive: $!";
		}
	}

	if (defined $error) {
		if (-e $partial && !unlink($partial)) {
			$error .= "; could not remove partial archive: $!";
		}
		return (0, $error);
	}
	return (1, undef);
}

1;

=head1 NAME

LoxBerry::PluginDownload - shared archive download for plugin installs and updates

=head1 DESCRIPTION

download_plugin_archive($curl, $url, $destination) returns (success, error).
Archives are streamed to a .part file and renamed only after curl succeeds.
Each attempt allows 30 minutes, with a 20-second connection timeout and a
60-second low-speed timeout below 1 KiB/s. Transient failures are retried twice.
TLS verification remains disabled for compatibility with existing downloads.
Callers must log errors and must not start installation after a failed download.
Common curl exit codes include an English explanation and troubleshooting hints
alongside the original diagnostic. These hints describe possible causes, not a
confirmed diagnosis. Unknown exit codes retain their original diagnostic.

=head1 TESTING

Run C<prove libs/perllib/LoxBerry/testing/plugin_download.t> for download,
CGI error handling and status handoff regressions. Set
C<LB_DOWNLOAD_SLOW_TEST=1> to include a 100 MiB transfer taking over 60 seconds.
Run C<node libs/perllib/LoxBerry/testing/plugin_download_status.js> for the
web interface status regressions (no npm dependencies required).

=cut
