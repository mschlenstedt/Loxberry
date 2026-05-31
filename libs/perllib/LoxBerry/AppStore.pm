# libs/perllib/LoxBerry/AppStore.pm
package LoxBerry::AppStore;
use strict; use warnings;
use JSON::PP ();

our $VERSION = "0.1.0";

my %BADGE = (
  STABLE => "ok", BETA => "beta", UNSTABLE => "warn",
  ALPHA => "warn", STOPPED => "stop", "" => "unknown",
);

# load_catalog($url, $fallback_path, $cache_path, $ttl_minutes) -> ($hashref, $source)
# $source ∈ cache|live|fallback|empty. Reihenfolge:
#   1) Frischer Cache (juenger als TTL) -> kein Netzwerk-Zugriff.
#   2) Live-Fetch vom Wiki (curl) -> Cache aktualisieren.
#   3) Veralteter Cache (Wiki nicht erreichbar) -> trotzdem nutzen.
#   4) Mitgelieferter (im Git evtl. leerer) Default-Katalog.
#   5) Gar nichts brauchbar -> leerer Katalog, source "empty" (NIE Exception).
# So wird das Wiki nur alle $ttl_minutes (Default 60) befragt statt bei jedem
# Seitenaufruf; der eigentliche Refresh haengt am Plugin-Update-Check.
# Toleriert auch ein leeres Default-JSON ({} oder {"plugins":[]}) ohne Fehler.
sub load_catalog {
    my ($url, $fallback, $cache, $ttl_minutes) = @_;
    $ttl_minutes = 60 unless defined $ttl_minutes && $ttl_minutes =~ /^\d+$/;

    # 1) frischer Cache -> ohne Netzwerk verwenden (nur wenn nicht leer)
    if ($cache && -e $cache && _cache_age_minutes($cache) < $ttl_minutes) {
        my $data = _read_json($cache);
        return ($data, "cache") if _has_plugins($data);
    }

    # 2) Live-Fetch via curl in den Cache (kurzes Timeout, fail-soft)
    if ($url) {
        my $safe = $url; $safe =~ s/'/'"'"'/g;
        my $tmp = "$cache.tmp";
        my $rc = system("curl -fsSLk --connect-timeout 5 --max-time 15 -o '$tmp' '$safe'");
        if ($rc == 0 && -s $tmp) {
            my $data = _read_json($tmp);
            if ($data && ref $data->{plugins} eq 'ARRAY') {
                # Cache-Schreiben darf den Live-Pfad nicht abbrechen, falls das
                # Verzeichnis nicht beschreibbar ist (z.B. falscher User/Rechte).
                eval { rename($tmp, $cache); 1 } or unlink($tmp);
                return ($data, "live");
            }
        }
        unlink($tmp) if -e $tmp;
    }

    # 3) veralteter Cache (Wiki nicht erreichbar) -> trotzdem nutzen
    if ($cache && -e $cache) {
        my $data = _read_json($cache);
        return ($data, "cache") if _has_plugins($data);
    }

    # 4) mitgelieferter Default-Katalog (kann leer sein)
    my $data = _read_json($fallback);
    return ($data, "fallback") if _has_plugins($data);

    # 5) nichts Brauchbares gefunden -> leerer Katalog statt Exception.
    return ({ plugins => [] }, "empty");
}

# Wahr, wenn $data ein nicht-leeres plugins-Array enthaelt.
sub _has_plugins {
    my ($data) = @_;
    return ($data && ref $data->{plugins} eq 'ARRAY' && @{$data->{plugins}}) ? 1 : 0;
}

# Alter einer Cache-Datei in Minuten (sehr gross, wenn nicht vorhanden).
sub _cache_age_minutes {
    my ($path) = @_;
    my $mtime = (stat($path))[9];
    return 1e9 unless defined $mtime;
    return (time() - $mtime) / 60;
}

