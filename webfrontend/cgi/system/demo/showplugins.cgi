#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
my @plugins = LoxBerry::System::get_plugins();

# With comments
print STDERR "Plugins with comments:\n";
foreach my $plugin (@plugins) {
	if ($plugin->{PLUGINDB_COMMENT}) {
		print STDERR "$plugin->{PLUGINDB_COMMENT}\n";
		next;
	}
	print STDERR "$plugin->{PLUGINDB_NO} $plugin->{PLUGINDB_TITLE} $plugin->{PLUGINDB_VERSION}\n";
}

# Without comments
print STDERR "\nPlugins without comments:\n";
foreach my $plugin (@plugins) {
	if ($plugin->{PLUGINDB_COMMENT}) {
		next;
	}
	print STDERR "$plugin->{PLUGINDB_NO} $plugin->{PLUGINDB_TITLE} $plugin->{PLUGINDB_VERSION}\n";
}

# Visit http://loxberry/admin/system/demo/showplugins.cgi


# Use the Array directly in HTML::Template
my $htmltemplate = HTML::Template->new(
				filename => "$lbscgidir/demo/showplugins.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				);
$htmltemplate->param('PLUGINS' => \@plugins);

LoxBerry::Web::lbheader("showplugins");
print $htmltemplate->output();
LoxBerry::Web::lbfooter();

 