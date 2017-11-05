#!/usr/bin/perl
use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use Scalar::Util qw(looks_like_number);
use Switch;
# use AptPkg::Config;

print header;

my $action = param('action');
my $value = param('value');

print STDERR "Action: $action // Value: $value\n";

switch ($action) {
	case 'secupdates' 	{ &secupdates; }
	else 				{ print "<red>Action not supported.</red>"; }
}


################################
# unattended-upgrades setting
################################
sub secupdates
{
	print STDERR "SECUPDATES\n";
	print STDERR "Value is: $value\n";
	
	if (!looks_like_number($value) && $value ne 'query') 
		{ print "<red>Value not supported.</red>"; 
		  return();}
	
	my $aptfile = "/etc/apt/apt.conf.d/02periodic";
	open(FILE, $aptfile) || die "File not found";
	my @lines = <FILE>;
	close(FILE);

	my $querystring;
	my $queryresult;
	
	my @newlines;
	foreach(@lines) {
		if (begins_with($_, "APT::Periodic::Unattended-Upgrade"))
			{   # print STDERR "############ FOUND #############";
				if ($value eq 'query') {
					my ($querystring, $queryresult) = split / /;
					print STDERR "### QUERY result: " . $queryresult . "\n";
					$queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g;
					print "option-secupdates-" . $queryresult;
				} else {
					$_ = "APT::Periodic::Unattended-Upgrade \"$value\";\n"; }
			}
		if (begins_with($_, "APT::Periodic::Update-Package-Lists") && $value ne 'query')
			{   # print STDERR "############ FOUND #############";
				$_ = "APT::Periodic::Update-Package-Lists \"$value\";\n";
			}
		
		
		
		
		push(@newlines,$_);
	}

	if ($value ne 'query') {
		open(FILE, '>', $aptfile) || die "File not found";
		print FILE @newlines;
		close(FILE);
	}
	
}

###################################################################
# Returns a value if string2 is the at the beginning of string 1
###################################################################

sub begins_with
{	
		
    return substr($_[0], 0, length($_[1])) eq $_[1];
}		
			
