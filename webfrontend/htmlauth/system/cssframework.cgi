#!/usr/bin/perl

# LoxBerry CSS Framework Preview/Help renderer
# Core-owned renderer for templates/system/themes/.
# Supports ?page=preview|help.
# System/Core renderer always uses the currently active LoxBerry theme from general.json.
# A caller may request ?layout=embedded&theme=theme-* for an isolated preview.

use strict;
use warnings;
use CGI;
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::System::General;

my $cgi = CGI->new;

my $page = lc($cgi->param('page') || 'preview');
if ($page ne 'preview' && $page ne 'help') {
	$page = 'preview';
}

##########################################################################
# Language Settings
##########################################################################

my $requested_lang = lc($cgi->param('lang') || '');
if ($requested_lang =~ /^([a-z]{2})(?:[-_].*)?$/) {
	# Optional language override for direct/embedded documentation links.
	$LoxBerry::Web::lang = $1;
}
my $lang = lblanguage() || 'en';

my $template_file = "$lbstemplatedir/themes/$page/index_$lang.html";

# Fallback to English if no template exists for the active LoxBerry language.
if (! -e $template_file) {
	$template_file = "$lbstemplatedir/themes/$page/index_en.html";
}


sub cssframework_escape_html {
	my ($value) = @_;
	$value = '' if !defined $value;
	$value =~ s/&/&amp;/g;
	$value =~ s/</&lt;/g;
	$value =~ s/>/&gt;/g;
	$value =~ s/"/&quot;/g;
	return $value;
}


sub cssframework_normalize_theme_class {
	my ($theme) = @_;
	$theme = '' if !defined $theme;
	$theme = lc($theme);
	$theme =~ s/^\s+|\s+$//g;
	return '' if $theme !~ /^[a-z0-9_-]+$/;
	my %legacy_theme_map = (
		'classic' => 'classic-lb',
		'modern'  => 'soft-rounded',
		'dark'    => 'glass',
	);
	$theme = $legacy_theme_map{$theme} if exists $legacy_theme_map{$theme};
	return ($theme =~ /^theme-/) ? $theme : "theme-$theme";
}

sub cssframework_current_renderer_url {
	return '/admin/system/cssframework.cgi';
}

sub cssframework_page_url {
	my ($base, $page, $theme_class, $embedded, $lang) = @_;
	$base = cssframework_current_renderer_url() if !defined $base || $base eq '';
	$page = 'preview' if !defined $page || $page eq '';
	my $url = $base . '?page=' . CGI::escape($page);
	if ($embedded) {
		$url .= '&layout=embedded';
	}
	if ($embedded && defined $theme_class && $theme_class ne '') {
		$url .= '&theme=' . CGI::escape($theme_class);
	}
	if ($embedded && defined $lang && $lang =~ /^[a-z]{2}$/) {
		$url .= '&lang=' . CGI::escape($lang);
	}
	return $url;
}

sub cssframework_renderer_context_class {
	my $layout = lc($cgi->param('layout') || '');
	return ($layout eq 'embedded') ? 'lb-renderer-embedded' : 'lb-renderer-core';
}

sub cssframework_core_themes {
	my $theme_dir = "$LoxBerry::System::lbshtmldir/css/themes";
	my @registry = (
		['theme-classic-lb.css',   'theme-classic-lb'],
		['theme-soft-rounded.css', 'theme-soft-rounded'],
		['theme-clean-admin.css',  'theme-clean-admin'],
		['theme-glass.css',        'theme-glass'],
	);
	my @themes;

	foreach my $entry (@registry) {
		my ($file, $class) = @$entry;
		next if !-f "$theme_dir/$file" || !-r "$theme_dir/$file";
		push @themes, {
			file  => $file,
			class => $class,
		};
	}

	return @themes;
}

sub cssframework_user_themes {
	my $theme_dir = "$LoxBerry::System::lbhomedir/data/plugins/cssframework/themes";
	my @themes;

	if (opendir(my $dh, $theme_dir)) {
		while (my $file = readdir($dh)) {
			next if $file =~ /^\./;
			next if $file !~ /^(theme-user-[a-z0-9][a-z0-9_-]*)\.css$/;
			next if !-f "$theme_dir/$file" || !-r "$theme_dir/$file" || -l "$theme_dir/$file";

			my $class = $1;
			push @themes, {
				file  => $file,
				class => $class,
			};
		}
		closedir($dh);
	}

	@themes = sort { lc($a->{class}) cmp lc($b->{class}) } @themes;
	return @themes;
}

sub cssframework_theme_file_url {
	my ($web_base, $file) = @_;
	$file = '' if !defined $file;
	if ($web_base =~ /\?file=$/) {
		return $web_base . $file;
	}
	return $web_base . '/' . $file;
}

sub cssframework_theme_links {
	my ($web_base, @themes) = @_;
	return '' if !@themes;

	return join("\n", map {
		"\t<link rel='stylesheet' href='" . cssframework_escape_html(cssframework_theme_file_url($web_base, $_->{file})) . "'>"
	} @themes);
}

