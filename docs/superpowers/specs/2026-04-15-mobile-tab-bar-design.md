# Mobile Tab Bar — Design Spec

## Zusammenfassung

iOS-inspirierte Bottom Tab Bar als primäre mobile Navigation (< 768px) für LoxBerry. Ersetzt den Hamburger-Button auf Mobile. Reine CSS-Lösung mit Design-Tokens, Glassmorphismus im Glass-Theme. Die vollständige Sidebar bleibt über den "Mehr"-Tab erreichbar.

## Ziele

- Wichtigste Funktionen mit einem Tap erreichbar (kein Hamburger-Umweg)
- Konsistent mit bestehendem Design-System (lb-* Klassen, Token-basiert, 7 Themes)
- Kein neues JavaScript, kein Build-Tooling
- Raspberry Pi-tauglich (keine Performance-Probleme)

## Nicht-Ziele

- Desktop-Navigation ändern
- Neue Icon-Library einführen
- Web Components oder SPA-artiges Tab-Switching

## Tab-Auswahl

5 Tabs, basierend auf den häufigsten Nutzungsszenarien:

| Tab | Icon | Ziel | Template-Variable |
|-----|------|------|-------------------|
| Home | `pi pi-home` | `/admin/system/index.cgi` | `IS_TAB_HOME` |
| Plugins | `pi pi-th-large` | `/admin/system/plugininstall.cgi` | `IS_TAB_PLUGINS` |
| MQTT | `pi pi-arrows-h` | `/admin/system/mqtt.cgi` | `IS_TAB_MQTT` |
| Logs | `pi pi-list` | `/admin/system/logmanager.cgi` | `IS_TAB_LOGS` |
| Mehr | `pi pi-ellipsis-h` | Sidebar-Toggle (Button) | — |

## HTML-Struktur

Wird in `templates/system/pagestart.html` eingefügt, direkt vor `</body>`, nach dem Sidebar-Markup:

```html
<nav class="lb-tab-bar" role="navigation" aria-label="Mobile Navigation">
  <a href="/admin/system/index.cgi" class="lb-tab-bar-item <TMPL_IF IS_TAB_HOME>active</TMPL_IF>">
    <i class="pi pi-home"></i>
    <span>Home</span>
  </a>
  <a href="/admin/system/plugininstall.cgi" class="lb-tab-bar-item <TMPL_IF IS_TAB_PLUGINS>active</TMPL_IF>">
    <i class="pi pi-th-large"></i>
    <span>Plugins</span>
  </a>
  <a href="/admin/system/mqtt.cgi" class="lb-tab-bar-item <TMPL_IF IS_TAB_MQTT>active</TMPL_IF>">
    <i class="pi pi-arrows-h"></i>
    <span>MQTT</span>
  </a>
  <a href="/admin/system/logmanager.cgi" class="lb-tab-bar-item <TMPL_IF IS_TAB_LOGS>active</TMPL_IF>">
    <i class="pi pi-list"></i>
    <span>Logs</span>
  </a>
  <button class="lb-tab-bar-item" onclick="lbToggleSidebar()" aria-label="Mehr anzeigen">
    <i class="pi pi-ellipsis-h"></i>
    <span>Mehr</span>
  </button>
</nav>
```

### Entscheidungen

- **Semantik:** `<nav>` mit ARIA-Label für Screenreader. 4 Links + 1 Button (kein Link, da "Mehr" eine Aktion auslöst, kein Seitenwechsel).
- **Aktiver Tab:** Serverseitig per `TMPL_IF` — jedes CGI-Script setzt seine Variable. Seiten ohne zugeordneten Tab: alle Tabs inaktiv.
- **"Mehr"-Button:** Ruft bestehendes `lbToggleSidebar()` auf — kein neuer JS-Code.

## CSS-Design

### Neue Design-Tokens (in `design-tokens.css`)

```css
--lb-tab-bar-bg       /* Fallback: var(--lb-sidebar-bg) */
--lb-tab-bar-text     /* Fallback: var(--lb-sidebar-text) */
--lb-tab-bar-active   /* Fallback: var(--lb-sidebar-active-text) */
```

Themes müssen diese nicht setzen — die Fallbacks auf bestehende Sidebar-Tokens funktionieren sofort. Themes können sie optional überschreiben.

### Komponenten-CSS (in `components.css`)

