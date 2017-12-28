#!/usr/bin/perl


use LWP::UserAgent;
require HTTP::Request;

my $endpoint = 'https://api.github.com';
my $resource = '/repos/mschlenstedt/Loxberry/releases';

my $ua = LWP::UserAgent->new;
my $request = HTTP::Request->new(GET => $endpoint . $resource);
$request->header('Accept' => 'application/vnd.github.v3+json');
$response = $ua->request($request);


print "Success: " if ($response->is_success);
print "Error  : " if ($response->is_error);
print $response->code . " " . $response->message . "\n";