sub cssframework_theme_classes_js {
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

sub cssframework_theme_class {
	my $theme = 'soft-rounded';

	eval {
		my $jsonobj = LoxBerry::System::General->new();
		my $cfg = $jsonobj->open();
		if ($cfg && ref($cfg) eq 'HASH' && $cfg->{Base} && defined $cfg->{Base}->{Theme} && $cfg->{Base}->{Theme} ne '') {
			$theme = $cfg->{Base}->{Theme};
		}
	};

	return cssframework_normalize_theme_class($theme) || 'theme-soft-rounded';
}

sub cssframework_registered_theme_class {
	my ($requested, @themes) = @_;
	my $class = cssframework_normalize_theme_class($requested);
	return '' if $class eq '';

	foreach my $theme (@themes) {
		return $class if $theme->{class} && $theme->{class} eq $class;
	}

	return '';
}

sub cssframework_extract_first_style_block {
	my ($html) = @_;
	$html = '' if !defined $html;
	return $1 if $html =~ m{(<style\b[^>]*>.*?</style>)}is;
	return '';
}

sub cssframework_extract_main_inner {
	my ($html) = @_;
	$html = '' if !defined $html;
	if ($html =~ m{<main\b[^>]*class=["'][^"']*\blb-content\b[^"']*["'][^>]*>(.*?)</main>}is) {
		return $1;
	}
	return $html;
}

sub cssframework_extract_dialogs_and_scripts {
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

sub cssframework_render_inside_loxberry_chrome {
	my ($content, $page, $lang) = @_;
	$content = '' if !defined $content;
	$page = 'preview' if !defined $page || $page eq '';

	my $title = ($page eq 'help')
		? (($lang && $lang eq 'de') ? 'LoxBerry CSS Framework Hilfe' : 'LoxBerry CSS Framework Help')
		: 'LoxBerry Design System Preview';

	my $style = cssframework_extract_first_style_block($content);
	my $main = cssframework_extract_main_inner($content);
	my $extra = cssframework_extract_dialogs_and_scripts($content);

	LoxBerry::Web::lbheader($title, '', '', 1);
	print $style;
	print "\n<div class=\"lb-cssframework-shared-page lb-cssframework-shared-$page\">\n";
	print $main;
	print "\n</div>\n";
	print $extra;
	LoxBerry::Web::lbfooter();
}

sub cssframework_render_error {
	my ($message, $is_embedded) = @_;
	$message = 'Unknown renderer error.' if !defined $message || $message eq '';

	if ($is_embedded) {
		print "<!doctype html>\n";
		print "<html lang=\"en\"><head><meta charset=\"utf-8\"><title>LoxBerry CSS Framework</title></head><body>\n";
		print "<h1>LoxBerry CSS Framework</h1>\n";
		print '<p>' . cssframework_escape_html($message) . "</p>\n";
		print "</body></html>\n";
	} else {
		LoxBerry::Web::lbheader('LoxBerry CSS Framework', '', '', 1);
		print '<div class="lb-content"><h1>LoxBerry CSS Framework</h1><p>'
			. cssframework_escape_html($message)
			. "</p></div>\n";
		LoxBerry::Web::lbfooter();
	}
	exit;
}

my @core_themes = cssframework_core_themes();
my @user_themes = cssframework_user_themes();
my @all_themes = (@core_themes, @user_themes);

# The normal Core page uses the configured LoxBerry theme. Embedded callers may
# request a registered theme explicitly, but cannot inject arbitrary class names.
my $renderer_context_class = cssframework_renderer_context_class();
my $is_embedded = ($renderer_context_class eq 'lb-renderer-embedded');
my $theme_param = $is_embedded ? ($cgi->param('theme') || '') : '';
my $current_theme_class = cssframework_registered_theme_class($theme_param, @all_themes)
	|| cssframework_registered_theme_class(cssframework_theme_class(), @all_themes)
	|| cssframework_registered_theme_class('theme-soft-rounded', @core_themes)
	|| (@core_themes ? $core_themes[0]->{class} : 'theme-soft-rounded');

my $core_theme_links = cssframework_theme_links('/system/css/themes', @core_themes);
my $user_theme_links = cssframework_theme_links('/admin/system/theme-file.cgi', @user_themes);
my $theme_classes_js = cssframework_theme_classes_js(@all_themes);
my $renderer_url = cssframework_current_renderer_url();
my $preview_url = cssframework_page_url($renderer_url, 'preview', $current_theme_class, $is_embedded, $lang);
my $help_url = cssframework_page_url($renderer_url, 'help', $current_theme_class, $is_embedded, $lang);
if ($is_embedded) {
	print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
}
binmode STDOUT, ':encoding(UTF-8)';

if (! -e $template_file) {
	cssframework_render_error('Template not found.', $is_embedded);
}

open(my $fh, '<:encoding(UTF-8)', $template_file) or do {
	cssframework_render_error('Could not open template.', $is_embedded);
};

my $content = '';
while (my $line = <$fh>) {
	$content .= $line;
}
close($fh);

# Lightweight token replacement only. Do not run the static documentation pages
# through HTML::Template because code snippets may contain template-like text.
$content =~ s/__LB_CURRENT_THEME_CLASS__/$current_theme_class/g;
$content =~ s/__LB_CORE_THEME_LINKS__/$core_theme_links/g;
$content =~ s/__LB_USER_THEME_LINKS__/$user_theme_links/g;
$content =~ s/__LB_THEME_CLASSES_JS__/$theme_classes_js/g;
$content =~ s/__LB_CSSFRAMEWORK_CGI_URL__/cssframework_escape_html($renderer_url)/ge;
$content =~ s/__LB_CSSFRAMEWORK_PREVIEW_URL__/cssframework_escape_html($preview_url)/ge;
$content =~ s/__LB_CSSFRAMEWORK_HELP_URL__/cssframework_escape_html($help_url)/ge;
$content =~ s/__LB_RENDERER_CONTEXT_CLASS__/cssframework_escape_html($renderer_context_class)/ge;

if (!$is_embedded) {
	cssframework_render_inside_loxberry_chrome($content, $page, $lang);
} else {
	print $content;
}

exit;
