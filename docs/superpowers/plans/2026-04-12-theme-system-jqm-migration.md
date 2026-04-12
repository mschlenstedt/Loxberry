# Theme-System & jQuery Mobile Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace jQuery Mobile widgets with lb-* CSS components across all Core templates and build a 4-theme token system (Soft & Rounded, Clean Admin, Glassmorphism, Classic LB).

**Architecture:** CSS custom properties in design-tokens.css provide structural defaults. Each theme overrides these tokens in its own file (theme-*.css). Components in components.css reference only var(--lb-*) — never hardcoded values. Templates swap jQuery Mobile data-role widgets for semantic HTML with lb-* classes. Perl backend (System.pm, Web.pm) routes theme selection to the correct CSS file.

**Tech Stack:** CSS Custom Properties, HTML5 (`<details>`, native checkboxes), HTML::Template (Perl), jQuery (DOM only, not jQuery Mobile widgets), PrimeIcons.

**Spec:** `docs/superpowers/specs/2026-04-12-theme-system-jqm-migration-design.md`

---

## File Map

### Create
- `webfrontend/html/system/css/theme-soft-rounded.css` — Design 3 token overrides
- `webfrontend/html/system/css/theme-clean-admin.css` — Design 1 token overrides
- `webfrontend/html/system/css/theme-glass.css` — Design 2 token overrides + glass extras
- `webfrontend/html/system/css/theme-classic-lb.css` — Design 9 token overrides

### Modify
- `webfrontend/html/system/css/design-tokens.css` — Add new tokens, remove old theme blocks
- `webfrontend/html/system/css/components.css` — Replace hardcoded values with var(--lb-*)
- `webfrontend/html/system/css/main.css` — Remove obsolete jQuery Mobile overrides
- `templates/system/head.html` — Dynamic theme link
- `templates/system/backup.html` — Migrate flipswitch, controlgroup, fieldcontains
- `templates/system/mailserver.html` — Migrate 2 controlgroups
- `templates/system/network.html` — Migrate 3 controlgroups
- `templates/system/plugininstall.html` — Migrate 2 controlgroups
- `templates/system/updates.html` — Migrate 5 controlgroups
- `templates/system/services_timeserver.html` — Migrate 1 controlgroup
- `templates/system/remote.html` — Migrate flipswitch + fieldcontain
- `templates/system/miniserver.html` — Migrate collapsible + ui-btn
- `templates/system/translate.html` — Migrate 6 controlgroups + ui-btn
- `templates/system/myloxberry.html` — Migrate controlgroup + theme dropdown
- `templates/system/fileanalyzer.html` — Migrate fieldcontain
- `templates/system/mqtt-gateway.html` — Migrate JS-generated controlgroups
- `libs/perllib/LoxBerry/System.pm` — Theme regex + mapping
- `libs/perllib/LoxBerry/Web.pm` — Theme template variables
- `webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi` — Theme validation

---

## Phase 1: Token-System & Komponenten

### Task 1: Erweitere design-tokens.css mit neuen Tokens

**Files:**
- Modify: `webfrontend/html/system/css/design-tokens.css`

- [ ] **Step 1: Add new token variables to :root**

In `design-tokens.css`, replace the entire file content with:

```css
/* LoxBerry Design Tokens
   All design values as CSS Variables.
   Themes override these variables — no structural changes needed. */

:root {
  /* === Colors === */
  --lb-primary: #6dac20;
  --lb-primary-hover: #5a9418;
  --lb-primary-dark: #4a7a12;

  --lb-danger: #dc2626;
  --lb-info: #0a4586;
  --lb-success: #6dac20;
  --lb-warning: #ca8a04;

  /* === Grays (used as fallbacks, themes override semantic tokens) === */
  --lb-gray-50: #fafafa;
  --lb-gray-100: #f5f5f5;
  --lb-gray-200: #e5e5e5;
  --lb-gray-300: #d4d4d4;
  --lb-gray-500: #737373;
  --lb-gray-700: #404040;
  --lb-gray-900: #171717;

  /* === Semantic Colors === */
  --lb-bg: #f5f5f5;
  --lb-text: #171717;
  --lb-text-secondary: #404040;
  --lb-text-muted: #737373;
  --lb-border-color: #e5e5e5;

  /* === Cards === */
  --lb-card-bg: white;
  --lb-card-border: 1px solid var(--lb-border-color);
  --lb-card-shadow: 0 1px 3px rgba(0,0,0,0.06);

  /* === Buttons === */
  --lb-btn-bg: #e6e6e6;
  --lb-btn-text: #000;
  --lb-btn-border: #7e7e7e;
  --lb-btn-radius: 4px;
  --lb-btn-primary-bg: var(--lb-primary);
  --lb-btn-primary-text: white;
  --lb-btn-primary-border: var(--lb-primary-hover);

  /* === Inputs === */
  --lb-input-bg: #fff;
  --lb-input-border: var(--lb-border-color);
  --lb-input-text: var(--lb-text);

  /* === Toggle === */
  --lb-toggle-bg: #d4d4d4;

  /* === Section Title === */
  --lb-section-border: var(--lb-primary);

  /* === Sidebar (defaults, overridden by themes) === */
  --lb-sidebar-bg: #3d3d3d;
  --lb-sidebar-text: rgba(255,255,255,.7);
  --lb-sidebar-active-bg: rgba(255,255,255,.1);
  --lb-sidebar-active-text: #6dac20;
  --lb-sidebar-border: rgba(255,255,255,.08);
  --lb-sidebar-section: rgba(255,255,255,.4);

  /* === Spacing === */
  --lb-space-xs: 4px;
  --lb-space-sm: 8px;
  --lb-space-md: 16px;
  --lb-space-lg: 24px;
  --lb-space-xl: 32px;

  /* === Typography === */
  --lb-font: system-ui, -apple-system, 'Segoe UI', sans-serif;
  --lb-font-mono: 'Consolas', 'Monaco', monospace;
  --lb-font-sm: 0.875rem;
  --lb-font-base: 1rem;
  --lb-font-lg: 1.25rem;

  /* === Border === */
  --lb-radius: 4px;
  --lb-radius-sm: 2px;
  --lb-border: 1px solid var(--lb-border-color);

  /* === Glass extras (only used by glass theme) === */
  --lb-backdrop-blur: none;
  --lb-glow-primary: none;
  --lb-glow-danger: none;
  --lb-glow-warning: none;
}
```

- [ ] **Step 2: Verify no syntax errors**

