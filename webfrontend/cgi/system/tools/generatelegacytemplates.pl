#!/usr/bin/perl

# Copyright 2017 for LoxBerry www.loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use LoxBerry::System;
use LoxBerry::Web;
use Getopt::Long qw(GetOptions);
use List::Util 'max'; 

my $force;

GetOptions('force' => \$force);

if ($force) {
	print STDERR "generatelegacytemplates.pl: Forcing creation of new templates.\n";
}

if (!$lbstemplatedir) { 
	print STDERR "generatelegacytemplates.pl: Cannot get \$lbstemplatedir. Exiting.\n";
	exit (1);
}

# Catch all language files to detect available languages
my @files = <$lbstemplatedir/lang/language_??.ini>;
foreach my $file (@files) {
	$file =~ s/\.[^.]*$//;
	my $langcode = substr($file, -2, 2);
	print STDERR "generatelegacytemplates.pl: Processing language $file\n";	

	## Checking timestamps, getting all file handles
	# If language files do not exist, they will be created later.
	open(my $fh_lang_header, "<:encoding(UTF-8)", "$lbstemplatedir/$langcode/header.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $lbstemplatedir/$langcode/header.html. File will be created.\n"; };
	open(my $fh_lang_footer, "<:encoding(UTF-8)", "$lbstemplatedir/$langcode/footer.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $lbstemplatedir/$langcode/footer.html. File will be created.\n"; };
	
	# If template files do not exist, we quit with error.
	open(my $fh_tmpl_head, "<:encoding(UTF-8)", "$lbstemplatedir/head.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $lbstemplatedir/head.html. EXITING.\n"; 
			exit(1);};
	open(my $fh_tmpl_pagestart, "<:encoding(UTF-8)", "$lbstemplatedir/pagestart.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $lbstemplatedir/pagestart.html. EXITING.\n"; 
			exit(1);};
	open(my $fh_tmpl_pageend, "<:encoding(UTF-8)", "$lbstemplatedir/pageend.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $lbstemplatedir/pageend.html. EXITING.\n"; 
			exit(1);};
	open(my $fh_tmpl_foot, "<:encoding(UTF-8)", "$lbstemplatedir/foot.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $lbstemplatedir/foot.html. EXITING.\n"; 
			exit(1);};
	open(my $fh_tmpl_lang, "<:encoding(UTF-8)", "$lbstemplatedir/lang/language_$langcode.ini") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $lbstemplatedir/lang/language_$langcode.ini. EXITING.\n"; 
			exit(1);};
	
	my $newest_epoch_lang = max( (stat($fh_lang_header))[9], (stat($fh_lang_footer))[9] );
	my $newest_epoch_tmpl = max ( (stat($fh_tmpl_head))[9], (stat($fh_tmpl_pagestart))[9], (stat($fh_tmpl_pageend))[9], (stat($fh_tmpl_foot))[9], (stat($fh_tmpl_lang))[9] );
	
	close $fh_lang_header;
	close $fh_lang_footer;
	
	
	# If nothing has changed, go to the next language
	if ($newest_epoch_tmpl <= $newest_epoch_lang && !$force)
		{ print STDERR "generatelegacytemplates.pl: No need to process language $langcode.\n";
		  next;
	}
	
	# Pre-set the language in LoxBerry:Web
	$LoxBerry::Web::lang = $langcode;
	
	my $output_header;
	my $output_footer;

	# Send STDOUT to variables
	open TOOUTPUT, '>', \$output_header or die "generatelegacytemplates.pl: Can't open new handle TOUTPUT: $!";
	select TOOUTPUT;
	LoxBerry::Web::lbheader('<!--$template_title-->', '<!--$helplink-->', '<!--$helptext-->'); 
	select STDOUT;
	
	open TOOUTPUT, '>', \$output_footer or die "generatelegacytemplates.pl: Can't open new handle TOUTPUT: $!";
	select TOOUTPUT;
	LoxBerry::Web::lbfooter(); 
	select STDOUT;
	
	if ($output_header && $output_footer) {
	open(my $fh_lang_header, ">:encoding(UTF-8)", "$lbstemplatedir/$langcode/header.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot write $lbstemplatedir/$langcode/header.html. Skipping.\n"; 
			 next;
			};
	open(my $fh_lang_footer, ">:encoding(UTF-8)", "$lbstemplatedir/$langcode/footer.html") or 
		do { print STDERR "generatelegacytemplates.pl: Cannot write $lbstemplatedir/$langcode/footer.html. Skipping.\n"; 
			next;
			};
	
	# This removes line 1 to 2 of the string to delete content-type: text/html 
	# as legacy plugins send that for their own
	$output_header =~ s/^(?:.*\n){1,2}//;
	
	
	# Writing new files
	print $fh_lang_header $output_header;
	print $fh_lang_footer $output_footer;
	close $fh_lang_header;
	close $fh_lang_footer;
	}
}

