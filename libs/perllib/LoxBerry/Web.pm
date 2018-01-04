# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
# no strict "refs"; # Currently header/footer template replacement regex needs this. Ideas?
use Config::Simple;
use CGI;
use LoxBerry::System;
use Carp;
use HTML::Template;
# use DateTime;
use Time::Piece;


# Potentially, this does something strange when using LoxBerry::Web without Webinterface (printing errors in HTML instead of plain text)
# See https://github.com/mschlenstedt/Loxberry/issues/312 and https://github.com/mschlenstedt/Loxberry/issues/287
use CGI::Carp qw(fatalsToBrowser set_message);
set_message('Depending of what you have done, report this error to the plugin developer or the LoxBerry-Core team.<br>Further information you may find in the error logs.');

package LoxBerry::Web;
our $VERSION = "0.3.3.1";
our $DEBUG;

use base 'Exporter';
our @EXPORT = qw (
		$lbpluginpage
		$lbsystempage
		get_plugin_icon
		%SL
		%L
		%htmltemplate_options
);


##################################################################
# This code is executed on every use
##################################################################

my $lang;
our $lbpluginpage = "/admin/system/index.cgi";
our $lbsystempage = "/admin/system/index.cgi?form=system";
our $notification_dir = $LoxBerry::System::lbsdatadir . "/notifications";
my @notifications;
my $notifications_error;
my $notifications_ok;

# Performance optimizations
our %htmltemplate_options = ( 
		'shared_cache' => 0,
		'file_cache' => 1,
		'file_cache_dir' => '/tmp/templatecache',
		# 'debug' => 1,
	);


# Finished everytime code execution
##################################################################


##################################################################
# Get LoxBerry URL parameter or System language
##################################################################
sub lblanguage 
{
	print STDERR "$0: LoxBerry::Web::lblanguage was moved to LoxBerry::System::lblanguage. The call was redirected, but you should update your program.\n";
	return LoxBerry::System::lblanguage();
}

#####################################################
# Page-Header-Sub
# Parameters:
# 	1. Page title (e.g. Plugin title)
# 	2. Help link
#	3. Help template file (without lang)
#	
#####################################################

sub lbheader 
{
	my ($pagetitle, $helpurl, $helptemplate) = @_;
	LoxBerry::Web::head($pagetitle);
	LoxBerry::Web::pagestart($pagetitle, $helpurl, $helptemplate);
}


#####################################################
# Page-Footer-Sub
#####################################################

sub lbfooter 
{
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	}

	
#####################################################
# head
#####################################################
sub head
{

	print STDERR "== head == prints html head including <body> start =================\n" if ($DEBUG);
	my $templatetext;
	my ($pagetitle) = @_;

	my $lang = LoxBerry::System::lblanguage();
	print STDERR "\nDetected language: $lang\n" if ($DEBUG);
	print STDERR "main::templatetitle: $main::template_title\n" if ($DEBUG);
	our $template_title = defined $pagetitle ? LoxBerry::System::lbfriendlyname() . " " . $pagetitle : LoxBerry::System::lbfriendlyname() . " " . $main::template_title;
	$template_title = LoxBerry::System::trim($template_title);
	if ($template_title eq "") {
		$template_title = "LoxBerry";
	}
	print STDERR "friendlyname: " . LoxBerry::System::lbfriendlyname() . "\n" if ($DEBUG);
	
	my $templatepath;
	my $headobj;
	
	$templatepath = $templatepath = "$LoxBerry::System::lbstemplatedir/head.html";
	if (! -e "$LoxBerry::System::lbstemplatedir/head.html") {
		confess ("ERROR: Missing head template $templatepath \n");
	}
	
	# Get the HTML::Template object for the header
	$headobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
		%htmltemplate_options,
	);
	
	LoxBerry::System::readlanguage($headobj, undef, 1);
	
	$headobj->param( TEMPLATETITLE => $template_title);
	$headobj->param( LANG => $lang);
	
	print "Content-Type: text/html\n\n";
	print $headobj->output();
	undef $headobj;
}

