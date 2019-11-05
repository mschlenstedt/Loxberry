# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
use LoxBerry::System;
# use CGI;
use HTML::Template;
use Time::Piece;


# Potentially, this does something strange when using LoxBerry::Web without Webinterface (printing errors in HTML instead of plain text)
# See https://github.com/mschlenstedt/Loxberry/issues/312 and https://github.com/mschlenstedt/Loxberry/issues/287
use CGI::Carp qw(fatalsToBrowser set_message);
set_message('Depending of what you have done, report this error to the plugin developer or the LoxBerry-Core team.<br>Further information you may find in the error logs.');

package LoxBerry::Web;
our $VERSION = "2.0.0.1";
our $DEBUG;

use base 'Exporter';
our @EXPORT = qw (
		$lbpluginpage
		$lbsystempage
		get_plugin_icon
		%SL
		%L
		%htmltemplate_options
		mslist_select_html
		loglist_html
		
);


##################################################################
# This code is executed on every use
##################################################################

my $lang;
our $lbpluginpage = "/admin/system/index.cgi";
our $lbsystempage = "/admin/system/index.cgi?form=system";

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
	$headobj->param( HTMLHEAD => $main::htmlhead);
	
	print "Content-Type: text/html; charset=utf-8\n\n";
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
	
        # If not helptemplate, render website without LoxBerry menu and Help Slider
        my $nopanels = 0;
        if ( $helpurl eq "nopanels" ) {
                print STDERR "\nDetected nopanels-option. Sidepanels will not be rendered.\n" if ($DEBUG);
                $nopanels = 1;
        }

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
	
	#my $systemcall = LoxBerry::System::is_systemcall();
	my $systemcall = defined $LoxBerry::System::lbpplugindir ? undef : 1;
	
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
		
		$helptext = $templatetext;
	}
	# Help is now in $helptext
	
        if ( $nopanels ) {
                $templatepath = "$LoxBerry::System::lbstemplatedir/pagestart_nopanels.html";
                if (! -e "$LoxBerry::System::lbstemplatedir/pagestart_nopanels.html") {
                        confess ("ERROR: Missing pagestart template " . $templatepath . "\n");
                }
        } else {
                $templatepath = "$LoxBerry::System::lbstemplatedir/pagestart.html";
                if (! -e "$LoxBerry::System::lbstemplatedir/pagestart.html") {
                        confess ("ERROR: Missing pagestart template " . $templatepath . "\n");
                }
        }
	
	# System language is "hardcoded" to file language_*.ini
	$langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
	
	# Get the HTML::Template object for the header
	$headerobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
		%htmltemplate_options,
	);
	
	LoxBerry::System::readlanguage($headerobj, undef, 1);
	
	# If help is empty, read default text from language file
	if (! $helptext) {
		$helptext = $LoxBerry::System::SL{'COMMON.HELP_NOT_AVAILABLE'};
	}
	print STDERR "template_title: $template_title\n" if ($DEBUG);
	print STDERR "helplink:       $helplink\n" if ($DEBUG);
	# print STDERR "helptext:       $helptext\n" if ($DEBUG);
	print STDERR "Home string: " . $LoxBerry::System::SL{'HEADER.PANEL_HOME'} . "\n" if ($DEBUG);
	
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
		my $topnavbar_notify_js;
		
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

			# # NavBar Notify old
			# if ($main::navbar{$element}{notifyRed}) {
				# $notify = ' <span class="notifyRedNavBar">' . $main::navbar{$element}{notifyRed} . '</span>';
			# } elsif ($main::navbar{$element}{notifyBlue}) {
				# $notify = ' <span class="notifyBlueNavBar">' . $main::navbar{$element}{notifyBlue} . '</span>';
			# }

			
			$notify .= qq(<div class="notifyBlueNavBar" id="notifyBlueNavBar$element" style="display: none">0</div>);
			$notify .= qq(<div class="notifyRedNavBar" id="notifyRedNavBar$element" style="display: none">0</div>);
			
			
			if ($main::navbar{$element}{Name}) {
				$topnavbar .= qq( <li><div style="position:relative">$notify<a href="$main::navbar{$element}{URL}"$btntarget$btnactive>$main::navbar{$element}{Name}</a></div></li>);
				$topnavbar_haselements = 1;
				
				# Inject Notify JS code
				my $notifyname = $main::navbar{$element}{Notify_Name};
				my $notifypackage = $main::navbar{$element}{Notify_Package};
				if ($notifyname && ! $notifypackage && $LoxBerry::System::lbpplugindir) {
					$notifypackage = $LoxBerry::System::lbpplugindir;
				}
				if ($notifypackage) {
				$topnavbar_notify_js .=
<<"EOT";

\$.post( "/admin/system/tools/ajax-notification-handler.cgi", { action: 'get_notification_count', package: '$notifypackage', name: '$notifyname' })
	.done(function(data) { 
		console.log("get_notification_count executed successfully");
		console.log("$main::navbar{$element}{Name}", data[0], data[1], data[2]);
		if (data[0] != 0) \$("#notifyRedNavBar$element").text(data[2]).fadeIn('slow');
		else \$("#notifyRedNavBar$element").text('0').fadeOut('slow');
		if (data[1] != 0) \$("#notifyBlueNavBar$element").text(data[1]).fadeIn('slow');
		else \$("#notifyBlueNavBar$element").text('0').fadeOut('slow');
		
	});
EOT

				}				
				
			}
		}
		$topnavbar .=  '	</ul>' .
			'</div>';	
		if ($topnavbar_haselements) {
			$headerobj->param ( TOPNAVBAR => $topnavbar);
		}
		if ($topnavbar_notify_js) {
			my $notify_js;
			$notify_js = 
<<"EOT";

<SCRIPT>
\$(document).on('pageshow',function(){ updatenavbar(); });
function updatenavbar() {
	console.log("updatenavbar called");
	$topnavbar_notify_js
};
</SCRIPT>
EOT
			$headerobj->param ( NAVBARJS => $notify_js);
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
	
#	# Reboot required button
#	if (-e $LoxBerry::System::reboot_required_file) 
#	{
#		my $reboot_req_string='<div data-href="/admin/system/power.cgi" id="btnpower_alert" style="pointer-events: none; display:none; width:30px; height:30px; background-repeat: no-repeat; background-image: url(\'/system/images/reboot_required.svg\');"></div><script>$(document).ready( function(){ $("#btnpower").attr("title","'.$SL{'POWER.MSG_REBOOT_REQUIRED_SHORT'}.'");  $("#btnpower_alert").on("click", function(e){ var ele = e.target; window.location.replace(ele.getAttribute("data-href"));}); function reboot_on(){ var reboot_alert_offset = $("#btnpower").offset(); $("#btnpower_alert").css({"padding": "0px", "border": "0px", "z-index": 10000, "top": "4px" ,"left" : reboot_alert_offset.left + 4, "position":"absolute" }); $("#btnpower_alert").fadeTo( 2000 , 1.0, function() { setTimeout(function(){ reboot_off(); }, 2700); }); }; function reboot_off(){ var reboot_alert_offset = $("#btnpower").offset(); $("#btnpower_alert").css({"padding": "0px", "border": "0px", "z-index": 10000, "top": "4px" ,"left" : reboot_alert_offset.left + 4, "position":"absolute" }); $("#btnpower_alert").fadeTo( 2000 , 0.1, function() { setTimeout(function(){ reboot_on(); }, 100); });   }; reboot_on(); });</script>';
#		$pageendobj->param( 'REBOOT_REQUIRED', $reboot_req_string );
#	}
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
# get_languages
# Input: 
# 	1. 	Send 1, if only avaliable system languages (or otherwise undef)
#	2. 	'values' to get an array with all values
#		'labels' to request a hash with key langcode and value langname
# 		
# Output: Array or Hash
# Keep in mind, that hashes are unsorted at all time
# The array order represents the file order
################################################################

sub iso_languages
{
	my ($onlyavail, $selection) = @_;
	
	my $filename = "$LoxBerry::System::lbsconfigdir/languages.default";
	open my $handle, '<', $filename;
	chomp(my @lines = <$handle>);
	close $handle;

	opendir( my $DIR, "$LoxBerry::System::lbstemplatedir/lang/" ) or Carp::carp "Cannot open system language directory lbstemplatedir/lang";
	my @files = readdir($DIR);
	my @availlangs;
	while ( my $direntry = shift @files ) {
		my ($name, $ext) = split (/\./, $direntry);
		print STDERR "Name: $name\n";
		next if (!LoxBerry::System::begins_with($name, 'language_') or $ext ne 'ini');
		my $filelang = substr($name, 9, 2);
		print STDERR "Lang: $filelang\n";
		push (@availlangs, $filelang);
	}
	closedir $DIR;
		
	my @resultvals;
	my %resultlabels;
	
	for my $i (0 .. $#lines) {
		# Skip header line of CSV
		next if $i==0;
		my $cl = $lines[$i];
		if ($cl eq "") {
			# line is empty
			next;
		}
		
		my ($SK_Language, $ISO639_3Code, $ISO639_2BCode, $ISO639_2TCode, $ISO639_1Code, $LanguageName, $Scope, $Type, $MacroLanguageISO639_3Code, $MacroLanguageName, $IsChild) = split(/;/, $cl);
		
		if ( $onlyavail and !grep(/^$ISO639_1Code$/, @availlangs)) {
			next;
		}
		$resultlabels{$ISO639_1Code} = $LanguageName;
		push (@resultvals, $ISO639_1Code);
	}
	return @resultvals if ($selection eq 'values');
	return %resultlabels if ($selection eq 'labels');
}

sub logfile_button_html
{
	my %p = @_;
	my $datamini;
	my $dataicon;
	if(! $p{LABEL}) {
		my %SL = LoxBerry::System::readlanguage(undef, undef, 1);
		$p{LABEL} = $SL{'COMMON.BUTTON_LOGFILE'};
	}
	if ($p{NAME} and !$p{PACKAGE} and $LoxBerry::System::lbpplugindir) {
		$p{PACKAGE} = $LoxBerry::System::lbpplugindir;
	}
	
	if($p{DATA_MINI} eq "0" ) {
		$datamini = "false";
	} else {
		$datamini = "true";
	}
	
	if ($p{DATA_ICON}) {
		$dataicon = $p{DATA_ICON};
	} else {
		$dataicon = "action";
	}
	
	return "<a data-role=\"button\" href=\"/admin/system/tools/logfile.cgi?logfile=$p{LOGFILE}&package=$p{PACKAGE}&name=$p{NAME}&header=html&format=template\" target=\"_blank\" data-inline=\"true\" data-mini=\"$datamini\" data-icon=\"$dataicon\">$p{LABEL}</a>\n";

}

sub loglist_url
{
	my %p = @_;
	
	if (!$p{PACKAGE} and $LoxBerry::System::lbpplugindir) {
		$p{PACKAGE} = $LoxBerry::System::lbpplugindir;
	}
	
	return "/admin/system/logmanager.cgi?package=$p{PACKAGE}&name=$p{NAME}";
}

sub loglist_button_html
{
	my %p = @_;
	my $datamini;
	my $dataicon;
	if(! $p{LABEL}) {
		my %SL = LoxBerry::System::readlanguage(undef, undef, 1);
		$p{LABEL} = $SL{'COMMON.BUTTON_LOGFILE_LIST'};
	}
	if (!$p{PACKAGE} and $LoxBerry::System::lbpplugindir) {
		$p{PACKAGE} = $LoxBerry::System::lbpplugindir;
	}
	
	if($p{DATA_MINI} eq "0" ) {
		$datamini = "false";
	} else {
		$datamini = "true";
	}
	
	if ($p{DATA_ICON}) {
		$dataicon = $p{DATA_ICON};
	} else {
		$dataicon = "bars";
	}
	
	return "<a data-role=\"button\" href=\"/admin/system/logmanager.cgi?package=$p{PACKAGE}&name=$p{NAME}\" target=\"_blank\" data-inline=\"true\" data-mini=\"$datamini\" data-icon=\"$dataicon\">$p{LABEL}</a>\n";

}

sub mslist_select_html
{
	my %p = @_;
	
	my $datamini;
	my $selected;
	my $html;
	
	if($p{DATA_MINI} eq "0" ) {
		$datamini = "false";
	} else {
		$datamini = "true";
	}
	if (! $p{FORMID}) {
		$p{FORMID} = "select_miniserver";
	}
	
	my %miniservers;
	%miniservers = LoxBerry::System::get_miniservers();
	
	if (%miniservers and ! $miniservers{$p{SELECTED}}) {
		$p{SELECTED} = '1';
	}
	
	$miniservers{$p{SELECTED}}{_selected} = 'selected="selected"' if(%miniservers);
	
	if (! %miniservers) {
		$html = '<div class="ui-field-contain">';
		if($p{LABEL}) {
			$html .= '<label style="margin:auto;" for="'.$p{FORMID}.'">'.$p{LABEL}.'</label>';
		}	
		$html .= '<div id="'.$p{FORMID}.'" style="color:red;font-weight:bold;margin: auto;">No Miniservers defined</div>';
		$html .= '</div>';
		return $html;
	}
	
	$html = <<EOF;
	<div class="ui-field-contain">
EOF
	if ($p{LABEL}) {
		$html .= <<EOF;
	<label for="$p{FORMID}">$p{LABEL}</label>
EOF
	}
	
	$html .= <<EOF;
	<select name="$p{FORMID}" id="$p{FORMID}" data-mini="$datamini">
EOF

	foreach my $ms (sort keys %miniservers) {
		$html .= "\t\t\t<option value=\"$ms\" $miniservers{$ms}{_selected}>" . $miniservers{$ms}{Name} . " (" . $miniservers{$ms}{IPAddress} . ")</option>\n";
	}
	$html .= <<EOF;
	</select>
	</div>
EOF

	return $html;
}

sub loglevel_select_html
{

	my %p = @_;
	
	my $datamini;
	my $selected;
	my $html;
	
	my $pluginfolder = defined $p{PLUGIN} ? $p{PLUGIN} : $LoxBerry::System::lbpplugindir;
	# print "pluginfolder: $pluginfolder\n";
	my $plugin = LoxBerry::System::plugindata($pluginfolder);
	
	if(!$plugin) {
		Carp::carp "loglevel_select_html called, but could not determine plugin";
		return "";
	}
	if (!$plugin->{'PLUGINDB_LOGLEVELS_ENABLED'}) {
		Carp::carp "loglevel_select_html called, but CUSTOM_LOGLEVELS not enabled in plugin.cfg (plugin " . $pluginfolder . ")";
		return "";
	}
	
	my %SL = LoxBerry::System::readlanguage(undef, undef, 1);
		
	if($p{DATA_MINI} eq "0" ) {
		$datamini = "false";
	} else {
		$datamini = "true";
	}
	if (! $p{FORMID}) {
		$p{FORMID} = "select_loglevel";
	}

	$html = '<div data-role="fieldcontain">';
	
	if (defined $p{LABEL} and $p{LABEL} eq "") {
		
	} elsif ($p{LABEL} and $p{LABEL} ne "") {
		$html .= qq { <label for="$p{FORMID}" style="display:inline-block;">$p{LABEL}</label> };
	} else {
		$html .= qq { <label for="$p{FORMID}" style="display:inline-block;">$SL{'PLUGININSTALL.UI_LABEL_LOGGING_LEVEL'}</label> };
	}
	$html .= "<fieldset data-role='controlgroup' data-mini='$datamini' style='width:200px;'>";
	
	$html .= <<EOF;
	
	<select name="$p{FORMID}" id="$p{FORMID}" data-mini="$datamini">
		<option value="0">$SL{'PLUGININSTALL.UI_LOG_0_OFF'}</option>
		<option value="3">$SL{'PLUGININSTALL.UI_LOG_3_ERRORS'}</option>
		<option value="4">$SL{'PLUGININSTALL.UI_LOG_4_WARNING'}</option>
		<option value="6">$SL{'PLUGININSTALL.UI_LOG_6_INFO'}</option>
		<option value="7">$SL{'PLUGININSTALL.UI_LOG_7_DEBUG'}</option>
	</select>
	</fieldset>
	</div>
	
	<script>
	\$(document).ready( function()
	{
		if ( '$plugin->{PLUGINDB_LOGLEVEL}' == 1 )
		{
			\$('<option value="1">$SL{'PLUGININSTALL.UI_LOG_1_ALERT'}</option>').insertAfter(\$("#$p{FORMID} option[value=0]"));
		}
		else if ( '$plugin->{PLUGINDB_LOGLEVEL}' == 2 )
		{
			\$('<option value="2">$SL{'PLUGININSTALL.UI_LOG_2_FAILURES'}</option>').insertAfter(\$("#$p{FORMID} option[value=0]"));
		}
		else if ( '$plugin->{PLUGINDB_LOGLEVEL}' == 5 )
		{
			\$('<option value="5">$SL{'PLUGININSTALL.UI_LOG_5_OK'}</option>').insertAfter(\$("#$p{FORMID} option[value=4]"));
		}

		\$("#$p{FORMID}").val('$plugin->{PLUGINDB_LOGLEVEL}').change();
	});
		
	\$("#$p{FORMID}").change(function(){
		var val = \$(this).val();
		console.log("Loglevel", val);
		post_value('plugin-loglevel', '$plugin->{PLUGINDB_MD5_CHECKSUM}', val); 
	});
	
	function post_value (action, pluginmd5, value)
	{
	console.log("Action:", action, "Plugin-MD5:", pluginmd5, "Value:", value);
	\$.post ( '/admin/system/tools/ajax-config-handler.cgi', 
		{ 	action: action,
			value: value,
			pluginmd5: pluginmd5
		});
	}

	</script>
EOF
	
	return $html;

}


sub loglist_html
{
	my %p = @_;
	if (!$p{PACKAGE} and $LoxBerry::System::lbpplugindir) {
		$p{PACKAGE} = $LoxBerry::System::lbpplugindir;
	}
	require LWP::UserAgent;
	my $ua = new LWP::UserAgent;
	my $url = 'http://localhost:' . LoxBerry::System::lbwebserverport() . '/admin/system/logmanager.cgi?package=' . URI::Escape::uri_escape($p{PACKAGE}) . '&name=' . URI::Escape::uri_escape($p{NAME}) . '&header=none';
	print STDERR "loglist_html $p{PACKAGE} Url: $url\n" if ($DEBUG);
	my $response = $ua->get($url);
	if($response->is_error) {
		print STDERR "loglist_html: Error requesting loglist. Error HTTP $response->code $response->message Url: $url\n";
		return undef;
	}
	return $response->content;
}



#####################################################
# Finally 1; ########################################
#####################################################
1;
