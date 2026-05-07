# Theme-System & jQuery Mobile Migration — Design Spec

## Ziel

Alle Core-Templates auf `lb-*` Klassen vereinheitlichen und ein Token-basiertes Theme-System aufbauen, mit dem Nutzer zwischen 4 Design-Richtungen wechseln koennen. jQuery Mobile Widgets (Controlgroups, Flipswitches, Collapsibles, Fieldcontains) werden durch CSS-only `lb-*` Komponenten ersetzt.

## Architektur

### Token-Schichten

```
design-tokens.css          <- Basis-Tokens (Spacing, Breakpoints, strukturelle Defaults)
theme-soft-rounded.css     <- Design 3: Farben, Radius 20px, Gradient-Buttons
theme-clean-admin.css      <- Design 1: Radius 10px, dunkle Sidebar
theme-glass.css            <- Design 2: Dark Gradient, Glassmorphism, Glow Effects
theme-classic-lb.css       <- Design 9: Radius 4px, Flat, Sans-serif
components.css             <- Nur var(--lb-*), nie hardcoded Werte
main.css                   <- jQuery Mobile Overrides aufraumen
```

Ein `<body class="theme-soft-rounded">` schaltet das Theme um. Die Template-Variable `THEME_CLASS` liefert die CSS-Klasse.

### Theme-Selektion (Perl-Backend)

- `LoxBerry::System` (`System.pm:543-544`): Regex erweitern um neue Theme-Namen
- `LoxBerry::Web` (`Web.pm:137-142`): Template-Variablen fuer neues Theme-System setzen
- `ajax-config-handler.cgi` (Zeile 58-62): Validierung erweitern
- `myloxberry.html`: Dropdown mit 4 neuen Themes
- Mapping alte Themes: `classic` -> `classic-lb`, `modern` -> `soft-rounded`, `dark` -> `glass`

## Token-Map (pro Theme)

| Token | Soft & Rounded (3) | Clean Admin (1) | Glass (2) | Classic LB (9) |
|-------|---------------------|------------------|-----------|----------------|
| `--lb-radius` | `20px` | `10px` | `14px` | `4px` |
| `--lb-radius-sm` | `12px` | `6px` | `10px` | `2px` |
| `--lb-font` | `'Segoe UI', system-ui, sans-serif` | `system-ui, -apple-system, sans-serif` | `system-ui, sans-serif` | `sans-serif` |
| `--lb-bg` | `#f0f4f8` | `#f4f5f7` | `linear-gradient(135deg, #0f2027, #203a43, #2c5364)` | `#f0f0f0` |
| `--lb-card-bg` | `white` | `white` | `rgba(255,255,255,.05)` | `white` |
| `--lb-card-shadow` | `0 1px 4px rgba(0,0,0,.05)` | `0 1px 3px rgba(0,0,0,.06)` | `none` | `none` |
| `--lb-card-border` | `none` | `1px solid #e5e5e5` | `1px solid rgba(255,255,255,.07)` | `1px solid #ddd` |
| `--lb-text` | `#2d3748` | `#1a1a2e` | `rgba(255,255,255,.8)` | `#333` |
| `--lb-text-secondary` | `#718096` | `#555` | `rgba(255,255,255,.5)` | `#555` |
| `--lb-text-muted` | `#a0aec0` | `#888` | `rgba(255,255,255,.3)` | `#aaa` |
| `--lb-border-color` | `#e2e8f0` | `#e5e5e5` | `rgba(255,255,255,.07)` | `#ddd` |
| `--lb-primary` | `#6dac20` | `#6dac20` | `#6dac20` | `#6dac20` |
| `--lb-primary-hover` | `#8bc34a` | `#5a9a1a` | `#8bc34a` | `#5a9a1a` |
| `--lb-btn-bg` | `#f0f4f8` | `#e6e6e6` | `rgba(255,255,255,.06)` | `#f0f0f0` |
| `--lb-btn-text` | `#718096` | `#000` | `rgba(255,255,255,.4)` | `#555` |
| `--lb-btn-border` | `transparent` | `#7e7e7e` | `rgba(255,255,255,.08)` | `#ddd` |
| `--lb-btn-radius` | `20px` | `4px` | `10px` | `4px` |
| `--lb-btn-primary-bg` | `linear-gradient(135deg, #6dac20, #8bc34a)` | `#6dac20` | `rgba(109,172,32,.2)` | `#6dac20` |
| `--lb-btn-primary-text` | `white` | `white` | `#6dac20` | `white` |
| `--lb-btn-primary-border` | `transparent` | `#5a9a1a` | `rgba(109,172,32,.3)` | `#5a9a1a` |
| `--lb-danger` | `#dc2626` | `#dc2626` | `#dc2626` | `#dc2626` |
| `--lb-warning` | `#ca8a04` | `#ca8a04` | `#ca8a04` | `#ca8a04` |
| `--lb-sidebar-bg` | `white` | `#1a1a2e` | `rgba(255,255,255,.04)` | `#3d3d3d` |
| `--lb-sidebar-text` | `#4a5568` | `rgba(255,255,255,.65)` | `rgba(255,255,255,.55)` | `rgba(255,255,255,.7)` |
| `--lb-sidebar-active-bg` | `#f0fff4` | `rgba(109,172,32,.12)` | `rgba(109,172,32,.1)` | `rgba(255,255,255,.1)` |
| `--lb-sidebar-active-text` | `#6dac20` | `#6dac20` | `#6dac20` | `#6dac20` |
| `--lb-sidebar-border` | `#e2e8f0` | `rgba(255,255,255,.08)` | `rgba(255,255,255,.06)` | `rgba(255,255,255,.08)` |
| `--lb-sidebar-section` | `#a0aec0` | `rgba(255,255,255,.35)` | `rgba(255,255,255,.2)` | `rgba(255,255,255,.4)` |
| `--lb-input-bg` | `white` | `white` | `rgba(255,255,255,.06)` | `white` |
| `--lb-input-border` | `#e2e8f0` | `#ddd` | `rgba(255,255,255,.1)` | `#ddd` |
| `--lb-input-text` | `#2d3748` | `#333` | `rgba(255,255,255,.8)` | `#333` |
| `--lb-toggle-bg` | `#cbd5e0` | `#ccc` | `rgba(255,255,255,.15)` | `#ccc` |
| `--lb-section-border` | `#6dac20` | `#6dac20` | `#6dac20` | `#6dac20` |

