# Redesign Phase 1: Design-System Fundament

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce CSS Variable design tokens, scrollable tabs, responsive flex layout, and refactor themes to use tokens — without breaking any existing plugin pages.

**Architecture:** A new `design-tokens.css` defines all colors/spacing/typography as CSS Variables. Theme files are reduced to variable overrides. A new `components.css` provides `lb-*` classes for future migration. Scrollable tabs and improved responsive breakpoints are added via CSS only.

**Tech Stack:** Pure CSS3 (CSS Custom Properties), HTML::Template (Perl), Vue 3 (navbar only)

**Spec:** `docs/superpowers/specs/2026-03-25-redesign-design-system.md`

**Test approach:** Manual visual testing on live LoxBerry (L: drive). After each task, copy changed files to L:, hard-refresh browser, verify:
1. Classic/Modern/Dark themes render correctly
2. Plugin pages (Weather4Loxone) are unaffected
3. Responsive behavior works at 1920px, 768px, 375px widths

---

### Task 1: Create design-tokens.css

**Files:**
- Create: `webfrontend/html/system/css/design-tokens.css`

- [ ] **Step 1: Create the design tokens file**

```css
/* LoxBerry Design Tokens
   All design values as CSS Variables.
   Themes override these variables — no structural changes needed. */

:root {
  /* === Colors === */
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
  --lb-border-color: var(--lb-gray-200);
  --lb-border: 1px solid var(--lb-border-color);
}
```

- [ ] **Step 2: Copy to L: and verify it loads**

```bash
cp "D:/Claude_Projekte/Loxberry NeXtGen/webfrontend/html/system/css/design-tokens.css" "L:/webfrontend/html/system/css/design-tokens.css"
```

Open browser DevTools → Elements → `<html>` → Computed → should NOT show `--lb-primary` yet (not linked in head.html yet).

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/design-tokens.css
git commit -m "feat: create design-tokens.css with CSS Variables"
```

---

### Task 2: Link design-tokens.css in head.html

**Files:**
- Modify: `templates/system/head.html:13`

- [ ] **Step 1: Add design-tokens.css link before main.css**

In `templates/system/head.html`, change line 13 from:

```html
	<link rel="stylesheet" href="/system/css/main.css?v=2" />
```

to:

```html
	<link rel="stylesheet" href="/system/css/design-tokens.css" />
	<link rel="stylesheet" href="/system/css/main.css?v=2" />
```

Design tokens must load first so `main.css` and theme files can reference them.

- [ ] **Step 2: Copy to L: and verify**

```bash
cp "D:/Claude_Projekte/Loxberry NeXtGen/templates/system/head.html" "L:/templates/system/head.html"
```

Open browser DevTools → Elements → `<html>` → Computed → verify `--lb-primary: #6dac20` is visible.

- [ ] **Step 3: Commit**

```bash
git add templates/system/head.html
git commit -m "feat: link design-tokens.css in head.html"
```

---

### Task 3: Refactor theme-dark.css to use CSS Variables

**Files:**
- Modify: `webfrontend/html/system/css/design-tokens.css` (add dark theme tokens)
- Modify: `webfrontend/html/system/css/theme-dark.css` (use variables)

- [ ] **Step 1: Add dark theme variable overrides to design-tokens.css**

Append to `design-tokens.css`:

```css
/* === Dark Theme Token Overrides === */
body.theme-dark {
  --lb-gray-50: #1e1e2e;
  --lb-gray-100: #252536;
  --lb-gray-200: #333350;
  --lb-gray-300: #444466;
  --lb-gray-500: #888888;
  --lb-gray-700: #c0c0c0;
  --lb-gray-900: #f0f0f0;
  --lb-border-color: var(--lb-gray-200);
}
```

- [ ] **Step 2: Replace hardcoded colors in theme-dark.css with variables**

Replace the full content of `theme-dark.css` with:

