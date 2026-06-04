#!/usr/bin/perl
# Get notifications in html format 
use HTML::Template;
use LoxBerry::Log;
use CGI qw/:standard/;
my $num_args = $#ARGV + 1;
my $package;
my $nname;
if ( param("package") ne "" )
{
	print "Content-Type: text/html\n\n";
    $package = param("package");
    $nname   = param("name");
}
elsif ( $ARGV[0] ne "" )
{
	$package = $ARGV[0];
    $nname   = $ARGV[1];
}
else
{
	print "Content-Type: text/plain\n\nInvalid request.";
	exit 1;
}
print LoxBerry::Log::get_notifications_html( $package , $nname );
exit;
