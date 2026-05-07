# jQuery Mobile Entfernung für Core-Seiten — Design Spec

## Zusammenfassung

jQuery Mobile (1.4.5) wird für Core-Seiten nicht mehr geladen. Plugin-Seiten behalten jQuery + jQuery Mobile. Die 10 noch abhängigen Templates werden auf `lb-*` Klassen migriert. jQuery Core (1.12.4) bleibt vorerst für alle Seiten.

## Ziele

- jQuery Mobile CSS und JS nicht mehr für Core-Seiten laden
- Alle 10 verbliebenen Core-Templates jQM-frei machen
- Plugin-Kompatibilität 100% beibehalten
- jQM-Override-Sektion in `components.css` für Core-Seiten obsolet machen

## Nicht-Ziele

- jQuery Core ($) entfernen (kommt in Phase 2+)
- form-validator ersetzen (eigene Phase)
- Plugin-Templates ändern
- Neue UI-Komponenten einführen (nur bestehende `lb-*` nutzen)

## Architektur: Conditional Loading

### Web.pm — IS_CORE_PAGE Variable

In `Web.pm` Funktion `head()` (~Zeile 134) eine neue Template-Variable setzen:

```perl
my $systemcall = defined $LoxBerry::System::lbpplugindir ? undef : 1;
$headobj->param( IS_CORE_PAGE => $systemcall ? 1 : 0 );
```

`die_on_bad_params => 0` ist gesetzt, d.h. unbekannte Variablen werden ignoriert — kein Risiko für bestehenden Code.

### head.html — Conditional jQM Loading

jQuery Mobile CSS und JS nur für Plugin-Seiten laden:

```html
<!-- jQuery Core — bleibt immer -->
<script src="/system/scripts/jquery/jquery-1.12.4.min.js"></script>

<!-- jQuery Mobile — nur für Plugins -->
<TMPL_UNLESS IS_CORE_PAGE>
<link rel="stylesheet" href="/system/scripts/jquery/themes/main/loxberry.css" />
<link rel="stylesheet" href="/system/scripts/jquery/themes/main/jquery.mobile.icons.min.css" />
<link rel="stylesheet" href="/system/scripts/jquery/jquery.mobile.structure-1.4.5.min.css" />
<script src="/system/scripts/jquery/jquery.mobile-1.4.5.min.js"></script>
</TMPL_UNLESS>
```

Der `<script>`-Block mit `$.mobile.*` Config wird ebenfalls in `TMPL_UNLESS IS_CORE_PAGE` gewrappt.

Die `syncLbBtnGroup`-Funktion bleibt (nutzt nur jQuery Core). Das jQM-Event `pagecreate` wird für Core-Seiten durch `$(document).ready()` ersetzt:

```html
<TMPL_IF IS_CORE_PAGE>
<script>
    $.ajaxSetup({ cache: false });
    $(document).ready(function() {
        setTimeout(syncAllBtnGroups, 200);
    });
</script>
<TMPL_IF>
<TMPL_UNLESS IS_CORE_PAGE>
<script>
    /* ... bestehender jQM-Config-Block ... */
</script>
</TMPL_UNLESS>
```

### form-validator

Bleibt global geladen — nutzt jQuery Core, nicht jQM. Keine Änderung nötig.

## Ersetzungsmuster

Die 10 Templates nutzen immer die gleichen jQM-Patterns. Hier die Standard-Ersetzungen:

