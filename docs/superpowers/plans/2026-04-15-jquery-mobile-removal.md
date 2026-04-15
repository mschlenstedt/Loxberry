# jQuery Mobile Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove jQuery Mobile from all Core system pages while keeping it for plugin pages.

**Architecture:** Conditional loading via `IS_CORE_PAGE` template variable set in `Web.pm`. Core pages get jQuery Core only. Plugin pages get jQuery Core + jQuery Mobile. Then migrate 10 remaining templates that still use jQM widgets.

**Tech Stack:** Perl (Web.pm), HTML::Template, CSS Custom Properties, vanilla JS

**Spec:** `docs/superpowers/specs/2026-04-15-jquery-mobile-removal-design.md`

**Testing:** No automated tests — this is CSS/HTML migration. Each task ends with deploy to `L:` and browser verification. To deploy a file: `cp <local-path> L:/<loxberry-path>` then `sed -i 's/\r$//' L:/<path>` for .html files. Browser: Ctrl+Shift+R.

---

## File Map

| File | Action | Task |
|------|--------|------|
| `libs/perllib/LoxBerry/Web.pm` | Modify | 1 |
| `templates/system/head.html` | Modify | 1 |
| `webfrontend/html/system/css/components.css` | Modify | 2, 13 |
| `templates/system/healthcheck.html` | Modify | 3 |
| `templates/system/mqtt-quickpublisher.html` | Modify | 4 |
| `templates/system/mqtt-finder.html` | Modify | 5 |
| `templates/system/plugininstall.html` | Modify | 6 |
| `templates/system/logfile.html` | Modify | 7 |
| `templates/system/netshares.html` | Modify | 8 |
| `templates/system/usbstorage.html` | Modify | 9 |
| `templates/system/changehostname.html` | Modify | 10 |
| `templates/system/backup.html` | Modify | 11 |
| `templates/system/mailserver.html` | Modify | 12 |

---

### Task 1: Conditional jQM Loading (Web.pm + head.html)

**Files:**
- Modify: `libs/perllib/LoxBerry/Web.pm:132-134`
- Modify: `templates/system/head.html` (full rewrite of script/style loading)

- [ ] **Step 1: Add IS_CORE_PAGE param to Web.pm head() function**

In `libs/perllib/LoxBerry/Web.pm`, find the `head()` function. After line 134 (`$headobj->param( HTMLHEAD => $main::htmlhead);`), insert:

```perl
	# Detect core vs plugin page for conditional jQuery Mobile loading
	my $systemcall = defined $LoxBerry::System::lbpplugindir ? undef : 1;
	$headobj->param( IS_CORE_PAGE => $systemcall ? 1 : 0 );
```

- [ ] **Step 2: Rewrite head.html for conditional loading**

Replace the entire content of `templates/system/head.html` with:

```html
<!DOCTYPE html>
<html lang="<TMPL_VAR LANG>">
<!-- head.html START -->
<head>
	<title><TMPL_VAR TEMPLATETITLE></title>
	<!-- THIS IS MULTI-LANG HEADER OF LOXBERRY::WEB -->
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=3, user-scalable=yes">

	<!-- jQuery Mobile CSS — only for plugins -->
	<TMPL_UNLESS IS_CORE_PAGE>
	<link rel="stylesheet" href="/system/scripts/jquery/themes/main/loxberry.css" />
	<link rel="stylesheet" href="/system/scripts/jquery/themes/main/jquery.mobile.icons.min.css" />
	<link rel="stylesheet" href="/system/scripts/jquery/jquery.mobile.structure-1.4.5.min.css" />
	</TMPL_UNLESS>

	<!-- Design System CSS — always -->
	<link rel="stylesheet" href="/system/css/design-tokens.css?v=3" />
	<link rel="stylesheet" href="/system/css/main.css?v=3" />
	<link rel="stylesheet" href="/system/css/components.css?v=3" />
	<link rel="stylesheet" href="/system/css/<TMPL_VAR THEME_FILE>?v=3" />
	<link rel="shortcut icon" href="/system/images/favicon.ico" />
	<link rel="icon" type="image/png" href="/system/images/favicon-96x96.png" sizes="96x96" />
	<link rel="icon" type="image/png" href="/system/images/favicon-32x32.png" sizes="32x32" />
	<link rel="icon" type="image/png" href="/system/images/favicon-16x16.png" sizes="16x16" />
	<link href="/system/css/primeicons.css" rel="stylesheet" />

	<!-- jQuery Core — always -->
	<script src="/system/scripts/jquery/jquery-1.12.4.min.js"></script>

	<!-- jQuery Mobile JS — only for plugins -->
	<TMPL_UNLESS IS_CORE_PAGE>
	<script src="/system/scripts/jquery/jquery.mobile-1.4.5.min.js"></script>
	</TMPL_UNLESS>

	<!-- Form validator — always (uses jQuery Core, not jQM) -->
	<script src="/system/scripts/form-validator/jquery.form-validator.min.js"></script>
	<script src="/system/scripts/setup.js"></script>
	<script src="/system/scripts/validate.js"></script>

	<!-- jQuery Mobile config — only for plugins -->
	<TMPL_UNLESS IS_CORE_PAGE>
	<script>
		// Disable JQUERY DOM Caching
		$.mobile.page.prototype.options.domCache = false;
		$.mobile.ajaxEnabled = false;
		$(document).on("pagehide", "div[data-role=page]", function(event)
		{
			$(event.target).remove();
		});
		// Disable caching of AJAX responses
		$.ajaxSetup ({ cache: false });
		// Reduce unnecessary JQM input enhancements
		$.mobile.degradeInputs.date = true;
		$.mobile.degradeInputs.datetime = true;
		$.mobile.degradeInputs["datetime-local"] = true;
		$.mobile.degradeInputs.month = true;
		$.mobile.degradeInputs.week = true;
		$.mobile.degradeInputs.time = true;
		$.mobile.degradeInputs.number = true;
		$.mobile.degradeInputs.range = false; // keep sliders

		// Safe-guard: prevent errors when calling jQM widget methods on migrated elements
		$.each(['checkboxradio', 'flipswitch', 'selectmenu'], function(i, widget) {
			var _orig = $.fn[widget];
			if (_orig) {
				$.fn[widget] = function() {
					try { return _orig.apply(this, arguments); } catch(e) { return this; }
				};
			}
		});
	</script>
	</TMPL_UNLESS>

	<!-- Core page config (no jQM) -->
	<TMPL_IF IS_CORE_PAGE>
	<script>
		$.ajaxSetup({ cache: false });
	</script>
	</TMPL_IF>

	<script>
		// Sync lb-checked class on lb-btn-group labels
		function syncLbBtnGroup($group) {
			$group.find("label").removeClass("lb-checked");
			$group.find("input[type='radio'], input[type='checkbox']").each(function() {
				if (this.checked) {
					var id = $(this).attr("id");
					var $label;
					if (id) {
						$label = $group.find("label[for='" + id + "']");
					}
					// Fallback: find next sibling label or parent's label
					if (!$label || !$label.length) {
						$label = $(this).next("label");
					}
					if (!$label || !$label.length) {
						$label = $(this).closest(".ui-radio, .ui-checkbox").find("label");
					}
					if ($label && $label.length) {
						$label.addClass("lb-checked");
					}
				}
			});
		}
		$(document).on("change click", ".lb-btn-group label, .lb-btn-group input", function() {
			var $group = $(this).closest(".lb-btn-group");
			setTimeout(function() { syncLbBtnGroup($group); }, 10);
		});
		// Initial sync on page load
		function syncAllBtnGroups() {
			$(".lb-btn-group").each(function() { syncLbBtnGroup($(this)); });
		}
		<TMPL_UNLESS IS_CORE_PAGE>
		$(document).on("pagecreate", function() {
			setTimeout(syncAllBtnGroups, 200);
			setTimeout(syncAllBtnGroups, 800);
		});
		</TMPL_UNLESS>
		$(document).ready(function() {
			setTimeout(syncAllBtnGroups, 200);
		});
	</script>
	<script src="/system/scripts/browser.js"></script>
	<!-- HTMLHEAD sent by the plugin author: -->
	<TMPL_VAR HTMLHEAD>
</head>
<body class="<TMPL_VAR THEME_CLASS>">
<!-- head.html END -->
```