Open any Core page in browser (e.g. `http://loxberry/admin/system/myloxberry.cgi`), open DevTools > Elements, check that `--lb-bg`, `--lb-text`, `--lb-btn-bg` etc. are visible on `:root`. Existing pages should look unchanged because the default values match what components.css currently uses.

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/design-tokens.css
git commit -m "refactor(tokens): add semantic design tokens for theme system"
```

---

### Task 2: Refactor components.css to use tokens

**Files:**
- Modify: `webfrontend/html/system/css/components.css`

- [ ] **Step 1: Replace hardcoded button values**

Find and replace in `components.css`:

```css
/* OLD — lines 18-41 */
.lb-btn,
a.lb-btn,
a.lb-btn:visited,
a.lb-btn:link {
  display: inline-block;
  padding: 0.7em 1em;
  margin: 0.5em 0.625em 0.5em 0;
  background-color: #e6e6e6;
  color: #000 !important;
  border: 1px solid #7e7e7e;
  border-radius: 0.2125em;
  font-size: var(--lb-font-base);
  font-weight: normal;
  font-family: sans-serif;
  line-height: 1.3;
  cursor: pointer;
  text-decoration: none !important;
  text-align: center;
  text-shadow: 0 1px 0 #eee;
  white-space: nowrap;
  overflow: hidden;
  -webkit-user-select: none;
  user-select: none;
  position: relative;
}
```

Replace with:

```css
/* NEW */
.lb-btn,
a.lb-btn,
a.lb-btn:visited,
a.lb-btn:link {
  display: inline-block;
  padding: 0.7em 1em;
  margin: 0.5em 0.625em 0.5em 0;
  background: var(--lb-btn-bg);
  color: var(--lb-btn-text) !important;
  border: 1px solid var(--lb-btn-border);
  border-radius: var(--lb-btn-radius);
  font-size: var(--lb-font-base);
  font-weight: normal;
  font-family: var(--lb-font);
  line-height: 1.3;
  cursor: pointer;
  text-decoration: none !important;
  text-align: center;
  white-space: nowrap;
  overflow: hidden;
  -webkit-user-select: none;
  user-select: none;
  position: relative;
}
```

- [ ] **Step 2: Replace hardcoded button hover/active**

Find:
```css
.lb-btn:hover {
  background-color: #fff;
  border-color: #8c8c8c;
  color: #000 !important;
  text-shadow: 0 1px 0 #eee;
}
.lb-btn:active {
  background-color: #fff;
}
```

Replace with:
```css
.lb-btn:hover {
  filter: brightness(1.08);
  color: var(--lb-btn-text) !important;
}
.lb-btn:active {
  filter: brightness(1.12);
}
```

- [ ] **Step 3: Replace hardcoded primary button**

Find:
```css
.lb-btn-primary {
  background-color: var(--lb-primary);
  color: white;
  border-color: var(--lb-primary-hover);
  text-shadow: 0 1px 0 rgba(0,0,0,0.2);
}
.lb-btn-primary:hover {
  background-color: var(--lb-primary-hover);
}
```

Replace with:
```css
.lb-btn-primary {
  background: var(--lb-btn-primary-bg);
  color: var(--lb-btn-primary-text) !important;
  border-color: var(--lb-btn-primary-border);
}
.lb-btn-primary:hover {
  filter: brightness(1.1);
}
```

- [ ] **Step 4: Replace hardcoded card values**

Find:
```css
.lb-card {
  background: white;
  border: var(--lb-border);
  border-radius: 8px;
  padding: var(--lb-space-lg);
  box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}
