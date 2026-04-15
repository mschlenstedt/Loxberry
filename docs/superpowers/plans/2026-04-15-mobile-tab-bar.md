# Mobile Tab Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an iOS-inspired bottom tab bar as the primary mobile navigation (<768px), replacing the hamburger menu.

**Architecture:** Pure CSS component in `components.css`, HTML in `pagestart.html`, active tab via JavaScript (same pattern as existing sidebar). Glass theme gets backdrop-filter overlay. No new JS files, no Perl changes.

**Tech Stack:** HTML::Template, CSS Custom Properties, PrimeIcons, existing `toggleSidebar()` JS

**Spec:** `docs/superpowers/specs/2026-04-15-mobile-tab-bar-design.md`

**Correction from spec:** The spec proposed `TMPL_IF` variables set via CGI scripts. During planning, I discovered that `pagestart.html` is rendered by `Web.pm::pagestart()` — CGI scripts don't have access to its template object. The active tab is instead detected via JavaScript, matching the existing sidebar pattern (pagestart.html:117-125). This eliminates all Perl changes.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `templates/system/pagestart.html` | Modify | Add tab bar HTML + active-tab JS |
| `webfrontend/html/system/css/components.css` | Modify | Add tab bar CSS (mobile only) |
| `webfrontend/html/system/css/design-tokens.css` | Modify | Add 3 tab bar tokens |
| `webfrontend/html/system/css/theme-glass.css` | Modify | Add glassmorphism override |

---

### Task 1: Add design tokens

**Files:**
- Modify: `webfrontend/html/system/css/design-tokens.css:83-88` (before glass extras)

- [ ] **Step 1: Add tab bar tokens to design-tokens.css**

Insert after the `--lb-border` line (line 82) and before the glass extras comment (line 84):

```css
  /* === Tab Bar (mobile) === */
  --lb-tab-bar-bg: var(--lb-sidebar-bg);
  --lb-tab-bar-text: var(--lb-sidebar-text);
  --lb-tab-bar-active: var(--lb-sidebar-active-text);
```

- [ ] **Step 2: Verify the file is valid**

Open `design-tokens.css` and confirm the new tokens sit between the border section and the glass extras section. All three reference existing sidebar tokens as defaults.

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/design-tokens.css
git commit -m "feat(tab-bar): add design tokens for mobile tab bar"
```

---

### Task 2: Add tab bar CSS to components.css

**Files:**
- Modify: `webfrontend/html/system/css/components.css` (append to section 6, after the existing `@media (max-width: 768px)` block ending at line 813)

- [ ] **Step 1: Add tab bar base rule (hidden on desktop)**

Append after line 813 (end of last `}` in the file):

```css


/* ============================================================
   7. Tab Bar (Mobile)
   ============================================================ */

.lb-tab-bar {
	display: none;
}
```

- [ ] **Step 2: Add tab bar mobile styles inside new media query**

Append directly after the base rule:

```css

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
		background: var(--lb-tab-bar-bg);
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
		font-family: var(--lb-font);
		-webkit-tap-highlight-color: transparent;
	}

	.lb-tab-bar-item i {
		font-size: 22px;
		color: var(--lb-tab-bar-text);
	}

	.lb-tab-bar-item span {
		font-size: 10px;
		font-weight: 500;
		color: var(--lb-tab-bar-text);
	}

	.lb-tab-bar-item.active i,
	.lb-tab-bar-item.active span {
		color: var(--lb-tab-bar-active);
	}
}
```

- [ ] **Step 3: Add content padding and hamburger hide to existing 768px media query**

In the existing `@media (max-width: 768px)` block (lines 773-813), add these two rules inside the block, before the closing `}` on line 813:

```css
	.lb-content {
		padding-bottom: 72px;
	}
	button.lb-sidebar-toggle.lb-header-btn {
		display: none !important;
	}