- [ ] **Step 3: Deploy and smoke-test**

Deploy both files:
```bash
cp libs/perllib/LoxBerry/Web.pm L:/libs/perllib/LoxBerry/Web.pm
cp templates/system/head.html L:/templates/system/head.html
sed -i 's/\r$//' L:/templates/system/head.html
```

Test in browser (Ctrl+Shift+R):
1. Open Dashboard (`/admin/system/index.cgi`) — should work, no jQM loaded. Check DevTools Network tab: no `jquery.mobile` requests.
2. Open a Plugin page — should work, jQM loaded normally.
3. Open Admin, Network, MyLoxBerry — all should look correct.

- [ ] **Step 4: Commit**

```bash
git add libs/perllib/LoxBerry/Web.pm templates/system/head.html
git commit -m "feat(jqm-removal): conditional jQuery Mobile loading for core vs plugin pages"
```

---

### Task 2: Add lb-disabled and lb-table CSS classes

**Files:**
- Modify: `webfrontend/html/system/css/components.css` (append new section)

- [ ] **Step 1: Add lb-disabled class**

Append after the Tab Bar Popups section (end of file):

```css


/* ============================================================
   9. Utility Classes
   ============================================================ */

.lb-disabled {
	opacity: 0.4;
	pointer-events: none;
}


/* ============================================================
   10. Tables
   ============================================================ */

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
.lb-table tbody tr:hover {
	background: var(--lb-sidebar-active-bg);
}

@media (max-width: 768px) {
	.lb-table-responsive thead {
		display: none;
	}
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
	.lb-table-responsive td:last-child {
		border-bottom: none;
	}
	.lb-table-responsive td::before {
		content: attr(data-label);
		font-weight: 600;
		color: var(--lb-text-secondary);
		margin-right: var(--lb-space-md);
	}
}
```

- [ ] **Step 2: Deploy and verify**