```css
/* LoxBerry Dark Mode Theme
   Colors via CSS Variables from design-tokens.css
   Only override colors — never touch jQuery Mobile structure */

/* === Global === */
.theme-dark .ui-page {
  background-color: var(--lb-gray-50);
  color: var(--lb-gray-900);
}

.theme-dark * {
  text-shadow: none !important;
}

.theme-dark .loxberry-logo,
.theme-dark .ui-panel-wrapper {
  background-image: none !important;
}

/* === Header === */
.theme-dark .ui-header .ui-bar-a {
  background: var(--lb-gray-100);
  color: var(--lb-gray-900);
  border-bottom-color: var(--lb-gray-200);
}

.theme-dark .ui-header .ui-bar-a .ui-btn,
.theme-dark .ui-header .ui-bar-a h1 {
  color: var(--lb-gray-900);
  text-shadow: none;
}

.theme-dark .ui-header .ui-bar-a .ui-btn:hover {
  color: var(--lb-primary);
}

/* === Buttons — colors only === */
.theme-dark .ui-btn {
  text-shadow: none;
  box-shadow: none;
  background: var(--lb-gray-100);
  color: var(--lb-gray-700);
  border-color: var(--lb-gray-300);
  font-weight: 500;
}

.theme-dark .ui-btn:hover {
  background: var(--lb-gray-200);
  border-color: var(--lb-gray-300);
}

.theme-dark .ui-btn-active,
.theme-dark .ui-btn.ui-btn-active,
.theme-dark .ui-radio-on .ui-btn,
.theme-dark .ui-checkbox-on .ui-btn,
.theme-dark .ui-controlgroup .ui-btn-active {
  background: var(--lb-primary) !important;
  color: white !important;
  border-color: var(--lb-primary) !important;
}

.theme-dark button[type="submit"],
.theme-dark .ui-btn-icon-left[data-icon="check"] {
  background: var(--lb-primary);
  color: white;
  border-color: var(--lb-primary-hover);
}

/* === Inputs — colors only === */
.theme-dark .ui-input-text,
.theme-dark .ui-input-search {
  border-color: transparent !important;
  box-shadow: none !important;
  background: transparent !important;
}

.theme-dark .ui-input-text input,
.theme-dark .ui-input-search input,
.theme-dark textarea,
.theme-dark select {
  border-color: var(--lb-gray-300) !important;
  background: var(--lb-gray-100) !important;
  color: var(--lb-gray-900) !important;
}

.theme-dark input::placeholder,
.theme-dark textarea::placeholder {
  color: var(--lb-gray-500) !important;
}

.theme-dark .ui-input-text input:focus,
.theme-dark .ui-input-search input:focus,
.theme-dark textarea:focus {
  border-color: var(--lb-primary) !important;
  outline: none;
  box-shadow: 0 0 0 3px rgba(109, 172, 32, 0.25);
}

/* === Content === */
.theme-dark .ui-content {
  background: var(--lb-gray-50);
  color: var(--lb-gray-900);
}

.theme-dark .ui-body-a,
.theme-dark .ui-body-inherit {
  background-color: var(--lb-gray-100);
  color: var(--lb-gray-900);
}

/* === Links === */
.theme-dark a {
  color: #8bc34a;
}

.theme-dark a:visited {
  color: #7cb342;
}

/* === Selects — colors only === */
.theme-dark .ui-select .ui-btn {
  border-color: var(--lb-gray-300) !important;
  background: var(--lb-gray-100) !important;
  color: var(--lb-gray-900);
}

.theme-dark .ui-select .ui-btn span {
  color: var(--lb-gray-900) !important;
}

.theme-dark select option {
  background: var(--lb-gray-100);
  color: var(--lb-gray-900);
}

/* === Panel === */
.theme-dark .ui-panel {
  background: var(--lb-gray-100);
}

.theme-dark .ui-panel-inner {
  color: var(--lb-gray-900);
}

/* === Side Menu === */
.theme-dark ul.lb-systemmenu li.lb-nonhover {
  background-color: var(--lb-primary);
  color: white !important;
}

.theme-dark ul.lb-systemmenu li {
  color: var(--lb-gray-700) !important;
  background-color: var(--lb-gray-100);
  border-bottom-color: var(--lb-gray-200);
}

.theme-dark ul.lb-systemmenu a {
  color: var(--lb-gray-700) !important;
}

.theme-dark ul.lb-systemmenu li:hover {
  background-color: var(--lb-primary);
  color: black !important;
}

.theme-dark ul.lb-systemmenu li:hover a {
  color: black !important;
}

/* === Tables — colors only === */
.theme-dark table td {
  color: var(--lb-gray-900);
}

/* === Flipswitch === */
.theme-dark .ui-flipswitch {
  background-color: var(--lb-gray-200) !important;
}

.theme-dark .ui-flipswitch-active {
  background-color: var(--lb-primary) !important;
}

.theme-dark .ui-slider-track {
  background-color: var(--lb-gray-200) !important;
}

/* === Section Headers === */
.theme-dark .wide {
  color: var(--lb-gray-900);
  border-bottom-color: var(--lb-primary);
}

.theme-dark h1, .theme-dark h2, .theme-dark h3, .theme-dark h4 {
  color: var(--lb-gray-900);
}

/* === Text colors === */
.theme-dark label,
.theme-dark .ui-controlgroup label {
  color: var(--lb-gray-700);
}

.theme-dark .hint {
  color: var(--lb-gray-700);
}

.theme-dark p, .theme-dark span, .theme-dark div {
  color: inherit;
}

.theme-dark small, .theme-dark .small {
  color: var(--lb-gray-500);
}

/* === Checkboxes & Radios — colors only === */
.theme-dark .ui-checkbox label,
.theme-dark .ui-radio label {
  color: var(--lb-gray-900) !important;
  background: var(--lb-gray-100) !important;
  border-color: var(--lb-gray-200) !important;
}

/* === Fieldset === */
.theme-dark fieldset {
  border-color: var(--lb-gray-200);
}

/* === Controlgroup — colors only === */
.theme-dark .ui-controlgroup .ui-btn {
  border-color: var(--lb-gray-200);
  background: var(--lb-gray-100);
  color: var(--lb-gray-700);
}

/* === Navbar — colors only === */
.theme-dark [data-role="navbar"] .ui-btn {
  background: var(--lb-gray-100) !important;
  color: var(--lb-gray-700) !important;
  border-color: var(--lb-gray-200) !important;
}

.theme-dark [data-role="navbar"] .ui-btn-active {
  background: var(--lb-primary) !important;
  color: white !important;
}

/* === Collapsible — colors only === */
.theme-dark .ui-collapsible-heading .ui-btn {
  background: var(--lb-gray-100);
  border-color: var(--lb-gray-200);
  color: var(--lb-gray-900);
}

/* === Footer === */
.theme-dark [data-role="footer"] {
  border-top-color: var(--lb-gray-200);
}

/* === Log colors === */
.theme-dark .logstart { background-color: var(--lb-primary); }
.theme-dark .loginf, .theme-dark .logdeb { background-color: #1a2a40; color: #c0d8f0; }
.theme-dark .logok { background-color: #1a3a1e; color: #a0d8a8; }
.theme-dark .logwarn { background-color: #3a3a1a; color: #d8d890; }
.theme-dark .logerr { background-color: #3a1a1a; color: #e0a0a0; }
.theme-dark .logcrit { background-color: #4a1a1a; color: #f0b0b0; }

/* === Form errors === */
.theme-dark .form-error, .theme-dark .form-error-message {
  color: var(--lb-danger);
}

/* === Dropzone === */
.theme-dark #dropzone {
  border-color: var(--lb-gray-300) !important;
  background: var(--lb-gray-100) !important;
}
.theme-dark #dropzone-text { color: var(--lb-gray-500) !important; }
.theme-dark #dropzone-text span { color: var(--lb-primary) !important; }
.theme-dark #dropzone-filename { color: var(--lb-gray-900) !important; }
```

