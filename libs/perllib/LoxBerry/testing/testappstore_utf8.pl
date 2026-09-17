#!/usr/bin/perl

# Regressionstest: AppStore-Katalog darf KEINE dekodierten Perl-Zeichenketten
# an das Template liefern.
#
# Hintergrund (Bug "BenÃ¶tigt LoxBerry ab Version"): Sprachstrings aus
# language_<lang>.ini sind rohe UTF-8-Bytes, JSON::PP::decode_json liefert
# dagegen dekodierte Zeichen. Mischt HTML::Template beides in EINE Ausgabe und
# enthaelt irgendein Katalogfeld ein Zeichen > U+00FF (z.B. "…", "–", "→"),
# kann Perl das Ergebnis beim print nicht mehr auf Bytes herunterstufen und
# gibt die interne UTF-8-Darstellung des GESAMTEN Strings aus. Die bereits
# UTF-8-kodierten Sprachstrings werden dadurch ein zweites Mal kodiert.
#
# Aufruf: perl libs/perllib/LoxBerry/testing/testappstore_utf8.pl

use strict;
use warnings;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/../..";
use LoxBerry::AppStore;

my $tests = 0;
my $fails = 0;

sub ok {
	my ($cond, $name) = @_;
	$tests++;
	if ($cond) { print "ok $tests - $name\n"; }
	else       { $fails++; print "not ok $tests - $name\n"; }
}

my $dir   = tempdir(CLEANUP => 1);
my $cache = "$dir/cache.json";

# Katalog mit Umlaut (2-Byte) UND einem Zeichen > U+00FF (Ellipse, 3-Byte)
my $json = qq({"plugins":[{"title":"H\x{c3}\x{bc}hnerklappe","description":"Steuert die T\x{c3}\x{bc}r \x{e2}\x{80}\x{a6}","zip":"https://example.org/p.zip"}]});
open(my $fh, '>:raw', $cache) or die "cache: $!";
print $fh $json;
close($fh);

# TTL sehr hoch -> Stufe 1 (frischer Cache), kein Netzwerkzugriff
my ($catalog, $source) = LoxBerry::AppStore::load_catalog(undef, $cache, 999_999, "4.0.0.15", undef);

ok($source eq 'cache', "Katalog kommt aus dem frischen Cache (source=$source)");
ok(ref $catalog->{plugins} eq 'ARRAY' && @{$catalog->{plugins}} == 1, "ein Plugin geladen");

my $p = $catalog->{plugins}[0];

ok(!utf8::is_utf8($p->{title}),       "title ist eine Byte-Zeichenkette (kein UTF8-Flag)");
ok(!utf8::is_utf8($p->{description}), "description ist eine Byte-Zeichenkette (kein UTF8-Flag)");

ok($p->{title} eq "H\x{c3}\x{bc}hnerklappe", "title enthaelt die unveraenderten UTF-8-Bytes");
ok($p->{description} eq "Steuert die T\x{c3}\x{bc}r \x{e2}\x{80}\x{a6}", "description enthaelt die unveraenderten UTF-8-Bytes");

# Kern des Bugs: Sprachstring (Bytes) + Katalogfeld in einer Ausgabe.
# Ergebnis muss byteweise gueltiges UTF-8 sein, nicht doppelt kodiert.
my $langstring = "Ben\x{c3}\x{b6}tigt LoxBerry ab Version";   # wie in language_de.ini
my $rendered   = "$langstring $p->{description}";
my $out        = "$dir/rendered.bin";
open(my $o, '>', $out) or die "out: $!";   # KEIN :encoding-Layer, wie CGI-STDOUT
print $o $rendered;
close($o);

open(my $i, '<:raw', $out) or die;
local $/; my $bytes = <$i>; close($i);

ok(index($bytes, "Ben\x{c3}\x{b6}tigt") >= 0, "Sprachstring bleibt einfach UTF-8-kodiert");
ok(index($bytes, "Ben\x{c3}\x{83}\x{c2}\x{b6}tigt") < 0, "Sprachstring ist NICHT doppelt kodiert (BenAe-Mojibake)");
ok(index($bytes, "\x{e2}\x{80}\x{a6}") >= 0, "Zeichen > U+00FF bleibt korrektes UTF-8");

print "\n$tests Tests, $fails Fehler\n";
exit($fails ? 1 : 0);
