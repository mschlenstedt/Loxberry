#!/usr/bin/perl
# Get notifications in html format 
# Quick and dirty
use lib '../../../libs/perllib/';
use LoxBerry::Web;
use LoxBerry::Log;
use CGI qw/:standard/;
my $num_args = $#ARGV + 1;
my $package;

if ( param("package") ne "" )
{
	print "Content-Type: text/html\n\n";
    my $package = param("package");
}
elsif ( $ARGV[0] ne "" )
{
	my $package=$ARGV[0];
}
else
{
	print "Content-Type: text/plain\n\nInvalid request.";
	exit 1;
}
print LoxBerry::Log::get_notifications_html("$package","");
exit;