```css
.lb-tab-bar {
  display: none;
}

@media (max-width: 768px) {
  .lb-tab-bar {
    display: flex;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 1100;
    justify-content: space-around;
    align-items: center;
    padding: 6px 0;
    padding-bottom: calc(6px + env(safe-area-inset-bottom, 0px));
    background: var(--lb-tab-bar-bg, var(--lb-sidebar-bg));
    border-top: 1px solid var(--lb-border-color);
  }

  .lb-tab-bar-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    text-decoration: none;
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px 0;
    min-width: 56px;
    -webkit-tap-highlight-color: transparent;
  }

  .lb-tab-bar-item i {
    font-size: 22px;
    color: var(--lb-tab-bar-text, var(--lb-sidebar-text));
  }

  .lb-tab-bar-item span {
    font-size: 10px;
    font-weight: 500;
    color: var(--lb-tab-bar-text, var(--lb-sidebar-text));
  }

  .lb-tab-bar-item.active i,
  .lb-tab-bar-item.active span {
    color: var(--lb-tab-bar-active, var(--lb-sidebar-active-text));
  }

  .lb-content {
    padding-bottom: 72px;
  }

  .lb-sidebar-toggle {
    display: none !important;
  }
}
```

### Entscheidungen

- **`display: none` auf Desktop:** Tab Bar existiert im DOM, ist aber unsichtbar. Kein Flackern, kein Layout-Impact.
- **`z-index: 1100`:** Über der Sidebar (1050), damit die Bar bei geöffneter Sidebar nicht verdeckt wird.
- **`env(safe-area-inset-bottom)`:** Für Geräte mit Home-Indicator (iPhone X+).
- **72px Body-Padding:** Verhindert, dass Content hinter der Tab Bar verschwindet.
- **Hamburger verstecken per CSS:** `display: none !important` auf `.lb-sidebar-toggle` innerhalb des Media-Query. Kein HTML-Entfernung — rückwärtskompatibel.
- **Immer sichtbar:** Kein Scroll-Hiding. Kein JS für Scroll-Detection nötig.

## Theme-Integration

### Glass-Theme (`theme-glass.css`)

Bekommt als einziges Theme eine spezielle Behandlung — Glassmorphismus passend zur iOS-Referenz:

```css
.lb-tab-bar {
  --lb-tab-bar-bg: rgba(30, 30, 30, 0.72);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border-top: 0.5px solid rgba(255, 255, 255, 0.12);
}
```

### Alle anderen Themes

Keine Änderung nötig. Fallback auf `--lb-sidebar-bg` / `--lb-sidebar-text` / `--lb-sidebar-active-text` ergibt konsistentes Aussehen.

### Fallback ohne `backdrop-filter`

Ältere Browser zeigen den soliden `--lb-sidebar-bg` Hintergrund. Kein visueller Bruch, nur kein Blur-Effekt.

## Perl-Anpassungen

Vier CGI-Scripts brauchen jeweils einen einzeiligen `param()`-Aufruf:

| Script | Zeile hinzufügen |
|--------|-----------------|
| `webfrontend/htmlauth/system/index.cgi` | `$template->param('IS_TAB_HOME', 1);` |
| `webfrontend/htmlauth/system/plugininstall.cgi` | `$template->param('IS_TAB_PLUGINS', 1);` |
| `webfrontend/htmlauth/system/mqtt.cgi` | `$template->param('IS_TAB_MQTT', 1);` |
| `webfrontend/htmlauth/system/logmanager.cgi` | `$template->param('IS_TAB_LOGS', 1);` |

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `templates/system/pagestart.html` | Tab Bar HTML einfügen |
| `webfrontend/html/system/css/components.css` | Tab Bar CSS hinzufügen |
| `webfrontend/html/system/css/design-tokens.css` | 3 neue Tokens (optional, für Dokumentation) |
| `webfrontend/html/system/css/theme-glass.css` | Glassmorphismus-Override |
| `webfrontend/htmlauth/system/index.cgi` | `IS_TAB_HOME` param |
| `webfrontend/htmlauth/system/plugininstall.cgi` | `IS_TAB_PLUGINS` param |
| `webfrontend/htmlauth/system/mqtt.cgi` | `IS_TAB_MQTT` param |
| `webfrontend/htmlauth/system/logmanager.cgi` | `IS_TAB_LOGS` param |

## Risiken und Mitigationen

| Risiko | Mitigation |
|--------|-----------|
| `backdrop-filter` ruckelt auf RPi | Nur im Glass-Theme aktiv. Andere Themes nutzen soliden Hintergrund. Glass-User akzeptieren den Tradeoff bereits. |
| Content wird von Tab Bar verdeckt | 72px `padding-bottom` auf `.lb-content` im Media-Query |
| Plugin-CGIs kennen kein `IS_TAB_*` | Kein Tab wird als aktiv markiert — korrektes Verhalten, alle Tabs gedimmt |
| Sidebar-Toggle funktioniert nicht nach Hamburger-Entfernung | `lbToggleSidebar()` ist eine globale JS-Funktion, unabhängig vom Hamburger-Button |
