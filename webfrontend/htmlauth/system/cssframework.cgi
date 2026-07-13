#!/usr/bin/perl

# LoxBerry CSS Framework Preview/Help renderer
# Shared Core/Plugin renderer for templates/system/themes/.
# Supports ?page=preview|help.
# System/Core renderer always uses the currently active LoxBerry theme from general.json.
# Plugin/Studio renderer additionally accepts ?theme=theme-* for Live Preview handoff.

use strict;
use warnings;
use CGI;
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::System::General;
use Cwd qw(abs_path);

my $cgi = CGI->new;

my $page = lc($cgi->param('page') || 'preview');
if ($page ne 'preview' && $page ne 'help') {
	$page = 'preview';
}

##########################################################################
# Language settings
##########################################################################

if ($R::lang) {
	# Optional LoxBerry language override. lblanguage() returns this value.
	$LoxBerry::Web::lang = substr($R::lang, 0, 2);
}

my $lang = lblanguage();

my $template_file = "$lbstemplatedir/themes/$page/index_$lang.html";

# Fallback to English if no template exists for the active LoxBerry language.
if (! -e $template_file) {
	$template_file = "$lbstemplatedir/themes/$page/index_en.html";
}


##########################################################################
# _cssframework_candidate_html_dirs()
#
# Builds an ordered list of possible public LoxBerry HTML roots.
# Duplicate and empty paths are removed while preserving priority.
#
# Parameters:
#   none
#
# Returns:
#   List of candidate absolute directory paths.
##########################################################################
sub _cssframework_candidate_html_dirs {
	my @dirs;

	# LoxBerry's stable installation root. This is the most reliable base for
	# system files, because cssframework.cgi itself is in htmlauth while themes
	# live in the public html tree.
	push @dirs, "$lbhomedir/webfrontend/html" if defined $lbhomedir && $lbhomedir ne '';

	# Runtime fallback: derive ../html from the current htmlauth document root.
	if ($ENV{DOCUMENT_ROOT}) {
		my $docroot = $ENV{DOCUMENT_ROOT};
		$docroot =~ s#/+$##;
		my $htmlroot = $docroot;
		$htmlroot =~ s#/htmlauth$#/html#;
		push @dirs, $htmlroot if $htmlroot ne $docroot;
	}

	# Runtime fallback: derive ../html from the CGI script path.
	my $script = eval { abs_path($0) } || $0 || '';
	if ($script ne '') {
		my $htmlroot = $script;
		$htmlroot =~ s#/webfrontend/htmlauth/.*$#/webfrontend/html#;
		push @dirs, $htmlroot if $htmlroot ne $script;
	}

	# Last-resort common LoxBerry path.
	push @dirs, '/opt/loxberry/webfrontend/html';

	my @unique;
	my %seen;
	foreach my $dir (@dirs) {
		next if !defined $dir || $dir eq '';
		next if $seen{$dir}++;
		push @unique, $dir;
	}

	return @unique;
}

##########################################################################
# _cssframework_find_first_dir(@relative_paths)
#
# Searches all candidate public HTML roots for the first existing directory
# matching one of the supplied relative paths.
#
# Parameters:
#   @relative_paths  Relative paths below the public HTML root.
#
# Returns:
#   Absolute directory path, or an empty string if none exists.
##########################################################################
sub _cssframework_find_first_dir {
	my (@relative_paths) = @_;

	foreach my $htmlroot (_cssframework_candidate_html_dirs()) {
		foreach my $rel (@relative_paths) {
			my $dir = "$htmlroot/$rel";
			return $dir if -d $dir;
		}
	}

	return '';
}

##########################################################################
# _cssframework_candidate_data_theme_dirs()
#
# Builds an ordered, de-duplicated list of possible plugin theme data
# directories used by the CSS Framework.
#
# Parameters:
#   none
#
# Returns:
#   List of candidate absolute directory paths.
##########################################################################
sub _cssframework_candidate_data_theme_dirs {
	my @dirs;

	push @dirs, "$lbhomedir/data/plugins/cssframework/themes" if defined $lbhomedir && $lbhomedir ne '';
	push @dirs, "$ENV{LBHOMEDIR}/data/plugins/cssframework/themes" if $ENV{LBHOMEDIR};
	push @dirs, '/opt/loxberry/data/plugins/cssframework/themes';

	my @unique;
	my %seen;
	foreach my $dir (@dirs) {
		next if !defined $dir || $dir eq '';
		next if $seen{$dir}++;
		push @unique, $dir;
	}

	return @unique;
}

