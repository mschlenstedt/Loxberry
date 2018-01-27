#!/usr/bin/perl


##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;

use warnings;
use strict;

$LoxBerry::Log::DEBUG = 1;

our $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
our $template_title = "Show all notifications";

# Version of this script
my $version = "0.3.5.1";

LoxBerry::Web::lbheader($template_title, $helplink);

print LoxBerry::Log::get_notifications_html();

LoxBerry::Web::lbfooter();