sub _read_json {
    my ($path) = @_;
    return undef unless $path && -e $path;
    # Raw-Bytes lesen (KEINE :encoding-Schicht): JSON::PP::decode_json erwartet
    # UTF-8-Bytes und dekodiert selbst. Mit einer :encoding(UTF-8)-Schicht waere
    # es doppelt dekodiert und wuerde bei Umlauten/Sonderzeichen fehlschlagen.
    open(my $fh, '<:raw', $path) or return undef;
    local $/; my $c = <$fh>; close($fh);
    my $data = eval { JSON::PP::decode_json($c) };
    return $data;
}

# classify($plugin) -> mutates: installable, badge_class
sub classify {
    my ($p) = @_;
    # Nur ueber http(s) installierbar — schuetzt vor javascript:/file:/ftp:-URLs
    # aus dem (community-editierbaren) Wiki-Katalog.
    $p->{installable} = ($p->{zip} && $p->{zip} =~ m{^https?://}i) ? 1 : 0;
    my $st = uc($p->{status} // "");
    $p->{badge_class} = $BADGE{$st} // "unknown";
    return $p;
}

# mark_installed($catalog, \@installed) -> mutates each plugin: is_installed, installed_version
# Abgleich ueber den normalisierten Titel (NICHT zusaetzlich Autor): die
# Autorennamen weichen zwischen Wiki-Katalog und lokaler Plugin-DB regelmaessig
# ab (z.B. Wiki "janw" vs. lokal anders), wodurch ein Titel+Autor-Schluessel
# fast nie matcht. Der Titel ist im LoxBerry-Oekosystem praktisch eindeutig.
sub mark_installed {
    my ($cat, $installed) = @_;
    my %byname;
    for my $ip (@$installed) {
        my $key = _key($ip->{PLUGINDB_TITLE});
        next unless $key ne "";
        $byname{$key} = $ip->{PLUGINDB_VERSION} // "";
    }
    for my $p (@{$cat->{plugins}}) {
        my $key = _key($p->{title});
        if ($key ne "" && exists $byname{$key}) {
            $p->{is_installed} = 1;
            $p->{installed_version} = $byname{$key};
        } else {
            $p->{is_installed} = 0;
            $p->{installed_version} = "";
        }
    }
    return $cat;
}

# version_ok($current, $min) -> 1|0
# Erfuellt die laufende LoxBerry-Version $current die geforderte Mindestversion
# $min? LoxBerry-Versionen sind punktgetrennte Zahlen (z.B. "3.0.1.3", "2.2.1");
# der Vergleich laeuft feldweise numerisch, fehlende Felder zaehlen als 0
# ("3.0" == "3.0.0"). Leeres/undef $min bedeutet keine Anforderung -> 1.
# Nicht in Zahlen zerlegbare Versionen sperren NICHT (-> 1), um False-Positives
# (faelschlich gesperrte Installs) zu vermeiden.
sub version_ok {
    my ($current, $min) = @_;
    return 1 unless defined $min && $min ne "";
    return 1 unless defined $current && $current ne "";
    my @c = _vparts($current);
    my @m = _vparts($min);
    return 1 unless @c && @m;   # nicht parsebar -> nicht sperren
    my $n = @c > @m ? scalar(@c) : scalar(@m);
    for my $i (0 .. $n - 1) {
        my $a = $c[$i] // 0;
        my $b = $m[$i] // 0;
        return 1 if $a > $b;
        return 0 if $a < $b;
    }
    return 1;   # alle Felder gleich -> erfuellt
}

# Zerlegt eine punktgetrennte Versionszeichenkette in numerische Felder.
# Fuehrendes "v" wird entfernt; Ergebnis ist leer, wenn keine Ziffern enthalten.
sub _vparts {
    my ($v) = @_;
    $v =~ s/^v//i;
    return ($v =~ /(\d+)/g);
}

# Normalisiert einen Plugin-Titel auf einen vergleichbaren Schluessel:
# Kleinbuchstaben, alle Nicht-Alphanumerischen entfernt.
# "Weather 4 Loxone" / "Weather4Loxone" -> "weather4loxone".
sub _key {
    my ($title) = @_;
    $title = lc($title // "");
    $title =~ s/[^a-z0-9]+//g;
    return $title;
}

1;
