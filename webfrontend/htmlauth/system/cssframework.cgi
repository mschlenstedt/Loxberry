#!/usr/bin/perl

# LoxBerry CSS Framework Preview/Help renderer
# Renders language-specific HTML templates from templates/system/themes/.

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

my $lang_param = $cgi->param('lang') || '';
my $lang = '';

if ($lang_param ne '') {
	$lang = substr($lang_param, 0, 2);
} else {
	$lang = lblanguage();
}

$lang = lc(substr($lang || 'en', 0, 2));
$lang =~ s/[^a-z]//g;
$lang = 'en' if $lang eq '';

my $template_file = "$lbstemplatedir/themes/$page/index_$lang.html";

# Fallback to English if no template exists for the active LoxBerry language.
if (! -e $template_file) {
	$template_file = "$lbstemplatedir/themes/$page/index_en.html";
}


sub cssframework_candidate_html_dirs {
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

sub cssframework_find_first_dir {
	my (@relative_paths) = @_;

	foreach my $htmlroot (cssframework_candidate_html_dirs()) {
		foreach my $rel (@relative_paths) {
			my $dir = "$htmlroot/$rel";
			return $dir if -d $dir;
		}
	}

	return '';
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

sub cssframework_title_from_class {
	my ($class, $prefix_to_remove) = @_;
	my $label = $class || '';
	$prefix_to_remove = '' if !defined $prefix_to_remove;
	$label =~ s/^\Q$prefix_to_remove\E// if $prefix_to_remove ne '';
	$label =~ s/^theme-//;
	$label =~ s/[-_]+/ /g;
	$label =~ s/(\b[a-z])/\U$1/g;
	return $label;
}

sub cssframework_core_theme_label {
	my ($class) = @_;
	my %known = (
		'theme-classic-lb'   => 'Classic LoxBerry',
		'theme-soft-rounded' => 'Soft & Rounded',
		'theme-clean-admin'  => 'Clean Admin',
		'theme-glass'        => 'Glassmorphism',
	);
	return $known{$class} if exists $known{$class};
	return cssframework_title_from_class($class, 'theme-');
}

sub cssframework_user_theme_label {
	my ($class) = @_;
	return 'User: ' . cssframework_title_from_class($class, 'theme-user-');
}

sub cssframework_core_theme_order {
	my ($class) = @_;
	my %order = (
		'theme-classic-lb'   => 10,
		'theme-soft-rounded' => 20,
		'theme-clean-admin'  => 30,
		'theme-glass'        => 40,
	);
	return exists $order{$class} ? $order{$class} : 1000;
}

sub cssframework_core_themes {
	my $theme_dir = cssframework_find_first_dir('system/css/themes');
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
				label => cssframework_core_theme_label($class),
				order => cssframework_core_theme_order($class),
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

sub cssframework_plugin_user_themes {
	my $theme_dir = cssframework_find_first_dir('plugins/cssframework/themes');
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
				label => cssframework_user_theme_label($class),
			};
		}
		closedir($dh);
	}

	@themes = sort { lc($a->{class}) cmp lc($b->{class}) } @themes;
	return @themes;
}

sub cssframework_theme_links {
	my ($web_base, @themes) = @_;
	return '' if !@themes;

	return join("\n", map {
		"\t<link rel='stylesheet' href='" . $web_base . "/" . $_->{file} . "'>"
	} @themes);
}

sub cssframework_theme_options {
	my ($lang, $empty_de, $empty_en, @themes) = @_;

	if (!@themes) {
		my $text = ($lang && $lang eq 'de') ? $empty_de : $empty_en;
		return "\t\t\t\t\t\t\t\t<option value='' disabled>" . cssframework_escape_html($text) . "</option>";
	}

	return join("\n", map {
		"\t\t\t\t\t\t\t\t<option value='" . $_->{class} . "'>" . cssframework_escape_html($_->{label}) . "</option>"
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

	$theme = lc($theme || 'soft-rounded');
	$theme =~ s/^\s+|\s+$//g;
	$theme =~ s/[^a-z0-9_-]//g;
	$theme = 'soft-rounded' if $theme eq '';

	# Legacy/Core compatibility: older configs may still use "classic".
	$theme = 'classic-lb' if $theme eq 'classic';

	return ($theme =~ /^theme-/) ? $theme : "theme-$theme";
}

my $current_theme_class = cssframework_theme_class();
my @core_themes = cssframework_core_themes();
my @plugin_user_themes = cssframework_plugin_user_themes();
my @all_themes = (@core_themes, @plugin_user_themes);

my $core_theme_links = cssframework_theme_links('/system/css/themes', @core_themes);
my $core_theme_options = cssframework_theme_options(
	$lang,
	'Keine Core-Themes gefunden',
	'No Core themes found',
	@core_themes
);
my $plugin_theme_links = cssframework_theme_links('/plugins/cssframework/themes', @plugin_user_themes);
my $plugin_theme_options = cssframework_theme_options(
	$lang,
	'Keine Plugin-Themes gefunden',
	'No plugin themes found',
	@plugin_user_themes
);
my $theme_classes_js = cssframework_theme_classes_js(@all_themes);

print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
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

my $content = '';
while (my $line = <$fh>) {
	$content .= $line;
}
close($fh);

# Lightweight token replacement only. Do not run the static documentation pages
# through HTML::Template because code snippets may contain template-like text.
$content =~ s/__LB_CURRENT_THEME_CLASS__/$current_theme_class/g;
$content =~ s/__LB_CORE_THEME_LINKS__/$core_theme_links/g;
$content =~ s/__LB_PLUGIN_THEME_LINKS__/$plugin_theme_links/g;
$content =~ s/__LB_CORE_THEME_OPTIONS__/$core_theme_options/g;
$content =~ s/__LB_PLUGIN_THEME_OPTIONS__/$plugin_theme_options/g;
$content =~ s/__LB_THEME_CLASSES_JS__/$theme_classes_js/g;

print $content;

exit;
