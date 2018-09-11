#!/usr/bin/perl

use warnings;
use strict;
use LoxBerry::TimeMes;
use LoxBerry::System;

mes "Self implemented";

my %lang;
my $count = 50;

for(my $x=0; $x<$count; $x++) {

	readlanguage2();

} 
mes "End";
mesout;

mes "LoxBerry System readlanguage";

my %SL = ();
for(my $x=0; $x<$count; $x++) {

	#undef %LoxBerry::System::SL;
	%SL = LoxBerry::System::readlanguage(undef, undef, 1);

}

print "Something from readlanguage (with hyphens) : $SL{'NETWORK_CHANGEHOSTNAME.INTRODUCTION'}\n";
print "Something from readlanguage2 (with hyphens): $lang{'NETWORK_CHANGEHOSTNAME.INTRODUCTION'}\n";

print "Something from readlanguage (fallback) : $SL{'COMMON.BUTTON_EXIT'}\n";
print "Something from readlanguage2 (fallback): $lang{'COMMON.BUTTON_EXIT'}\n";


mes "End";
mesout;




sub readlanguage2 
{
	
	if (%lang) { return %lang; }
	
	my $content_en = read_file('/opt/loxberry/templates/system/lang/language_en.ini');
	my $content_de = read_file('/opt/loxberry/templates/system/lang/language_de.ini');

	parse_lang_file($content_en);
	parse_lang_file($content_de);

}


sub parse_lang_file
{
	my ($content) = @_;
	my @cont = split(/\n/, $content);

	my $section = 'default';

	foreach my $line (@cont) {
		# Trim
		$line =~ s/^\s+|\s+$//g;	
		my $firstletter = substr($line, 0, 1);
		# print "Firstletter: $firstletter\n";
		# Comments
		if($firstletter eq '' or $firstletter eq '#' or $firstletter eq '/' or $firstletter eq ';') {
			next;}
		# Sections
		if ($firstletter eq '[') {
			my $closebracket = index($line, ']', 1);
			if($closebracket == -1) {
				next;
			}
			$section = substr($line, 1, $closebracket-1);
			# print "\n[$section]\n";
			next;
		}
		# Define variables
		my ($param, $value) = split(/=/, $line, 2);
		$param =~ s/^\s+|\s+$//g;	
		next if ($lang{"$section.$param"});
		$value =~ s/^\s+|\s+$//g;
		my $firsthyphen=substr($value, 0, 1);
		my $lasthyphen=substr($value, -1, 1);
		if ($firsthyphen eq '"' and $lasthyphen eq '"') {
			$value = substr($value, 1, -1);
		}
		# print "$param=$value\n";
		$lang{"$section.$param"} = $value;
	}
}

sub read_file
{
	my ($filename) = @_;
	local $/=undef;
	open FILE, $filename or return undef;
	my $string = <FILE>;
	close FILE;
	return $string;
}

