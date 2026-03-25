# LoxBerry Redesign — Design-System + Schrittweise Migration

**Date:** 2026-03-25
**Status:** Approved

## Summary

Einführung eines CSS-Variable-basierten Design-Systems als Schicht über jQuery Mobile. Schrittweise Migration der Core-Seiten auf neue `lb-*` Komponenten-Klassen, ohne bestehende Plugins zu brechen.

## Goals

- Konsistentes Design-System mit CSS Variables (Design Tokens)
- Mobile-optimierte Navigation (scrollbare Tabs)
- Responsive Layouts für alle Bildschirmgrößen
- Cleaner/moderner Look — mehr Weißraum, feinere Borders, dezentere Schatten
- Einfach erweiterbare Themes — neues Theme = nur CSS Variables überschreiben, keine eigene Datei mit hunderten Selektoren
- Rückwärtskompatibilität: bestehende Plugins funktionieren ohne Änderung

## Constraints

- jQuery Mobile bleibt geladen (Plugins nutzen `data-role` Markup)
- Kein Build-Step (kein Tailwind, kein PostCSS) — läuft auf Raspberry Pi
- Plugin-HTML wird nicht verändert
- Server-side Templates (HTML::Template, Perl) bleiben

## 1. Design-System Fundament

### Design Tokens (`design-tokens.css`)

Neue Datei, wird in `head.html` vor allen Theme-Dateien geladen.

```css
:root {
  /* Colors */
  --lb-primary: #6dac20;
  --lb-primary-hover: #5a9418;
  --lb-primary-dark: #4a7a12;

  --lb-gray-50: #fafafa;
  --lb-gray-100: #f5f5f5;
  --lb-gray-200: #e5e5e5;
  --lb-gray-300: #d4d4d4;
  --lb-gray-500: #737373;
  --lb-gray-700: #404040;
  --lb-gray-900: #171717;

  --lb-danger: #dc2626;
  --lb-info: #0a4586;
  --lb-success: #6dac20;
  --lb-warning: #ca8a04;

  /* Spacing */
  --lb-space-xs: 4px;
  --lb-space-sm: 8px;
  --lb-space-md: 16px;
  --lb-space-lg: 24px;
  --lb-space-xl: 32px;

  /* Typography */
  --lb-font: system-ui, -apple-system, 'Segoe UI', sans-serif;
  --lb-font-mono: 'Consolas', 'Monaco', monospace;
  --lb-font-sm: 0.875rem;
  --lb-font-base: 1rem;
  --lb-font-lg: 1.25rem;

  /* Border */
  --lb-radius: 4px;
  --lb-border: 1px solid var(--lb-gray-200);
}
```

### Theme-Umschaltung via Variables

Themes überschreiben nur die CSS Variables — keine eigenen Selektoren für Struktur mehr nötig.

```css
body.theme-dark {
  --lb-gray-50: #1e1e2e;
  --lb-gray-100: #252536;
  --lb-gray-200: #333350;
  --lb-gray-300: #444466;
  --lb-gray-500: #888;
  --lb-gray-700: #c0c0c0;
  --lb-gray-900: #f0f0f0;
  --lb-border: 1px solid var(--lb-gray-200);
}

body.theme-modern {
  --lb-gray-50: #fafafa;
  --lb-font: 'Segoe UI', system-ui, -apple-system, sans-serif;
}
```

Bestehende Theme-CSS-Dateien bleiben als Fallback für jQuery Mobile Overrides (Farben), werden aber langfristig kleiner.

### New Files

| File | Purpose |
|------|---------|
| `webfrontend/html/system/css/design-tokens.css` | CSS Variables / Design Tokens |

### Modified Files

| File | Change |
|------|--------|
| `templates/system/head.html` | Load `design-tokens.css` before theme CSS |

## 2. Responsive Navigation

### Scrollbare Tabs

Die Vue-Navbar Tabs werden auf schmalen Screens horizontal scrollbar statt umzubrechen oder zu schrumpfen.

```css
.vuenavbarcontainer {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.vuenavbarcontainer::-webkit-scrollbar {
  display: none;
}
.vuenavbarelement {
  white-space: nowrap;
  flex-shrink: 0;
  min-width: fit-content;
}
```

Kein JavaScript nötig — reine CSS-Lösung.

### Responsive `lb_flex-*` Layout

Verbesserung der bestehenden Media Queries in `main.css`:

- **Desktop (>875px):** Label links (200px), Input mitte, Hilfetext rechts — wie bisher
- **Tablet (600-875px):** Label oben (volle Breite), Input volle Breite, Hilfetext darunter
- **Mobile (<600px):** Alles gestapelt, volle Breite, Labels fett