#####################################################
# pagestart
#####################################################
sub pagestart
{
	print STDERR "== pagestart == prints page including panels =================\n" if ($DEBUG);
	my $templatetext;
	
	my ($pagetitle, $helpurl, $helptemplate, $page) = @_;
	
	if (!$page) {
		$page = "main1";
	} 
	
	my $lang = LoxBerry::System::lblanguage();
	print STDERR "\nDetected language: $lang\n" if ($DEBUG);
	our $template_title = $pagetitle ? LoxBerry::System::lbfriendlyname() . " " . $pagetitle : LoxBerry::System::lbfriendlyname() . " " . $main::template_title;
	print STDERR "friendlyname: " . LoxBerry::System::lbfriendlyname() . "\n" if ($DEBUG);
	our $helplink = $helpurl ? $helpurl : $main::helplink;
	
	my $templatepath;
	my $ismultilang;
	our $helptext; 
	our %HelpPhrases;
	my $helpobj;
	my $headerobj;
	my $langfile;
	
	my $systemcall = LoxBerry::System::is_systemcall();
	
	# Help for plugin calls
	if (! defined $main::helptext and !$systemcall) {
		print STDERR "-- PLUGIN Help Template --\n" if ($DEBUG);
		if (-e "$LoxBerry::System::lbptemplatedir/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbptemplatedir/help/$helptemplate";
			$langfile = "$LoxBerry::System::lbptemplatedir/lang/$helptemplate";
			$ismultilang = 1;
		} elsif (-e "$LoxBerry::System::lbptemplatedir/$lang/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbptemplatedir/$lang/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbptemplatedir/en/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbptemplatedir/en/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbptemplatedir/de/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbptemplatedir/de/$helptemplate";
		}
	}
	
	# Help for system calls
	if (! defined $main::helptext and $systemcall) {
		print STDERR "-- SYSTEM Help Template --\n" if ($DEBUG);
		if (-e "$LoxBerry::System::lbstemplatedir/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/help/$helptemplate";
			$langfile = "$LoxBerry::System::lbstemplatedir/lang/$helptemplate";
			$ismultilang = 1;
		} elsif (-e "$LoxBerry::System::lbstemplatedir/$lang/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/$lang/help/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbstemplatedir/en/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/en/help/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbstemplatedir/de/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/de/help/$helptemplate";
		}
	}
	
	## This is a multi-lang template in HTML::Template ("Loxberry 0.3x mode")
	## 
	if ($ismultilang) {
				
		print STDERR "We are in MULTILANG help mode\n" if ($DEBUG);
		# Strip file extension
		$langfile =~ s/\.[^.]*$//;
		
		# Read English language as default
		# Missing phrases in foreign language will fall back to English
		my $lang_en = $langfile . "_en.ini";
		print STDERR "English language file: $lang_en\n" if ($DEBUG);
		
		Config::Simple->import_from($lang_en, \%HelpPhrases) or Carp::carp(Config::Simple->error());
		
		# Read foreign language if exists and not English
		$langfile = $langfile . "_" . $lang . ".ini";
		print STDERR "Foreign language file: $langfile\n" if ($DEBUG);
		
		# Now overwrite phrase variables with user language
		if ((-e $langfile) and ($lang ne 'en')) {
			Config::Simple->import_from($langfile, \%HelpPhrases) or Carp::carp(Config::Simple->error());
		}
		
		# Get another HTML::Template object for the help
		$helpobj = HTML::Template->new(
			filename => $templatepath,
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			%htmltemplate_options,
			);
		
		# Insert LangPhrases
		while (my ($name, $value) = each %HelpPhrases){
			$helpobj->param("$name" => $value);
		}
					
		$helptext = $helpobj->output();
		undef $helpobj;
		undef %HelpPhrases;
	} else
	{
	## This is the legacy help generation
		print STDERR "We are in LEGACY help mode\n" if ($DEBUG);
		print STDERR "templatepath: $templatepath\n" if ($DEBUG);
		if ($templatepath && $helptemplate ne '<!--$helptext-->') {
			if (open(F,"$templatepath")) {
				my @help = <F>;
				foreach (@help)
				{
					s/[\n\r]/ /g;
					$templatetext = $templatetext . $_;
				}
				close(F);
			} else {
			Carp::carp ("Help template $templatepath could not be opened - continuing without help.\n") if ($DEBUG);
			}
		} elsif ($helptemplate eq '<!--$helptext-->') {
			$templatetext = '<!--$helptext-->';
		} else {
			Carp::carp ("Help template \$templatepath is empty - continuing without help.\n") if ($DEBUG);
		}
		
		if (! $templatetext) {
			if ($lang eq 'de') {
				$templatetext = "Keine Hilfe verf&uumlgbar.";
			} else {
				$templatetext = "No further help available.";
			}
		}
		$helptext = $templatetext;
	}
	# Help is now in $helptext
	
	$templatepath = $templatepath = "$LoxBerry::System::lbstemplatedir/pagestart.html";
	if (! -e "$LoxBerry::System::lbstemplatedir/pagestart.html") {
		confess ("ERROR: Missing pagestart template " . $templatepath . "\n");
	}
	
	# System language is "hardcoded" to file language_*.ini
	my $langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
	
	# Get the HTML::Template object for the header
	$headerobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
		%htmltemplate_options,
	);
	
	LoxBerry::System::readlanguage($headerobj, undef, 1);
	
	print STDERR "template_title: $template_title\n" if ($DEBUG);
	print STDERR "helplink:       $helplink\n" if ($DEBUG);
	# print STDERR "helptext:       $helptext\n" if ($DEBUG);
	print STDERR "Home string: " . $LoxBerry::Web::SL{'HEADER.PANEL_HOME'} . "\n" if ($DEBUG);
	
	$headerobj->param( 	TEMPLATETITLE => $template_title, 
						HELPLINK => $helplink, 
						HELPTEXT => $helptext, 
						PAGE => $page,
						LANG => $lang );

	# If a navigation bar is defined
	if (%main::navbar) {
		# navbar is defined as HASH
		my $topnavbar = '<div data-role="navbar">' . 
			'	<ul>';
		my $topnavbar_haselements = undef;
		foreach my $element (sort keys %main::navbar) {
			my $btnactive;
			my $btntarget;
			my $notify;
			if ($main::navbar{$element}{active} eq 1) {
				$btnactive = ' class="ui-btn-active"';
			} else { $btnactive = undef; 
			}
			if ($main::navbar{$element}{target}) {
				$btntarget = ' target="' . $main::navbar{$element}{target} . '"';
			}
			
			if ($main::navbar{$element}{notifyRed}) {
				$notify = ' <span class="notifyRedNavBar">' . $main::navbar{$element}{notifyRed} . '</span>';
			} elsif ($main::navbar{$element}{notifyBlue}) {
				$notify = ' <span class="notifyBlueNavBar">' . $main::navbar{$element}{notifyBlue} . '</span>';
			}

			if ($main::navbar{$element}{Name}) {
				$topnavbar .= '		<li><a href="' . $main::navbar{$element}{URL} . '"' . $btntarget . $btnactive . '>' . $main::navbar{$element}{Name} . '</a>' . $notify . '</li>';
				$topnavbar_haselements = 1;
			}
		}
		$topnavbar .=  '	</ul>' .
			'</div>';	
		if ($topnavbar_haselements) {
			$headerobj->param ( TOPNAVBAR => $topnavbar);
		}
		%main::navbar = undef;
	} elsif ($main::navbar) {
		# navbar is defined as plain STRING
		$headerobj->param ( TOPNAVBAR => $main::navbar);
		$main::navbar = undef;
	} else {
		$headerobj->param ( TOPNAVBAR => "");
	}
	
	# <div data-role="navbar">
	# <ul>
		# <li><a href="#">First</a></li>
		# <li><a href="#">Second</a></li>
		# <li><a href="#">Third</a></li>
	# </ul>
	# </div>
				
	print $headerobj->output();
	undef $headerobj;
}