```

Note: There is already a rule `button.lb-sidebar-toggle.lb-header-btn { display: none !important; }` at line 606-608 (outside any media query — it hides the hamburger on desktop). The existing rule at line 606-608 must be **removed** because the hamburger should only be hidden on mobile (the tab bar replaces it), not globally. On desktop the sidebar is always visible so the hamburger is already invisible via layout, but keeping the global hide is misleading. Actually — re-reading the code, line 801-806 already shows `.lb-sidebar-toggle` inside the 768px media query with `display: flex !important`. So there's a conflict: line 606 hides it globally, line 801 shows it on mobile. The current behavior is: line 606 wins because it's more specific (`button.lb-sidebar-toggle.lb-header-btn` vs `.lb-sidebar-toggle`).

**Resolution:** Remove lines 606-608 (the global hide). Then in the 768px media query, the existing `.lb-sidebar-toggle { display: flex !important; }` block at lines 801-806 should be **replaced** with the new hide rule:

Remove lines 606-608:
```css
button.lb-sidebar-toggle.lb-header-btn {
	display: none !important;
}
```

Replace lines 801-806 in the 768px media query:
```css
	.lb-sidebar-toggle {
		display: flex !important;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}
```

With:
```css
	button.lb-sidebar-toggle.lb-header-btn {
		display: none !important;
	}
```

- [ ] **Step 4: Verify CSS structure**

Confirm:
1. `.lb-tab-bar { display: none; }` exists at the top level
2. New `@media (max-width: 768px)` block contains all tab bar mobile styles
3. Existing 768px media query has `padding-bottom: 72px` on `.lb-content`
4. Hamburger is hidden on mobile via the new rule, not globally
5. No duplicate `.lb-sidebar-toggle` rules

- [ ] **Step 5: Commit**

```bash
git add webfrontend/html/system/css/components.css
git commit -m "feat(tab-bar): add mobile tab bar CSS and hide hamburger on mobile"
```

---

### Task 3: Add tab bar HTML and active-tab JavaScript to pagestart.html

**Files:**
- Modify: `templates/system/pagestart.html`

- [ ] **Step 1: Add tab bar HTML before the closing main div area**

Insert the tab bar `<nav>` immediately after the sidebar backdrop div (line 51) and before the help panel (line 54). This places it at the layout level, not inside `.lb-main`:

After line 51 (`<div class="lb-sidebar-backdrop" id="lb-sidebar-backdrop" onclick="toggleSidebar()"></div>`), insert:

```html

	<!-- Mobile Tab Bar -->
	<nav class="lb-tab-bar" id="lb-tab-bar" role="navigation" aria-label="Mobile Navigation">
		<a href="/admin/system/index.cgi" class="lb-tab-bar-item" data-tab-path="/admin/system/index.cgi">
			<i class="pi pi-home"></i>
			<span>Home</span>
		</a>
		<a href="/admin/system/plugininstall.cgi" class="lb-tab-bar-item" data-tab-path="/admin/system/plugininstall.cgi">
			<i class="pi pi-th-large"></i>
			<span>Plugins</span>
		</a>
		<a href="/admin/system/mqtt.cgi" class="lb-tab-bar-item" data-tab-path="/admin/system/mqtt.cgi">
			<i class="pi pi-arrows-h"></i>
			<span>MQTT</span>
		</a>
		<a href="/admin/system/logmanager.cgi" class="lb-tab-bar-item" data-tab-path="/admin/system/logmanager.cgi">
			<i class="pi pi-list"></i>
			<span>Logs</span>
		</a>
		<button class="lb-tab-bar-item" onclick="toggleSidebar()" aria-label="Mehr anzeigen">
			<i class="pi pi-ellipsis-h"></i>
			<span>Mehr</span>
		</button>
	</nav>
```

- [ ] **Step 2: Add active-tab detection JavaScript**

In the existing `<script>` block (lines 116-136), add the tab bar highlight logic right after the sidebar highlight loop (after line 125, before the closing `})();`):

```javascript
			// Highlight current tab in mobile tab bar
			var tabItems = document.querySelectorAll('.lb-tab-bar-item[data-tab-path]');
			tabItems.forEach(function(tab) {
				if (tab.getAttribute('data-tab-path') === currentPath) {
					tab.classList.add('active');
				}
			});
