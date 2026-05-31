# tests/appstore/appstore.t
use strict; use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../../libs/perllib";
use File::Temp qw(tempdir);
use JSON::PP;

use_ok('LoxBerry::AppStore');

my $dir = tempdir(CLEANUP => 1);
my $fallback = "$dir/fallback.json";
open(my $fh, '>:encoding(UTF-8)', $fallback) or die $!;
print $fh encode_json({
  generated => "x", source => "test",
  plugins => [
    { pid=>"plugins:a:start", title=>"Alpha", author=>"Bob", status=>"STABLE",
      version=>"1.0", zip=>"https://x/a.zip", repo=>"", description=>"d",
      languages=>"DE", logo=>"", forum=>"", lastmodified=>"" },
    { pid=>"plugins:b:start", title=>"Beta", author=>"Sue", status=>"BETA",
      version=>"2.0", zip=>"", repo=>"https://github.com/x/b", description=>"d",
      languages=>"EN", logo=>"", forum=>"", lastmodified=>"" },
  ],
}); close($fh);

# load_catalog: unreachable URL -> fallback
my ($cat, $src) = LoxBerry::AppStore::load_catalog(
  "http://127.0.0.1:9/none.json", $fallback, "$dir/cache.json");
is($src, "fallback", "falls back when URL unreachable");
is(scalar @{$cat->{plugins}}, 2, "loaded 2 plugins from fallback");

# classify: zip -> installable, repo-only -> not
LoxBerry::AppStore::classify($_) for @{$cat->{plugins}};
is($cat->{plugins}[0]{installable}, 1, "zip plugin installable");
is($cat->{plugins}[1]{installable}, 0, "repo-only not installable");
is($cat->{plugins}[0]{badge_class}, "ok", "STABLE -> ok badge");
is($cat->{plugins}[1]{badge_class}, "beta", "BETA -> beta badge");

# mark_installed: match by NORMALIZED TITLE only (author may differ between
# wiki catalog and local plugin DB; spaces/case must not break the match).
my @installed = ( { PLUGINDB_TITLE=>"alpha", PLUGINDB_AUTHOR_NAME=>"someone-else",
                    PLUGINDB_VERSION=>"0.9" } );
LoxBerry::AppStore::mark_installed($cat, \@installed);
is($cat->{plugins}[0]{is_installed}, 1, "Alpha matched by title despite different author");
is($cat->{plugins}[0]{installed_version}, "0.9", "installed version captured");
is($cat->{plugins}[1]{is_installed}, 0, "Beta not installed");

# Titel mit Leerzeichen/Schreibvariante muss auf kompakten Katalog-Titel matchen
{
  my $cat2 = { plugins => [
    { title => "Weather4Loxone", author => "janw", zip => "https://x/w.zip", status => "STABLE" },
  ] };
  my @inst2 = ( { PLUGINDB_TITLE => "Weather 4 Loxone", PLUGINDB_AUTHOR_NAME => "x",
                  PLUGINDB_VERSION => "4.9" } );
  LoxBerry::AppStore::mark_installed($cat2, \@inst2);
  is($cat2->{plugins}[0]{is_installed}, 1, "'Weather 4 Loxone' matches 'Weather4Loxone'");
}

# Cache-Schreibfehler darf nicht crashen: ungueltiger Cache-Pfad
{
  my ($c2, $s2) = LoxBerry::AppStore::load_catalog(
    "http://127.0.0.1:9/none.json", $fallback, "/nonexistent_dir/cache.json");
  is($s2, "fallback", "unwritable cache path still yields fallback, no crash");
}

# classify: nur http(s)-URLs sind installierbar (Schutz vor javascript:/file: etc.)
{
  my $evil = { zip => "javascript:alert(1)", status => "STABLE" };
  LoxBerry::AppStore::classify($evil);
  is($evil->{installable}, 0, "non-http(s) zip is not installable");
  my $good = { zip => "https://example.com/x.zip", status => "STABLE" };
  LoxBerry::AppStore::classify($good);
  is($good->{installable}, 1, "https zip is installable");
}

# Katalog mit Nicht-ASCII (Umlaute, …) muss laden — Regression gegen
# Doppel-Dekodierung in _read_json (Raw-Bytes statt :encoding-Schicht).
{
  my $uf = "$dir/fallback_utf8.json";
  open(my $ufh, '>:raw', $uf) or die $!;
  print $ufh JSON::PP::encode_json({
    generated => "x", source => "test",
    plugins => [
      { pid=>"plugins:u:start", title=>"Grünbeck", author=>"Jörg",
        status=>"STABLE", version=>"1.0", zip=>"https://x/u.zip", repo=>"",
        description=>"Liest Sensoren aus … und sendet Werte.",
        languages=>"DE", logo=>"", forum=>"", lastmodified=>"" },
    ],
  });
  close($ufh);
  my ($uc, $us) = LoxBerry::AppStore::load_catalog("", $uf, "$dir/cache_utf8.json");
  is($us, "fallback", "utf8 catalog loads from fallback");
  is(scalar @{$uc->{plugins}}, 1, "utf8 catalog has 1 plugin (no decode crash)");
}

# TTL: ein frischer Cache wird OHNE Netzwerk-Zugriff verwendet (Quelle "cache").
# Cache hat andere Plugin-Anzahl als Fallback, damit die Herkunft erkennbar ist.
{
  my $cachep = "$dir/ttl_cache.json";
  open(my $cf, '>:raw', $cachep) or die $!;
  print $cf JSON::PP::encode_json({
    generated => "x", source => "cache",
    plugins => [ { pid=>"plugins:c:start", title=>"Cached", author=>"x",
      status=>"STABLE", version=>"1.0", zip=>"https://x/c.zip", repo=>"",
      description=>"d", languages=>"DE", logo=>"", forum=>"", lastmodified=>"" } ],
  });
  close($cf);

  # Frischer Cache + TTL 60 -> Cache, kein Fetch-Versuch (URL waere unerreichbar).
  my ($fc, $fs) = LoxBerry::AppStore::load_catalog(
    "http://127.0.0.1:9/none.json", $fallback, $cachep, 60);
  is($fs, "cache", "fresh cache used without hitting the network");
  is(scalar @{$fc->{plugins}}, 1, "data came from cache (1 plugin), not fallback (2)");

  # Cache kuenstlich veralten + unerreichbare URL -> veralteter Cache wird genutzt.
  my $old = time() - 3600 * 24;
  utime($old, $old, $cachep);
  my ($sc, $ss) = LoxBerry::AppStore::load_catalog(
    "http://127.0.0.1:9/none.json", $fallback, $cachep, 60);
  is($ss, "cache", "stale cache still used when wiki unreachable");
}

done_testing();
