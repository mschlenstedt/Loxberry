# LoxBerry NeXtGen — Modernisierung Proposal

**Erstellt:** 2026-03-15
**Autor:** Strike1988 (Fork: strike1988/Loxberry)
**Basis:** Codebase-Audit + Research der aktuellen Best Practices

---

## Zusammenfassung

LoxBerry funktioniert — aber unter der Haube hat sich über die Jahre einiges angestaut: Sicherheitslücken, veraltete Libraries, doppelter Code, fehlende Tests. Dieses Dokument zeigt, was gemacht werden sollte, wie aufwendig es ist, und in welcher Reihenfolge es Sinn ergibt.

---

## Quick Wins (wenig Aufwand, hoher Effekt)

Diese Änderungen sind klein, risikoarm und sofort als PRs einreichbar.

### 🟢 MQTT Gateway Performance (1-2 PRs)
**Aufwand:** Gering — optimierte Datei liegt bereits vor
**Was:** 7 Performance-Fixes: Early-Filtering vor JSON-Expansion, HTTP Connection-Pooling, Miniserver-Config-Cache, vorkompilierte Regexes, eigene Topics filtern (stoppt 404-Lawine), Hash::Flatten einmal instanziieren, JSON::XS bevorzugen
**Effekt:** Spürbar weniger CPU-Last und Log-Noise bei hohem MQTT-Traffic
**Risiko:** Niedrig — rückwärtskompatibel, gleiche Config, gleiches Verhalten

### 🟢 Debug-Noise entfernen (1 PR)
**Aufwand:** Gering — 63 print STDERR Statements gaten
**Was:** Unconditional `print STDERR` in CGI-Scripts hinter `$DEBUG` Flag setzen
**Effekt:** Saubere Error-Logs, echte Fehler werden sichtbar
**Risiko:** Minimal

### 🟢 Shell-Injection Fix in admin.cgi (1 PR)
**Aufwand:** Gering — Passwörter via STDIN statt Kommandozeile übergeben
**Was:** `qx(sudo ... '$password')` → `system LIST` Form oder STDIN-Pipe
**Effekt:** Kritische Sicherheitslücke geschlossen
**Risiko:** Niedrig — nur interne Aufrufe betroffen

### 🟢 fatalsToBrowser entfernen (1 PR)
**Aufwand:** Gering — 13 CGI-Scripts, gleiche Änderung überall
**Was:** `CGI::Carp qw(fatalsToBrowser)` durch strukturierte Fehlerseite ersetzen
**Effekt:** Keine Stack Traces mehr im Browser, Pfade/Variablen nicht mehr exponiert
**Risiko:** Niedrig

### 🟢 Doppelte AJAX-Handler mergen (1 PR)
**Aufwand:** Gering — ajax-generic2.php in ajax-generic.php zusammenführen
**Was:** Zwei fast identische Dateien zu einer zusammenführen
**Effekt:** Kein doppelter Wartungsaufwand mehr, keine Divergenz
**Risiko:** Niedrig — Funktionalität identisch

### 🟢 jsonrpc.php Logging entschärfen (1 PR)
**Aufwand:** Minimal — 2 Zeilen ändern
**Was:** Unconditional `error_log()` von Request/Response-Bodies entfernen oder hinter Debug-Flag
**Effekt:** Keine Passwörter/Credentials mehr im Apache Error Log
**Risiko:** Minimal

---

## Mittlerer Aufwand (gut planbar, klarer Scope)

### 🟡 CSRF-Schutz (2-3 PRs)
**Aufwand:** Mittel — Token-System implementieren + Plugin-Bypass-Mechanismus
**Was:** CSRF-Token-Validierung auf allen state-changing Endpoints
**Effekt:** Schutz gegen Cross-Site Angriffe (fehlt komplett!)
**Risiko:** Mittel — braucht Plugin-Bypass damit localhost-Aufrufe weiter funktionieren
**Abhängigkeit:** Plugin-Entwickler müssen informiert werden

### 🟡 JsonRPC Allowlist (1-2 PRs)
**Aufwand:** Mittel — Denylist durch explizite Allowlist ersetzen
**Was:** Nur noch explizit freigegebene Methoden über JsonRPC aufrufbar
**Effekt:** Neue Funktionen sind nicht mehr automatisch exponiert
**Risiko:** Mittel — muss gegen tatsächlich genutzte Methoden validiert werden

### 🟡 general.cfg abschaffen (2-3 PRs)
**Aufwand:** Mittel — alle Leser auf general.json migrieren, Shim entfernen
**Was:** Dual-Config-Format (seit v2.0.2 mitgeschleppt) endgültig bereinigen
**Effekt:** Kein synchroner Subprocess mehr bei jedem Config-Write
**Risiko:** Mittel — Update-Scripts in sbin/loxberryupdate/ müssen geprüft werden

### 🟡 Theme-System via CSS Custom Properties (2-3 PRs)
**Aufwand:** Mittel — CSS-Layer in head.html, Theme-Toggle, Persistenz
**Was:** 3-4 vordefinierte Themes (hell, dunkel, klassisch, auto) — kein JavaScript nötig
**Effekt:** Sofort sichtbare Modernisierung, Plugins erben Themes automatisch
**Risiko:** Niedrig — rein additiv, bricht nichts

### 🟡 SSL/TLS-Verifizierung optional machen (1-2 PRs)
**Aufwand:** Mittel — IO.pm/loxberry_io.php anpassen + Admin-UI Option pro Miniserver
**Was:** SSL_verify_mode und verify_hostname konfigurierbar statt hartcodiert auf 0
**Effekt:** MITM-Schutz für Miniserver-Kommunikation möglich
**Risiko:** Niedrig — optional, Standard bleibt wie bisher