```

Replace with:
```css
.lb-card {
  background: var(--lb-card-bg);
  border: var(--lb-card-border);
  border-radius: var(--lb-radius);
  padding: var(--lb-space-lg);
  box-shadow: var(--lb-card-shadow);
  backdrop-filter: var(--lb-backdrop-blur);
}
```

- [ ] **Step 5: Replace hardcoded input values**

Find:
```css
.lb-input,
.lb-select,
.lb-textarea {
  width: 100%;
  padding: 10px 14px;
  border: var(--lb-border);
  border-radius: var(--lb-radius);
  font-size: var(--lb-font-base);
  background: var(--lb-input-bg, #fff);
  color: var(--lb-gray-900);
  box-sizing: border-box;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
```

Replace with:
```css
.lb-input,
.lb-select,
.lb-textarea {
  width: 100%;
  padding: 10px 14px;
  border: 1px solid var(--lb-input-border);
  border-radius: var(--lb-radius);
  font-size: var(--lb-font-base);
  background: var(--lb-input-bg);
  color: var(--lb-input-text);
  box-sizing: border-box;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
```

- [ ] **Step 6: Replace hardcoded section title values**

Find:
```css
.lb-section-title {
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: 0.01em;
  border-bottom: 2px solid var(--lb-primary);
  padding-bottom: 10px;
  margin-top: var(--lb-space-lg);
  margin-bottom: var(--lb-space-lg);
  color: var(--lb-gray-900);
}
```

Replace with:
```css
.lb-section-title {
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: 0.01em;
  border-bottom: 2px solid var(--lb-section-border);
  padding-bottom: 10px;
  margin-top: var(--lb-space-lg);
  margin-bottom: var(--lb-space-lg);
  color: var(--lb-text);
}
```

- [ ] **Step 7: Replace hardcoded form layout values**

Find:
```css
.lb-form-label {
  min-width: 150px;
  width: 200px;
  text-align: right;
  font-weight: 600;
  font-size: var(--lb-font-sm);
  color: var(--lb-gray-700);
  line-height: 1.4;
}
```

Replace with:
```css
.lb-form-label {
  min-width: 150px;
  width: 200px;
  text-align: right;
  font-weight: 600;
  font-size: var(--lb-font-sm);
  color: var(--lb-text-secondary);
  line-height: 1.4;
}
```

Find:
```css
.lb-form-help {
  flex-basis: 100%;
  font-size: 0.8rem;
  color: var(--lb-gray-500);
  margin-top: calc(-1 * var(--lb-space-sm));
  line-height: 1.5;
  padding-left: 216px;
}
```

Replace with:
```css
.lb-form-help {
  flex-basis: 100%;
  font-size: 0.8rem;
  color: var(--lb-text-muted);
  margin-top: calc(-1 * var(--lb-space-sm));
  line-height: 1.5;
  padding-left: 216px;
}
```

- [ ] **Step 8: Replace hardcoded toggle values**

Find:
```css
.lb-toggle-slider {
  position: absolute;
  cursor: pointer;
  top: 0; left: 0; right: 0; bottom: 0;
  background: var(--lb-gray-300);
  border-radius: 28px;
  transition: background 0.2s ease;
}
```

Replace with:
```css
.lb-toggle-slider {
  position: absolute;
  cursor: pointer;
  top: 0; left: 0; right: 0; bottom: 0;
  background: var(--lb-toggle-bg);
  border-radius: 28px;
  transition: background 0.2s ease;
}
```

- [ ] **Step 9: Replace hardcoded button group values**

Find:
```css
.lb-btn-group .lb-btn,
.lb-btn-group label,
.lb-btn-group input[type="radio"] + label,
.lb-btn-group input[type="checkbox"] + label {
  border: none;
  border-right: var(--lb-border);
  border-radius: 0;
  margin: 0;
  padding: 8px 16px;
  background: var(--lb-gray-100);
  color: var(--lb-gray-900);
  font-family: var(--lb-font);
  font-size: var(--lb-font-sm);
  font-weight: 500;
  cursor: pointer;
  display: inline-block;
  text-align: center;
  transition: background 0.15s ease;
}
```

Replace with:
```css
.lb-btn-group .lb-btn,
.lb-btn-group label,
.lb-btn-group input[type="radio"] + label,
.lb-btn-group input[type="checkbox"] + label {
  border: none;
  border-right: 1px solid var(--lb-border-color);
  border-radius: 0;
  margin: 0;
  padding: 8px 16px;
  background: var(--lb-btn-bg);
  color: var(--lb-text);
  font-family: var(--lb-font);
  font-size: var(--lb-font-sm);
  font-weight: 500;
  cursor: pointer;
  display: inline-block;
  text-align: center;
  transition: background 0.15s ease;
}
```

Also find:
```css
.lb-btn-group .lb-btn:hover,
.lb-btn-group label:hover {
  background: var(--lb-gray-200);
}
```

Replace with:
```css
.lb-btn-group .lb-btn:hover,
.lb-btn-group label:hover {
  filter: brightness(0.95);
}
```

- [ ] **Step 10: Replace hardcoded collapsible values**

Find:
```css
.lb-collapsible summary {
  padding: 10px 16px;
  background: var(--lb-gray-100);
  color: var(--lb-gray-900);
  font-weight: 500;
  font-family: var(--lb-font);
  cursor: pointer;
  list-style: none;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
```

Replace with:
```css
.lb-collapsible summary {
  padding: 10px 16px;
  background: var(--lb-btn-bg);
  color: var(--lb-text);
  font-weight: 500;
  font-family: var(--lb-font);
  cursor: pointer;
  list-style: none;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
```

Find:
```css
.lb-collapsible summary::after {
  content: "\276F";
  font-size: 0.8em;
  color: var(--lb-gray-500);
  transition: transform 0.2s ease;
}
```

Replace with:
```css
.lb-collapsible summary::after {
  content: "\276F";
  font-size: 0.8em;
  color: var(--lb-text-muted);
  transition: transform 0.2s ease;
}
```

- [ ] **Step 11: Remove old jQuery Mobile controlgroup responsive override**

Delete lines 329-344 (the `@media` block with `.ui-controlgroup-horizontal`):
```css
/* === Controlgroup responsive (jQuery Mobile) === */
@media (max-width: 768px) {
  .ui-controlgroup-horizontal .ui-controlgroup-controls {
    display: flex !important;
    width: 100% !important;
  }
  .ui-controlgroup-horizontal .ui-controlgroup-controls .ui-radio,
  .ui-controlgroup-horizontal .ui-controlgroup-controls .ui-checkbox {
    flex: 0 1 auto !important;
  }
  .ui-controlgroup-horizontal .ui-controlgroup-controls .ui-btn {
    margin: 0 !important;
    text-align: center;
    white-space: nowrap;
  }
}
```

Replace with:
```css
/* === Button Group responsive === */
@media (max-width: 768px) {
  .lb-btn-group {
    flex-wrap: wrap;
  }
  .lb-btn-group label {
    flex: 1 1 auto;
    min-width: 0;
  }
}
```

- [ ] **Step 12: Verify visually**

Open a Core page that uses lb-* classes (e.g. backup.cgi). The page should look identical to before — all changes use the same default values that were previously hardcoded.

- [ ] **Step 13: Commit**

```bash
git add webfrontend/html/system/css/components.css
git commit -m "refactor(components): replace hardcoded values with CSS token references"
```

---

### Task 3: Create theme-soft-rounded.css (Design 3)

**Files:**
- Create: `webfrontend/html/system/css/theme-soft-rounded.css`

- [ ] **Step 1: Write the theme file**

```css
/* LoxBerry Theme: Soft & Rounded (Design 3)
   Freundlich, 20px Radius, Gradient-Buttons, weicher Hintergrund.
   Inspired by: Segoe UI, soft shadows, pill-shaped buttons. */

body.theme-soft-rounded {
  --lb-font: 'Segoe UI', system-ui, -apple-system, sans-serif;

  --lb-bg: #f0f4f8;
  --lb-text: #2d3748;
  --lb-text-secondary: #718096;
  --lb-text-muted: #a0aec0;
  --lb-border-color: #e2e8f0;

  --lb-radius: 20px;
  --lb-radius-sm: 12px;

  --lb-card-bg: white;
  --lb-card-border: none;
  --lb-card-shadow: 0 1px 4px rgba(0,0,0,.05);

  --lb-btn-bg: #f0f4f8;
  --lb-btn-text: #718096;
  --lb-btn-border: transparent;
  --lb-btn-radius: 20px;
  --lb-btn-primary-bg: linear-gradient(135deg, #6dac20, #8bc34a);
  --lb-btn-primary-text: white;
  --lb-btn-primary-border: transparent;

  --lb-primary-hover: #8bc34a;

  --lb-input-bg: white;
  --lb-input-border: #e2e8f0;
  --lb-input-text: #2d3748;

  --lb-toggle-bg: #cbd5e0;

  --lb-sidebar-bg: white;
  --lb-sidebar-text: #4a5568;
  --lb-sidebar-active-bg: #f0fff4;
  --lb-sidebar-active-text: #6dac20;
  --lb-sidebar-border: #e2e8f0;
  --lb-sidebar-section: #a0aec0;
}
```

- [ ] **Step 2: Commit**

```bash
git add -f webfrontend/html/system/css/theme-soft-rounded.css
git commit -m "feat(theme): add Soft & Rounded theme (Design 3)"
```

---

### Task 4: Create theme-clean-admin.css (Design 1)

**Files:**
- Create: `webfrontend/html/system/css/theme-clean-admin.css`

- [ ] **Step 1: Write the theme file**

```css
/* LoxBerry Theme: Clean Admin (Design 1)
   Professionell, dunkle Sidebar, heller Content.
   Inspired by: Home Assistant, Grafana, Portainer. */

body.theme-clean-admin {
  --lb-font: system-ui, -apple-system, sans-serif;

  --lb-bg: #f4f5f7;
  --lb-text: #1a1a2e;
  --lb-text-secondary: #555;
  --lb-text-muted: #888;
  --lb-border-color: #e5e5e5;

  --lb-radius: 10px;
  --lb-radius-sm: 6px;

  --lb-card-bg: white;
  --lb-card-border: 1px solid #e5e5e5;
  --lb-card-shadow: 0 1px 3px rgba(0,0,0,.06);

  --lb-btn-bg: #e6e6e6;
  --lb-btn-text: #000;
  --lb-btn-border: #7e7e7e;
  --lb-btn-radius: 4px;
  --lb-btn-primary-bg: #6dac20;
  --lb-btn-primary-text: white;
  --lb-btn-primary-border: #5a9a1a;

  --lb-input-bg: white;
  --lb-input-border: #ddd;
  --lb-input-text: #333;

  --lb-toggle-bg: #ccc;

  --lb-sidebar-bg: #1a1a2e;
  --lb-sidebar-text: rgba(255,255,255,.65);
  --lb-sidebar-active-bg: rgba(109,172,32,.12);
  --lb-sidebar-active-text: #6dac20;
  --lb-sidebar-border: rgba(255,255,255,.08);
  --lb-sidebar-section: rgba(255,255,255,.35);
}
```

- [ ] **Step 2: Commit**

```bash
git add -f webfrontend/html/system/css/theme-clean-admin.css
git commit -m "feat(theme): add Clean Admin theme (Design 1)"
```

---

### Task 5: Create theme-glass.css (Design 2)

**Files:**
- Create: `webfrontend/html/system/css/theme-glass.css`

- [ ] **Step 1: Write the theme file**

```css
/* LoxBerry Theme: Glassmorphism (Design 2)
   Dark gradient, halbtransparente Glaseffekte, Glow-Akzente.
   Uses backdrop-filter for glass effect on cards. */

body.theme-glass {
  --lb-font: system-ui, sans-serif;

  --lb-bg: #0f2027;
  --lb-text: rgba(255,255,255,.8);
  --lb-text-secondary: rgba(255,255,255,.5);
  --lb-text-muted: rgba(255,255,255,.3);
  --lb-border-color: rgba(255,255,255,.07);

  --lb-radius: 14px;
  --lb-radius-sm: 10px;

  --lb-card-bg: rgba(255,255,255,.05);
  --lb-card-border: 1px solid rgba(255,255,255,.07);
  --lb-card-shadow: none;

  --lb-btn-bg: rgba(255,255,255,.06);
  --lb-btn-text: rgba(255,255,255,.4);
  --lb-btn-border: rgba(255,255,255,.08);
  --lb-btn-radius: 10px;
  --lb-btn-primary-bg: rgba(109,172,32,.2);
  --lb-btn-primary-text: #6dac20;
  --lb-btn-primary-border: rgba(109,172,32,.3);

  --lb-primary-hover: #8bc34a;

  --lb-input-bg: rgba(255,255,255,.06);
  --lb-input-border: rgba(255,255,255,.1);
  --lb-input-text: rgba(255,255,255,.8);

  --lb-toggle-bg: rgba(255,255,255,.15);

  --lb-sidebar-bg: rgba(255,255,255,.04);
  --lb-sidebar-text: rgba(255,255,255,.55);
  --lb-sidebar-active-bg: rgba(109,172,32,.1);
  --lb-sidebar-active-text: #6dac20;
  --lb-sidebar-border: rgba(255,255,255,.06);
  --lb-sidebar-section: rgba(255,255,255,.2);

  --lb-backdrop-blur: blur(12px);
  --lb-glow-primary: 0 0 6px rgba(109,172,32,.5);
  --lb-glow-danger: 0 0 6px rgba(220,38,38,.5);
  --lb-glow-warning: 0 0 8px rgba(202,138,4,.3);
}

/* Glass page background gradient */
body.theme-glass {
  background: linear-gradient(135deg, #0f2027 0%, #203a43 40%, #2c5364 100%);
  background-attachment: fixed;
  min-height: 100vh;
}

/* Glass backdrop on cards */
body.theme-glass .lb-card {
  backdrop-filter: var(--lb-backdrop-blur);
  -webkit-backdrop-filter: var(--lb-backdrop-blur);
}

/* Glow on status indicators */
body.theme-glass .lb-status-ok { box-shadow: var(--lb-glow-primary); }
body.theme-glass .lb-status-error { box-shadow: var(--lb-glow-danger); }
body.theme-glass .lb-status-warning { box-shadow: var(--lb-glow-warning); }
```

- [ ] **Step 2: Commit**

```bash
git add -f webfrontend/html/system/css/theme-glass.css
git commit -m "feat(theme): add Glassmorphism theme (Design 2)"
```

---

### Task 6: Create theme-classic-lb.css (Design 9)

**Files:**
- Create: `webfrontend/html/system/css/theme-classic-lb.css`

- [ ] **Step 1: Write the theme file**

```css
/* LoxBerry Theme: Classic LoxBerry (Design 9)
   Vertrautes Design, modernisiert. Flat, kein Shadow, 4px Radius.
   Green header bar, gray sidebar, white content. */

body.theme-classic-lb {
  --lb-font: sans-serif;

  --lb-bg: #f0f0f0;
  --lb-text: #333;
  --lb-text-secondary: #555;
  --lb-text-muted: #aaa;
  --lb-border-color: #ddd;

  --lb-radius: 4px;
  --lb-radius-sm: 2px;

  --lb-card-bg: white;
  --lb-card-border: 1px solid #ddd;
  --lb-card-shadow: none;

  --lb-btn-bg: #f0f0f0;
  --lb-btn-text: #555;
  --lb-btn-border: #ddd;
  --lb-btn-radius: 4px;
  --lb-btn-primary-bg: #6dac20;
  --lb-btn-primary-text: white;
  --lb-btn-primary-border: #5a9a1a;

  --lb-input-bg: white;
  --lb-input-border: #ddd;
  --lb-input-text: #333;

  --lb-toggle-bg: #ccc;

  --lb-sidebar-bg: #3d3d3d;
  --lb-sidebar-text: rgba(255,255,255,.7);
  --lb-sidebar-active-bg: rgba(255,255,255,.1);
  --lb-sidebar-active-text: #6dac20;
  --lb-sidebar-border: rgba(255,255,255,.08);
  --lb-sidebar-section: rgba(255,255,255,.4);
}
```

- [ ] **Step 2: Commit**

```bash
git add -f webfrontend/html/system/css/theme-classic-lb.css
git commit -m "feat(theme): add Classic LoxBerry theme (Design 9)"
```

---

## Phase 2: Template-Migration

### Task 7: Migrate backup.html

**Files:**
- Modify: `templates/system/backup.html:79-136`

- [ ] **Step 1: Replace flipswitch + fieldcontain (lines 79-86)**

Find:
```html
	<div style="display:flex;">
		<div style="width:95%">
			<div data-role="fieldcontain" class="ui-field-contain">
				<label for="scheduleactive"><TMPL_VAR BACKUP.LABEL_ACTIVATE></label>
				<input type="checkbox" id="scheduleactive" data-role="flipswitch" data-mini="true">
			</div>
		</div>
	</div>
```

Replace with:
```html
	<div class="lb-form-row">
		<label class="lb-form-label" for="scheduleactive"><TMPL_VAR BACKUP.LABEL_ACTIVATE></label>
		<div class="lb-form-field">
			<label class="lb-toggle">
				<input type="checkbox" id="scheduleactive">
				<span class="lb-toggle-slider"></span>
			</label>
		</div>
	</div>
```

- [ ] **Step 2: Replace controlgroup + fieldcontain (lines 90-121)**

Find:
```html
	<div style="display:flex;">
		<div style="width: 95%">
			<div data-role="fieldcontain" class="ui-field-contain">
				<label for="wochentag"><TMPL_VAR BACKUP.LABEL_TIME></label>
				<table border=0>
				<tr>
					<td style="width: 28em">
					<fieldset id="wochentag" data-role="controlgroup" data-type="horizontal" data-mini="true">
						<input type="checkbox" name="mon" id="mon">
						<label for="mon"><TMPL_VAR BACKUP.LABEL_MONDAY></label>
						<input type="checkbox" name="tue" id="tue">
						<label for="tue"><TMPL_VAR BACKUP.LABEL_TUESDAY></label>
						<input type="checkbox" name="wed" id="wed">
						<label for="wed"><TMPL_VAR BACKUP.LABEL_WEDNESDAY></label>
						<input type="checkbox" name="thu" id="thu">
						<label for="thu"><TMPL_VAR BACKUP.LABEL_THURSDAY></label>
						<input type="checkbox" name="fre" id="fre">
						<label for="fre"><TMPL_VAR BACKUP.LABEL_FRIDAY></label>
						<input type="checkbox" name="sat" id="sat">
						<label for="sat"><TMPL_VAR BACKUP.LABEL_SATURDAY></label>
						<input type="checkbox" name="sun" id="sun">
						<label for="sun"><TMPL_VAR BACKUP.LABEL_SUNDAY></label>
					</fieldset>
					</td>
					<td style="width: 5em">
					<input type="time" data-clear-btn="false" name="timef" id="timef" value="" data-mini="true">
					</td>
				</tr>
				</table>
			</div>
		</div>
	</div>
```

Replace with:
```html
	<div class="lb-form-row">
		<label class="lb-form-label" for="wochentag"><TMPL_VAR BACKUP.LABEL_TIME></label>
		<div class="lb-form-field" style="display:flex; align-items:center; gap:var(--lb-space-md);">
			<div class="lb-btn-group" id="wochentag">
				<input type="checkbox" name="mon" id="mon">
				<label for="mon"><TMPL_VAR BACKUP.LABEL_MONDAY></label>
				<input type="checkbox" name="tue" id="tue">
				<label for="tue"><TMPL_VAR BACKUP.LABEL_TUESDAY></label>
				<input type="checkbox" name="wed" id="wed">
				<label for="wed"><TMPL_VAR BACKUP.LABEL_WEDNESDAY></label>
				<input type="checkbox" name="thu" id="thu">
				<label for="thu"><TMPL_VAR BACKUP.LABEL_THURSDAY></label>
				<input type="checkbox" name="fre" id="fre">
				<label for="fre"><TMPL_VAR BACKUP.LABEL_FRIDAY></label>
				<input type="checkbox" name="sat" id="sat">
				<label for="sat"><TMPL_VAR BACKUP.LABEL_SATURDAY></label>
				<input type="checkbox" name="sun" id="sun">
				<label for="sun"><TMPL_VAR BACKUP.LABEL_SUNDAY></label>
			</div>
			<input class="lb-input" type="time" name="timef" id="timef" value="" style="width:6em;">
		</div>
	</div>
```

- [ ] **Step 3: Replace repeat fieldcontain (lines 125-136)**

Find:
```html
	<div style="display:flex;">
		<div style="width: 95%">
			<div data-role="fieldcontain" class="ui-field-contain">
				<label for="repeat"><TMPL_VAR BACKUP.LABEL_REPEAT></label>
				<select name="repeat" id="repeat" data-mini="true">
```

Replace with:
```html
	<div class="lb-form-row">
		<label class="lb-form-label" for="repeat"><TMPL_VAR BACKUP.LABEL_REPEAT></label>
		<div class="lb-form-field">
			<select class="lb-select" name="repeat" id="repeat">
```

Also find the closing tags below the select options and replace:
```html
				</select>
			</div>
		</div>
	</div>
```
with:
```html
			</select>
		</div>
	</div>
```

- [ ] **Step 4: Verify in browser**

Open `http://loxberry/admin/system/backup.cgi`, verify the schedule section renders correctly: toggle switch, day checkboxes as button group, time input, repeat dropdown.

- [ ] **Step 5: Commit**

```bash
git add templates/system/backup.html
git commit -m "migrate(backup): replace jQuery Mobile widgets with lb-* classes"
```

---

### Task 8: Migrate mailserver.html

**Files:**
- Modify: `templates/system/mailserver.html:150-175`

- [ ] **Step 1: Replace both controlgroups**

Find the system notifications controlgroup:
```html
		<fieldset data-role="controlgroup" data-type="horizontal">
        <!-- <legend>System notifications</legend> -->
        <input type="checkbox" name="MAIL_SYSTEM_INFOS" id="MAIL_SYSTEM_INFOS" class="MAILNOTIFY">
        <label for="MAIL_SYSTEM_INFOS"><TMPL_VAR MAILSERVER.OPTION_INFOS></label>
        <input type="checkbox" name="MAIL_SYSTEM_ERRORS" id="MAIL_SYSTEM_ERRORS" class="MAILNOTIFY">
        <label for="MAIL_SYSTEM_ERRORS"><TMPL_VAR MAILSERVER.OPTION_ERRORS></label>
		</fieldset>
```

Replace with:
```html
		<div class="lb-btn-group">
        <input type="checkbox" name="MAIL_SYSTEM_INFOS" id="MAIL_SYSTEM_INFOS" class="MAILNOTIFY">
        <label for="MAIL_SYSTEM_INFOS"><TMPL_VAR MAILSERVER.OPTION_INFOS></label>
        <input type="checkbox" name="MAIL_SYSTEM_ERRORS" id="MAIL_SYSTEM_ERRORS" class="MAILNOTIFY">
        <label for="MAIL_SYSTEM_ERRORS"><TMPL_VAR MAILSERVER.OPTION_ERRORS></label>
		</div>
```

Find the plugin notifications controlgroup:
```html
		<fieldset data-role="controlgroup" data-type="horizontal">
        <!-- <legend>Plugin notifications</legend> -->
        <input type="checkbox" name="MAIL_PLUGIN_INFOS" id="MAIL_PLUGIN_INFOS" class="MAILNOTIFY">
        <label for="MAIL_PLUGIN_INFOS"><TMPL_VAR MAILSERVER.OPTION_INFOS></label>
        <input type="checkbox" name="MAIL_PLUGIN_ERRORS" id="MAIL_PLUGIN_ERRORS" class="MAILNOTIFY">
        <label for="MAIL_PLUGIN_ERRORS"><TMPL_VAR MAILSERVER.OPTION_ERRORS></label>
		</fieldset>
```

Replace with:
```html
		<div class="lb-btn-group">
        <input type="checkbox" name="MAIL_PLUGIN_INFOS" id="MAIL_PLUGIN_INFOS" class="MAILNOTIFY">
        <label for="MAIL_PLUGIN_INFOS"><TMPL_VAR MAILSERVER.OPTION_INFOS></label>
        <input type="checkbox" name="MAIL_PLUGIN_ERRORS" id="MAIL_PLUGIN_ERRORS" class="MAILNOTIFY">
        <label for="MAIL_PLUGIN_ERRORS"><TMPL_VAR MAILSERVER.OPTION_ERRORS></label>
		</div>
```

- [ ] **Step 2: Commit**

```bash
git add templates/system/mailserver.html
git commit -m "migrate(mailserver): replace jQuery Mobile controlgroups with lb-btn-group"
```

---

### Task 9: Migrate network.html

**Files:**
- Modify: `templates/system/network.html:39,109,187`

- [ ] **Step 1: Replace interface controlgroup (line 39)**

Find:
```html
					<fieldset data-role="controlgroup" id="netzwerkanschluss">
```

Replace with:
```html
					<div class="lb-btn-group" id="netzwerkanschluss" style="flex-direction:column;">
```

Find its closing tag:
```html
					</fieldset>
```

Replace with:
```html
					</div>
```

- [ ] **Step 2: Replace IPv4 controlgroup (line 109)**

Find:
```html
						<fieldset data-role="controlgroup">
```

Replace with:
```html
						<div class="lb-btn-group" style="flex-direction:column;">
```

Find its closing tag:
```html
						</fieldset>
```

Replace with:
```html
						</div>
```

- [ ] **Step 3: Replace IPv6 controlgroup (line 187)**

Find:
```html
						<fieldset data-role="controlgroup">
							<input onclick="disable(); validate_clean_objects(['#netzwerkipadresse_IPv6','#netzwerkipmaske_IPv6','#netzwerknameserver_IPv6']);" <TMPL_VAR CHECKED_AUTO_IPv6> id="netzwerkadressen_auto_IPv6" name="netzwerkadressen_IPv6" type="radio" value="auto">
```

Replace the opening `<fieldset>` with `<div class="lb-btn-group" style="flex-direction:column;">` and the closing `</fieldset>` with `</div>`, keeping all inner content identical.

- [ ] **Step 4: Commit**

```bash
git add templates/system/network.html
git commit -m "migrate(network): replace jQuery Mobile controlgroups with lb-btn-group"
```

---

### Task 10: Migrate plugininstall.html

**Files:**
- Modify: `templates/system/plugininstall.html:157,186`

- [ ] **Step 1: Replace auto-update controlgroup**

Find:
```html
			<fieldset data-role="controlgroup" data-type="horizontal" data-mini="true">
				<input type="radio" name="au_<TMPL_VAR PLUGINDB_MD5_CHECKSUM>" id="au_<TMPL_VAR PLUGINDB_MD5_CHECKSUM>_option1"	value="1">
```

Replace opening tag:
```html
			<div class="lb-btn-group">
				<input type="radio" name="au_<TMPL_VAR PLUGINDB_MD5_CHECKSUM>" id="au_<TMPL_VAR PLUGINDB_MD5_CHECKSUM>_option1"	value="1">
```

Replace closing `</fieldset>` with `</div>`.

Also update the JavaScript `checkboxradio("refresh")` call below it. Find:
```javascript
				$( "#au_<TMPL_VAR PLUGINDB_MD5_CHECKSUM>_option"+<TMPL_VAR PLUGINDB_AUTOUPDATE> ).prop( "checked", true ).checkboxradio( "refresh" );
```

Replace with:
```javascript
				$( "#au_<TMPL_VAR PLUGINDB_MD5_CHECKSUM>_option"+<TMPL_VAR PLUGINDB_AUTOUPDATE> ).prop( "checked", true ).trigger("change");
```

- [ ] **Step 2: Replace loglevel controlgroup**

Find:
```html
				<fieldset data-role="controlgroup" data-type="horizontal" data-mini="true">
				<select name="loglevel<TMPL_VAR PLUGINDB_MD5_CHECKSUM>" id="loglevel<TMPL_VAR PLUGINDB_MD5_CHECKSUM>" data-mini="true">
```

Replace with:
```html
				<select class="lb-select" name="loglevel<TMPL_VAR PLUGINDB_MD5_CHECKSUM>" id="loglevel<TMPL_VAR PLUGINDB_MD5_CHECKSUM>">
```

Remove the closing `</fieldset>` that wraps the select.

- [ ] **Step 3: Commit**

```bash
git add templates/system/plugininstall.html
git commit -m "migrate(plugininstall): replace jQuery Mobile controlgroups with lb-* classes"
```

---

### Task 11: Migrate updates.html

**Files:**
- Modify: `templates/system/updates.html:12,22,229,239,250`

- [ ] **Step 1: Replace all 5 controlgroups**

For each of the 5 `<fieldset data-role="controlgroup" ...>` occurrences, replace the opening tag with `<div class="lb-btn-group">` and the closing `</fieldset>` with `</div>`. Remove `data-mini="true"` and `style="width:300px"` attributes.

First controlgroup (line 12):
```html
<!-- OLD -->
<fieldset data-role="controlgroup" data-mini="true" style="width:300px">
<TMPL_VAR UPDATE_RADIO>
</fieldset>

<!-- NEW -->
<div class="lb-btn-group" style="flex-direction:column;">
<TMPL_VAR UPDATE_RADIO>
</div>
```

Second controlgroup (line 22):
```html
<!-- OLD -->
<fieldset data-role="controlgroup" data-mini="true" style="width:300px">
<TMPL_VAR UPDATE_REBOOT_CHECKBOX>
</fieldset>

<!-- NEW -->
<div class="lb-btn-group" style="flex-direction:column;">
<TMPL_VAR UPDATE_REBOOT_CHECKBOX>
</div>
```

Third (line 229), fourth (line 239), fifth (line 250) — same pattern:
```html
<!-- OLD -->
<fieldset data-role="controlgroup" data-mini="true">

<!-- NEW -->
<div class="lb-btn-group" style="flex-direction:column;">
```

And replace each matching `</fieldset>` with `</div>`.

For the fifth one also fix the invalid ID:
```html
<!-- OLD -->
<fieldset id="#installtime" data-role="controlgroup" data-mini="true">

<!-- NEW -->
<div class="lb-btn-group" id="installtime" style="flex-direction:column;">
```

- [ ] **Step 2: Commit**

```bash
git add templates/system/updates.html
git commit -m "migrate(updates): replace jQuery Mobile controlgroups with lb-btn-group"
```

---

### Task 12: Migrate services_timeserver.html, remote.html, miniserver.html

**Files:**
- Modify: `templates/system/services_timeserver.html:26`
- Modify: `templates/system/remote.html:60-64`
- Modify: `templates/system/miniserver.html:621-628`

- [ ] **Step 1: services_timeserver.html — Replace controlgroup**

Find:
```html
				<fieldset data-role="controlgroup">
```

Replace with:
```html
				<div class="lb-btn-group" style="flex-direction:column;">
```

Replace closing `</fieldset>` with `</div>`.

- [ ] **Step 2: remote.html — Replace flipswitch + fieldcontain**

Find:
```html
		<div style="width: 20%">
			<div data-role="fieldcontain" class="ui-field-contain">
				<input type="checkbox" id="autoconnect" data-role="flipswitch" data-mini="true">
			</div>
		</div>
```

Replace with:
```html
		<div style="width: 20%">
			<label class="lb-toggle">
				<input type="checkbox" id="autoconnect">
				<span class="lb-toggle-slider"></span>
			</label>
		</div>
```

- [ ] **Step 3: miniserver.html — Replace collapsible + ui-btn**

Find:
```html
	<div data-role="collapsible">
		<h4>Details</h4>
		<div class="monospace"><TMPL_VAR ERRORDETAILS></div>
		</div>
		<div style="text-align:center;">
		<p>
			<a id="btnback" href="javascript:history.back();" class="ui-btn ui-btn-inline ui-mini ui-corner-all ui-btn-icon-left ui-icon-delete"><TMPL_VAR COMMON.BUTTON_BACK></a>
		</p>
		</div>
```

Replace with:
```html
	<details class="lb-collapsible">
		<summary>Details</summary>
		<div class="lb-collapsible-content monospace"><TMPL_VAR ERRORDETAILS></div>
	</details>
		<div style="text-align:center;">
		<p>
			<a id="btnback" href="javascript:history.back();" class="lb-btn lb-btn-sm lb-btn-icon"><i class="pi pi-arrow-left"></i> <TMPL_VAR COMMON.BUTTON_BACK></a>
		</p>
		</div>
```

- [ ] **Step 4: Commit**

```bash
git add templates/system/services_timeserver.html templates/system/remote.html templates/system/miniserver.html
git commit -m "migrate(timeserver,remote,miniserver): replace jQM widgets with lb-* classes"
```

---

### Task 13: Migrate translate.html, myloxberry.html, fileanalyzer.html

**Files:**
- Modify: `templates/system/translate.html:135-177`
- Modify: `templates/system/myloxberry.html:56-60`
- Modify: `templates/system/fileanalyzer.html:61-63`

- [ ] **Step 1: translate.html — Replace all 6 controlgroups**

For each of the 6 `<fieldset data-role="controlgroup" data-mini="true">` blocks, replace with plain `<div>`. These controlgroups are used as form wrappers, not as button groups — they contain labels, selects, and buttons, not radio/checkbox groups.

Replace every occurrence of:
```html
<fieldset data-role="controlgroup" data-mini="true">
```
with:
```html
<div>
```

And every matching:
```html
</fieldset>
```
with:
```html
</div>
```

Also replace the ui-btn (in the download section):
```html
<a href="#" id="downloadfile" class="ui-btn ui-btn-inline"><TMPL_VAR TRANSLATE.BUTTON_DOWNLOAD></a>
```

With:
```html
<a href="#" id="downloadfile" class="lb-btn"><TMPL_VAR TRANSLATE.BUTTON_DOWNLOAD></a>
```

And replace the submit button:
```html
<input type="submit" data-icon="eye" tabindex="3" value="<TMPL_VAR TRANSLATE.BUTTON_LOAD>">
```

With:
```html
<input type="submit" class="lb-btn lb-btn-primary" tabindex="3" value="<TMPL_VAR TRANSLATE.BUTTON_LOAD>">
```

- [ ] **Step 2: myloxberry.html — Replace send statistics controlgroup**

Find:
```html
			<fieldset data-role="controlgroup" data-mini="true">
				<TMPL_VAR SENDSTATISTIC_CHECKBOX>
			</fieldset>
```

Replace with:
```html
			<div>
				<TMPL_VAR SENDSTATISTIC_CHECKBOX>
			</div>
```

- [ ] **Step 3: fileanalyzer.html — Replace fieldcontain**

Find:
```html
	<div data-role="fieldcontain">
		<label for="minSize" style="color:darkgray;font-size:80%">Only show files larger than (MB)</label>
		<input name="minSize" v-model="lsof_minsize" placeholder="Min Size" @update:lsof_minsize="lsof_minsize = $event" data-mini="true" />
	</div>
```

Replace with:
```html
	<div class="lb-form-row">
		<label class="lb-form-label" for="minSize">Only show files larger than (MB)</label>
		<div class="lb-form-field">
			<input class="lb-input" name="minSize" v-model="lsof_minsize" placeholder="Min Size" @update:lsof_minsize="lsof_minsize = $event" />
		</div>
	</div>
```

- [ ] **Step 4: Commit**

```bash
git add templates/system/translate.html templates/system/myloxberry.html templates/system/fileanalyzer.html
git commit -m "migrate(translate,myloxberry,fileanalyzer): replace jQM widgets with lb-* classes"
```

---

### Task 14: Migrate mqtt-gateway.html JS-generated controlgroups

**Files:**
- Modify: `templates/system/mqtt-gateway.html:1194-1230`

- [ ] **Step 1: Update http_table_skel() function**

Find (inside the `http_table_skel()` function):
```javascript
		http_table+= '<fieldset data-role="controlgroup" data-type="horizontal" class="http_filters">';
		http_table+= '<label style="display:inline;"><input type="checkbox" data-mini="true" id="http_filter_all" class="http_filter_checkbox" checked>Show All</label>';
		http_table+= '<label style="display:inline;"><input type="checkbox" data-mini="true" id="http_filter_200" class="http_filter_checkbox"><img src="../../system/images/icon-check.png" height="12">&nbsp;OK</label>';
		http_table+= '<label style="display:inline;"><input type="checkbox" data-mini="true" id="http_filter_404" class="http_filter_checkbox"><img src="../../system/images/icon-notfound.png" height="12">&nbsp;Not found</label>';
```

Replace `<fieldset data-role="controlgroup" data-type="horizontal" class="http_filters">` with `<div class="lb-btn-group http_filters">`.

Remove all `data-mini="true"` from the checkbox inputs inside.

Replace the closing `</fieldset>` in http_table_skel with `</div>`.

- [ ] **Step 2: Update udp_table_skel() function**

Same pattern — find:
```javascript
		udp_table+= '<fieldset data-role="controlgroup" data-type="horizontal" class="udp_filters">';
```

Replace with:
```javascript
		udp_table+= '<div class="lb-btn-group udp_filters">';
```

Remove `data-mini="true"` from inputs. Replace closing `</fieldset>` with `</div>`.

- [ ] **Step 3: Commit**

```bash
git add templates/system/mqtt-gateway.html
git commit -m "migrate(mqtt-gateway): replace JS-generated controlgroups with lb-btn-group"
```

---

## Phase 3: Theme-Infrastruktur

### Task 15: Update Perl backend (System.pm, Web.pm, ajax-handler)

**Files:**
- Modify: `libs/perllib/LoxBerry/System.pm:543-544`
- Modify: `libs/perllib/LoxBerry/Web.pm:137-142`
- Modify: `webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi:58-62`

- [ ] **Step 1: Update System.pm theme validation**

Find (line 543-544):
```perl
	$lbtheme        = $cfg->{Base}->{Theme} // 'classic';
	$lbtheme        = 'classic' unless $lbtheme =~ /^(classic|modern|dark)$/;
```

Replace with:
```perl
	$lbtheme        = $cfg->{Base}->{Theme} // 'soft-rounded';
	# Map legacy theme names to new themes
	my %_theme_map = ('classic' => 'classic-lb', 'modern' => 'soft-rounded', 'dark' => 'glass');
	$lbtheme = $_theme_map{$lbtheme} if exists $_theme_map{$lbtheme};
	$lbtheme = 'soft-rounded' unless $lbtheme =~ /^(soft-rounded|clean-admin|glass|classic-lb)$/;
```

- [ ] **Step 2: Update Web.pm theme template variables**

Find (lines 137-142):
```perl
	# Theme support
	my $theme = $LoxBerry::System::lbtheme // 'classic';
	$theme = 'classic' unless $theme =~ /^(classic|modern|dark)$/;
	$headobj->param( THEME_CLASS => "theme-$theme" );
	$headobj->param( THEME_CLASSIC => ($theme eq 'classic' ? 1 : 0) );
	$headobj->param( THEME_MODERN => ($theme eq 'modern' ? 1 : 0) );
	$headobj->param( THEME_DARK => ($theme eq 'dark' ? 1 : 0) );
```

Replace with:
```perl
	# Theme support
	my $theme = $LoxBerry::System::lbtheme // 'soft-rounded';
	$theme = 'soft-rounded' unless $theme =~ /^(soft-rounded|clean-admin|glass|classic-lb)$/;
	$headobj->param( THEME_CLASS => "theme-$theme" );
	$headobj->param( THEME_FILE => "theme-$theme.css" );
```

- [ ] **Step 3: Update ajax-config-handler.cgi**

Find (lines 58-62):
```perl
elsif ($action eq 'changetheme') {
	if ($value =~ /^(classic|modern|dark)$/) {
		change_generaljson("Base->Theme", $value);
	}
}
```

Replace with:
```perl
elsif ($action eq 'changetheme') {
	if ($value =~ /^(soft-rounded|clean-admin|glass|classic-lb)$/) {
		change_generaljson("Base->Theme", $value);
	}
}
```

- [ ] **Step 4: Commit**

```bash
git add libs/perllib/LoxBerry/System.pm libs/perllib/LoxBerry/Web.pm webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi
git commit -m "feat(backend): update Perl theme validation for new theme system"
```

---

### Task 16: Update head.html for dynamic theme loading

**Files:**
- Modify: `templates/system/head.html:16-18`

- [ ] **Step 1: Replace conditional theme includes with dynamic link**

Find:
```html
	<TMPL_IF THEME_CLASSIC><link rel="stylesheet" href="/system/css/theme-classic.css?v=2" /></TMPL_IF>
	<TMPL_IF THEME_MODERN><link rel="stylesheet" href="/system/css/theme-modern.css?v=2" /></TMPL_IF>
	<TMPL_IF THEME_DARK><link rel="stylesheet" href="/system/css/theme-dark.css?v=2" /></TMPL_IF>
```

Replace with:
```html
	<link rel="stylesheet" href="/system/css/<TMPL_VAR THEME_FILE>?v=3" />
```

- [ ] **Step 2: Commit**

```bash
git add templates/system/head.html
git commit -m "feat(head): dynamic theme CSS loading via THEME_FILE variable"
```

---

### Task 17: Update myloxberry.html theme dropdown

**Files:**
- Modify: `templates/system/myloxberry.html:32-36,100-101`

- [ ] **Step 1: Replace theme dropdown options**

Find:
```html
				<select name="themeselector" id="themeselector" data-mini="true">
					<option value="classic">Classic</option>
					<option value="modern">Modern Flat</option>
					<option value="dark">Dark Mode</option>
				</select>
```

Replace with:
```html
				<select class="lb-select" name="themeselector" id="themeselector">
					<option value="soft-rounded">Soft &amp; Rounded</option>
					<option value="clean-admin">Clean Admin</option>
					<option value="glass">Glassmorphism</option>
					<option value="classic-lb">Classic LoxBerry</option>
				</select>
```

- [ ] **Step 2: Update JavaScript theme initialization**

Find:
```javascript
			var currentTheme = "<TMPL_VAR CURRENTTHEME>" || "classic";
			$("#themeselector").val(currentTheme).selectmenu('refresh');
```

Replace with:
```javascript
			var currentTheme = "<TMPL_VAR CURRENTTHEME>" || "soft-rounded";
			$("#themeselector").val(currentTheme);
```

(Remove `.selectmenu('refresh')` — that's a jQuery Mobile method that won't exist with `lb-select`.)

- [ ] **Step 3: Commit**

```bash
git add templates/system/myloxberry.html
git commit -m "feat(myloxberry): update theme dropdown for 4 new themes"
```

---

## Phase 4: Cleanup & Verify

### Task 18: Remove obsolete old theme files and main.css overrides

**Files:**
- Modify: `webfrontend/html/system/css/main.css` — remove jQuery Mobile widget overrides

- [ ] **Step 1: Remove ui-flipswitch overrides from main.css**

Search main.css for `.ui-flipswitch` rules and remove them. These styled the jQuery Mobile flipswitch which is now replaced by `.lb-toggle`.

- [ ] **Step 2: Remove ui-controlgroup-controls exceptions from main.css**

Search main.css for `.ui-controlgroup-controls` and remove those rules. They prevented table styling from leaking into jQuery Mobile controlgroups, which no longer exist.

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/main.css
git commit -m "cleanup(main.css): remove obsolete jQuery Mobile widget overrides"
```

---

### Task 19: Visual verification on LoxBerry

**Files:** None (testing only)

- [ ] **Step 1: Deploy to LoxBerry**

Copy changed files to L: (network drive to 192.168.30.10):
```bash
# CSS files
cp webfrontend/html/system/css/design-tokens.css L:/opt/loxberry/webfrontend/html/system/css/
cp webfrontend/html/system/css/components.css L:/opt/loxberry/webfrontend/html/system/css/
cp webfrontend/html/system/css/theme-*.css L:/opt/loxberry/webfrontend/html/system/css/

# Templates (convert CRLF -> LF)
for f in templates/system/backup.html templates/system/mailserver.html templates/system/network.html templates/system/plugininstall.html templates/system/updates.html templates/system/services_timeserver.html templates/system/remote.html templates/system/miniserver.html templates/system/translate.html templates/system/myloxberry.html templates/system/fileanalyzer.html templates/system/mqtt-gateway.html templates/system/head.html; do
  sed 's/\r$//' "$f" > "L:/opt/loxberry/$f"
done

# Perl + CGI (convert CRLF -> LF)
sed 's/\r$//' libs/perllib/LoxBerry/System.pm > L:/opt/loxberry/libs/perllib/LoxBerry/System.pm
sed 's/\r$//' libs/perllib/LoxBerry/Web.pm > L:/opt/loxberry/libs/perllib/LoxBerry/Web.pm
sed 's/\r$//' webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi > L:/opt/loxberry/webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi
```

- [ ] **Step 2: Test each theme**

Open `http://loxberry/admin/system/myloxberry.cgi` and switch through all 4 themes. For each theme, verify:

1. Theme dropdown works and page reloads with new style
2. Buttons have correct radius, color, font
3. Form inputs are styled correctly
4. Section titles use theme colors

- [ ] **Step 3: Test migrated pages per theme**

For the active theme, navigate to each page and verify:
- backup.cgi — toggle switch, day buttons, time input, repeat dropdown
- mailserver.cgi — notification checkboxes
- network.cgi — radio button groups for interface, IPv4, IPv6
- plugininstall.cgi — auto-update radios, loglevel dropdown
- updates.cgi — all radio groups
- services_timeserver.cgi — NTP radio
- remote.cgi — autoconnect toggle
- miniserver.cgi — error details collapsible (trigger by saving invalid data)
- translate.cgi — form elements, download button
- fileanalyzer.cgi — min size input

- [ ] **Step 4: Test plugin pages**

Open any plugin page (e.g. Stats4Lox). Verify that plugin pages still render correctly with jQuery Mobile — they must NOT break.

- [ ] **Step 5: Test mobile**

Open LoxBerry on a phone or use browser DevTools responsive mode. Verify:
- Button groups wrap on small screens
- Form layout stacks vertically
- Toggle switches are touch-friendly