- [ ] **Step 3: Copy both files to L: and test**

```bash
cp "D:/Claude_Projekte/Loxberry NeXtGen/webfrontend/html/system/css/design-tokens.css" "L:/webfrontend/html/system/css/design-tokens.css"
cp "D:/Claude_Projekte/Loxberry NeXtGen/webfrontend/html/system/css/theme-dark.css" "L:/webfrontend/html/system/css/theme-dark.css"
```

Switch to Dark theme, hard-refresh. Verify:
- All colors look the same as before
- No structural changes (buttons, controlgroups unchanged)
- Plugin pages still render correctly

- [ ] **Step 4: Commit**

```bash
git add webfrontend/html/system/css/design-tokens.css webfrontend/html/system/css/theme-dark.css
git commit -m "refactor: dark theme uses CSS Variables from design-tokens.css"
```

---

### Task 4: Refactor theme-modern.css to use CSS Variables

**Files:**
- Modify: `webfrontend/html/system/css/design-tokens.css` (add modern theme tokens)
- Modify: `webfrontend/html/system/css/theme-modern.css` (use variables)

- [ ] **Step 1: Add modern theme variable overrides to design-tokens.css**

Append to `design-tokens.css`:

```css
/* === Modern Theme Token Overrides === */
body.theme-modern {
  --lb-font: 'Segoe UI', system-ui, -apple-system, sans-serif;
}
```