### Glass-Theme Zusatz-Tokens
Das Glass-Theme braucht zusaetzliche Tokens die andere Themes nicht verwenden:
| Token | Wert | Beschreibung |
|-------|------|-------------|
| `--lb-backdrop-blur` | `blur(12px)` | Glassmorphism-Effekt auf Karten |
| `--lb-glow-primary` | `0 0 6px rgba(109,172,32,.5)` | Glow auf Status-Dots |
| `--lb-glow-danger` | `0 0 6px rgba(220,38,38,.5)` | Glow auf Error-Dots |
| `--lb-glow-warning` | `0 0 8px rgba(202,138,4,.3)` | Glow auf Warning-Badges |

## Komponenten-Refactoring (components.css)

Alle hardcoded Werte in components.css werden durch Token-Referenzen ersetzt:

### Buttons (.lb-btn)
- `border-radius: 0.2125em` -> `var(--lb-btn-radius)`
- `background-color: #e6e6e6` -> `var(--lb-btn-bg)`
- `color: #000` -> `var(--lb-btn-text)`
- `border: 1px solid #7e7e7e` -> `1px solid var(--lb-btn-border)`
- `font-family: sans-serif` -> `var(--lb-font)`
- Primary: `background` -> `var(--lb-btn-primary-bg)` (supports both solid + gradient)

### Cards (.lb-card)
- `background: white` -> `var(--lb-card-bg)`
- `border: var(--lb-border)` -> `var(--lb-card-border)`
- `border-radius: 8px` -> `var(--lb-radius)`
- `box-shadow: ...` -> `var(--lb-card-shadow)`

### Inputs (.lb-input, .lb-select, .lb-textarea)
- `background: var(--lb-input-bg, #fff)` -> `var(--lb-input-bg)`
- `color: var(--lb-gray-900)` -> `var(--lb-input-text)`
- `border: var(--lb-border)` -> `1px solid var(--lb-input-border)`
- `border-radius: var(--lb-radius)` (already token-based, good)

### Toggle (.lb-toggle)
- `background: var(--lb-gray-300)` -> `var(--lb-toggle-bg)`

### Button Group (.lb-btn-group)
- `border-radius: var(--lb-radius)` (already token-based)
- `background: var(--lb-gray-100)` -> `var(--lb-btn-bg)`

### Section Title (.lb-section-title)
- `color: var(--lb-gray-900)` -> `var(--lb-text)`
- `border-bottom: 2px solid var(--lb-primary)` -> `var(--lb-section-border)`

### Form Layout (.lb-form-row, .lb-form-label, .lb-form-help)
- `color: var(--lb-gray-700)` -> `var(--lb-text-secondary)`
- `color: var(--lb-gray-500)` -> `var(--lb-text-muted)`
- `font-family: var(--lb-font)` (already token-based)