```bash
cp webfrontend/html/system/css/components.css L:/webfrontend/html/system/css/components.css
```

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/components.css
git commit -m "feat(jqm-removal): add lb-disabled and lb-table CSS classes"
```

---

### Task 3: Migrate healthcheck.html (Batch A)

**Files:**
- Modify: `templates/system/healthcheck.html:177`

- [ ] **Step 1: Replace jQM button in JavaScript string**

Find line 177 which dynamically creates an anchor with jQM attributes:

```javascript
$("#"+rowname+"logfile").html('<a data-logfile="'+element.logfile+'" data-role="button" href="/admin/system/tools/logfile.cgi?logfile='+element.logfile+'&header=html&format=template&only=once" target="_blank" data-inline="true" data-mini="true" data-icon="action">Logfile</a>');
```

Replace with:

```javascript
$("#"+rowname+"logfile").html('<a data-logfile="'+element.logfile+'" class="lb-btn lb-btn-sm" href="/admin/system/tools/logfile.cgi?logfile='+element.logfile+'&header=html&format=template&only=once" target="_blank">Logfile</a>');
```

- [ ] **Step 2: Deploy and test**

```bash
cp templates/system/healthcheck.html L:/templates/system/healthcheck.html
sed -i 's/\r$//' L:/templates/system/healthcheck.html
```

Open `/admin/system/healthcheck.cgi` — verify logfile buttons render as `lb-btn` without jQM styling.

- [ ] **Step 3: Commit**

```bash
git add templates/system/healthcheck.html
git commit -m "feat(jqm-removal): migrate healthcheck.html — remove jQM button attributes"
```

---

### Task 4: Migrate mqtt-quickpublisher.html (Batch A)

**Files:**
- Modify: `templates/system/mqtt-quickpublisher.html`

- [ ] **Step 1: Remove all data-mini attributes**

Remove `data-mini="true"` from all input, select, and checkbox elements (lines 58, 66, 69, 79, 87, 90, 100, 108, 111, 121, 129, 132, 142, 150, 153). Use replace-all.

- [ ] **Step 2: Remove all data-iconpos attributes**

Remove `data-iconpos="left"` from all select elements (lines 61, 82, 103, 124, 145). Add `class="lb-select"` to each select instead.

- [ ] **Step 3: Replace ui-btn classes on publish buttons**

Replace all 5 publish buttons (lines 73, 94, 115, 136, 157):

Old: `class="ui-btn ui-corner-all ui-mini"`
New: `class="lb-btn lb-btn-sm"`

- [ ] **Step 4: Remove widget refresh calls in JavaScript**

Line 192 — remove or comment out:
```javascript
$(value).attr('checked', true).checkboxradio("refresh");
```
Replace with:
```javascript
$(value).attr('checked', true);
```

Line 199 — remove or comment out:
```javascript
$(value).val(savedVal).selectmenu("refresh");
```
Replace with:
```javascript
$(value).val(savedVal);
```

- [ ] **Step 5: Deploy and test**

```bash
cp templates/system/mqtt-quickpublisher.html L:/templates/system/mqtt-quickpublisher.html
sed -i 's/\r$//' L:/templates/system/mqtt-quickpublisher.html
```

Open MQTT → Quick Publisher tab — verify inputs render correctly, publish buttons work.

- [ ] **Step 6: Commit**

```bash
git add templates/system/mqtt-quickpublisher.html
git commit -m "feat(jqm-removal): migrate mqtt-quickpublisher.html — remove jQM attributes and widget calls"
```

---

### Task 5: Migrate mqtt-finder.html (Batch A)

**Files:**
- Modify: `templates/system/mqtt-finder.html`

- [ ] **Step 1: Remove data-mini and data-clear-btn attributes**

Line 37: Remove `data-mini="true" data-clear-btn="true"` from the search input. Add `class="lb-input"` instead.

Line 38: Remove `data-mini="true"` from the checkbox input.

- [ ] **Step 2: Remove checkboxradio refresh**

Line 68: Change:
```javascript
$("#checkboxSubscription").prop('checked', true).checkboxradio("refresh");
```
To:
```javascript
$("#checkboxSubscription").prop('checked', true);
```

- [ ] **Step 3: Remove data-clear-btn JS manipulation**

Line 89: Remove `$('#filter_search').attr("data-clear-btn", false);`
Line 96: Remove `$('#filter_search').attr("data-clear-btn", true);`

These are jQM-specific — the clear button is a jQM enhancement.

- [ ] **Step 4: Replace ui-btn classes on expand buttons**

Lines 243 and 250: Replace the dynamically generated button HTML.

Line 243 old:
```javascript
html += `<a href="#" class="ui-mini ui-btn ui-shadow ui-icon-clipboard ui-btn-inline topicExpand" data-topic="${topic}" style="padding:1px;font-size:86%;height:12px;width:20px;">...</a>`;
```
Line 243 new:
```javascript
html += `<a href="#" class="lb-btn lb-btn-sm topicExpand" data-topic="${topic}" style="padding:1px;font-size:86%;height:12px;width:20px;">...</a>`;
```

Line 250 old:
```javascript
html += `<a href="#" class="ui-mini ui-btn ui-shadow ui-icon-clipboard ui-btn-inline topicExpand" data-topic="${topic}" style="padding:1px;font-size:86%;height:12px;width:20px;">^</a>`;
```
Line 250 new:
```javascript
html += `<a href="#" class="lb-btn lb-btn-sm topicExpand" data-topic="${topic}" style="padding:1px;font-size:86%;height:12px;width:20px;">^</a>`;
```

- [ ] **Step 5: Deploy and test**

```bash
cp templates/system/mqtt-finder.html L:/templates/system/mqtt-finder.html
sed -i 's/\r$//' L:/templates/system/mqtt-finder.html
```

Open MQTT → Finder tab — verify search input, checkbox, and expand buttons work.

- [ ] **Step 6: Commit**

```bash
git add templates/system/mqtt-finder.html
git commit -m "feat(jqm-removal): migrate mqtt-finder.html — remove jQM attributes and widget calls"
```

---

### Task 6: Migrate plugininstall.html (Batch A)

**Files:**
- Modify: `templates/system/plugininstall.html`

- [ ] **Step 1: Replace jQM table**

Line 109: Change:
```html
<table data-role="table" data-mode="table" class="ui-responsive" data-enhance="false">
```
To:
```html
<table class="lb-table">
```

- [ ] **Step 2: Remove selectmenu refresh**

Line 221: Change:
```javascript
$("#loglevel<TMPL_VAR PLUGINDB_MD5_CHECKSUM>").val('<TMPL_VAR PLUGINDB_LOGLEVEL>').selectmenu('refresh');
```
To:
```javascript
$("#loglevel<TMPL_VAR PLUGINDB_MD5_CHECKSUM>").val('<TMPL_VAR PLUGINDB_LOGLEVEL>');
```

- [ ] **Step 3: Deploy and test**

```bash
cp templates/system/plugininstall.html L:/templates/system/plugininstall.html
sed -i 's/\r$//' L:/templates/system/plugininstall.html
```

Open Plugin Install page — verify plugin table renders correctly, loglevel dropdowns work.

- [ ] **Step 4: Commit**

```bash
git add templates/system/plugininstall.html
git commit -m "feat(jqm-removal): migrate plugininstall.html — replace jQM table and selectmenu"
```

---

### Task 7: Migrate logfile.html (Batch B)

**Files:**
- Modify: `templates/system/logfile.html`

- [ ] **Step 1: Replace jQM structural roles and classes**

Line 4: Change `<div data-role="header" id="warning">` to `<div id="warning">`

Line 8: Change `<div id="log_content" data-role="content" role="main" class="ui-content">` to `<div id="log_content" class="lb-content">`

Line 9: Change `<div id="log_sub_content" class="ui-body ui-body-a ui-corner-all loxberry-logo">` to `<div id="log_sub_content" class="lb-card loxberry-logo">`

- [ ] **Step 2: Remove data-mini**

Line 41: Remove `data-mini="true"` from the checkbox input.

- [ ] **Step 3: Remove checkboxradio refresh calls**

Lines 121, 130, 228: In each case change `.checkboxradio("refresh")` to nothing. For example:

Line 121: `$("#checkboxLogScroll").prop('checked', true).checkboxradio("refresh");` → `$("#checkboxLogScroll").prop('checked', true);`

Line 130: `$("#checkboxLogScroll").prop('checked', false).checkboxradio("refresh");` → `$("#checkboxLogScroll").prop('checked', false);`

Line 228: Same pattern — remove `.checkboxradio("refresh")`.

- [ ] **Step 4: Deploy and test**

```bash
cp templates/system/logfile.html L:/templates/system/logfile.html
sed -i 's/\r$//' L:/templates/system/logfile.html
```

Open Log Manager → click any log file link — verify the logfile viewer page renders correctly.

- [ ] **Step 5: Commit**

```bash
git add templates/system/logfile.html
git commit -m "feat(jqm-removal): migrate logfile.html — replace jQM structural roles and classes"
```

---

### Task 8: Migrate netshares.html (Batch B)

**Files:**
- Modify: `templates/system/netshares.html`

- [ ] **Step 1: Replace jQM table markup**

Line 93: Change:
```html
<table data-role="table" data-mode="columntoggle" data-filter="true" data-input="#filterTable-input" class="ui-body-d ui-shadow table-stripe ui-responsive" data-column-btn-text="<TMPL_VAR NETSHARES.BUTTON_SHOWCOLS>">
```
To:
```html
<table class="lb-table lb-table-responsive">
```

- [ ] **Step 2: Remove ui-bar-d from thead**

Line 95 (or nearby): Remove `class="ui-bar-d"` from the `<thead>` or `<tr>` in the table header. The `lb-table thead th` styles replace it.

- [ ] **Step 3: Add data-label attributes to td elements**

For each `<td>` in the TMPL_LOOP that renders table rows, add `data-label="<column name>"` so the responsive mobile view shows labels. The column names from the headers are:

```
No | Server | Type | Share | Size | Used | Available | Status | Action
```

Each `<td>` in the loop needs `data-label="<TMPL_VAR NETSHARES.SHARESTABLE_NO>"` etc. matching the corresponding header.

- [ ] **Step 4: Deploy and test**

```bash
cp templates/system/netshares.html L:/templates/system/netshares.html
sed -i 's/\r$//' L:/templates/system/netshares.html
```

Open Network Shares page — verify table renders with alternating rows. Test on mobile: verify card-style layout with labels.

- [ ] **Step 5: Commit**

```bash
git add templates/system/netshares.html
git commit -m "feat(jqm-removal): migrate netshares.html — replace jQM table with lb-table"
```

---

### Task 9: Migrate usbstorage.html (Batch B)

**Files:**
- Modify: `templates/system/usbstorage.html`

- [ ] **Step 1: Replace jQM table markup**

Line 17: Change:
```html
<table data-role="table" data-mode="columntoggle" data-filter="true" data-input="#filterTable-input" class="ui-body-d ui-shadow table-stripe ui-responsive" data-column-btn-text="<TMPL_VAR NETSHARES.BUTTON_SHOWCOLS>">
```
To:
```html
<table class="lb-table lb-table-responsive">
```

- [ ] **Step 2: Remove ui-bar-d from thead**

Line 19 (or nearby): Remove `class="ui-bar-d"` from the `<thead>` or `<tr>` in the table header.

- [ ] **Step 3: Add data-label attributes to td elements**

The column names from the headers are:

```
No | Device Name | Block Device | Type | Size | Used | Available | Used% | Status | Action
```

Each `<td>` in the loop needs `data-label="..."` matching the corresponding header TMPL_VAR.

- [ ] **Step 4: Deploy and test**

```bash
cp templates/system/usbstorage.html L:/templates/system/usbstorage.html
sed -i 's/\r$//' L:/templates/system/usbstorage.html
```

Open USB Storage page — verify table renders correctly.

- [ ] **Step 5: Commit**

```bash
git add templates/system/usbstorage.html
git commit -m "feat(jqm-removal): migrate usbstorage.html — replace jQM table with lb-table"
```

---

### Task 10: Migrate changehostname.html (Batch B)

**Files:**
- Modify: `templates/system/changehostname.html`

This is a standalone page that loads its own jQuery Mobile. It needs to stop doing that and use the shared head.html infrastructure.

- [ ] **Step 1: Remove standalone jQM loading**

Line 8: Remove `<link rel="stylesheet" href="/system/scripts/jquery/jquery.mobile.structure-1.4.5.min.css" />`

Line 12: Remove `<script src="/system/scripts/jquery/jquery.mobile-1.4.5.min.js"></script>`

Note: This file has its own `<head>` section rather than using `head.html` via Web.pm. The jQM CSS/JS lines must be deleted. jQuery Core (`jquery-1.8.2.min.js` or similar) can stay if present.

- [ ] **Step 2: Replace jQM structural roles (first page section)**

Line 22 (or similar): Change `<div data-role="header">` to just `<div>`

Line 26 (or similar): Change `<div data-role="content" role="main" class="ui-content">` to `<div class="lb-content">`

Line 27: Change `class="ui-body ui-body-a ui-corner-all loxberry-logo"` to `class="lb-card loxberry-logo"`

- [ ] **Step 3: Replace jQM structural roles (second page section)**

Line 84: Change `<div data-role="header" id="warning">` to `<div id="warning">`

Line 88: Change `<div data-role="content" role="main" class="ui-content">` to `<div class="lb-content">`

Line 89: Change `class="ui-body ui-body-a ui-corner-all loxberry-logo"` to `class="lb-card loxberry-logo"`

- [ ] **Step 4: Deploy and test**

```bash
cp templates/system/changehostname.html L:/templates/system/changehostname.html
sed -i 's/\r$//' L:/templates/system/changehostname.html
```

Trigger the hostname change dialog (if possible) — verify it renders without jQM.

- [ ] **Step 5: Commit**

```bash
git add templates/system/changehostname.html
git commit -m "feat(jqm-removal): migrate changehostname.html — remove standalone jQM loading"
```

---

### Task 11: Migrate backup.html (Batch C)

**Files:**
- Modify: `templates/system/backup.html`

This is the most complex migration — flipswitch, checkboxradio refresh, selectmenu refresh, and ui-disabled classes.

- [ ] **Step 1: Remove all widget refresh calls**

Line 211: `$("#archive").val(data.Backup.Keep_archives).selectmenu('refresh',true);` → `$("#archive").val(data.Backup.Keep_archives);`

Line 212: `$("#compression").val(data.Backup.Compression).selectmenu('refresh',true);` → `$("#compression").val(data.Backup.Compression);`

Line 213: `$("#repeat").val(data.Backup.Schedule.Repeat).selectmenu('refresh',true);` → `$("#repeat").val(data.Backup.Schedule.Repeat);`

Line 215: `$("#scheduleactive").prop( "checked", JSON.parse(data.Backup.Schedule.Active) ).flipswitch('refresh');` → `$("#scheduleactive").prop( "checked", JSON.parse(data.Backup.Schedule.Active) );`

Lines 216-222: Remove `.checkboxradio('refresh')` from each line. Example:
`$("#mon").prop( "checked", JSON.parse(data.Backup.Schedule.Mon) ).checkboxradio('refresh');` → `$("#mon").prop( "checked", JSON.parse(data.Backup.Schedule.Mon) );`

Repeat for tue, wed, thu, fre, sat, sun.

- [ ] **Step 2: Replace ui-disabled with lb-disabled**

Search the entire file for `ui-disabled` and replace all occurrences with `lb-disabled`. This affects lines 155, 231, 245, 252, 285, 286, 289, 297, 298, 299, 300, 301, 302, 303 (approximately).

Use global search/replace: `ui-disabled` → `lb-disabled`

- [ ] **Step 3: Convert flipswitch to lb-toggle**

Find the flipswitch input for `scheduleactive`. The current HTML will be something like:
```html
<input type="checkbox" name="scheduleactive" id="scheduleactive" data-role="flipswitch">
```

Replace with lb-toggle markup:
```html
<label class="lb-toggle">
	<input type="checkbox" name="scheduleactive" id="scheduleactive">
	<span class="lb-toggle-slider"></span>