Modern theme uses mostly the same colors as default (`:root`), only the font changes. All color overrides happen via the existing theme-modern.css selectors using the variables.

- [ ] **Step 2: Replace hardcoded colors in theme-modern.css with variables**

Replace the full content of `theme-modern.css` with:

```css
/* LoxBerry Modern Flat Theme
   Colors via CSS Variables from design-tokens.css
   Only override colors — never touch jQuery Mobile structure */

/* === Global === */
.theme-modern .ui-page {
  background-color: var(--lb-gray-50);
  font-family: var(--lb-font);
}

.theme-modern * {
  text-shadow: none !important;
}

/* === Header === */
.theme-modern .ui-header .ui-bar-a {
  background: #ffffff;
  color: var(--lb-gray-900);
  border-bottom-color: var(--lb-gray-200);
}

.theme-modern .ui-header .ui-bar-a .ui-btn,
.theme-modern .ui-header .ui-bar-a h1 {
  color: var(--lb-gray-900);
  text-shadow: none;
}

.theme-modern .ui-header .ui-bar-a .ui-btn:hover {
  color: var(--lb-primary);
}

/* === Buttons — colors only === */
.theme-modern .ui-btn {
  text-shadow: none;
  box-shadow: none;
  font-weight: 500;
  font-family: inherit;
}

.theme-modern .ui-btn-active,
.theme-modern .ui-btn.ui-btn-active {
  background: var(--lb-primary);
  color: white;
  border-color: var(--lb-primary);
}

.theme-modern button[type="submit"],
.theme-modern .ui-btn-icon-left[data-icon="check"] {
  background: var(--lb-primary);
  color: white;
  border-color: var(--lb-primary-hover);
}

/* === Inputs — colors only === */
.theme-modern .ui-input-text input:focus,
.theme-modern .ui-input-search input:focus,
.theme-modern textarea:focus {
  border-color: var(--lb-primary);
  outline: none;
  box-shadow: 0 0 0 3px rgba(109, 172, 32, 0.15);
}

/* === Content === */
.theme-modern .ui-content {
  background: var(--lb-gray-50);
}

.theme-modern .ui-body-a,
.theme-modern .ui-body-inherit {
  background-color: rgba(255, 255, 255, 0.95);
}

/* === Selects — colors only === */
.theme-modern .ui-select .ui-btn {
  background: #ffffff;
}

/* === Panel === */
.theme-modern .ui-panel {
  background: #ffffff;
}

.theme-modern .ui-panel-inner {
  color: var(--lb-gray-900);
}

/* === Side Menu === */
.theme-modern ul.lb-systemmenu li.lb-nonhover {
  background-color: var(--lb-primary);
  color: white !important;
  font-weight: 600;
  font-family: inherit;
}

.theme-modern ul.lb-systemmenu li {
  font-family: inherit;
  color: var(--lb-gray-900) !important;
  background-color: #ffffff;
  border-bottom-color: var(--lb-gray-200);
}

.theme-modern ul.lb-systemmenu a {
  color: var(--lb-gray-700) !important;
}

.theme-modern ul.lb-systemmenu li:hover {
  background-color: var(--lb-primary);
  color: white !important;
}

.theme-modern ul.lb-systemmenu li:hover a {
  color: white !important;
}

/* === Flipswitch === */
.theme-modern .ui-flipswitch-active {
  background-color: var(--lb-primary) !important;
}

/* === Section Headers === */
.theme-modern .wide {
  font-family: inherit;
  font-weight: 600;
  border-bottom-color: var(--lb-primary);
}

/* === Footer === */
.theme-modern [data-role="footer"] {
  border-top-color: var(--lb-gray-200);
}

/* === Text colors === */
.theme-modern .ui-listview > li,
.theme-modern .ui-listview > li a {
  color: var(--lb-gray-700);
}

.theme-modern table td {
  color: var(--lb-gray-700);
}
```

