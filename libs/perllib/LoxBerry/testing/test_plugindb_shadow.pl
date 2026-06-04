#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::System::PluginDB;

use Data::Dumper;

$LoxBerry::JSON::DEBUG = 1;
$LoxBerry::System::PluginDB::DEBUG = 1;

if(!$lbsdatadir) {
	die("Could not read LoxBerry variables");
}

my $dbfile = "$lbsdatadir/plugindatabase.json";
my $dbfile_secured = "$lbsdatadir/plugindatabase.json-";

my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
print "Plugin 1 Title: $plugin1->{title}\n";
print "Changing title of Plugin 1...\n";

print "Load Shadow copy...\n";
my $plugin2 = LoxBerry::System::PluginDB->plugin( md5 => '1cd1e75734f2410b0dc795a13d3c04ef', _dbfile => $dbfile_secured );
print "Plugin 2 Title: $plugin2->{title}\n";