### 🟡 Debian 13 Trixie Support (2-3 PRs)
**Aufwand:** Mittel — packages13.txt erstellen, PHP 8.3 testen, Installer erweitern
**Was:** Install-Script erkennt Debian 12 und 13, wählt passende Pakete
**Effekt:** Zukunftssicher — Bookworm wird Juni 2026 oldstable
**Risiko:** Niedrig — additiv, Debian 12 bleibt unterstützt

---

## Größere Vorhaben (mehrere PRs, braucht Planung)

### 🟠 Responsive Admin-UI + Navigation (3-5 PRs)
**Aufwand:** Hoch — Layout-Anpassungen über alle Admin-Seiten
**Was:** Admin-UI auf Mobilgeräten nutzbar, Menü-Struktur vereinfachen
**Effekt:** Moderne UX, LoxBerry vom Handy aus bedienbar
**Risiko:** Mittel — betrifft viele Templates
**Voraussetzung:** Theme-System sollte zuerst stehen

### 🟠 Python API Layer (3-4 PRs)
**Aufwand:** Hoch — Flask-Service, systemd-Unit, Apache ProxyPass, Config-Modul
**Was:** Python-Backend neben Perl/PHP einführen (Strangler Fig Pattern)
**Effekt:** Neue Features können in Python geschrieben werden
**Risiko:** Mittel — muss sauber neben dem bestehenden System laufen
**Voraussetzung:** Code-Cleanup sollte vorher abgeschlossen sein

### 🟠 Backup-System (4-5 PRs)
**Aufwand:** Hoch — Miniserver-API, System-Backup, Scheduler, NAS-Integration, UI
**Was:** Miniserver-Config-Backup (Alleinstellungsmerkmal!), Full-Backup, Zeitsteuerung, NAS/Cloud-Ziele via rclone
**Effekt:** Feature das kein anderes Smart-Home-System für Loxone bietet
**Risiko:** Mittel — Miniserver-API muss geprüft werden
**Voraussetzung:** Python API Layer

### 🟠 Test-Infrastruktur (3-4 PRs)
**Aufwand:** Hoch — pytest für Perl/Python, Vitest für Vue, CI-Pipeline
**Was:** Automatisierte Tests für LoxBerry::System, ::IO, ::Log + PHP-Pendants
**Effekt:** Regressions werden erkannt bevor sie Plugins brechen
**Risiko:** Niedrig — rein additiv
**Hinweis:** Eigentlich Grundvoraussetzung für alles andere

---

## Langfristig (Vision, braucht Community-Abstimmung)

### 🔴 jQuery Mobile → Vue 3 Migration (5+ PRs)
**Aufwand:** Sehr hoch — Seite für Seite, Build-Pipeline nötig
**Was:** jQuery 1.12.4 + jQuery Mobile 1.4.0 (beide EOL!) durch Vue 3 ersetzen
**Effekt:** Moderne, wartbare Frontend-Architektur
**Risiko:** Hoch — jQuery Mobile ist tief in jeder Seite verankert
**Strategie:** Strangler Fig — eine Seite pro PR, jQuery bleibt bis die letzte Seite migriert ist
**Wichtig:** Build läuft nur in CI, NICHT auf dem Pi (1 GB RAM → OOM)

### 🔴 Python SDK + Plugin-Scaffold (2-3 PRs)
**Aufwand:** Hoch — SDK spezifizieren, dokumentieren, Decommission-Schedule erstellen
**Was:** Offizielle Python-API für Plugin-Entwickler, klarer Ablöseplan für Perl/PHP
**Effekt:** Plugin-Entwickler können in Python arbeiten
**Risiko:** Mittel — braucht klaren Kompatibilitätsvertrag (PLUGIN_API.md)

---

## Empfohlene Reihenfolge

```
SOFORT MACHBAR          MITTELFRISTIG              LANGFRISTIG
─────────────          ──────────────             ────────────
Shell-Injection Fix     CSRF-Schutz                Vue 3 Migration
fatalsToBrowser weg     JsonRPC Allowlist           Python SDK
Debug-Noise gaten       general.cfg abschaffen
MQTT Gateway Optim.     Theme-System
AJAX-Handler mergen     SSL/TLS optional
jsonrpc Logging fix     Debian 13 Support
                        Responsive UI
                        Python API Layer
                        Backup-System
                        Test-Infrastruktur
```

## Grundprinzipien

1. **Plugin-Kompatibilität ist heilig** — keine Breaking Changes am SDK
2. **Ein PR = ein Thema** — reviewbar in unter 30 Minuten
3. **Strangler Fig statt Big Bang** — Neues wächst neben dem Alten
4. **Raspberry Pi Limits respektieren** — 1 GB RAM, kein Build-Tooling auf dem Gerät
5. **Sicherheit zuerst** — ohne Security-Fixes nimmt kein Entwickler den Rest ernst

---

## Bekannte offene Fragen

- Welche Plugins nutzen `LoxBerry::System_v1.pm`? → Plugin-Registry scannen
- Miniserver HTTP API für Config-Export — welche Endpoints genau?
- Community-Präferenz für NAS-Backup: SMB vs NFS vs WebDAV?
- Flask vs FastAPI für Python-Layer — RAM-Messung auf echtem Pi nötig
- Minimale Browser-Version für Admin-UI? → Entscheidet Tailwind v3.4 vs v4

---

*Basierend auf einem automatisierten Codebase-Audit (1264 Dateien) und Research zu Best Practices für Smart Home Platform Modernisierung.*
