#!/usr/bin/perl

require LWP::UserAgent;
require XML::Simple;
require Encode;

my $xmlresp = '<?xml version="1.0" encoding="utf-8"?><LL control="dev/sps/io/LMS 9d:aa:a9:d3:7c:c3 artist/Tina Turner & David Bowie" value="100" Code="500"/>';

	# eval {
		# $xmlresp = XML::Simple::XMLin(Encode::encode_utf8($xmlresp));
		
		# print STDERR "Loxone Response: Code " . $xmlresp->{Code} . " Value " . $xmlresp->{value} . "\n" if ($DEBUG);
		# # return ($xmlresp->{Code}, $xmlresp->{value});
		
	# };
	# if ($@) {
		# print STDERR "mshttp_call ERROR: $@\nMiniserver Response: " . $xmlresp . "\n";
		# return (undef, 500, $xmlresp);
	# }
	
$xmlresp =~ /control\=\"(.*?)\"/;
$control = $1;
$xmlresp =~ /value\=\"(.*?)\"/;
$value=$1;
$xmlresp =~ /Code\=\"(.*?)\"/;
$code=$1;


print "Control '$control'\nValue '$value'\nCode '$code'\nFull Responxe: $xmlresp\n";