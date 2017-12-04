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

# You can explicitly read the plugindb without comments in the array
# With that filtered array, you don't need to skip or TMPL_IF it, but you'll loose comments on writing.
# my @plugins = LoxBerry::System::get_plugins(1);

# You can force to re-read the array from disk (during the runtime of the script, usually it is cached after one call)
# This might be useful if you read->write->read it within one single user request.
# my @plugins = LoxBerry::System::get_plugins(undef, 1);