| jQM Pattern | Ersetzung |
|-------------|-----------|
| `data-mini="true"` | Entfernen (lb-* hat eigene Größen) |
| `data-icon="..."` / `data-iconpos="..."` | Entfernen (PrimeIcons stattdessen) |
| `data-role="button"` | `class="lb-btn"` |
| `data-role="header"` / `data-role="content"` | Entfernen (lb-layout übernimmt) |
| `data-type="horizontal"` | `class="lb-btn-group"` |
| `data-role="table" data-mode="columntoggle"` | `class="lb-table lb-table-responsive"` |
| `data-role="popup"` | `<dialog class="lb-modal">` |
| `.checkboxradio("refresh")` | Entfernen (native Checkbox braucht kein Refresh) |
| `.flipswitch("refresh")` | Entfernen (lb-toggle braucht kein Refresh) |
| `.selectmenu("refresh")` | Entfernen (native `<select class="lb-select">` braucht kein Refresh) |
| `.popup("open")` | `document.getElementById('id').showModal()` |
| `ui-btn ui-corner-all ui-mini` | `lb-btn lb-btn-sm` |
| `ui-disabled` addClass/removeClass | `lb-disabled` addClass/removeClass |
| `ui-body-d ui-shadow ui-responsive` | Entfernen (lb-table styled sich selbst) |
| `ui-bar-d` | Entfernen (lb-table `<thead>` styled sich selbst) |
| `ui-content` / `ui-body ui-body-a ui-corner-all` | `lb-content` oder entfernen |

### Neue CSS-Klasse: lb-disabled

In `components.css` hinzufügen:

```css
.lb-disabled {
    opacity: 0.4;
    pointer-events: none;
}
```

### Neue CSS-Klasse: lb-table / lb-table-responsive

In `components.css` hinzufügen für responsive Tabellen (ersetzt jQM `data-role="table"`):

```css
.lb-table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--lb-font);
    font-size: var(--lb-font-sm);
}
.lb-table th,
.lb-table td {
    padding: 8px 12px;
    text-align: left;
    border-bottom: 1px solid var(--lb-border-color);
}
.lb-table thead th {
    font-weight: 600;
    color: var(--lb-text-secondary);
    background: var(--lb-btn-bg);
}
@media (max-width: 768px) {
    .lb-table-responsive thead { display: none; }
    .lb-table-responsive tr {
        display: block;
        margin-bottom: var(--lb-space-sm);
        border: 1px solid var(--lb-border-color);
        border-radius: var(--lb-radius);
    }
    .lb-table-responsive td {
        display: flex;
        justify-content: space-between;
        padding: 6px 12px;
        border-bottom: 1px solid var(--lb-border-color);
    }
    .lb-table-responsive td::before {
        content: attr(data-label);
        font-weight: 600;
        color: var(--lb-text-secondary);
        margin-right: var(--lb-space-md);
    }
}
```

## Template-Migration

### Batch A — Trivial (nur Attribute/Klassen ersetzen)

**healthcheck.html:**
- Zeile 177: `data-role="button" data-inline="true" data-mini="true" data-icon="action"` → `class="lb-btn lb-btn-sm"`

**mqtt-quickpublisher.html:**
- 20x `data-mini="true"` → entfernen
- 5x `data-iconpos="left"` → entfernen
- 5x `ui-btn ui-corner-all ui-mini` → `lb-btn lb-btn-sm`
- Zeile 192: `.checkboxradio("refresh")` → entfernen
- Zeile 199: `.selectmenu("refresh")` → entfernen

**mqtt-finder.html:**
- Zeile 37: `data-mini="true" data-clear-btn="true"` → entfernen
- Zeile 38: `data-mini="true"` → entfernen
- Zeile 68: `.checkboxradio("refresh")` → entfernen
- Zeile 243, 250: `ui-mini ui-btn ui-shadow ui-icon-clipboard ui-btn-inline` → `lb-btn lb-btn-sm lb-btn-icon`

**plugininstall.html:**
- Zeile 10-32: CSS-Selektoren mit `fieldset[data-type="horizontal"]` und `ui-btn` → `lb-btn-group` und `lb-btn` Selektoren
- Zeile 109: `data-role="table" data-mode="table"` → `class="lb-table"`
- Zeile 221: `.selectmenu('refresh')` → entfernen

### Batch B — Widget-Ersetzung

**logfile.html:**
- Zeile 4: `data-role="header"` → entfernen
- Zeile 8: `data-role="content"` + `ui-content` → `lb-content`
- Zeile 9: `ui-body ui-body-a ui-corner-all` → `lb-card`
- Zeile 41: `data-mini="true"` → entfernen
- Zeile 121, 130, 228: `.checkboxradio("refresh")` → entfernen

