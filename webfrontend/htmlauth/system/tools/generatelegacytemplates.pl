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

use utf8;
use strict;
use warnings;
use LoxBerry::System;
use LoxBerry::Web;
use Getopt::Long qw(GetOptions);
use List::Util qw(max min); 
use File::Path qw(make_path rmtree);

my $force;

GetOptions('force' => \$force);

if ($force) {
	print STDERR "generatelegacytemplates.pl: Forcing creation of new templates.\n";
}

if (!$lbstemplatedir) { 
	print STDERR "generatelegacytemplates.pl: Cannot get \$lbstemplatedir. Exiting.\n";
	exit (1);
}

print STDERR "We are running as $ENV{USERNAME}.\n";

# We need to backup the reboot state because we do not want it in the template
my $reboot_required_file = $LoxBerry::System::reboot_required_file;
if (-e $reboot_required_file) {
	rename "$reboot_required_file", "$reboot_required_file.backup";
}

# Catch all language files to detect available languages
my @files = <$lbstemplatedir/lang/language_??.ini>;
foreach my $file (@files) {
	$file =~ s/\.[^.]*$//;
	my $langcode = substr($file, -2, 2);
	print STDERR "generatelegacytemplates.pl: Checking language $file\n";	

	# All LB 0.3 templates
	my @tmpl_filelist = (
			"$lbstemplatedir/head.html",
			"$lbstemplatedir/pagestart.html",
			"$lbstemplatedir/pageend.html",
			"$lbstemplatedir/foot.html",
			"$lbstemplatedir/success.html",
			"$lbstemplatedir/error.html",
			"$lbstemplatedir/lang/language_$langcode.ini"
	);

	# All legacy templates
	my @lang_filelist = (
			"$lbstemplatedir/$langcode/header.html",
			"$lbstemplatedir/$langcode/footer.html",
			"$lbstemplatedir/$langcode/success.html",
			"$lbstemplatedir/$langcode/error.html"
	);
	
	my $max_tmpl_epoch = 0;
	foreach my $tmpl (@tmpl_filelist) {
		open(my $tmpl_fh, "<", $tmpl) or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $tmpl. EXITING.\n"; 
			exit(1);};
		if ( defined ((stat($tmpl_fh))[9]) && ((stat($tmpl_fh))[9]) gt $max_tmpl_epoch ) {
			$max_tmpl_epoch = (stat($tmpl_fh))[9];
		}
		close $tmpl_fh;
	}
	
	my $min_tmpllang_epoch;
	foreach my $tmpllang (@lang_filelist) {
		open(my $tmpllang_fh, "<", $tmpllang) or 
		do { print STDERR "generatelegacytemplates.pl: Cannot open $tmpllang. File will be created.\n";
			 $min_tmpllang_epoch = 0;};
		if ( ! defined $min_tmpllang_epoch && defined ((stat($tmpllang_fh))[9]) ) {
			$min_tmpllang_epoch = (stat($tmpllang_fh))[9];
		} elsif ( ((stat($tmpllang_fh))[9]) < $min_tmpllang_epoch ) {
			$min_tmpllang_epoch = (stat($tmpllang_fh))[9];
		}
		close $tmpllang_fh;
	}

	# If nothing has changed, go to the next language
	if ($max_tmpl_epoch <= $min_tmpllang_epoch && !$force)
		{ print STDERR "generatelegacytemplates.pl: No need to process language $langcode.\n";
		  next;
	}
	
	print STDERR "generatelegacytemplates.pl: Language $file WILL BE RE-CREATED\n";	
	print STDERR "max_tmpl_epoch: $max_tmpl_epoch   min_tmpllang_epoch: $min_tmpllang_epoch\n";
	
	# Pre-set the language in LoxBerry:System
	$LoxBerry::System::lang = $langcode;
	
	# Delete language cache
	undef %LoxBerry::System::SL;
		
	my $output_header;
	my $output_footer;
	my $output_success;
	my $output_error;
	

	# Send STDOUT to variables
	
	# lbheader.html
	open TOOUTPUT, '>', \$output_header or die "generatelegacytemplates.pl: Can't open new handle TOUTPUT: $!";
	select TOOUTPUT;
	LoxBerry::Web::lbheader('<!--$template_title-->', '<!--$helplink-->', '<!--$helptext-->'); 
	select STDOUT;
	
	# lbfooter.html
	open TOOUTPUT, '>', \$output_footer or die "generatelegacytemplates.pl: Can't open new handle TOUTPUT: $!";
	select TOOUTPUT;
	LoxBerry::Web::lbfooter(); 
	select STDOUT;
	
	# error.html
	open TOOUTPUT, '>', \$output_error or die "generatelegacytemplates.pl: Can't open new handle TOUTPUT: $!";
	select TOOUTPUT;
	my $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/error.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				);
	$maintemplate->param( "ERROR", '<!--$error-->');
	readlanguage($maintemplate);
	# LoxBerry::Web::lbheader('<!--$template_title-->', '<!--$helplink-->', '<!--$helptext-->'); 
	print $maintemplate->output();
	# LoxBerry::Web::lbfooter();
	select STDOUT;
	undef $maintemplate;
	
	# success.html
	open TOOUTPUT, '>', \$output_success or die "generatelegacytemplates.pl: Can't open new handle TOUTPUT: $!";
	select TOOUTPUT;
	$maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/success.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				);
	$maintemplate->param( "MESSAGE", '<!--$message-->');
	$maintemplate->param( "NEXTURL", '<!--$nexturl-->');
	readlanguage($maintemplate);
	# LoxBerry::Web::lbheader('<!--$template_title-->', '<!--$helplink-->', '<!--$helptext-->'); 
	print $maintemplate->output();
	# LoxBerry::Web::lbfooter();
	select STDOUT;
	
	if ($output_header && $output_footer && $output_error && $output_success) {

		make_path("$lbstemplatedir/$langcode", { owner => "loxberry", group => "loxberry" });
		
		open(my $fh_lang_header, ">", "$lbstemplatedir/$langcode/header.html") or 
			do { print STDERR "generatelegacytemplates.pl: Cannot write $lbstemplatedir/$langcode/header.html. Skipping.\n"; 
				 next;
				};
		open(my $fh_lang_footer, ">", "$lbstemplatedir/$langcode/footer.html") or 
			do { print STDERR "generatelegacytemplates.pl: Cannot write $lbstemplatedir/$langcode/footer.html. Skipping.\n"; 
				next;
				};
		open(my $fh_lang_error, ">", "$lbstemplatedir/$langcode/error.html") or 
			do { print STDERR "generatelegacytemplates.pl: Cannot write $lbstemplatedir/$langcode/error.html. Skipping.\n"; 
				next;
				};
		open(my $fh_lang_success, ">", "$lbstemplatedir/$langcode/success.html") or 
			do { print STDERR "generatelegacytemplates.pl: Cannot write $lbstemplatedir/$langcode/success.html. Skipping.\n"; 
				next;
				};
		
		# This removes line 1 to 2 of the string to delete content-type: text/html 
		# as legacy plugins send that for their own
		$output_header =~ s/^(?:.*\n){1,2}//;
		$output_error =~ s/^(?:.*\n){1,2}//;
		$output_success =~ s/^(?:.*\n){1,2}//;
		
		
		# Writing new files
		print $fh_lang_header $output_header;
		print $fh_lang_footer $output_footer;
		print $fh_lang_error $output_error;
		print $fh_lang_success $output_success;
			
		close $fh_lang_header;
		close $fh_lang_footer;
		close $fh_lang_error;
		close $fh_lang_success;
		
	}
}

if (-e "$reboot_required_file.backup") {
	rename "$reboot_required_file.backup", "$reboot_required_file";
}

delete_directory ('/tmp/templatecache');



sub delete_directory
{
	my ($delfolder) = @_;
	
	if (-d $delfolder) {   
		rmtree($delfolder, {error => \my $err});
		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					# LOGERR "     Delete folder: general error: $message";
				} else {
					# LOGERR "     Delete folder: problem unlinking $file: $message";
				}
			}
		return undef;
		}
	}
	return 1;
}

