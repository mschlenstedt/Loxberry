#!/usr/bin/perl

# Copyright 2026 LoxBerry Team
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

# AppStore — durchsuchbarer Plugin-Katalog. Duenner Controller;
# Logik in LoxBerry::AppStore. Installation via bestehende plugininstall.cgi.

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use LoxBerry::AppStore;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use JSON::PP ();
use File::Path qw(make_path);
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $version = "0.1.0";
my $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_appstore";

# Cache-/Datenverzeichnis sicherstellen. $lbsdatadir ist bereits
# .../data/system (NICHT .../data), daher KEIN zusaetzliches system/.
make_path("/dev/shm/appstore")         unless -d "/dev/shm/appstore";
make_path("$lbsdatadir/appstore") unless -d "$lbsdatadir/appstore";

##########################################################################
# Read config (appstore.json, fallback to shipped .default)
##########################################################################

my $cfgfile = "$lbsconfigdir/appstore.json";
$cfgfile = "$lbsconfigdir/appstore.json.default" if !-e $cfgfile && -e "$lbsconfigdir/appstore.json.default";

my $cfg = {};
if (-e $cfgfile) {
	open(my $fh, '<:encoding(UTF-8)', $cfgfile);
	local $/;
	my $c = <$fh>;
	close($fh);
	$cfg = eval { JSON::PP::decode_json($c) } || {};
}
my $url        = $cfg->{url} || "";
my $ttl        = defined $cfg->{cache_ttl_minutes} ? $cfg->{cache_ttl_minutes} : 60;
my $cache      = "/dev/shm/appstore/cache.json";
my $persistent = "$lbsdatadir/appstore/plugins.json";

##########################################################################
# Load catalog (fresh cache -> live -> stale cache -> fallback) + enrich
##########################################################################

my $lbv = LoxBerry::System::lbversion();
my ($catalog, $source) = LoxBerry::AppStore::load_catalog($url, $cache, $ttl, $lbv, $persistent);

my @installed = LoxBerry::System::get_plugins();
LoxBerry::AppStore::mark_installed($catalog, \@installed);
LoxBerry::AppStore::classify($_) for @{$catalog->{plugins}};

# min_lb_version: pro Plugin pruefen, ob die laufende LoxBerry-Version die vom
# Plugin geforderte Mindestversion erfuellt. Ist sie zu alt, sperrt das Template
# den Install-Button und zeigt stattdessen einen Hinweis (kein Fehlinstall).
# Die Vergleichslogik liegt in LoxBerry::AppStore::version_ok (dependency-frei,
# unit-getestet). Die laufende Version steht zur Anzeige in jedem Plugin-Hash.
for my $p (@{$catalog->{plugins}}) {
	$p->{lb_current_version} = $lbv;
	$p->{version_ok} = LoxBerry::AppStore::version_ok($lbv, $p->{min_lb_version});
}

##########################################################################
# Template
##########################################################################

my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/appstore.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
	%htmltemplate_options,
);

# System language file (language_<lang>.ini), strings in section [APPSTORE]
my %SL = LoxBerry::System::readlanguage($maintemplate);

$maintemplate->param("PLUGINS"     => $catalog->{plugins});
$maintemplate->param("SOURCE"      => $source);
# "evtl. nicht aktuell"-Banner nur bei VERALTETEM Cache (Quelle nicht erreichbar)
# oder mitgeliefertem Default-Katalog. Frischer Cache (source "cache") sind aktuelle
# Live-Daten innerhalb der TTL -> KEIN Banner. Leerer Katalog -> Empty-Meldung.
$maintemplate->param("IS_FALLBACK" => ($source eq "cache_stale") ? 1 : 0);  # Banner nur bei veraltetem Cache
$maintemplate->param("PLUGINCOUNT" => scalar @{$catalog->{plugins}});

my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'APPSTORE.WIDGETLABEL'};

##########################################################################
# Render
##########################################################################

LoxBerry::Web::head();
LoxBerry::Web::pagestart($template_title, $helplink);
print $maintemplate->output();
undef $maintemplate;
LoxBerry::Web::pageend();
LoxBerry::Web::foot();

exit;