- [ ] **Step 3: Copy both files to L: and test**

```bash
cp "D:/Claude_Projekte/Loxberry NeXtGen/webfrontend/html/system/css/design-tokens.css" "L:/webfrontend/html/system/css/design-tokens.css"
cp "D:/Claude_Projekte/Loxberry NeXtGen/webfrontend/html/system/css/theme-modern.css" "L:/webfrontend/html/system/css/theme-modern.css"
```

Switch to Modern theme, hard-refresh. Verify same look, no structural changes.

- [ ] **Step 4: Commit**

```bash
git add webfrontend/html/system/css/design-tokens.css webfrontend/html/system/css/theme-modern.css
git commit -m "refactor: modern theme uses CSS Variables from design-tokens.css"
```

---

### Task 5: Scrollable Tabs

**Files:**
- Modify: `templates/system/pagestart.html:147-167`

- [ ] **Step 1: Update .vuenavbarcontainer CSS**

In `templates/system/pagestart.html`, replace lines 147-167:

```css
.vuenavbarcontainer {
	border-top: 1px solid #3d3d3d;
	display:flex;
	flex-direction:row;
	flex-wrap:nowrap;
	justify-content: center;
	align-items: center;
	background-color:#3d3d3d;
	/* min-height:35px; */
}
.vuenavbarelement {
	flex:1;
	text-shadow:none;
	padding: 10px 20px 10px 20px;
	color: white !important;
	font-size: 13px;
	font-weight: bold;
	text-align: center;
	text-decoration: none;
	min-height:18px;
}
```

with:

```css
.vuenavbarcontainer {
	border-top: 1px solid #3d3d3d;
	display:flex;
	flex-direction:row;
	flex-wrap:nowrap;
	justify-content: center;
	align-items: center;
	background-color:#3d3d3d;
	overflow-x: auto;
	-webkit-overflow-scrolling: touch;
	scrollbar-width: none;
}
.vuenavbarcontainer::-webkit-scrollbar {
	display: none;
}
.vuenavbarelement {
	flex:1;
	text-shadow:none;
	padding: 10px 20px 10px 20px;
	color: white !important;
	font-size: 13px;
	font-weight: bold;
	text-align: center;
	text-decoration: none;
	min-height:18px;
	white-space: nowrap;
	flex-shrink: 0;
	min-width: fit-content;
}
```

