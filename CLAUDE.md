# LoxBerry NeXtGen — Projektkontext

## Was ist LoxBerry?

Smart-Home-Plattform für Loxone Miniservers, läuft auf Raspberry Pi (Debian). Plugin-basiert, Core in Perl/PHP, WebUI mit HTML::Template + lb-* Design-System. jQuery Mobile wurde für Core-Seiten entfernt (bleibt für Plugins). Fork von `mschlenstedt/Loxberry`.

## Aktive Branches

- `master` — Upstream-Sync mit mschlenstedt/Loxberry
- `feature/theme-refresh-dragdrop` — Hauptarbeitsbranch: CSS Design-System, Mobile Tab Bar, jQM-Removal, MQTT Gateway V2, Python-Daemon

## Projektstruktur

```
sbin/                    # Perl-Daemons (mqttgateway.pl, mqtt-handler.pl, mqttfinder.pl)
sbin/mqttgateway/        # Python-Daemon (NEU) — asyncio, V2-only
templates/system/        # HTML::Template (.html) — WebUI Templates
webfrontend/htmlauth/    # CGI-Scripts (.cgi) + AJAX-Handler (.php)
webfrontend/html/        # Statische Assets (CSS, JS, Images)
libs/perllib/            # Perl-Module (LoxBerry::System, ::IO, ::JSON, ::Log)
libs/phplib/             # PHP-Bibliotheken
libs/pythonlib/          # Python-Bibliotheken (noch minimal)
config/system/           # JSON-Configs (general.json, mqttgateway.json)
vorarbeit/               # Entwürfe, Analysen, Interview-Materialien
docs/                    # Design-Mockups, Specs, Pläne (gitignored, muss mit -f added werden)
```

## Coding-Konventionen

### Allgemein
- **Indentation:** Tabs, Größe 4 (siehe .editorconfig)
- **Sprache im Code:** Englisch (Variablen, Funktionen, Kommentare)
- **Sprache in UI:** Deutsch als Standard, i18n über language_de.ini / language_en.ini
- **Umlaute:** Immer echte Umlaute verwenden (ä ö ü ß), nie ae oe ue ss
- **Encoding:** UTF-8 überall, bei Deploy auf LoxBerry CRLF → LF konvertieren

### CSS / Design-System
- Neue Klassen: `lb-*` Präfix (lb-btn, lb-section-title, lb-form-row, lb-table, lb-disabled, lb-tab-bar, lb-collapsible)
- Themes nur über CSS Custom Properties (`var(--lb-*)` aus design-tokens.css)
- jQuery Mobile JS+Structure CSS wird für Core-Seiten NICHT geladen (nur loxberry.css Theme-CSS bleibt)
- jQuery Mobile bleibt für Plugin-Seiten vollständig aktiv (IS_CORE_PAGE Steuerung in Web.pm/head.html)
- jQM-Overrides in components.css Sektion 1 auf `.lb-layout` gescoped (bricht nicht Plugin-Seiten)
- Icons: PrimeIcons (`pi pi-*`)
- `ui-disabled` → `lb-disabled` verwenden (opacity + pointer-events)
- jQM Popup → native `<dialog>` mit `lb-modal` Klasse + `.showModal()`
- jQM Collapsible → native `<details>`/`<summary>` mit `lb-collapsible` Klasse
- MQTT Gateway V1-WebUI (mqtt-gateway.html) muss jQM-migriert werden — V1 bleibt!

### Python (sbin/mqttgateway/)
- Python 3.11+ (asyncio TaskGroup)
- Type Hints überall
- `from __future__ import annotations`
- Tests mit pytest + pytest-asyncio
- Async: aiomqtt, httpx, asyncio.DatagramProtocol

### Perl
- `use strict; use warnings;`
- LoxBerry-Module: LoxBerry::System, ::IO, ::JSON, ::Log
- Config via LoxBerry::JSON (mit File-Locking)

### HTML Templates
- HTML::Template mit `<TMPL_VAR>`, `<TMPL_IF>`, `<TMPL_LOOP>`
- Sprachstrings: `<TMPL_VAR SECTION.KEY>` aus language_*.ini via readlanguage()
- Kein Inline-JavaScript in Templates wenn möglich — in externe .js Datei auslagern

## MQTT Gateway V2

### Config-Format (Michaels @@-Notation)
```json
{
  "Subscriptions": [
    {
      "Id": "topic/path",
      "Toms": [1, 2],
      "Jsonexpand": true,
      "Json": [
        { "Id": "nested@@field@@path", "Toms": [1] },
        { "Id": "array@@[0]@@name", "Toms": [] }
      ]
    }
  ]
}
```
- `@@` als Pfad-Separator für verschachtelte JSON-Felder
- `@@[0]` für Array-Indizes (0-basiert in Config, 1-basiert Richtung Miniserver)
- Präsenz in Config = abonniert (kein enabled-Flag)
- Leeres `Toms` = Default-Miniserver

### Python-Daemon Module
- `config.py` — Config laden, @@-Notation parsen
- `pipeline.py` — Filter → Debounce → JSON-Expand → Convert → Route
- `miniserver.py` — HTTP Delta-Send + UDP
- `mqtt_client.py` — aiomqtt Wrapper
- `udp_listener.py` — MS→MQTT Reverse-Kanal
- `transformer.py` — Async Subprocess für PHP/Perl Transformer
- `state.py` — Topic-Snapshot für WebUI (/dev/shm/)
- `logging_compat.py` — LoxBerry::Log kompatibles Format

## Deploy auf LoxBerry

Produktive LoxBerry unter `L:` (Netzlaufwerk, 192.168.30.10). Nach Änderungen:
1. Dateien nach `L:/<pfad>` kopieren (KEIN /opt/loxberry/ Prefix — Dateien liegen direkt auf L:)
2. Bei .html-Dateien: CRLF → LF konvertieren (`sed -i 's/\r$//' <datei>`)
3. Browser: Ctrl+Shift+R (Hard-Refresh)

## Core-Team

- **Michael Schlenstedt** (mschlenstedt) — Hauptentwickler, gibt Feedback zu MQTT V2
- **Christian Fenzl** — stats.loxberry.de, Array-Auflösung im Gateway
- **Sven Thierfelder** (svethi)
- **Christian Wörstenfeld** (Wörsty)
- **Philipp Lewald** (strike1988) — das bin ich

## Wichtige Regeln

1. **Plugin-Kompatibilität ist heilig** — keine Breaking Changes am Plugin-SDK, Plugins bekommen weiterhin jQuery + jQuery Mobile
2. **Core-Seiten sind jQM-frei** — neue Features nutzen lb-* Klassen, kein data-role/ui-* mehr
3. **Raspberry Pi Limits** — 1 GB RAM, kein Build-Tooling auf dem Gerät
4. **Strangler Fig** — Neues wächst neben dem Alten, kein Big Bang
5. **Ein PR = ein Thema** — reviewbar in unter 30 Minuten
6. **Mobile Tab Bar** — 5 Tabs (Home, Plugins-Popup, Updates, Einstellungen-Popup, Mehr-Popup) ersetzen Hamburger-Menü auf Mobile (<768px)