**netshares.html:**
- Zeile 93: `data-role="table" data-mode="columntoggle" data-filter="true"` + `ui-body-d ui-shadow table-stripe ui-responsive` → `lb-table lb-table-responsive`
- Zeile 95: `ui-bar-d` → entfernen (thead th wird von lb-table gestyled)
- Jede `<td>` bekommt `data-label="Spaltenname"` für mobile Ansicht

**usbstorage.html:**
- Identisch zu netshares — gleiche Tabellen-Migration

**changehostname.html:**
- Eigenständige Seite mit eigenem jQM-Loading
- Zeile 21, 83: `data-role="page"` → beibehalten (pagestart nutzt es auch)
- Zeile 22, 84: `data-role="header"` → entfernen
- Zeile 26, 88: `data-role="content"` + `ui-content` → `lb-content`
- Zeile 27, 89: `ui-body ui-body-a ui-corner-all` → `lb-card`
- Eigenes jQM script-Tag entfernen (Seite nutzt `head.html` über Web.pm)

### Batch C — Aufwändigere Seiten

**backup.html:**
- Zeile 211-213: 3x `.selectmenu('refresh', true)` → entfernen, `<select>` bekommt `class="lb-select"`
- Zeile 215: `.flipswitch('refresh')` → entfernen, flipswitch-Input → `lb-toggle` Markup
- Zeile 216-222: 7x `.checkboxradio('refresh')` → entfernen
- Zeile 154-155, 231, 245, 252, 285-303: `ui-disabled` → `lb-disabled`

**mailserver.html:**
- Zeile 182-190: `data-role="popup"` → `<dialog class="lb-modal">`
- Zeile 184: `data-role="header"` im Popup → `lb-modal-header`
- Zeile 300: `.popup("open")` → `document.getElementById('testmail-dialog').showModal()`
- Zeile 394-410: 7x `.checkboxradio("refresh")` → entfernen
- Zeile 276-292: `ui-disabled` → `lb-disabled`

## Aufräumen nach Migration

### components.css Sektion 1

Nach Abschluss aller Batches kann die gesamte Sektion 1 ("jQuery Mobile Overrides", Zeilen 1-116) entfernt werden — Core-Seiten laden jQM nicht mehr, Plugins nutzen ihre eigenen Styles.

## Reihenfolge

1. `Web.pm` + `head.html` — Conditional Loading einbauen
2. Smoke-Test: Bereits migrierte Seiten (Dashboard, Admin, Network) funktionieren ohne jQM
3. `components.css` — `lb-disabled`, `lb-table`, `lb-table-responsive` hinzufügen
4. Batch A — 4 triviale Templates
5. Batch B — 4 Templates mit Widget-Ersetzung
6. Batch C — backup.html + mailserver.html
7. Aufräumen: jQM-Overrides in components.css Sektion 1 entfernen

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `libs/perllib/LoxBerry/Web.pm` | IS_CORE_PAGE param |
| `templates/system/head.html` | Conditional jQM loading |
| `webfrontend/html/system/css/components.css` | lb-disabled, lb-table, jQM-Overrides entfernen |
| `templates/system/healthcheck.html` | Batch A |
| `templates/system/mqtt-quickpublisher.html` | Batch A |
| `templates/system/mqtt-finder.html` | Batch A |
| `templates/system/plugininstall.html` | Batch A |
| `templates/system/logfile.html` | Batch B |
| `templates/system/netshares.html` | Batch B |
| `templates/system/usbstorage.html` | Batch B |
| `templates/system/changehostname.html` | Batch B |
| `templates/system/backup.html` | Batch C |
| `templates/system/mailserver.html` | Batch C |

## Risiken und Mitigationen

| Risiko | Mitigation |
|--------|-----------|
| Plugin bricht ohne jQM | Plugin-Seiten laden jQM weiterhin (IS_CORE_PAGE=0) |
| `$.mobile` undefined auf Core-Seiten | jQM-Config-Block ist in TMPL_UNLESS gewrappt |
| form-validator braucht jQM | Nein — nutzt nur jQuery Core. Getestet. |
| `pagecreate` Event fehlt auf Core-Seiten | Durch `$(document).ready()` ersetzt |
| Seite sieht kaputt aus nach Migration | Deploy + Test pro Batch, Rollback = alte Datei zurückkopieren |
