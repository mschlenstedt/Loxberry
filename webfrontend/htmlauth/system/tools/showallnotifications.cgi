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

our $helplink = "https://wiki.loxberry.de/";
our $template_title = "Notifications";

# Version of this script
my $version = "3.0.0.1";

our %SL = LoxBerry::System::readlanguage();

our %navbar;
$navbar{1}{Name} = $SL{'HEADER.TITLE_PAGE_PLUGINS'};
$navbar{1}{URL} = "/admin/system/index.cgi";
$navbar{2}{Name} = $SL{'HEADER.TITLE_PAGE_SYSTEM'};
$navbar{2}{URL} = "/admin/system/index.cgi?form=system";
$navbar{2}{active} = 1;

LoxBerry::Web::lbheader($template_title, $helplink);

print LoxBerry::Log::get_notifications_html();

LoxBerry::Web::lbfooter();