## Template-Migration

### Dateien und Widgets

| Datei | Controlgroups | Flipswitches | Collapsibles | Fieldcontains | sonstige jQM |
|-------|:---:|:---:|:---:|:---:|:---|
| backup.html | 1 (Wochentage) | 1 (scheduleactive) | - | 3 | Buttons |
| mailserver.html | 2 (System/Plugin Notifications) | - | - | - | Popup, Buttons |
| network.html | 3 (Interface, IPv4, IPv6) | - | - | - | Buttons |
| plugininstall.html | 2 (Auto-Updates, Loglevel) | - | - | - | Buttons |
| updates.html | 5 (Upgrades, Reboot, Release, Install, Time) | - | - | - | Buttons |
| services_timeserver.html | 1 (NTP) | - | - | - | Buttons |
| remote.html | - | 1 (autoconnect) | - | 1 | Buttons |
| miniserver.html | - | - | 1 (Error Details) | - | Buttons |
| translate.html | 6 (Plugin, File, Source, Dest, Load, Download) | - | - | - | 1 ui-btn |
| myloxberry.html | 1 (Send Statistics) | - | - | - | Buttons |
| fileanalyzer.html | - | - | - | 1 | - |

### Migration-Patterns

**Controlgroup -> lb-btn-group:**
```html
<!-- ALT (jQuery Mobile) -->
<fieldset data-role="controlgroup" data-type="horizontal" data-mini="true">
    <input type="checkbox" name="mon" id="mon">
    <label for="mon">Mo</label>
    <input type="checkbox" name="tue" id="tue">
    <label for="tue">Di</label>
</fieldset>

<!-- NEU (lb-*) -->
<div class="lb-btn-group">
    <input type="checkbox" name="mon" id="mon">
    <label for="mon">Mo</label>
    <input type="checkbox" name="tue" id="tue">
    <label for="tue">Di</label>
</div>
```

**Flipswitch -> lb-toggle:**
```html
<!-- ALT (jQuery Mobile) -->
<div data-role="fieldcontain" class="ui-field-contain">
    <label for="scheduleactive">Activate</label>
    <input type="checkbox" id="scheduleactive" data-role="flipswitch" data-mini="true">
</div>

<!-- NEU (lb-*) -->
<div class="lb-form-row">
    <label class="lb-form-label" for="scheduleactive">Activate</label>
    <div class="lb-form-field">
        <label class="lb-toggle">
            <input type="checkbox" id="scheduleactive">
            <span class="lb-toggle-slider"></span>
        </label>
    </div>
</div>
```

**Collapsible -> lb-collapsible:**
```html
<!-- ALT (jQuery Mobile) -->
<div data-role="collapsible">
    <h4>Details</h4>
    <div class="monospace">Content</div>
</div>

<!-- NEU (lb-*) -->
<details class="lb-collapsible">
    <summary>Details</summary>
    <div class="lb-collapsible-content monospace">Content</div>
</details>
```

**Fieldcontain -> lb-form-row:**
```html
<!-- ALT (jQuery Mobile) -->
<div data-role="fieldcontain" class="ui-field-contain">
    <label for="repeat">Repeat</label>
    <select name="repeat" id="repeat" data-mini="true">...</select>
</div>

<!-- NEU (lb-*) -->
<div class="lb-form-row">
    <label class="lb-form-label" for="repeat">Repeat</label>
    <div class="lb-form-field">
        <select class="lb-select" name="repeat" id="repeat">...</select>
    </div>
</div>
```

**Translate ui-btn -> lb-btn:**
```html
<!-- ALT -->
<a href="#" id="downloadfile" class="ui-btn ui-btn-inline">Download</a>

<!-- NEU -->
<a href="#" id="downloadfile" class="lb-btn">Download</a>
```

### JavaScript-Aenderungen

**mqtt-gateway.html** — Dynamisch generierte Controlgroups in JS-Funktionen:

`http_table_skel()` und `udp_table_skel()` erzeugen jQuery Mobile Controlgroups als HTML-Strings. Diese muessen auf `lb-btn-group` mit Checkbox+Label-Pattern umgestellt werden.

`syncBtnGroup()` bleibt unveraendert — funktioniert bereits mit lb-btn-group, da es nur jQuery `.prop("checked")` und CSS-Klassen prueft.

### main.css Aufraeumen