- [ ] **Step 2: Copy to L: and test**

```bash
cp "D:/Claude_Projekte/Loxberry NeXtGen/templates/system/pagestart.html" "L:/templates/system/pagestart.html"
```

Resize browser to <500px width. Tabs should scroll horizontally instead of shrinking to unreadable sizes.

- [ ] **Step 3: Commit**

```bash
git add templates/system/pagestart.html
git commit -m "feat: scrollable tabs on narrow screens"
```

---

### Task 6: Responsive lb_flex-* Layout

**Files:**
- Modify: `webfrontend/html/system/css/main.css:133-194`

- [ ] **Step 1: Improve the existing 875px media query**

In `main.css`, replace the `@media ( max-width: 875px )` block for `lb_flex-*` (lines 153-194) with:

```css
	.lb_flex-container {
			  flex-flow: column wrap;
			  justify-content: center;
			  align-items: stretch;
			  align-content: center;
			  flex-direction: column;
			  text-align:left;
			}
			.lb_flex-item-spacer
			{
	  			width:0%;
				display: none;
			}
			.lb_flex-item-label
			{
	    		text-align	:left;
	    		white-space	:normal;
				min-width	:auto;
				width		:auto;
				max-width	:none;
				margin-right:0;
				margin-bottom:4px;
				font-weight: bold;
	      	}
			.lb_flex-item
			{
	    		text-align	:left;
				min-width	:0;
				width		:100%;
				max-width	:100%;
			}
			.lb_flex-item-help
			{
	    		text-align	:left;
		  		width		:100%;
				min-width	:0;
				position	:relative;
				margin-top	:5px;
				margin-left :0;
			}
```

This replaces the existing centered/nowrap layout with a stacked layout: label on top, input full width, help text below.

- [ ] **Step 2: Add a 600px breakpoint for smaller screens**

Append after the closing `}` of the 875px media query:

```css
@media (max-width: 600px) {
	.wide {
		font-size: calc(12px + 1vw);
		letter-spacing: 0.05em;
		word-break: break-word;
	}

	.widget {
		width: 120px;
		min-width: 100px;
		height: 120px;
	}

	.caption {
		width: auto;
		font-size: 2em;
	}
}
```

- [ ] **Step 3: Copy to L: and test**

```bash
cp "D:/Claude_Projekte/Loxberry NeXtGen/webfrontend/html/system/css/main.css" "L:/webfrontend/html/system/css/main.css"
```

Test at 1920px (3-column layout), 768px (stacked layout), 375px (stacked + smaller widgets). Verify plugin pages are unaffected.

- [ ] **Step 4: Commit**

```bash
git add webfrontend/html/system/css/main.css
git commit -m "feat: responsive lb_flex-* layout with improved breakpoints"
```

---

### Task 7: Create components.css with lb-* classes

**Files:**
- Create: `webfrontend/html/system/css/components.css`
- Modify: `templates/system/head.html`

- [ ] **Step 1: Create components.css**

