#!/usr/bin/perl

use strict;
use warnings;
use Config::Simple '-strict';
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use JSON qw(decode_json encode_json);
use LoxBerry::System;
use LoxBerry::Web;

##########################################################################
# Variables
##########################################################################

my $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Read Settings
##########################################################################

my $version = LoxBerry::System::pluginversion();
my $cfg = new Config::Simple("$lbpconfigdir/mqttbenchmark.cfg");

##########################################################################
# Form Processing: Save settings
##########################################################################

if ($R::saveformdata) {
    # Validate and save duration
    my $duration = ($R::duration && $R::duration =~ /^(30|60|120)$/) ? $1 : 60;
    $cfg->param("BENCHMARK.DURATION", $duration);

    # Validate and save loglevel
    my $loglevel = ($R::loglevel && $R::loglevel =~ /^(3|6|7)$/) ? $1 : 6;
    $cfg->param("BENCHMARK.LOGLEVEL", $loglevel);

    # Validate and save runs
    my $runs = "";
    $runs .= "realistic," if $R::run_realistic;
    $runs .= "stress,"    if $R::run_stress;
    $runs =~ s/,$//;
    $runs = "realistic,stress" unless $runs;
    $cfg->param("BENCHMARK.RUNS", $runs);

    # Validate and save fixes
    my @fixes;
    for my $i (1..7) {
        my $param = "fix_$i";
        push @fixes, $i if $R::{$param};
    }
    my $fixes_str = @fixes ? join(",", @fixes) : "1,2,3,4,5,6,7";
    $cfg->param("BENCHMARK.FIXES", $fixes_str);

    $cfg->save();
}

##########################################################################
# Template
##########################################################################

my $template = HTML::Template->new(
    filename        => "$lbptemplatedir/settings.html",
    global_vars     => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
    associate       => $cfg,
);

# Load language file
my %L = LoxBerry::System::readlanguage($template, "language.ini");

##########################################################################
# Fill template variables from config
##########################################################################

my $duration = $cfg->param("BENCHMARK.DURATION") || 60;
my $loglevel = $cfg->param("BENCHMARK.LOGLEVEL") || 6;
my $runs     = $cfg->param("BENCHMARK.RUNS") || "realistic,stress";
my $fixes    = $cfg->param("BENCHMARK.FIXES") || "1,2,3,4,5,6,7";

# Duration dropdown selected states
$template->param("DURATION_30_SEL",  ($duration == 30)  ? "selected" : "");
$template->param("DURATION_60_SEL",  ($duration == 60)  ? "selected" : "");
$template->param("DURATION_120_SEL", ($duration == 120) ? "selected" : "");

# Loglevel dropdown selected states
$template->param("LOGLEVEL_3_SEL", ($loglevel == 3) ? "selected" : "");
$template->param("LOGLEVEL_6_SEL", ($loglevel == 6) ? "selected" : "");
$template->param("LOGLEVEL_7_SEL", ($loglevel == 7) ? "selected" : "");

# Runs checkboxes
$template->param("RUN_REALISTIC_CHK", ($runs =~ /realistic/) ? "checked" : "");
$template->param("RUN_STRESS_CHK",    ($runs =~ /stress/)    ? "checked" : "");

# Fixes checkboxes
for my $i (1..7) {
    $template->param("FIX_${i}_CHK", ($fixes =~ /\b$i\b/) ? "checked" : "");
}

##########################################################################
# Navbar
##########################################################################

our %navbar;
$navbar{1}{Name}  = "$L{'COMMON.TAB_BENCHMARK'}";
$navbar{1}{URL}   = 'index.cgi?form=1';

$navbar{2}{Name}  = "$L{'COMMON.TAB_RESULTS'}";
$navbar{2}{URL}   = 'index.cgi?form=2';

$navbar{3}{Name}  = "$L{'COMMON.TAB_COMPARE'}";
$navbar{3}{URL}   = 'index.cgi?form=3';

$navbar{99}{Name} = "$L{'COMMON.TAB_LOGS'}";
$navbar{99}{URL}  = 'index.cgi?form=99';

# Active tab
if (!$R::form || $R::form eq "1") {
    $navbar{1}{active} = 1;
    $template->param("FORM1", 1);
} elsif ($R::form eq "2") {
    $navbar{2}{active} = 1;
    $template->param("FORM2", 1);
} elsif ($R::form eq "3") {
    $navbar{3}{active} = 1;
    $template->param("FORM3", 1);
} elsif ($R::form eq "99") {
    $navbar{99}{active} = 1;
    $template->param("FORM99", 1);
    $template->param("LOGLIST_HTML", LoxBerry::Web::loglist_html());
}

# Save confirmation
if ($R::saveformdata) {
    $template->param("SAVE_OK", 1);
}

##########################################################################
# Output
##########################################################################

LoxBerry::Web::lbheader(
    "$L{'COMMON.PLUGIN_TITLE'} V$version",
    "https://wiki.loxberry.de/plugins/mqttbenchmark/start",
    "help.html"
);
print $template->output();
LoxBerry::Web::lbfooter();

exit;