Folgende Bloecke in main.css werden obsolet nach der Migration:
- `.ui-flipswitch` Overrides (Zeile ~469, ~480)
- `.ui-controlgroup-controls` Ausnahmen (Zeile ~531, ~535-536)
- Controlgroup responsive Override in components.css (Zeile 329-344) — wird durch lb-btn-group responsive ersetzt

## Theme-Infrastruktur (Perl-Backend)

### System.pm aendern
```perl
# ALT
$theme = 'classic' unless $theme =~ /^(classic|modern|dark)$/;

# NEU
$theme = 'soft-rounded' unless $theme =~ /^(soft-rounded|clean-admin|glass|classic-lb)$/;
```

### Web.pm aendern
Statt einzelner THEME_CLASSIC/THEME_MODERN/THEME_DARK Flags ein generisches System:
```perl
my $theme = $LoxBerry::System::lbtheme // 'soft-rounded';
$theme = 'soft-rounded' unless $theme =~ /^(soft-rounded|clean-admin|glass|classic-lb)$/;
$headobj->param( THEME_CLASS => "theme-$theme" );
$headobj->param( THEME_FILE => "theme-$theme.css" );
```

### head.html aendern
```html
<!-- ALT: 3 einzelne TMPL_IF -->
<TMPL_IF THEME_CLASSIC><link rel="stylesheet" href="..." /></TMPL_IF>
<TMPL_IF THEME_MODERN><link rel="stylesheet" href="..." /></TMPL_IF>
<TMPL_IF THEME_DARK><link rel="stylesheet" href="..." /></TMPL_IF>

<!-- NEU: 1 dynamischer Link -->
<link rel="stylesheet" href="/system/css/<TMPL_VAR THEME_FILE>?v=3" />
```

### ajax-config-handler.cgi aendern
```perl
# ALT
if ($value =~ /^(classic|modern|dark)$/) {

# NEU
if ($value =~ /^(soft-rounded|clean-admin|glass|classic-lb)$/) {
```

### myloxberry.html Theme-Dropdown
Dropdown mit 4 Optionen:
- Soft & Rounded (soft-rounded) — Freundlich, abgerundet
- Clean Admin (clean-admin) — Professionell, dunkle Sidebar
- Glassmorphism (glass) — Dark Gradient, Glow Effects, halbtransparent
- Classic LoxBerry (classic-lb) — Vertrautes Design

### Abwaertskompatibilitaet
Falls ein User den alten Theme-Wert "classic", "modern" oder "dark" in general.json hat:
```perl
# Mapping alte -> neue Themes
my %theme_map = (
    'classic' => 'classic-lb',
    'modern'  => 'soft-rounded',
    'dark'    => 'glass',
);
$theme = $theme_map{$theme} // $theme;
```

## Nicht im Scope

- **pagestart*.html Sidebar-Struktur** — separater Plan nach Core-Team Feedback
- **Popups/Modals** (`data-role="popup"`, 3 Vorkommen) — braucht neues `lb-modal` Komponente
- **Page Structure** (`data-role="page/header/content"`) — struktureller Umbau
- **Panels** (`data-role="panel"`) — Sidebar-Umbau
- **Plugin-Templates** — bleiben bei jQuery Mobile, werden nicht migriert
- **jQuery Mobile aus head.html entfernen** — erst wenn alles inkl. Struktur migriert
- **Tabellen** (`data-role="table"`, 5 Vorkommen) — funktionieren auch ohne Enhancement

## Phasen

### Phase 1: Token-System & Komponenten (CSS-only)
1. design-tokens.css refactoren — strukturelle Basis-Tokens
2. components.css refactoren — hardcoded Werte -> var(--lb-*)
3. 4 Theme-Files schreiben (soft-rounded, clean-admin, glass, classic-lb)
4. main.css aufraumen — obsolete jQuery Mobile Overrides markieren

### Phase 2: Template-Migration (HTML-Aenderungen)
5. 11 Template-Dateien: jQuery Mobile Widgets -> lb-* Klassen
6. mqtt-gateway.html JS-Funktionen anpassen (dynamische Controlgroups)
7. main.css jQuery Mobile Overrides entfernen

### Phase 3: Theme-Infrastruktur (Perl-Backend)
8. System.pm, Web.pm: Neue Theme-Namen + Mapping
9. head.html: Dynamischer Theme-Link
10. ajax-config-handler.cgi: Validierung erweitern
11. myloxberry.html: Theme-Dropdown aktualisieren

### Phase 4: Testen & Deploy
12. Auf LoxBerry (L:) deployen
13. Alle 4 Themes auf allen Core-Seiten testen
14. Plugin-Seiten testen (duerfen nicht brechen)
15. Mobile/Responsive testen
