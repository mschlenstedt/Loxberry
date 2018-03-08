#!/usr/bin/perl

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;

use warnings;
use strict;

$LoxBerry::Log::DEBUG = 1;

our $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
our $template_title = "Show all notifications";

# Version of this script
my $version = "1.0.0.1";






LoxBerry::Web::lbheader($template_title, $helplink);

my @notifications = get_notifications();

print "<h2>" . scalar(@notifications) . " notifications </h2>\n";
 
# Check if a specific attribute, set by notify_ext, is present:
print 	qq(<table style="width: 100%;">\n);

for my $notification (@notifications ) {

	print qq(	<tr>\n);
	print qq(		<td colspan="2">\n);
	print qq(			<h3>PACKAGE: $notification->{PACKAGE}  NAME: $notification->{NAME} SEVERITY: $notification->{SEVERITY}\n);
	print qq(				(ERROR)) if ($notification->{SEVERITY} == 3);
	print qq(				(INFO)) if ($notification->{SEVERITY} == 6);
	print qq(				(<i>UNDEFINED</i>)) if ($notification->{SEVERITY} != 6 && $notification->{SEVERITY} != 3);
	print qq(				<a href='#' class='notifdelete' id='notifdelete$notification->{KEY}' data-delid='$notification->{KEY}' data-role='button' data-icon='delete' data-iconpos='notext' data-inline='true' data-mini='true'>Dismiss</a>\n);
	print qq(			</h3>\n);
	print qq(		</td>\n); 
	print qq(	</tr>\n);
	 foreach my $key (sort(keys %$notification)) {
        next if ($key eq 'PACKAGE');
		next if ($key eq 'NAME');
		next if ($key eq 'SEVERITY');
		print qq(	<tr>\n);
		print qq(		<td>$key</td>\n);
		print qq(		<td>$notification->{$key} </td>\n);
		print qq(	</tr>\n);
    }
	
     
    # Attribute myownattribute is available
    # do stuff with it
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

