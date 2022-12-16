use LoxBerry::System;
require LWP::UserAgent;
my $ua = LWP::UserAgent->new;
my $host;

# my $server_endpoint = "http://localhost:" . LoxBerry::System::lbwebserverport() . "/admin/system/ajax/ajax-storage-handler.cgi";
$host = "http://localhost:" . LoxBerry::System::lbwebserverport();
callrequest($host);
$host = "http://[::1]:" . LoxBerry::System::lbwebserverport();
callrequest($host);


sub callrequest 
{
	my $server_endpoint = shift;
	$server_endpoint .= "/admin/system/ajax/ajax-notification-handler.cgi";

	print "URL: " . $server_endpoint."\n";
	
	# set custom HTTP request header fields
	my $req = HTTP::Request->new(POST => $server_endpoint);
	$req->header('content-type' => 'application/x-www-form-urlencoded; charset=utf-8');
	 
	# add POST data to HTTP request body
	my $post_data;
	$post_data = "action=get_notification_count";

	$req->content($post_data);
	 
	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		print "HTTP " . $resp->code . " " . $resp->message . ": " . $message . "\n";
	}
	else {
		print "ERROR ". $resp->code . " " . $resp->message . "\n";
	}
}