Plugin-Seiten die `lb_flex-*` Klassen nutzen profitieren automatisch. Plugin-Seiten mit eigenem `<table>` Layout bleiben unverändert.

### Modified Files

| File | Change |
|------|--------|
| `templates/system/pagestart.html` | Scrollbare Tabs CSS |
| `webfrontend/html/system/css/main.css` | Verbesserte `lb_flex-*` Media Queries |

## 3. Komponenten-Klassen (`lb-*`)

Neue CSS-Klassen die parallel zu jQuery Mobile existieren. Core-Seiten nutzen sie bei Migration, Plugins bleiben bei jQuery Mobile.

### `lb-btn`

```css
.lb-btn {
  padding: var(--lb-space-sm) var(--lb-space-md);
  background: var(--lb-gray-100);
  color: var(--lb-gray-900);
  border: var(--lb-border);
  border-radius: var(--lb-radius);
  font-family: var(--lb-font);
  font-size: var(--lb-font-base);
  cursor: pointer;
}
.lb-btn:hover {
  background: var(--lb-gray-200);
}
.lb-btn-primary {
  background: var(--lb-primary);
  color: white;
  border-color: var(--lb-primary-hover);
}
.lb-btn-primary:hover {
  background: var(--lb-primary-hover);
}
```

### `lb-input`

```css
.lb-input, .lb-select, .lb-textarea {
  width: 100%;
  padding: var(--lb-space-sm) var(--lb-space-md);
  border: var(--lb-border);
  border-radius: var(--lb-radius);
  font-family: var(--lb-font);
  font-size: var(--lb-font-base);
  background: var(--lb-gray-50);
  color: var(--lb-gray-900);
}
.lb-input:focus, .lb-select:focus, .lb-textarea:focus {
  border-color: var(--lb-primary);
  outline: none;
  box-shadow: 0 0 0 3px rgba(109, 172, 32, 0.15);
}
```

### `lb-card`, `lb-section-title`

```css
.lb-card {
  background: var(--lb-gray-50);
  border: var(--lb-border);
  border-radius: var(--lb-radius);
  padding: var(--lb-space-lg);
}
.lb-section-title {
  font-size: var(--lb-font-lg);
  font-weight: 600;
  border-bottom: 2px solid var(--lb-primary);
  padding-bottom: var(--lb-space-sm);
  margin-bottom: var(--lb-space-md);
  color: var(--lb-gray-900);
}
```

### New Files

| File | Purpose |
|------|---------|
| `webfrontend/html/system/css/components.css` | `lb-*` Komponenten-Klassen |

### Modified Files

| File | Change |
|------|--------|
| `templates/system/head.html` | Load `components.css` after `design-tokens.css` |

## 4. Migration-Strategie

### Phase 1 — Fundament (sofort)

- `design-tokens.css` erstellen und einbinden
- Theme-Dateien auf CSS Variables umstellen
- Scrollbare Tabs CSS
- Responsive `lb_flex-*` Media Queries verbessern
- `components.css` mit Basis-Klassen erstellen

### Phase 2 — Pilot-Seite

- `myloxberry.html` als erste Core-Seite auf `lb-*` Klassen migrieren
- jQuery Mobile Markup bleibt parallel (Fallback)
- Testen ob Plugins unberührt bleiben

### Phase 3 — Weitere Core-Seiten

- Miniserver, Netzwerk, Plugin-Verwaltung, Updates
- Seite für Seite, jeweils mit PR an Michael

### Phase 4 — jQuery Mobile optional

- Wenn alle Core-Seiten migriert: jQuery Mobile nur laden auf Plugin-Seiten
- Plugin-Entwicklern `lb-*` Klassen dokumentieren
- Langfristig: jQuery Mobile komplett entfernen

## 5. Was sich NICHT ändert

- Plugin-HTML bleibt unangetastet
- jQuery Mobile bleibt geladen (Rückwärtskompatibilität)
- `data-role` Markup funktioniert weiter
- Bestehende Theme-CSS-Dateien bleiben als Fallback
- Server-side Template-Engine (HTML::Template) bleibt
- Vue 3 nur für Navbar (kein SPA)

## 6. Testing

- Test jedes Theme (Classic, Modern, Dark) nach Design-Token-Umstellung
- Test Responsive: Desktop, Tablet (768px), Mobile (375px)
- Test scrollbare Tabs mit vielen Tabs (>5)
- Test Plugin-Seiten (Weather4Loxone, Stats4Lox) — dürfen sich nicht verändern
- Test `lb-*` Klassen auf migrierten Seiten
- Test auf Chrome, Firefox