#####################################################
# pageend
#####################################################
sub pageend
{
	my $lang = LoxBerry::System::lblanguage();
	my $templatepath = "$LoxBerry::System::lbstemplatedir/pageend.html";
	my $pageendobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 0,
		loop_context_vars => 0,
		die_on_bad_params => 0,
		%htmltemplate_options,
	);
	my %SL = LoxBerry::System::readlanguage($pageendobj, undef, 1);
	
	$pageendobj->param( LANG => $lang);
	
	# Reboot required button
	if (-e "$LoxBerry::System::lbslogdir/reboot.required") {
		my $reboot_req_string='<a href="/admin/system/power.cgi"><span style="color:red; text-shadow: disabled;">' . $SL{'POWER.MSG_REBOOT_REQUIRED_SHORT'} . '</span></a>';
		$pageendobj->param( 'REBOOT_REQUIRED', $reboot_req_string );
	}
	print $pageendobj->output();
}

#####################################################
# foot
#####################################################
sub foot
{
	my $lang = LoxBerry::System::lblanguage();
	my $templatepath = "$LoxBerry::System::lbstemplatedir/foot.html";
	my $footobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 0,
		loop_context_vars => 0,
		die_on_bad_params => 0,
		%htmltemplate_options,
	);
	$footobj->param( LANG => $lang);
	print $footobj->output();
}

	
	
#####################################################
# readlanguage
# Moved to LoxBerry::System
#####################################################
sub readlanguage
{
	print STDERR "$0: LoxBerry::Web::readlanguage was moved to LoxBerry::System::readlanguage. The call was redirected, but you should update your program.\n";
	return LoxBerry::System::readlanguage(@_);
}

################################################################
# get_plugin_icon - Returns the Web path to the Plugin logo
# Input: Size as number in pixels
# Output: Absolute HTTP path to the Plugin icon (without server)
################################################################