##########################################################################
# _cssframework_find_first_data_theme_dir()
#
# Returns the first existing CSS Framework plugin theme data directory.
#
# Parameters:
#   none
#
# Returns:
#   Absolute directory path, or an empty string if none exists.
##########################################################################
sub _cssframework_find_first_data_theme_dir {
	foreach my $dir (_cssframework_candidate_data_theme_dirs()) {
		return $dir if -d $dir;
	}

	return '';
}

##########################################################################
# _cssframework_escape_html($value)
#
# Escapes a scalar for safe insertion into HTML text or attribute values.
#
# Parameters:
#   $value  Value to escape; undef is treated as an empty string.
#
# Returns:
#   HTML-escaped string.
##########################################################################
sub _cssframework_escape_html {
	my ($value) = @_;
	$value = '' if !defined $value;
	$value =~ s/&/&amp;/g;
	$value =~ s/</&lt;/g;
	$value =~ s/>/&gt;/g;
	$value =~ s/"/&quot;/g;
	return $value;
}


##########################################################################
# _cssframework_normalize_theme_class($theme)
#
# Sanitizes a theme identifier and converts it to the canonical CSS class
# form beginning with "theme-". The legacy "classic" name is mapped to
# "classic-lb".
#
# Parameters:
#   $theme  Theme identifier or CSS class.
#
# Returns:
#   Normalized theme class, or an empty string for invalid input.
##########################################################################
sub _cssframework_normalize_theme_class {
	my ($theme) = @_;
	$theme = '' if !defined $theme;
	$theme = lc($theme);
	$theme =~ s/^\s+|\s+$//g;
	$theme =~ s/[^a-z0-9_-]//g;
	return '' if $theme eq '';
	$theme = 'classic-lb' if $theme eq 'classic';
	return ($theme =~ /^theme-/) ? $theme : "theme-$theme";
}

