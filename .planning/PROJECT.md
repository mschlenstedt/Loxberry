# LoxBerry NeXtGen

## What This Is

Eine umfassende Modernisierung des LoxBerry-Projekts — der Raspberry Pi-basierten Smart Home Erweiterung für Loxone Miniserver. Ziel ist ein zeitgemäßes, sicheres und wartbares System mit modernem UI, schrittweiser Python-Migration und neuen Backup-Funktionen. Das Ergebnis soll als Proposal an die Core-Entwickler des Original-Projekts (mschlenstedt/Loxberry) gehen.

## Core Value

LoxBerry muss zuverlässig und für alle Nutzer — vom Bastler bis zum Endanwender — einfach bedienbar bleiben, während es unter der Haube modernisiert wird. Rückwärtskompatibilität mit bestehenden Plugins ist nicht verhandelbar.

## Requirements

### Validated

<!-- Existing capabilities inferred from codebase map -->

- ✓ Plugin-System mit Standard-Scaffold und Shared SDK (Perl, PHP, Python, Bash) — existing
- ✓ Miniserver-Kommunikation via HTTP, UDP, MQTT über LoxBerry::IO — existing
- ✓ Web-Administration mit HTTP Basic Auth (öffentlich + authentifiziert) — existing
- ✓ MQTT Gateway für Broker-Management und Message-Routing — existing
- ✓ Plugin-Installation/-Deinstallation über Web-UI — existing
- ✓ Logging-System mit Severity-Levels und Notifications — existing
- ✓ Systemkonfiguration über general.json mit Web-Editor — existing
- ✓ Multi-Miniserver-Support — existing
- ✓ CloudDNS-Auflösung für Remote-Zugriff — existing
- ✓ Health-Check-System für Systemüberwachung — existing

### Active

<!-- New scope for this modernization effort -->

- [ ] Modernes, responsive UI-Design mit Theme-System (3-4 vordefinierte Themes: hell, dunkel, klassisch)
- [ ] Sicherheitshärtung: CSRF-Schutz, Input-Sanitisierung, Shell-Injection-Fixes
- [ ] Performance-Optimierung: MQTT Gateway, Config-Handling, Connection-Pooling
- [ ] Schrittweise Python-Migration: Neue Features in Python, bestehendes Perl/PHP nach und nach ablösen
- [ ] Miniserver-Config-Backup: Automatische Sicherung der Loxone-Konfiguration
- [ ] LoxBerry Full-Backup: Komplettes System-Backup inkl. Plugins, Configs, Daten
- [ ] Scheduled Backups: Zeitgesteuerte automatische Backups
- [ ] Backup-Ziele: NAS, Cloud-Storage, externer Speicher
- [ ] Code-Aufräumung: Duplizierter Code, Dead Code, Legacy-Module entfernen
- [ ] jQuery/jQuery Mobile Migration auf moderne Frontend-Libs (Vue 3 bereits teilweise vorhanden)
- [ ] Test-Infrastruktur für Core-Module aufbauen
- [ ] SSL/TLS-Verifizierung optional aktivierbar machen
- [ ] Debian 13 (Trixie) Kompatibilität: Pakete, PHP 8.3, Kernel-Anpassungen
- [ ] Install-Script Modernisierung: Optimierter Installer mit Debian 12/13 Dual-Support, Sicherheitshärtung

### Out of Scope

- Komplett-Neuentwicklung in Python — schrittweise Migration statt Big Bang
- Neues Plugin-API mit Breaking Changes — bestehende Plugins müssen weiter funktionieren
- Custom-Theme-Editor für Endanwender — nur vordefinierte Themes
- Mobile App — Web-first Ansatz

## Context

- **Codebase-Zustand:** ~1264 Dateien, primär Perl 5.36 + PHP 7.4/8.2, Bash, etwas Python. jQuery 1.12.4 (EOL) als Frontend-Basis. Kein Test-Framework im Einsatz.
- **Bekannte Probleme:** Shell Injection in admin.cgi, kein CSRF-Schutz, SSL-Verifizierung deaktiviert, doppelte AJAX-Handler, 60+ veraltete Migrationsscripts, monolithischer MQTT Gateway (1592 Zeilen).
- **Bestehende Optimierung:** `mqttgateway_optimized.pl` liegt vor mit 7 Performance-Fixes (Early-Filtering, Connection-Pooling, Caching, vorkompilierte Regexes).
- **Bestehender Installer:** `install_fast.sh` — optimiertes Install-Script (1x apt-update, batch-Paketinstallation, 1x daemon-reload). Zielt auf Debian 12/DietPi. Muss auf Debian 13 Trixie erweitert werden.
- **Debian-Stand:** Debian 13 Trixie seit August 2025 stable, DietPi unterstützt Trixie seit v9.16. PHP 8.3 ist Standard in Trixie.
- **Ziel:** Professionelles Proposal für Core-Entwickler mit priorisierter Roadmap. Die Entwickler entscheiden, welche Phasen umgesetzt werden.
- **Fork:** strike1988/Loxberry (Fork von mschlenstedt/Loxberry), aktuell synchron mit upstream master.

## Constraints

- **Kompatibilität**: Alle bestehenden Plugins müssen weiter funktionieren — keine Breaking Changes am Plugin-SDK
- **Hardware**: Muss auf Raspberry Pi (1 GB RAM) performant laufen — keine ressourcenhungrigen Frameworks
- **Schrittweise**: Änderungen müssen als einzelne Pull Requests einreichbar sein — kein monolithischer Umbau
- **Community**: Proposal muss für Core-Entwickler nachvollziehbar und diskutierbar sein

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Schrittweise Python-Migration statt Komplett-Rewrite | Rückwärtskompatibilität, realistischer Aufwand, Community-Akzeptanz | — Pending |
| Vue 3 als Frontend-Framework | Bereits teilweise im Einsatz (vue3.js vorhanden), ersetzt jQuery/jQuery Mobile | — Pending |
| Theme-System mit vordefinierten Themes | Wartbar, konsistent, deckt Nutzerwünsche ab ohne Komplexität eines Theme-Editors | — Pending |
| Backup als neue Core-Funktion statt Plugin | Miniserver-Backup und System-Backup sind fundamental genug für Core-Integration | — Pending |
| PR-basierter Workflow | Jede Phase wird als eigenständiger Pull Request eingereicht und diskutiert | — Pending |
| Debian 13 Trixie als primäres Ziel | Bookworm wird Debian oldstable im Juni 2026, Trixie ist Zukunft | — Pending |

---
*Last updated: 2026-03-15 after adding Debian 13 Trixie + Installer requirements*