</label>
```

Note: Read the exact current HTML around the `scheduleactive` input before editing — it may have `data-role="none"` already.

- [ ] **Step 4: Add lb-select class to select elements**

Find the `<select>` elements for archive, compression, and repeat. Add `class="lb-select"` to each if not already present.

- [ ] **Step 5: Deploy and test**

```bash
cp templates/system/backup.html L:/templates/system/backup.html
sed -i 's/\r$//' L:/templates/system/backup.html
```

Open Backup page — verify:
1. Schedule toggle (lb-toggle) works
2. Day checkboxes check/uncheck correctly
3. Archive/Compression/Repeat dropdowns populate from config
4. Disabled state applies correctly when backup is running
5. Manual backup button works

- [ ] **Step 6: Commit**

```bash
git add templates/system/backup.html
git commit -m "feat(jqm-removal): migrate backup.html — flipswitch, checkboxradio, selectmenu, ui-disabled"
```

---

### Task 12: Migrate mailserver.html (Batch C)

**Files:**
- Modify: `templates/system/mailserver.html`

- [ ] **Step 1: Convert popup to dialog/lb-modal**

Lines 182-190: Replace the jQM popup with an HTML `<dialog>`:

Old:
```html
<div data-role="popup" id="testmailoverlay" style="min-width:500px;max-width:80%;min-height:600px;" class="ui-content" data-transition="fade">
    <a href="#" data-rel="back" class="lb-btn lb-btn-sm" style="position:absolute;right:8px;top:8px;">Close</a>
	<div data-role="header">
    	<h1><TMPL_VAR MAILSERVER.CAPTION_TESTMAIL_DIALOG></h1>
    </div>
    <div role="main" class="ui-content">
		<div id="smtpresults" style="word-wrap:break-word;"></div>
    </div>