```css
/* LoxBerry Component Classes (lb-*)
   New design-system components using CSS Variables.
   Use these on migrated Core pages. Plugins keep jQuery Mobile. */

/* === Buttons === */
.lb-btn {
  display: inline-block;
  padding: var(--lb-space-sm) var(--lb-space-md);
  background: var(--lb-gray-100);
  color: var(--lb-gray-900);
  border: var(--lb-border);
  border-radius: var(--lb-radius);
  font-family: var(--lb-font);
  font-size: var(--lb-font-base);
  cursor: pointer;
  text-decoration: none;
  text-align: center;
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
.lb-btn-danger {
  background: var(--lb-danger);
  color: white;
  border-color: var(--lb-danger);
}

/* === Inputs === */
.lb-input,
.lb-select,
.lb-textarea {
  width: 100%;
  padding: var(--lb-space-sm) var(--lb-space-md);
  border: var(--lb-border);
  border-radius: var(--lb-radius);
  font-family: var(--lb-font);
  font-size: var(--lb-font-base);
  background: var(--lb-gray-50);
  color: var(--lb-gray-900);
  box-sizing: border-box;
}
.lb-input:focus,
.lb-select:focus,
.lb-textarea:focus {
  border-color: var(--lb-primary);
  outline: none;
  box-shadow: 0 0 0 3px rgba(109, 172, 32, 0.15);
}

/* === Cards === */
.lb-card {
  background: var(--lb-gray-50);
  border: var(--lb-border);
  border-radius: var(--lb-radius);
  padding: var(--lb-space-lg);
}

/* === Section Title === */
.lb-section-title {
  font-size: var(--lb-font-lg);
  font-weight: 600;
  font-family: var(--lb-font);
  border-bottom: 2px solid var(--lb-primary);
  padding-bottom: var(--lb-space-sm);
  margin-bottom: var(--lb-space-md);
  color: var(--lb-gray-900);
}

/* === Form Layout === */
.lb-form-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--lb-space-md);
  margin-bottom: var(--lb-space-md);
}
.lb-form-label {
  min-width: 150px;
  width: 200px;
  text-align: right;
  font-weight: 500;
  color: var(--lb-gray-700);
}
.lb-form-field {
  flex: 1;
  min-width: 200px;
}
.lb-form-help {
  flex-basis: 100%;
  font-size: var(--lb-font-sm);
  color: var(--lb-gray-500);
  margin-top: calc(-1 * var(--lb-space-sm));
}

@media (max-width: 875px) {
  .lb-form-row {
    flex-direction: column;
    align-items: stretch;
  }
  .lb-form-label {
    text-align: left;
    width: auto;
    min-width: auto;
    font-weight: 600;
  }
  .lb-form-field {
    width: 100%;
  }
}
```

- [ ] **Step 2: Link components.css in head.html**

In `templates/system/head.html`, after the design-tokens line, add:

```html
	<link rel="stylesheet" href="/system/css/components.css" />
```

So the order is: `design-tokens.css` → `main.css` → `components.css` → theme CSS.

- [ ] **Step 3: Copy to L: and test**

```bash
cp "D:/Claude_Projekte/Loxberry NeXtGen/webfrontend/html/system/css/components.css" "L:/webfrontend/html/system/css/components.css"
cp "D:/Claude_Projekte/Loxberry NeXtGen/templates/system/head.html" "L:/templates/system/head.html"
```

Verify existing pages are unchanged (no `lb-*` classes in use yet). The file just needs to load without errors.

- [ ] **Step 4: Commit**

```bash
git add webfrontend/html/system/css/components.css templates/system/head.html
git commit -m "feat: add lb-* component classes (buttons, inputs, cards, form layout)"
```

---

### Task 8: Verify all themes and plugin pages

**Files:** None (manual testing only)

- [ ] **Step 1: Test Classic theme**

Switch to Classic, hard-refresh. Check: system settings, plugin-install, Weather4Loxone plugin. Everything should look like original LoxBerry.

- [ ] **Step 2: Test Modern theme**

Switch to Modern, hard-refresh. Same pages. Verify clean flat look, no structural differences from Classic.

- [ ] **Step 3: Test Dark theme**

Switch to Dark, hard-refresh. Same pages. Verify dark backgrounds, readable text, no thin lines between table rows.

- [ ] **Step 4: Test responsive at 768px and 375px**

Resize browser. Verify:
- Tabs scroll horizontally
- `lb_flex-*` layouts stack on narrow screens
- No horizontal overflow

- [ ] **Step 5: Final commit with all files**

```bash
git status
# If any uncommitted fixes, commit them
git log --oneline -8  # Verify all task commits are present
```