sub get_plugin_icon
{
	my ($iconsize) = @_;
	$iconsize = defined $iconsize ? $iconsize : 64;
	if 		($iconsize > 256) { $iconsize = 512; }
	elsif	($iconsize > 128) { $iconsize = 256; }
	elsif	($iconsize > 64) { $iconsize = 128; }
	else					{ $iconsize = 64; }
	
	my $logopath = "$LoxBerry::System::lbshtmldir/images/icons/$LoxBerry::System::lbpplugindir/icon_$iconsize.png";
	my $logopath_web = "/system/images/icons/$LoxBerry::System::lbpplugindir/icon_$iconsize.png";
	
	if (-e $logopath) { 
		return $logopath_web;
	}
	return undef;
}

################################################################
# get_notifications
# Input: (optional) specific notification event filter
# Output: Hash with notifications
################################################################

sub read_notificationlist
{
	if (@notifications) {
		#print STDERR "Notification list cached.\n" if ($DEBUG);
		return;
	}
	opendir( my $DIR, $notification_dir );
	my @files = sort {$b cmp $a} readdir($DIR);
	my $direntry;
	my $notifycount;
	@notifications = ();
		
	while ( my $direntry = shift @files ) {
		next if $direntry eq '.' or $direntry eq '..' or $direntry eq '.dummy';
		print STDERR "Direntry: $direntry\n" if ($DEBUG);
		my $notstr = substr($direntry, 16, rindex($direntry, '.')-16);
		my ($package, $name, $severity) = split(/_/, $notstr);
		my $notdate = substr($direntry, 0, 15);
		# LOGDEB "Log type: $nottype  Date: $notdate";
		my $dateobj = parsedatestring($notdate);
		my %notification;
		$notifycount++;
		if (lc($severity) eq 'err') {
			$notifications_error++;
		} else {
			$notifications_ok++;
		}
		$notification{'PACKAGE'} = $package;
		$notification{'NAME'} = $name;
		$notification{'SEVERITY'} = lc($severity);
		$notification{'DATEOBJ'} = $dateobj;
		$notification{'DATESTR'} = $dateobj->strftime("%d.%m.%Y %H:%M");
		$notification{'FILENAME'} = $direntry;
		$notification{'FULLPATH'} = "$notification_dir/$direntry";
		push(@notifications, \%notification);
	}
	# return @notifications;
	closedir $DIR;
	print STDERR "Number of elements: " . scalar(@notifications) . "\n" if ($DEBUG);
}

sub get_notifications
{
	# print STDERR "get_notifications called.\n" if ($DEBUG);
	my ($package, $name, $latest, $count) = @_;
	LoxBerry::Web::read_notificationlist();
	if (! $package) {
		return @notifications if (! $count);
		return $notifications_error, $notifications_ok, ($notifications_error+$notifications_ok);
	}
	
	my @filtered = ();
	my $filtered_errors=0;
	my $filtered_ok=0;
	
	foreach my $notification (@notifications) {
		next if ($package ne $notification->{PACKAGE});
		next if ($name && $name ne $notification->{NAME});
		if ($notification->{'SEVERITY'} eq 'err') {
			$filtered_errors++;
		} else {
			$filtered_ok++;
		}
		push(@filtered, $notification);
		last if ($latest);
		# print STDERR "Notification datestring: " . $notification->{DATESTR} . "\n" if ($DEBUG);
	}
	print STDERR "get_notifications: \n" if ($DEBUG);
	print STDERR "Countings: $filtered_errors errors / $filtered_ok ok's\n" if ($DEBUG);
	return @filtered if (! $count);
	return $filtered_errors, $filtered_ok, ($filtered_errors+$filtered_ok);
}

sub get_notification_count
{
	my ($package, $name, $latest) = @_;
	my ($notification_error, $notification_ok, $notification_sum) = LoxBerry::Web::get_notifications($package, $name, $latest, 1);
	return $notification_error, $notification_ok, $notification_sum;

}

sub delete_notifications
{
	my ($package, $name, $ignorelatest) = @_;
	LoxBerry::Web::read_notificationlist();
	my $latestkept=0;
	
	foreach my $notification (@notifications) {
		next if ($package ne $notification->{PACKAGE});
		next if ($name && $name ne $notification->{NAME});
		if ($ignorelatest && $latestkept == 0) {
			$latestkept = 1;
		} else {
			unlink $notification->{FULLPATH};
		}
		# print STDERR "Notification datestring: " . $notification->{DATESTR} . "\n" if ($DEBUG);
	}
	undef @notifications;
}

#####################################################
# Parse yyyymmdd_hhmmss date to date object
#####################################################

sub parsedatestring 
{
	my ($datestring) = @_;
	
	my $dt = Time::Piece->strptime($datestring, "%Y%m%d_%H%M%S");
	
	# LOGDEB "parsedatestring: Calculated date/time: " . $dt->strftime("%d.%m.%Y %H:%M");
	return $dt;
}


#####################################################
# Finally 1; ########################################
#####################################################
1;