```

The full IIFE block becomes:

```javascript
		// Highlight current page in sidebar
		(function() {
			var currentPath = window.location.pathname + window.location.search;
			var links = document.querySelectorAll('.lb-sidebar-link');
			links.forEach(function(link) {
				if (link.getAttribute('href') === currentPath) {
					link.classList.add('active');
				}
			});
			// Highlight current tab in mobile tab bar
			var tabItems = document.querySelectorAll('.lb-tab-bar-item[data-tab-path]');
			tabItems.forEach(function(tab) {
				if (tab.getAttribute('data-tab-path') === currentPath) {
					tab.classList.add('active');
				}
			});
		})();
```

- [ ] **Step 3: Verify HTML structure**

Confirm:
1. Tab bar nav sits between sidebar backdrop and help panel
2. Each link has a `data-tab-path` attribute matching its `href`
3. "Mehr" button uses `onclick="toggleSidebar()"` (same function as existing sidebar toggle)
4. JS block adds active class based on URL match
5. No template variables needed — pure HTML + JS

- [ ] **Step 4: Commit**

```bash
git add templates/system/pagestart.html
git commit -m "feat(tab-bar): add mobile tab bar HTML and active-tab detection"
```

---

### Task 4: Add glassmorphism override in theme-glass.css

**Files:**
- Modify: `webfrontend/html/system/css/theme-glass.css` (append at end, after line 185)

- [ ] **Step 1: Add glass tab bar styles**

Append at the end of `theme-glass.css`:

```css

/* Glass mobile tab bar */
body.theme-glass .lb-tab-bar {
	--lb-tab-bar-bg: rgba(30, 30, 30, 0.72);
	backdrop-filter: blur(20px) saturate(180%);
	-webkit-backdrop-filter: blur(20px) saturate(180%);
	border-top: 0.5px solid rgba(255, 255, 255, 0.12);
}
```

- [ ] **Step 2: Verify consistency with existing glass patterns**

Confirm the `rgba` values match existing glass patterns:
- `rgba(30, 30, 30, 0.72)` — similar to sidebar's `rgba(255,255,255,.04)` but opaque enough for readability over scrolling content
- `blur(20px) saturate(180%)` — matches iOS reference, slightly stronger than card blur (12px)
- Border uses `rgba(255, 255, 255, 0.12)` — matches iOS reference, slightly more visible than card borders (0.07)

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/theme-glass.css
git commit -m "feat(tab-bar): add glassmorphism effect for glass theme"
```

---

### Task 5: Manual testing on device

No code changes — verification only.

- [ ] **Step 1: Deploy to LoxBerry**

Copy the 4 changed files to `L:` (192.168.30.10):
```bash
cp webfrontend/html/system/css/design-tokens.css L:/opt/loxberry/webfrontend/html/system/css/
cp webfrontend/html/system/css/components.css L:/opt/loxberry/webfrontend/html/system/css/
cp webfrontend/html/system/css/theme-glass.css L:/opt/loxberry/webfrontend/html/system/css/
cp templates/system/pagestart.html L:/opt/loxberry/templates/system/
```

- [ ] **Step 2: Test on mobile (or browser DevTools mobile view)**

Verify:
1. Tab bar appears at bottom on screens ≤768px
2. Tab bar is hidden on desktop
3. Hamburger button is gone on mobile
4. Tapping Home/Plugins/MQTT/Logs navigates to correct page
5. Active tab is highlighted with accent color
6. Tapping "Mehr" opens the sidebar overlay
7. Content is not hidden behind the tab bar (72px padding)
8. On glass theme: blur effect visible, content scrolls behind the bar

- [ ] **Step 3: Test edge cases**

1. Page not matching any tab (e.g., `/admin/system/network.cgi`) — no tab highlighted
2. Plugin pages — no tab highlighted
3. Sidebar opens/closes correctly via "Mehr" tab
4. Tab bar stays fixed while scrolling