##########################################################################
# _cssframework_current_renderer_url()
#
# Determines and sanitizes the URL of the currently executing renderer.
#
# Parameters:
#   none
#
# Returns:
#   Safe renderer URL with a Core renderer fallback.
##########################################################################
sub _cssframework_current_renderer_url {
	my $script = $ENV{SCRIPT_NAME} || '/admin/system/cssframework.cgi';
	$script =~ s/[\r\n\"\'<>]//g;
	$script = '/admin/system/cssframework.cgi' if $script eq '';
	return $script;
}

##########################################################################
# _cssframework_page_url($base, $page, $theme_class)
#
# Builds a renderer URL for a Preview or Help page. A theme parameter is
# appended only when a non-empty theme class is supplied.
#
# Parameters:
#   $base         Renderer base URL.
#   $page         Page name, normally "preview" or "help".
#   $theme_class  Optional theme CSS class.
#
# Returns:
#   URL including escaped query parameters.
##########################################################################
sub _cssframework_page_url {
	my ($base, $page, $theme_class) = @_;
	$base = _cssframework_current_renderer_url() if !defined $base || $base eq '';
	$page = 'preview' if !defined $page || $page eq '';
	my $url = $base . '?page=' . CGI::escape($page);
	if (defined $theme_class && $theme_class ne '') {
		$url .= '&theme=' . CGI::escape($theme_class);
	}
	return $url;
}

##########################################################################
# _cssframework_renderer_context_class()
#
# Determines whether the script runs as the Core renderer or as the CSS
# Framework Studio renderer. Explicit development overrides are supported.
#
# Parameters:
#   none
#
# Returns:
#   "lb-renderer-core" or "lb-renderer-studio".
##########################################################################
sub _cssframework_renderer_context_class {
	my $script = $ENV{SCRIPT_NAME} || '';
	my $param = lc($cgi->param('renderer') || $cgi->param('chrome') || $cgi->param('context') || '');
	$param =~ s/[^a-z_-]//g;

	# Explicit override for development/testing.
	return 'lb-renderer-studio' if $param =~ /^(studio|plugin|sidebar|withsidebar)$/;
	return 'lb-renderer-core'   if $param =~ /^(core|system|nosidebar|no-sidebar|plain)$/;

	# Default: plugin renderer is used inside the CSS Framework Studio and keeps
	# the preview sidebar; system renderer is rendered inside the original LoxBerry chrome.
	return ($script =~ m#/plugins/cssframework/#) ? 'lb-renderer-studio' : 'lb-renderer-core';
}

##########################################################################
# _cssframework_title_from_class($class, $prefix_to_remove)
#
# Converts a machine-readable theme class into a human-readable title.
#
# Parameters:
#   $class             Theme CSS class.
#   $prefix_to_remove  Optional leading prefix to remove first.
#
# Returns:
#   Human-readable title.
##########################################################################
sub _cssframework_title_from_class {
	my ($class, $prefix_to_remove) = @_;
	my $label = $class || '';
	$prefix_to_remove = '' if !defined $prefix_to_remove;
	$label =~ s/^\Q$prefix_to_remove\E// if $prefix_to_remove ne '';
	$label =~ s/^theme-//;
	$label =~ s/[-_]+/ /g;
	$label =~ s/(\b[a-z])/\U$1/g;
	return $label;
}

##########################################################################
# _cssframework_core_theme_label($class)
#
# Returns the preferred display label for a Core theme. Unknown Core themes
# are converted to a readable title automatically.
#
# Parameters:
#   $class  Core theme CSS class.
#
# Returns:
#   Display label.
##########################################################################
sub _cssframework_core_theme_label {
	my ($class) = @_;
	my %known = (
		'theme-classic-lb'   => 'Classic LoxBerry',
		'theme-soft-rounded' => 'Soft & Rounded',
		'theme-clean-admin'  => 'Clean Admin',
		'theme-glass'        => 'Glassmorphism',
	);
	return $known{$class} if exists $known{$class};
	return _cssframework_title_from_class($class, 'theme-');
}

##########################################################################
# _cssframework_user_theme_label($class)
#
# Builds the display label for a plugin-managed user theme.
#
# Parameters:
#   $class  User theme CSS class.
#
# Returns:
#   Display label prefixed with "User:".
##########################################################################
sub _cssframework_user_theme_label {
	my ($class) = @_;
	return 'User: ' . _cssframework_title_from_class($class, 'theme-user-');
}

##########################################################################
# _cssframework_core_theme_order($class)
#
# Provides a stable sort priority for known Core themes.
#
# Parameters:
#   $class  Core theme CSS class.
#
# Returns:
#   Numeric sort priority; unknown themes receive a low-priority fallback.
##########################################################################
sub _cssframework_core_theme_order {
	my ($class) = @_;
	my %order = (
		'theme-classic-lb'   => 10,
		'theme-soft-rounded' => 20,
		'theme-clean-admin'  => 30,
		'theme-glass'        => 40,
	);
	return exists $order{$class} ? $order{$class} : 1000;
}

##########################################################################
# _cssframework_core_themes()
#
# Discovers available Core theme CSS files and returns normalized metadata
# sorted by the preferred Core theme order.
#
# Parameters:
#   none
#
# Returns:
#   List of hash references containing file, class, label, and order.
##########################################################################
sub _cssframework_core_themes {
	my $theme_dir = _cssframework_find_first_dir('system/css/themes');
	my @themes;

	if (opendir(my $dh, $theme_dir)) {
		while (my $file = readdir($dh)) {
			next if $file =~ /^\./;
			next if $file !~ /^(theme-[A-Za-z0-9_-]+)\.css$/;
			next if $file =~ /^theme-user-/;
			next if ! -f "$theme_dir/$file";

			my $class = $1;
			push @themes, {
				file  => $file,
				class => $class,
				label => _cssframework_core_theme_label($class),
				order => _cssframework_core_theme_order($class),
			};
		}
		closedir($dh);
	}

	@themes = sort {
		$a->{order} <=> $b->{order}
		|| lc($a->{class}) cmp lc($b->{class})
	} @themes;
	return @themes;
}

##########################################################################
# _cssframework_plugin_user_themes()
#
# Discovers plugin-managed user theme CSS files in the CSS Framework data
# directory and returns normalized metadata sorted by class name.
#
# Parameters:
#   none
#
# Returns:
#   List of hash references containing file, class, and label.
##########################################################################
sub _cssframework_plugin_user_themes {
	my $theme_dir = _cssframework_find_first_data_theme_dir();
	my @themes;

	if (opendir(my $dh, $theme_dir)) {
		while (my $file = readdir($dh)) {
			next if $file =~ /^\./;
			next if $file !~ /^(theme-user-[A-Za-z0-9_-]+)\.css$/;
			next if ! -f "$theme_dir/$file";

			my $class = $1;
			push @themes, {
				file  => $file,
				class => $class,
				label => _cssframework_user_theme_label($class),
			};
		}
		closedir($dh);
	}

	@themes = sort { lc($a->{class}) cmp lc($b->{class}) } @themes;
	return @themes;
}

##########################################################################
# _cssframework_theme_file_url($web_base, $file)
#
# Combines a theme delivery base URL with a theme filename. Both directory
# style URLs and CGI URLs ending in "?file=" are supported.
#
# Parameters:
#   $web_base  Theme delivery base URL.
#   $file      Theme filename.
#
# Returns:
#   Complete theme URL.
##########################################################################
sub _cssframework_theme_file_url {
	my ($web_base, $file) = @_;
	$file = '' if !defined $file;
	if ($web_base =~ /\?file=$/) {
		return $web_base . $file;
	}
	return $web_base . '/' . $file;
}

##########################################################################
# _cssframework_theme_links($web_base, @themes)
#
# Generates stylesheet link elements for a list of theme metadata entries.
#
# Parameters:
#   $web_base  Theme delivery base URL.
#   @themes    Theme metadata hash references.
#
# Returns:
#   Newline-separated HTML link elements, or an empty string.
##########################################################################
sub _cssframework_theme_links {
	my ($web_base, @themes) = @_;
	return '' if !@themes;

	return join("\n", map {
		"\t<link rel='stylesheet' href='" . _cssframework_escape_html(_cssframework_theme_file_url($web_base, $_->{file})) . "'>"
	} @themes);
}

##########################################################################
# _cssframework_theme_options($lang, $empty_de, $empty_en, @themes)
#
# Generates HTML option elements for a theme selector. When no themes are
# available, a localized disabled placeholder is returned.
#
# Parameters:
#   $lang      Effective LoxBerry language code.
#   $empty_de  German empty-list text.
#   $empty_en  English empty-list text.
#   @themes    Theme metadata hash references.
#
# Returns:
#   Newline-separated HTML option elements.
##########################################################################
sub _cssframework_theme_options {
	my ($lang, $empty_de, $empty_en, @themes) = @_;

	if (!@themes) {
		my $text = ($lang && $lang eq 'de') ? $empty_de : $empty_en;
		return "\t\t\t\t\t\t\t\t<option value='' disabled>" . _cssframework_escape_html($text) . "</option>";
	}

	return join("\n", map {
		"\t\t\t\t\t\t\t\t<option value='" . $_->{class} . "'>" . _cssframework_escape_html($_->{label}) . "</option>"
	} @themes);
}

##########################################################################
# _cssframework_theme_classes_js(@themes)
#
# Converts unique theme class names into JavaScript string literals for
# insertion into the static Preview and Help templates.
#
# Parameters:
#   @themes  Theme metadata hash references.
#
# Returns:
#   Comma-separated JavaScript string entries, or an empty string.
##########################################################################
sub _cssframework_theme_classes_js {
	my (@themes) = @_;
	return '' if !@themes;

	my @classes;
	my %seen;
	foreach my $theme (@themes) {
		next if !$theme->{class};
		next if $seen{$theme->{class}}++;
		push @classes, "\t\t\t'" . $theme->{class} . "'";
	}

	return join(",\n", @classes);
}

##########################################################################
# _cssframework_theme_class()
#
# Reads the active LoxBerry theme from general.json and converts it to the
# canonical CSS class. Errors fall back to Soft & Rounded.
#
# Parameters:
#   none
#
# Returns:
#   Normalized active theme CSS class.
##########################################################################
sub _cssframework_theme_class {
	my $theme = 'soft-rounded';

	eval {
		my $jsonobj = LoxBerry::System::General->new();
		my $cfg = $jsonobj->open();
		if ($cfg && ref($cfg) eq 'HASH' && $cfg->{Base} && defined $cfg->{Base}->{Theme} && $cfg->{Base}->{Theme} ne '') {
			$theme = $cfg->{Base}->{Theme};
		}
	};

	return _cssframework_normalize_theme_class($theme) || 'theme-soft-rounded';
}

##########################################################################
# _cssframework_extract_first_style_block($html)
#
# Extracts the first complete style element from a static page template.
#
# Parameters:
#   $html  Complete HTML document or fragment.
#
# Returns:
#   First style element including its tags, or an empty string.
##########################################################################
sub _cssframework_extract_first_style_block {
	my ($html) = @_;
	$html = '' if !defined $html;
	return $1 if $html =~ m{(<style\b[^>]*>.*?</style>)}is;
	return '';
}

##########################################################################
# _cssframework_extract_main_inner($html)
#
# Extracts the inner markup of the main.lb-content element used by shared
# Preview and Help templates.
#
# Parameters:
#   $html  Complete HTML document or fragment.
#
# Returns:
#   Inner main content; the original input if no matching element exists.
##########################################################################
sub _cssframework_extract_main_inner {
	my ($html) = @_;
	$html = '' if !defined $html;
	if ($html =~ m{<main\b[^>]*class=["'][^"']*\blb-content\b[^"']*["'][^>]*>(.*?)</main>}is) {
		return $1;
	}
	return $html;
}

##########################################################################
# _cssframework_extract_dialogs_and_scripts($html)
#
# Extracts dialog elements and page-specific scripts required after embedding
# a shared template into the normal LoxBerry chrome. Scripts belonging to the
# standalone navigation shell are deliberately excluded.
#
# Parameters:
#   $html  Complete HTML document or fragment.
#
# Returns:
#   Concatenated dialog and permitted script blocks.
##########################################################################
sub _cssframework_extract_dialogs_and_scripts {
	my ($html) = @_;
	$html = '' if !defined $html;
	my $extra = '';
	while ($html =~ m{(<dialog\b.*?</dialog>)}gis) {
		$extra .= "\n" . $1 . "\n";
	}
	while ($html =~ m{(<script\b.*?</script>)}gis) {
		my $block = $1;
		next if $block =~ /createnavbar|toggleSidebar|lb_updateTabbarHeight|btnnotifies_get|mainicons_get/i;
		$extra .= "\n" . $block . "\n";
	}
	return $extra;
}

##########################################################################
# _cssframework_render_inside_loxberry_chrome($content, $page, $lang)
#
# Renders a shared Preview or Help template inside the standard LoxBerry
# header, content area, and footer.
#
# Parameters:
#   $content  Fully token-replaced shared template content.
#   $page     Page name, normally "preview" or "help".
#   $lang     Effective LoxBerry language code.
#
# Returns:
#   Nothing. HTML is written directly to STDOUT.
##########################################################################
sub _cssframework_render_inside_loxberry_chrome {
	my ($content, $page, $lang) = @_;
	$content = '' if !defined $content;
	$page = 'preview' if !defined $page || $page eq '';

	my $title = ($page eq 'help')
		? (($lang && $lang eq 'de') ? 'LoxBerry CSS Framework Hilfe' : 'LoxBerry CSS Framework Help')
		: 'LoxBerry Design System Preview';

	my $style = _cssframework_extract_first_style_block($content);
	my $main = _cssframework_extract_main_inner($content);
	my $extra = _cssframework_extract_dialogs_and_scripts($content);

	LoxBerry::Web::lbheader($title, '', '', 1);
	print $style;
	print "\n<div class=\"lb-cssframework-shared-page lb-cssframework-shared-$page\">\n";
	print $main;
	print "\n</div>\n";
	print $extra;
	LoxBerry::Web::lbfooter();
}

# Renderer roles are intentionally automatic:
# - /admin/system/cssframework.cgi is Core-owned and always shows the currently
#   active LoxBerry theme from general.json. It must not become a manual theme
#   chooser and therefore ignores ?theme=... parameters.
# - /admin/plugins/cssframework/cssframework.cgi is Studio-owned and may receive
#   ?theme=... from the Design Studio iframe/live preview.
my $renderer_context_class = _cssframework_renderer_context_class();
my $theme_param = '';
if ($renderer_context_class ne 'lb-renderer-core') {
	$theme_param = $cgi->param('theme') || $cgi->param('theme_class') || $cgi->param('preview_theme') || '';
}
my $current_theme_class = _cssframework_normalize_theme_class($theme_param) || _cssframework_theme_class();

my @core_themes = _cssframework_core_themes();
my @plugin_user_themes = _cssframework_plugin_user_themes();
my @all_themes = (@core_themes, @plugin_user_themes);

my $core_theme_links = _cssframework_theme_links('/system/css/themes', @core_themes);
my $core_theme_options = _cssframework_theme_options(
	$lang,
	'Keine Core-Themes gefunden',
	'No Core themes found',
	@core_themes
);
my $plugin_theme_links = _cssframework_theme_links('/admin/plugins/cssframework/theme-file.cgi', @plugin_user_themes);
my $plugin_theme_options = _cssframework_theme_options(
	$lang,
	'Keine Plugin-Themes gefunden',
	'No plugin themes found',
	@plugin_user_themes
);
my $theme_classes_js = _cssframework_theme_classes_js(@all_themes);
my $renderer_url = _cssframework_current_renderer_url();
my $preview_url = _cssframework_page_url($renderer_url, 'preview', $current_theme_class);
my $help_url = _cssframework_page_url($renderer_url, 'help', $current_theme_class);
if ($renderer_context_class ne 'lb-renderer-core') {
	print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
}
binmode STDOUT, ':encoding(UTF-8)';

if (! -e $template_file) {
	print "<!doctype html>\n";
	print "<html lang=\"en\"><head><meta charset=\"utf-8\"><title>LoxBerry CSS Framework</title></head><body>\n";
	print "<h1>LoxBerry CSS Framework</h1>\n";
	print "<p>Template not found.</p>\n";
	print "</body></html>\n";
	exit;
}

open(my $fh, '<:encoding(UTF-8)', $template_file) or do {
	print "<!doctype html>\n";
	print "<html lang=\"en\"><head><meta charset=\"utf-8\"><title>LoxBerry CSS Framework</title></head><body>\n";
	print "<h1>LoxBerry CSS Framework</h1>\n";
	print "<p>Could not open template.</p>\n";
	print "</body></html>\n";
	exit;
};

local $/;
my $content = <$fh>;
close($fh);
$content = '' if !defined $content;

# Lightweight token replacement only. Do not run the static documentation pages
# through HTML::Template because code snippets may contain template-like text.
$content =~ s/__LB_CURRENT_THEME_CLASS__/$current_theme_class/g;
$content =~ s/__LB_CORE_THEME_LINKS__/$core_theme_links/g;
$content =~ s/__LB_PLUGIN_THEME_LINKS__/$plugin_theme_links/g;
$content =~ s/__LB_CORE_THEME_OPTIONS__/$core_theme_options/g;
$content =~ s/__LB_PLUGIN_THEME_OPTIONS__/$plugin_theme_options/g;
$content =~ s/__LB_THEME_CLASSES_JS__/$theme_classes_js/g;
$content =~ s/__LB_CSSFRAMEWORK_CGI_URL__/_cssframework_escape_html($renderer_url)/ge;
$content =~ s/__LB_CSSFRAMEWORK_PREVIEW_URL__/_cssframework_escape_html($preview_url)/ge;
$content =~ s/__LB_CSSFRAMEWORK_HELP_URL__/_cssframework_escape_html($help_url)/ge;
$content =~ s/__LB_RENDERER_CONTEXT_CLASS__/_cssframework_escape_html($renderer_context_class)/ge;

if ($renderer_context_class eq 'lb-renderer-core') {
	_cssframework_render_inside_loxberry_chrome($content, $page, $lang);
} else {
	print $content;
}

exit;
