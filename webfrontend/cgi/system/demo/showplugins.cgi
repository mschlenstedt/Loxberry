#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;

# We explicitly use parameter 1 to read the comments (if we don't want to loose the comments).
my @plugins = LoxBerry::System::get_plugins(1);
# For normal situations, where ommit the parameter and only get plugins without comments.

# The following example shows how to suppress the loaded comments in code and in HTML::Template.

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

# To only get plugins without comments, simply ommit the parameter
# my @plugins = LoxBerry::System::get_plugins();

# You can force to re-read the array from disk (during the runtime of the script, usually it is cached after one call)
# This might be useful if you read->write->read it within one single user request.
# my @plugins = LoxBerry::System::get_plugins(1, 1);
# This is: re-read from disk with comments.