</div>
```

New:
```html
<dialog id="testmailoverlay" class="lb-modal" style="min-width:500px;max-width:80%;min-height:600px;">
	<div class="lb-modal-header" style="display:flex;justify-content:space-between;align-items:center;">
		<h2><TMPL_VAR MAILSERVER.CAPTION_TESTMAIL_DIALOG></h2>
		<button class="lb-btn lb-btn-sm" onclick="document.getElementById('testmailoverlay').close();">&times;</button>
	</div>
	<div class="lb-modal-content" style="text-align:left;">
		<div id="smtpresults" style="word-wrap:break-word;"></div>
	</div>
</dialog>
```

- [ ] **Step 2: Replace popup("open") with showModal()**

Line 300 (approximately): Find `.popup("open")` call. Change:
```javascript
$("#testmailoverlay").popup("open");
```
To:
```javascript
document.getElementById('testmailoverlay').showModal();
```

- [ ] **Step 3: Remove all checkboxradio refresh calls**

Lines 394-410: Remove `.checkboxradio("refresh")` from all 7 calls. Example:

`$("#activate_mail").prop('checked', true).checkboxradio("refresh");` → `$("#activate_mail").prop('checked', true);`

Repeat for: smtpauth, smtpcrypt, MAIL_SYSTEM_ERRORS, MAIL_SYSTEM_INFOS, MAIL_PLUGIN_ERRORS, MAIL_PLUGIN_INFOS.

- [ ] **Step 4: Replace ui-disabled with lb-disabled**

Global search/replace in this file: `ui-disabled` → `lb-disabled`

This affects lines 276, 277, 281, 285, 291, 292 (approximately).

- [ ] **Step 5: Deploy and test**

```bash
cp templates/system/mailserver.html L:/templates/system/mailserver.html
sed -i 's/\r$//' L:/templates/system/mailserver.html
```

Open Mail Server page — verify:
1. Settings load correctly (checkboxes populate)
2. Enable/disable toggles work (fields enable/disable)
3. "Test SMTP" button opens the dialog (modal)
4. Dialog close button works
5. Save works

- [ ] **Step 6: Commit**

```bash
git add templates/system/mailserver.html
git commit -m "feat(jqm-removal): migrate mailserver.html — popup to dialog, remove widget calls"
```

---

### Task 13: Cleanup — Remove jQM overrides from components.css

**Files:**
- Modify: `webfrontend/html/system/css/components.css:1-116`

This is the final cleanup — only do this after ALL templates are migrated and tested.

- [ ] **Step 1: Remove Section 1 (jQuery Mobile Overrides)**

Delete the entire Section 1 block (lines 1-116 approximately), from:
```css
/* ============================================================
   1. jQuery Mobile Overrides
   ...
```
Up to and including the last rule before Section 2 starts:
```css
/* ============================================================
   2. Base Components
   ============================================================ */
```

Keep the Section 2 header and everything after it.

Note: Plugin pages still load jQM, but they have their own CSS. The overrides in components.css were bridge code for Core pages — no longer needed since Core pages don't load jQM anymore.

- [ ] **Step 2: Update section numbering**

Renumber sections: old Section 2 becomes Section 1, old Section 3 becomes Section 2, etc. This is optional but keeps the file clean.

- [ ] **Step 3: Deploy and full regression test**

```bash
cp webfrontend/html/system/css/components.css L:/webfrontend/html/system/css/components.css
```

Test ALL system pages one more time:
1. Dashboard, Admin, Network, MyLoxBerry — basic pages
2. Plugin Install, Backup, Mail Server — migrated pages
3. MQTT (all tabs), Log Manager — migrated pages
4. A plugin page — still works with jQM

- [ ] **Step 4: Commit**

```bash
git add webfrontend/html/system/css/components.css
git commit -m "refactor(jqm-removal): remove jQuery Mobile override CSS — no longer needed for core pages"
```
