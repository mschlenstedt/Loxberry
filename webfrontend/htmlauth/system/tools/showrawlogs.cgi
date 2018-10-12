#!/usr/bin/perl

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use DBI;

use warnings;
use strict;

$LoxBerry::Log::DEBUG = 1;

our $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
our $template_title = "Show raw logs";

# Version of this script
my $version = "1.2.5.1";

LoxBerry::Web::lbheader($template_title, $helplink);

my $dbh = LoxBerry::Log::log_db_init_database();

my ($logs_count) = $dbh->selectrow_array("SELECT COUNT(*) FROM logs;");
my ($logs_attr_count) = $dbh->selectrow_array("SELECT COUNT(*) FROM logs_attr;");
my $db_filesize = LoxBerry::System::bytes_humanreadable(-s $dbh->sqlite_db_filename());
my @logs = LoxBerry::Log::get_logs(undef, undef, 'nofilter');




print "<h2>" . scalar(@logs) . " logs (table 'logs': $logs_count entries, table 'logs_attr': $logs_attr_count entries, filesize: $db_filesize)</h2>\n";
 
print 	qq(<table style="width: 100%;">\n);

for my $log (@logs ) {

	print qq(	<tr>\n);
	print qq(		<td colspan="2">\n);
	print qq(			<h3>PACKAGE: $log->{PACKAGE}  NAME: $log->{NAME} STATUS: $log->{STATUS} ($LoxBerry::Log::severitylist{$log->{STATUS}}) <br>);
	print qq( FILENAME: $log->{FILENAME}\n);
	print qq(			</h3>\n);
	print qq(		</td>\n); 
	print qq(	</tr>\n);
	 foreach my $key (sort(keys %$log)) {
        next if ($key eq 'PACKAGE');
		next if ($key eq 'NAME');
		next if ($key eq 'FILENAME');
		next if ($key eq 'STATUS');
		print qq(	<tr>\n);
		print qq(		<td>$key</td>\n);
		print qq(		<td>$log->{$key} </td>\n);
		print qq(	</tr>\n);
    }
}
print qq(</table>);
print <<"EOT";

<style>
table, tr, td {
border: 0.5px solid lightgray; border-collapse: collapse; padding:5px; vertical-align: top;
}
</style>

<script>
	\$(".notifdelete").click(function() {
		var delid = \$(this).attr('data-delid');
		var delid_encoded = delid.replace(".", "\\.");
		console.log("Delete key", delid);
		\$.post ( '/admin/system/tools/ajax-notification-handler.cgi', 
					{ 	action: 'notify-deletekey',
						value: delid,
					});
		location.reload();
						
	});
</script>

EOT



LoxBerry::Web::lbfooter();

