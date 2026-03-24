# Requirements: LoxBerry NeXtGen

**Defined:** 2026-03-15
**Core Value:** LoxBerry muss zuverlässig und einfach bedienbar bleiben, während es unter der Haube modernisiert wird. Plugin-Kompatibilität ist nicht verhandelbar.

## v1 Requirements

### Security

- [ ] **SEC-01**: CSRF-Token-Validierung auf allen state-changing Endpoints (AJAX, CGI, PHP)
- [ ] **SEC-02**: Shell-Injection in admin.cgi behoben — Passwörter via STDIN statt Kommandozeile
- [ ] **SEC-03**: `fatalsToBrowser` durch strukturierte Fehlerseiten ersetzt (13 CGI-Scripts)
- [ ] **SEC-04**: JsonRPC-Endpoint von Denylist auf explizite Allowlist umgestellt
- [ ] **SEC-05**: SSL/TLS-Verifizierung für Miniserver-Kommunikation optional aktivierbar
- [ ] **SEC-06**: Input-Sanitisierung in ajax-generic.php/ajax-generic2.php vor Config-Write
- [ ] **SEC-07**: `plugininstall.pl` Pfad-Validierung mit striktem Regex für `$pfolder`

### UI/UX

- [ ] **UI-01**: Theme-System mit CSS Custom Properties (3-4 Themes: hell, dunkel, klassisch, auto)
- [ ] **UI-02**: Responsive Admin-UI — nutzbar auf Desktop, Tablet und Smartphone
- [ ] **UI-03**: Aufgeräumte Navigation — vereinfachte Menüstruktur mit logischer Gruppierung
- [ ] **UI-04**: jQuery/jQuery Mobile schrittweise durch Vue 3 ersetzen (Seite für Seite, kein Big Bang)
- [ ] **UI-05**: Tailwind CSS 3.4 als Utility-Framework für konsistentes Styling

### Backup

- [ ] **BAK-01**: Miniserver-Config automatisch sichern (Loxone-Konfiguration exportieren)
- [ ] **BAK-02**: LoxBerry Full-Backup — System, Plugins, Configs, Daten als Archiv
- [ ] **BAK-03**: Zeitgesteuerte Backups (täglich/wöchentlich/monatlich konfigurierbar)
- [ ] **BAK-04**: Backup-Ziele: lokaler Speicher, NAS (SMB), Cloud-Storage via rclone
- [ ] **BAK-05**: Backup-Restore über Web-UI anzeigen und auslösen
- [ ] **BAK-06**: Backup-Status und -Historie in der Admin-Oberfläche sichtbar

### Performance

- [ ] **PERF-01**: MQTT Gateway optimiert — Early-Filtering, Connection-Pooling, vorkompilierte Regexes
- [ ] **PERF-02**: `general.cfg` Regeneration entfernen — alle Leser auf `general.json` migrieren
- [ ] **PERF-03**: CloudDNS-Cache innerhalb Request-Lifetime cachen (nicht pro Call neu lesen)

### Infrastructure

- [ ] **INF-01**: Debian 13 (Trixie) Kompatibilität — Pakete, PHP 8.3, packages13.txt
- [ ] **INF-02**: Install-Script modernisiert — Dual Debian 12/13 Support, Sicherheitshärtung
- [ ] **INF-03**: Python API Foundation — Flask/FastAPI Skeleton mit Apache ProxyPass
- [ ] **INF-04**: Code-Aufräumung: ajax-generic2.php merge, System_v1.pm archivieren, Dead Code entfernen, Debug-STDERR gaten
- [ ] **INF-05**: Test-Infrastruktur: pytest für Perl/Python Core-Module, Vitest für Vue-Komponenten

### Developer Experience

- [ ] **DX-01**: PLUGIN_API.md — Kompatibilitätsvertrag dokumentiert (frozen SDK surface)
- [ ] **DX-02**: Python SDK Spezifikation und Decommission-Schedule für abgelöste Perl/PHP-Module

## v2 Requirements

### Advanced UI

- **UI-V2-01**: Dashboard mit System-Status-Widgets (CPU, RAM, Disk, MQTT-Traffic)
- **UI-V2-02**: MQTT Gateway Health Dashboard mit Live-Metriken

### Advanced Backup

- **BAK-V2-01**: Verschlüsselte Backups (at rest)
- **BAK-V2-02**: Backup-Retention-Policies (automatisches Löschen alter Backups)
- **BAK-V2-03**: Selective Restore (einzelne Plugins/Configs wiederherstellen)

### Platform

- **INF-V2-01**: Debian 14 (Forky) Vorbereitung
- **INF-V2-02**: Python Plugin Scaffold — Plugins in Python schreiben

## Out of Scope

| Feature | Reason |
|---------|--------|
| Komplett-Rewrite in Python | Schrittweise Migration statt Big Bang — Risiko und Aufwand zu hoch |
| Docker/Container für Plugins | Raspberry Pi 1 GB RAM reicht nicht für Container-Overhead |
| Custom Theme Editor | Wartungsaufwand; vordefinierte Themes decken Bedarf ab |
| Mobile App | Web-first, responsive UI reicht für v1 |
| Real-time Device Dashboard | Scope-Falle, hohe Komplexität, nicht Core-Funktion |
| Cloud-Account-System | Widerspricht der lokalen Philosophie von LoxBerry |
| Tailwind CSS v4 | Browser-Floor zu hoch (Chrome 111+), unsicher für Admin-Panel mit diversen Clients |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEC-01 | Phase 1 | Pending |
| SEC-02 | Phase 1 | Pending |
| SEC-03 | Phase 1 | Pending |
| SEC-04 | Phase 1 | Pending |
| SEC-05 | Phase 1 | Pending |
| SEC-06 | Phase 1 | Pending |
| SEC-07 | Phase 1 | Pending |
| PERF-01 | Phase 2 | Pending |
| PERF-03 | Phase 2 | Pending |
| UI-01 | Phase 3 | Pending |
| UI-02 | Phase 3 | Pending |
| UI-03 | Phase 3 | Pending |
| UI-05 | Phase 3 | Pending |
| INF-04 | Phase 4 | Pending |
| PERF-02 | Phase 4 | Pending |
| INF-03 | Phase 5 | Pending |
| BAK-01 | Phase 6 | Pending |
| BAK-02 | Phase 6 | Pending |
| BAK-03 | Phase 6 | Pending |
| BAK-04 | Phase 6 | Pending |
| BAK-05 | Phase 6 | Pending |
| BAK-06 | Phase 6 | Pending |
| UI-04 | Phase 7 | Pending |
| INF-01 | Phase 8 | Pending |
| INF-02 | Phase 8 | Pending |
| INF-05 | Phase 8 | Pending |
| DX-01 | Phase 8 | Pending |
| DX-02 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---
*Requirements defined: 2026-03-15*
*Last updated: 2026-03-15 — traceability mapped after roadmap creation*
