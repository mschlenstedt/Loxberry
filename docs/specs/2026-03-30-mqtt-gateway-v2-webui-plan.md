# MQTT Gateway V2 WebUI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing MQTT Gateway WebUI to support a V2 (Opt-In) mode with topic discovery browser, conditional V1/V2 tabs, and live status indicator.

**Architecture:** Inline-migration of `templates/system/mqtt-gateway.html` with V1/V2 conditional blocks controlled by `GATEWAY_VERSION` template variable from `general.json`. New AJAX endpoints in `ajax-mqtt.php`. CGI handler extended with new form type and navbar restructuring.

**Tech Stack:** Perl CGI (HTML::Template), PHP (AJAX handlers), jQuery, HTML5 `<details>`, CSS `lb-*` design system classes.

**Design Spec:** `docs/specs/2026-03-30-mqtt-gateway-v2-webui-design.md`

---

## File Structure

### Files to Modify:
| File | Responsibility | Changes |
|------|---------------|---------|
| `webfrontend/htmlauth/system/mqtt-gateway.cgi` | CGI handler, form switching, navbar | Add `GATEWAY_VERSION` variable, new `?form=basic` handler, restructure navbar for V2 |
| `templates/system/mqtt-gateway.html` | All gateway UI forms | Add MQTT Basic tab, V2 subscriptions tab, conditional V2 blocks in Incoming, V1-only markers in Settings |
| `webfrontend/htmlauth/system/ajax/ajax-mqtt.php` | AJAX endpoint handler | Add `discover_topics`, `save_subscriptions_v2`, `get_subscriptions_v2` actions |

### Files to Create:
| File | Responsibility |
|------|---------------|
| `webfrontend/html/system/css/mqtt-gateway-v2.css` | V2-specific styles (topic browser, discovery bar, status indicator, JSON expand rows) |

### Reference Files (read-only):
| File | Why |
|------|-----|
| `webfrontend/html/system/css/components.css` | `lb-*` class definitions to use |
| `webfrontend/html/system/css/design-tokens.css` | CSS variable names |
| `templates/system/myloxberry.html` | Example of `lb-*` form patterns |
| `templates/system/mqtt.html` | Sibling MQTT page for context |

---

## Task 1: Add GATEWAY_VERSION to CGI Handler

**Files:**
- Modify: `webfrontend/htmlauth/system/mqtt-gateway.cgi:49-58` (config loading section)
- Modify: `webfrontend/htmlauth/system/mqtt-gateway.cgi:39-44` (template init section)

- [ ] **Step 1: Read the CGI handler file**

Read `webfrontend/htmlauth/system/mqtt-gateway.cgi` fully to confirm line numbers.

- [ ] **Step 2: Add GATEWAY_VERSION template variable**

In the config loading section (after line ~58 where `general.json` is parsed), add the gateway version extraction. Find the block that reads `general.json` and extract `Mqtt.GatewayVersion`:

```perl
# After the existing general.json loading (around line 54-58):
# Existing code reads $udpinport and $uselocalbroker from $gencfg

# Add gateway version - default to 1 for existing installations
my $gatewayversion = $gencfg->{'Mqtt'}->{'GatewayVersion'} // 1;
$template->param("GATEWAY_VERSION", $gatewayversion);
$template->param("GATEWAY_V2", $gatewayversion == 2 ? 1 : 0);
```

This provides both the version number and a boolean for V2-specific blocks in the template.

- [ ] **Step 3: Add hidden config div for JS access**

In the template init section, ensure the gateway version is also available to JavaScript. This will be used in Step 5 (template changes). For now, just confirm the template variable is set.

- [ ] **Step 4: Verify CGI loads correctly**

Open `http://<loxberry>/admin/system/mqtt-gateway.cgi` in browser and confirm no errors. The page should load identically to before since no template changes have been made yet.

- [ ] **Step 5: Commit**

```bash
git add webfrontend/htmlauth/system/mqtt-gateway.cgi
git commit -m "feat(mqtt-gw): add GATEWAY_VERSION template variable from general.json"
```

---

## Task 2: Restructure Navbar for V2

**Files:**
- Modify: `webfrontend/htmlauth/system/mqtt-gateway.cgi:113-151` (navbar definition)
- Modify: `webfrontend/htmlauth/system/mqtt-gateway.cgi:60-98` (form switching)

- [ ] **Step 1: Read the navbar definition**

Read lines 113-151 of `mqtt-gateway.cgi` to confirm the exact navbar structure.

- [ ] **Step 2: Add MQTT Basic form handler**

Add a new form type `basic` in the form switching section (around line 62). Insert before the existing default settings handler:

```perl
# New: MQTT Basic tab (first tab for V2)
if( $q->{form} eq "basic" ) {
    $navbar{5}{active} = 1;
    $template->param("FORM_BASIC", 1);
    basic_form();
}
# Existing: Default form (Settings)
elsif( !$q->{form} or $q->{form} eq "settings" ) {
```

- [ ] **Step 3: Add basic_form() function**

Add the form handler function after the existing `logs_form()` function (around line 228):

```perl
sub basic_form
{
    # MQTT Basic tab needs Miniserver list for default MS selection
    require "$lbshtmlauthdir/system/tools/mslist_select.pl";
    $template->param("mslist_select_html", mslist_select_html(
        formid => 'Main.msno',
        selected => $cfg->{'Main'}->{'msno'},
    ));
}
```

- [ ] **Step 4: Restructure navbar based on gateway version**

Replace the navbar definition to be conditional on gateway version. The key change: V2 adds "MQTT Basic" as first submenu item and reorders:

```perl
# Build navbar based on gateway version
my @gw_submenu;

if ($gatewayversion == 2) {
    @gw_submenu = (
        { "Name" => "MQTT Basic",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=basic" },
        { "Name" => "Abonnements",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=subscriptions" },
        { "Name" => "Incoming Overview",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=incoming" },
        { "Name" => "Settings",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=settings" },
        { "Name" => "Transformers",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=transformers" },
    );
} else {
    @gw_submenu = (
        { "Name" => "Gateway Settings",
          "URL" => "/admin/system/mqtt-gateway.cgi" },
        { "Name" => "Gateway Subscriptions",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=subscriptions" },
        { "Name" => "Gateway Conversions",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=conversions" },
        { "Name" => "Incoming Overview",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=incoming" },
        { "Name" => "Gateway Transformers",
          "URL" => "/admin/system/mqtt-gateway.cgi?form=transformers" },
    );
}

our @navbar = (
    { "Name" => "MQTT Basics",
      "URL" => "/admin/system/mqtt.cgi" },
    { "Name" => "MQTT Gateway",
      "Submenu" => \@gw_submenu },
    { "Name" => "MQTT Finder",
      "URL" => "/admin/system/mqtt-finder.cgi" },
    { "Name" => "Log Files",
      "URL" => "/admin/system/mqtt-gateway.cgi?form=logs" },
);
```

Note: `$gatewayversion` must be accessible in this scope. Move its declaration before the navbar definition if needed.

- [ ] **Step 5: Update default form for V2**

When V2 is active and no form parameter is given, redirect to the MQTT Basic tab instead of Settings:

```perl
# Adjust the default form redirect
if( $q->{form} eq "basic" or ($gatewayversion == 2 and !$q->{form}) ) {
    $navbar{5}{active} = 1;
    $template->param("FORM_BASIC", 1);
    basic_form();
}
elsif( !$q->{form} or $q->{form} eq "settings" ) {
    $navbar{10}{active} = 1;
    $template->param("FORM_SETTINGS", 1);
    settings_form();
}
```

- [ ] **Step 6: Test navbar rendering**

Open the gateway page in browser. For V1 (default), tabs should be unchanged. To test V2, temporarily set `Mqtt.GatewayVersion` to `2` in `general.json` and reload.

- [ ] **Step 7: Commit**

```bash
git add webfrontend/htmlauth/system/mqtt-gateway.cgi
git commit -m "feat(mqtt-gw): restructure navbar and add MQTT Basic form handler for V2"
```

---

## Task 3: Create V2 CSS File

**Files:**
- Create: `webfrontend/html/system/css/mqtt-gateway-v2.css`
- Modify: `templates/system/mqtt-gateway.html:1-5` (add CSS include)

- [ ] **Step 1: Read components.css for reference**

Read `webfrontend/html/system/css/components.css` to confirm exact `lb-*` class definitions and follow the same patterns.

- [ ] **Step 2: Create mqtt-gateway-v2.css**

```css
/* MQTT Gateway V2 Styles
   Uses design tokens from design-tokens.css
   Complements lb-* component classes from components.css */

/* === Status Indicator === */
.mqttgw-status {
  display: flex;
  align-items: center;
  gap: var(--lb-space-sm);
  padding: 10px 14px;
  border-radius: var(--lb-radius);
  margin-bottom: var(--lb-space-lg);
  font-size: var(--lb-font-sm);
}
.mqttgw-status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.mqttgw-status-ok {
  background: #f0f9e8;
  border: 1px solid #c3e6a0;
}
.mqttgw-status-ok .mqttgw-status-dot {
  background: var(--lb-success);
}
.mqttgw-status-ok .mqttgw-status-label {
  color: var(--lb-primary-dark);
  font-weight: 600;
}
.mqttgw-status-warn {
  background: #fff8e1;
  border: 1px solid #f0d060;
}
.mqttgw-status-warn .mqttgw-status-dot {
  background: var(--lb-warning);
}
.mqttgw-status-warn .mqttgw-status-label {
  color: #8a6d04;
  font-weight: 600;
}
.mqttgw-status-error {
  background: #fef2f2;
  border: 1px solid #fca5a5;
}
.mqttgw-status-error .mqttgw-status-dot {
  background: var(--lb-danger);
}
.mqttgw-status-error .mqttgw-status-label {
  color: var(--lb-danger);
  font-weight: 600;
}
.mqttgw-status-detail {
  color: var(--lb-gray-500);
}
.mqttgw-status-uptime {
  margin-left: auto;
  font-size: 0.8rem;
  color: var(--lb-gray-500);
}

/* === Version Warning Box === */
.mqttgw-version-warning {
  padding: 12px 16px;
  background: #fff8e1;
  border: 1px solid #f0d060;
  border-radius: var(--lb-radius);
  margin-bottom: var(--lb-space-lg);
  font-size: var(--lb-font-sm);
}

/* === Discovery Bar === */
.mqttgw-discovery {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: var(--lb-gray-50);
  border: 1px solid var(--lb-gray-200);
  border-radius: var(--lb-radius);
  margin-bottom: var(--lb-space-md);
}
.mqttgw-discovery-info {
  color: var(--lb-gray-500);
  font-size: var(--lb-font-sm);
}
.mqttgw-discovery-last {
  margin-left: auto;
  font-size: 0.8rem;
  color: var(--lb-gray-500);
}

/* === Filter Bar === */
.mqttgw-filter {
  display: flex;
  gap: 12px;
  margin-bottom: var(--lb-space-md);
  align-items: center;
}
.mqttgw-filter-input {
  flex: 1;
}
.mqttgw-filter-label {
  font-size: var(--lb-font-sm);
  color: var(--lb-gray-500);
  white-space: nowrap;
}
.mqttgw-filter-count {
  font-size: var(--lb-font-sm);
  color: var(--lb-gray-500);
}

/* === Topic Group (extends lb-collapsible) === */
.mqttgw-group summary {
  display: flex;
  align-items: center;
  gap: var(--lb-space-sm);
}
.mqttgw-group summary::after {
  /* Override lb-collapsible arrow — we use inline arrows */
  content: none;
}
.mqttgw-group-badge {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 10px;
  margin-left: var(--lb-space-sm);
}
.mqttgw-group-badge-active {
  background: var(--lb-primary);
  color: white;
}
.mqttgw-group-badge-inactive {
  background: var(--lb-gray-200);
  color: var(--lb-gray-500);
}
.mqttgw-group-actions {
  margin-left: auto;
  display: flex;
  gap: 4px;
}
.mqttgw-group-actions button {
  font-size: 11px;
  padding: 3px 10px;
  background: transparent;
  border: var(--lb-border);
  border-radius: 3px;
  cursor: pointer;
  color: var(--lb-gray-500);
}
.mqttgw-group-actions button:hover {
  background: var(--lb-gray-100);
}

/* === Topic Row === */
.mqttgw-topic-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--lb-gray-100);
}
.mqttgw-topic-row:last-child {
  border-bottom: none;
}
.mqttgw-topic-row-disabled {
  opacity: 0.6;
}
.mqttgw-topic-name {
  font-family: var(--lb-font-mono);
  flex: 1;
  font-size: var(--lb-font-sm);
}
.mqttgw-topic-payload {
  font-size: 0.8rem;
  color: var(--lb-gray-500);
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mqttgw-topic-json-label {
  font-size: 0.8rem;
  color: var(--lb-gray-500);
  white-space: nowrap;
  display: flex;
  align-items: center;
  gap: 4px;
}
.mqttgw-topic-ms {
  font-size: 11px;
  padding: 2px 4px;
  border: 1px solid var(--lb-gray-200);
  border-radius: 3px;
  color: var(--lb-gray-500);
}

/* === JSON Expand Rows === */
.mqttgw-json-rows {
  background: #f7fbf2;
  border-bottom: 1px solid var(--lb-gray-100);
}
.mqttgw-json-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 14px 6px 44px;
}
.mqttgw-json-key {
  font-family: var(--lb-font-mono);
  font-size: 0.8rem;
  color: var(--lb-primary-dark);
}
.mqttgw-json-value {
  font-size: 0.8rem;
  color: var(--lb-gray-500);
}
.mqttgw-json-type {
  margin-left: auto;
  font-size: 11px;
  color: var(--lb-gray-300);
}

/* Dark theme adjustments */
body.theme-dark .mqttgw-status-ok {
  background: rgba(109, 172, 32, 0.1);
  border-color: rgba(109, 172, 32, 0.3);
}
body.theme-dark .mqttgw-status-warn {
  background: rgba(202, 138, 4, 0.1);
  border-color: rgba(202, 138, 4, 0.3);
}
body.theme-dark .mqttgw-status-error {
  background: rgba(220, 38, 38, 0.1);
  border-color: rgba(220, 38, 38, 0.3);
}
body.theme-dark .mqttgw-json-rows {
  background: rgba(109, 172, 32, 0.05);
}
body.theme-dark .mqttgw-version-warning {
  background: rgba(202, 138, 4, 0.1);
  border-color: rgba(202, 138, 4, 0.3);
}
body.theme-dark .mqttgw-discovery {
  background: var(--lb-gray-100);
  border-color: var(--lb-gray-200);
}

/* === Responsive === */
@media (max-width: 875px) {
  .mqttgw-status {
    flex-wrap: wrap;
  }
  .mqttgw-status-uptime {
    margin-left: 0;
    flex-basis: 100%;
  }
  .mqttgw-discovery {
    flex-wrap: wrap;
  }
  .mqttgw-discovery-last {
    margin-left: 0;
    flex-basis: 100%;
  }
  .mqttgw-filter {
    flex-wrap: wrap;
  }
  .mqttgw-topic-row {
    flex-wrap: wrap;
  }
  .mqttgw-topic-payload {
    max-width: 100%;
    flex-basis: 100%;
    padding-left: 26px;
  }
}
```

- [ ] **Step 3: Add CSS include to template**

At the top of `templates/system/mqtt-gateway.html` (before line 18, the hidden config divs), add:

```html
<link rel="stylesheet" href="/system/css/mqtt-gateway-v2.css">
```

- [ ] **Step 4: Verify CSS loads**

Open the gateway page and check browser DevTools Network tab — `mqtt-gateway-v2.css` should load with 200 status.

- [ ] **Step 5: Commit**

```bash
git add webfrontend/html/system/css/mqtt-gateway-v2.css templates/system/mqtt-gateway.html
git commit -m "feat(mqtt-gw): add V2-specific CSS with topic browser, status indicator styles"
```

---

## Task 4: Build MQTT Basic Tab (Template)

**Files:**
- Modify: `templates/system/mqtt-gateway.html` (insert new FORM_BASIC block)

- [ ] **Step 1: Read the template header**

Read lines 1-30 of `mqtt-gateway.html` to find the right insertion point for the new form block.

- [ ] **Step 2: Add GATEWAY_VERSION hidden div**

In the existing hidden config divs section (lines 18-24), add:

```html
<div id="gatewayversion"><TMPL_VAR GATEWAY_VERSION></div>
```

- [ ] **Step 3: Add FORM_BASIC block**

Insert before the existing `<TMPL_IF FORM_SETTINGS>` block (line 26). This is the complete MQTT Basic tab:

```html
<TMPL_IF FORM_BASIC>
<!-- Form BASIC (MQTT Basic - V2) -->
<form id="form_basic" onsubmit="return false;">

    <!-- Live Status Indicator -->
    <div id="mqttgw_status" class="mqttgw-status mqttgw-status-ok" style="display:none">
        <span class="mqttgw-status-dot"></span>
        <span class="mqttgw-status-label">Gateway laeuft</span>
        <span class="mqttgw-status-detail" id="mqttgw_status_detail"></span>
        <span class="mqttgw-status-uptime" id="mqttgw_status_uptime"></span>
    </div>

    <!-- Section: Gateway Version -->
    <div class="lb-section-title">Gateway Version</div>

    <div class="lb-form-row">
        <div class="lb-form-label">Version</div>
        <div class="lb-form-field">
            <div class="lb-btn-group" id="version_toggle">
                <input type="radio" name="gatewayversion" id="gw_v1" value="1">
                <label for="gw_v1">V1 &mdash; Max. Kompatibilit&auml;t</label>
                <input type="radio" name="gatewayversion" id="gw_v2" value="2">
                <label for="gw_v2">V2 &mdash; Max. Performance</label>
            </div>
        </div>
    </div>
    <div class="lb-form-row">
        <div class="lb-form-label"></div>
        <div class="lb-form-field">
            <div class="lb-form-help" style="padding-left:0">
                V1 subscribes alle konfigurierten Topics global. V2 nutzt Opt-In &mdash; nur explizit ausgew&auml;hlte Payloads werden weitergeleitet.<br>
                Bestehende Installationen: Default V1. Neuinstallationen: Default V2.
            </div>
        </div>
    </div>

    <!-- Version change warning (hidden by default) -->
    <div id="version_change_warning" class="mqttgw-version-warning" style="display:none">
        <strong>&#9888; Hinweis:</strong> Bei Wechsel von V1 auf V2 m&uuml;ssen Topics im Tab &quot;Abonnements&quot; explizit ausgew&auml;hlt werden. Bestehende Subscriptions werden als Vorauswahl &uuml;bernommen.
    </div>

    <!-- Section: Miniserver Data Routing -->
    <div class="lb-section-title">Miniserver Datenweiterleitung</div>

    <div class="lb-form-row">
        <div class="lb-form-label">Standard Miniserver</div>
        <div class="lb-form-field">
            <TMPL_VAR mslist_select_html>
        </div>
    </div>

    <div class="lb-form-row">
        <div class="lb-form-label">Protokoll</div>
        <div class="lb-form-field">
            <div class="lb-btn-group" id="protocol_toggle">
                <input type="radio" name="protocol" id="proto_http" value="http">
                <label for="proto_http">HTTP</label>
                <input type="radio" name="protocol" id="proto_udp" value="udp">
                <label for="proto_udp">UDP</label>
                <input type="radio" name="protocol" id="proto_both" value="both">
                <label for="proto_both">Beide</label>
            </div>
        </div>
    </div>

    <div class="lb-form-row">
        <div class="lb-form-label">UDP Port</div>
        <div class="lb-form-field">
            <input class="lb-input" type="number" id="basic_udpport" style="width:120px">
        </div>
        <div class="lb-form-help">Port f&uuml;r Miniserver UDP Kommunikation</div>
    </div>

</form>

<script>
$(function() {
    var gatewayversion = parseInt($("#gatewayversion").text()) || 1;
    var cfgstr = $("#mqttconfig").text();
    var cfg = cfgstr ? JSON.parse(cfgstr) : {};

    // Set version toggle
    $("#gw_v" + gatewayversion).prop("checked", true);

    // Set protocol toggle
    var use_http = cfg.Main && cfg.Main.use_http;
    var use_udp = cfg.Main && cfg.Main.use_udp;
    if (use_http && use_udp) $("#proto_both").prop("checked", true);
    else if (use_udp) $("#proto_udp").prop("checked", true);
    else $("#proto_http").prop("checked", true);

    // Set UDP port
    $("#basic_udpport").val(cfg.Main ? cfg.Main.udpport : "");

    // Version change warning
    var originalVersion = gatewayversion;
    $('input[name="gatewayversion"]').on("change", function() {
        var newVersion = parseInt($(this).val());
        if (newVersion !== originalVersion) {
            $("#version_change_warning").slideDown(200);
        } else {
            $("#version_change_warning").slideUp(200);
        }
    });

    // Status indicator
    function updateStatus() {
        $.post('ajax/ajax-mqtt.php', { ajax: 'getpids' })
        .done(function(resp) {
            var data = typeof resp === 'string' ? JSON.parse(resp) : resp;
            var $status = $("#mqttgw_status");
            $status.show();

            if (data.pids && data.pids.mqttgateway) {
                var brokerhost = "localhost";  // Could be enhanced later
                $status.removeClass("mqttgw-status-warn mqttgw-status-error").addClass("mqttgw-status-ok");
                $(".mqttgw-status-label", $status).text("Gateway l\u00e4uft");
                $("#mqttgw_status_detail").text("\u2014 PID " + data.pids.mqttgateway);
            } else {
                $status.removeClass("mqttgw-status-ok mqttgw-status-warn").addClass("mqttgw-status-error");
                $(".mqttgw-status-label", $status).text("Gateway gestoppt");
                $("#mqttgw_status_detail").text("");
            }
        });
    }
    updateStatus();
    setInterval(updateStatus, 10000);

    // Save handler
    $("#saveapply").click(function() {
        var newVersion = parseInt($('input[name="gatewayversion"]:checked').val());
        var protocol = $('input[name="protocol"]:checked').val();

        cfg.Main = cfg.Main || {};
        cfg.Main.use_http = (protocol === "http" || protocol === "both") ? 1 : 0;
        cfg.Main.use_udp = (protocol === "udp" || protocol === "both") ? 1 : 0;
        cfg.Main.udpport = parseInt($("#basic_udpport").val()) || 11883;
        cfg.Main.msno = parseInt($("#Main\\.msno").val()) || 1;

        // Save gateway config
        $.ajax({
            type: 'POST',
            url: '/admin/system/ajax/ajax-generic.php?file=LBSCONFIG/mqttgateway.json&write&replace',
            dataType: 'json',
            contentType: 'application/json; charset=UTF-8',
            data: JSON.stringify(cfg)
        });

        // Save gateway version to general.json
        $.ajax({
            type: 'POST',
            url: '/admin/system/ajax/ajax-generic.php?file=LBSCONFIG/general.json&section=Mqtt&write',
            dataType: 'json',
            contentType: 'application/json; charset=UTF-8',
            data: JSON.stringify({ GatewayVersion: newVersion })
        })
        .done(function() {
            if (newVersion !== originalVersion) {
                // Reload page to reflect new navbar structure
                location.reload();
            }
        });
    });
});
</script>
</TMPL_IF>
```

- [ ] **Step 4: Test MQTT Basic tab**

Set `Mqtt.GatewayVersion` to `2` in `general.json`, then open `http://<loxberry>/admin/system/mqtt-gateway.cgi`. Should show the new MQTT Basic tab with status indicator, version toggle, and Miniserver config.

- [ ] **Step 5: Test version toggle**

Click V1 in the version toggle — warning box should slide down. Click back to V2 — warning should disappear. Click Save — `general.json` should update and page should reload with correct navbar.

- [ ] **Step 6: Commit**

```bash
git add templates/system/mqtt-gateway.html
git commit -m "feat(mqtt-gw): add MQTT Basic tab with version toggle and status indicator"
```

---

## Task 5: Add V2 AJAX Endpoints

**Files:**
- Modify: `webfrontend/htmlauth/system/ajax/ajax-mqtt.php`

- [ ] **Step 1: Read the AJAX handler**

Read `webfrontend/htmlauth/system/ajax/ajax-mqtt.php` fully to confirm the pattern and find the insertion point (before the closing `else` / error handler).

- [ ] **Step 2: Add discover_topics endpoint**

This endpoint reads the MQTT Finder data (which already performs broker-wide discovery) as a temporary solution. The pattern follows existing endpoints:

```php
// === V2: Discover Topics ===
elseif ( $_POST['ajax'] == 'discover_topics' || $_GET['ajax'] == 'discover_topics' ) {
    // Use MQTT Finder's discovery data as topic source
    // The finder already subscribes to # and collects topics
    $finderfile = '/dev/shm/mqttfinder.json';
    if (file_exists($finderfile)) {
        $finderdata = json_decode(file_get_contents($finderfile), true);
        $topics = array();

        if (is_array($finderdata)) {
            foreach ($finderdata as $topic => $entry) {
                if (is_string($topic) && strlen($topic) > 0) {
                    $group = explode('/', $topic)[0];
                    $topics[] = array(
                        'topic' => $topic,
                        'group' => $group,
                        'payload' => isset($entry['value']) ? $entry['value'] : '',
                        'timestamp' => isset($entry['timestamp']) ? $entry['timestamp'] : ''
                    );
                }
            }
        }

        header('Content-Type: application/json');
        echo json_encode(array(
            'topics' => $topics,
            'count' => count($topics),
            'source' => 'mqttfinder'
        ));
    } else {
        header('Content-Type: application/json');
        echo json_encode(array(
            'topics' => array(),
            'count' => 0,
            'error' => 'No discovery data available. Open MQTT Finder first to populate.'
        ));
    }
}
```

- [ ] **Step 3: Add get_subscriptions_v2 endpoint**

```php
// === V2: Get Subscriptions ===
elseif ( $_POST['ajax'] == 'get_subscriptions_v2' || $_GET['ajax'] == 'get_subscriptions_v2' ) {
    $cfgfile = 'mqttgateway.json';
    $fullcfgfile = LBSCONFIGDIR.'/'.$cfgfile;

    if (file_exists($fullcfgfile)) {
        $cfg = json_decode(file_get_contents($fullcfgfile), true);
        $subs = isset($cfg['subscriptions_v2']) ? $cfg['subscriptions_v2'] : array();
        header('Content-Type: application/json');
        echo json_encode(array('subscriptions_v2' => $subs));
    } else {
        header('Content-Type: application/json');
        echo json_encode(array('subscriptions_v2' => array()));
    }
}
```

- [ ] **Step 4: Add save_subscriptions_v2 endpoint**

```php
// === V2: Save Subscriptions ===
elseif ( $_POST['ajax'] == 'save_subscriptions_v2' ) {
    $cfgfile = 'mqttgateway.json';
    $fullcfgfile = LBSCONFIGDIR.'/'.$cfgfile;

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || !isset($input['subscriptions_v2'])) {
        http_response_code(400);
        echo json_encode(array('error' => 'Missing subscriptions_v2 data'));
        exit;
    }

    $fp = fopen($fullcfgfile, "c");
    if (!$fp) {
        error_log("mqtt-ajax: Could not open $fullcfgfile");
        http_response_code(500);
        exit;
    }
    flock($fp, LOCK_EX);
    $cfg = json_decode(file_get_contents($fullcfgfile), true);
    if (!$cfg) $cfg = array();

    $cfg['subscriptions_v2'] = $input['subscriptions_v2'];

    file_put_contents($fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    flock($fp, LOCK_UN);
    fclose($fp);

    header('Content-Type: application/json');
    echo json_encode(array('status' => 'ok', 'count' => count($input['subscriptions_v2'])));
}
```

- [ ] **Step 5: Test endpoints**

Test each endpoint with curl or browser DevTools console:

```javascript
// Test discover_topics
$.post('ajax/ajax-mqtt.php', { ajax: 'discover_topics' }, function(r) { console.log(r); });

// Test get_subscriptions_v2
$.post('ajax/ajax-mqtt.php', { ajax: 'get_subscriptions_v2' }, function(r) { console.log(r); });

// Test save_subscriptions_v2
$.ajax({ type: 'POST', url: 'ajax/ajax-mqtt.php?ajax=save_subscriptions_v2',
    contentType: 'application/json', data: JSON.stringify({
        subscriptions_v2: [{ topic: 'test/topic', enabled: true, json_expand: false, json_fields: [], toMS: [1] }]
    }), success: function(r) { console.log(r); }
});
```

- [ ] **Step 6: Commit**

```bash
git add webfrontend/htmlauth/system/ajax/ajax-mqtt.php
git commit -m "feat(mqtt-gw): add V2 AJAX endpoints for topic discovery and subscription management"
```

---

## Task 6: Build V2 Subscriptions Tab (Topic Browser)

**Files:**
- Modify: `templates/system/mqtt-gateway.html` (inside FORM_SUBSCRIPTIONS block)

This is the largest task — the core V2 feature.

- [ ] **Step 1: Read the existing FORM_SUBSCRIPTIONS block**

Read lines 109-188 of `mqtt-gateway.html` to understand the existing V1 subscriptions UI.

- [ ] **Step 2: Wrap existing V1 content in conditional**

Wrap the existing subscriptions form content (the textarea-based UI) in a V1-only block:

```html
<TMPL_IF FORM_SUBSCRIPTIONS>

<TMPL_UNLESS GATEWAY_V2>
<!-- V1: Textarea-based subscriptions (existing code unchanged) -->
<!-- ... existing form content stays here exactly as is ... -->
</TMPL_UNLESS>

<TMPL_IF GATEWAY_V2>
<!-- V2: Topic Browser (new) -->
<!-- ... new V2 content goes here ... -->
</TMPL_IF>

</TMPL_IF>
```

- [ ] **Step 3: Add V2 topic browser HTML**

Inside the `<TMPL_IF GATEWAY_V2>` block, add the complete topic browser:

```html
<TMPL_IF GATEWAY_V2>
<!-- V2: Topic Browser -->
<form id="form_subscriptions_v2" onsubmit="return false;">

    <!-- Discovery Bar -->
    <div class="mqttgw-discovery">
        <button class="lb-btn lb-btn-primary lb-btn-sm lb-btn-icon" id="btn_discover" type="button">
            &#128269; Topics entdecken
        </button>
        <span class="mqttgw-discovery-info">Scannt alle Topics am Broker f&uuml;r 10 Sekunden</span>
        <span class="mqttgw-discovery-last" id="discovery_last_info"></span>
    </div>

    <!-- Loading indicator (hidden) -->
    <div id="discovery_loading" style="display:none; text-align:center; padding:20px; color:var(--lb-gray-500)">
        <span id="discovery_countdown">10</span> Sekunden &mdash; Sammle Topics...
    </div>

    <!-- Filter Bar -->
    <div class="mqttgw-filter">
        <input class="lb-input mqttgw-filter-input" type="text" id="topic_filter" placeholder="Topics filtern...">
        <label class="mqttgw-filter-label">
            <input type="checkbox" id="filter_subscribed_only"> Nur abonnierte
        </label>
        <span class="mqttgw-filter-count" id="filter_count"></span>
    </div>

    <!-- Topic Groups Container -->
    <div id="topic_groups_container">
        <div style="text-align:center; padding:40px; color:var(--lb-gray-500)">
            Klicke &quot;Topics entdecken&quot; um verf&uuml;gbare MQTT Topics anzuzeigen.
        </div>
    </div>

</form>

<script>
$(function() {
    var discoveredTopics = [];
    var subscriptionsV2 = {};  // keyed by topic path
    var msCount = parseInt($("#Main\\.msno option").length) || 1;

    // Load existing V2 subscriptions
    $.post('ajax/ajax-mqtt.php', { ajax: 'get_subscriptions_v2' })
    .done(function(resp) {
        var data = typeof resp === 'string' ? JSON.parse(resp) : resp;
        if (data.subscriptions_v2) {
            data.subscriptions_v2.forEach(function(sub) {
                subscriptionsV2[sub.topic] = sub;
            });
        }
    });

    // Build MS options HTML
    function msOptionsHtml(selectedMS) {
        if (msCount <= 1) return '';
        var opts = '<option value="default">Standard</option>';
        for (var i = 1; i <= msCount; i++) {
            opts += '<option value="' + i + '"' + (selectedMS && selectedMS.length === 1 && selectedMS[0] === i ? ' selected' : '') + '>MS ' + i + '</option>';
        }
        if (msCount === 2) {
            opts += '<option value="1,2"' + (selectedMS && selectedMS.length === 2 ? ' selected' : '') + '>MS 1+2</option>';
        }
        return '<select class="mqttgw-topic-ms">' + opts + '</select>';
    }

    // Render topic groups
    function renderTopics() {
        var groups = {};
        var filterText = $("#topic_filter").val().toLowerCase();
        var subscribedOnly = $("#filter_subscribed_only").prop("checked");
        var totalCount = 0;
        var subCount = 0;

        // Group topics by first segment
        discoveredTopics.forEach(function(t) {
            var sub = subscriptionsV2[t.topic];
            var isSubscribed = sub && sub.enabled;
            if (subscribedOnly && !isSubscribed) return;
            if (filterText && t.topic.toLowerCase().indexOf(filterText) === -1) return;

            if (!groups[t.group]) groups[t.group] = { topics: [], subCount: 0 };
            groups[t.group].topics.push(t);
            totalCount++;
            if (isSubscribed) {
                groups[t.group].subCount++;
                subCount++;
            }
        });

        $("#filter_count").text(subCount + " von " + totalCount + " abonniert");

        var html = '';
        var sortedGroups = Object.keys(groups).sort();

        sortedGroups.forEach(function(groupName) {
            var g = groups[groupName];
            var badgeClass = g.subCount > 0 ? 'mqttgw-group-badge-active' : 'mqttgw-group-badge-inactive';
            var isOpen = g.subCount > 0 ? ' open' : '';

            html += '<details class="lb-collapsible mqttgw-group"' + isOpen + '>';
            html += '<summary>';
            html += '<strong>' + groupName + '</strong>';
            html += '<span class="mqttgw-group-badge ' + badgeClass + '">' + g.subCount + ' / ' + g.topics.length + '</span>';
            html += '<span class="mqttgw-group-actions">';
            html += '<button type="button" onclick="groupToggleAll(\'' + groupName + '\', true)">Alle an</button>';
            html += '<button type="button" onclick="groupToggleAll(\'' + groupName + '\', false)">Alle aus</button>';
            html += '</span>';
            html += '</summary>';
            html += '<div class="lb-collapsible-content" style="padding:0">';

            g.topics.forEach(function(t) {
                var sub = subscriptionsV2[t.topic] || { enabled: false, json_expand: false, json_fields: [], toMS: [] };
                var topicId = t.topic.replace(/[\/\.#\+]/g, '_');
                var disabledClass = sub.enabled ? '' : ' mqttgw-topic-row-disabled';
                var shortTopic = t.topic.substring(groupName.length + 1);

                html += '<div class="mqttgw-topic-row' + disabledClass + '" data-topic="' + t.topic + '">';
                html += '<input type="checkbox" class="topic-subscribe" data-topic="' + t.topic + '"' + (sub.enabled ? ' checked' : '') + '>';
                html += '<span class="mqttgw-topic-name">' + shortTopic + '</span>';
                html += '<span class="mqttgw-topic-payload" title="' + (t.payload || '').replace(/"/g, '&quot;') + '">' + (t.payload || '') + '</span>';
                html += '<label class="mqttgw-topic-json-label"><input type="checkbox" class="topic-json-expand" data-topic="' + t.topic + '"' + (sub.json_expand ? ' checked' : '') + '> JSON</label>';
                if (msCount > 1) {
                    html += msOptionsHtml(sub.toMS);
                }
                html += '</div>';

                // JSON expanded fields
                if (sub.json_expand && t.payload) {
                    try {
                        var jsonPayload = JSON.parse(t.payload);
                        if (typeof jsonPayload === 'object' && jsonPayload !== null) {
                            html += '<div class="mqttgw-json-rows" data-parent="' + t.topic + '">';
                            Object.keys(jsonPayload).forEach(function(key) {
                                var fieldEnabled = true;
                                if (sub.json_fields && sub.json_fields.length > 0) {
                                    var field = sub.json_fields.find(function(f) { return f.key === key; });
                                    fieldEnabled = field ? field.enabled : true;
                                }
                                var val = jsonPayload[key];
                                var valType = typeof val;

                                html += '<div class="mqttgw-json-row">';
                                html += '<input type="checkbox" class="json-field-subscribe" data-topic="' + t.topic + '" data-key="' + key + '"' + (fieldEnabled ? ' checked' : '') + '>';
                                html += '<span class="mqttgw-json-key">.' + key + '</span>';
                                html += '<span class="mqttgw-json-value">= ' + val + '</span>';
                                html += '<span class="mqttgw-json-type">' + valType + '</span>';
                                html += '</div>';
                            });
                            html += '</div>';
                        }
                    } catch(e) { /* not valid JSON, skip expand */ }
                }
            });

            html += '</div></details>';
        });

        if (html === '') {
            html = '<div style="text-align:center; padding:40px; color:var(--lb-gray-500)">Keine Topics gefunden.</div>';
        }

        $("#topic_groups_container").html(html);
    }

    // Discovery button
    $("#btn_discover").click(function() {
        var $btn = $(this);
        $btn.prop("disabled", true).text("Scanne...");
        $("#discovery_loading").show();

        var countdown = 10;
        var countdownInterval = setInterval(function() {
            countdown--;
            $("#discovery_countdown").text(countdown);
            if (countdown <= 0) clearInterval(countdownInterval);
        }, 1000);

        // Trigger MQTT Finder scan, then fetch results
        $.post('ajax/ajax-mqtt.php', { ajax: 'getmqttfinderdata' })
        .always(function() {
            // Wait for scan to collect data, then fetch
            setTimeout(function() {
                $.post('ajax/ajax-mqtt.php', { ajax: 'discover_topics' })
                .done(function(resp) {
                    var data = typeof resp === 'string' ? JSON.parse(resp) : resp;
                    discoveredTopics = data.topics || [];
                    var now = new Date();
                    $("#discovery_last_info").text("Letzter Scan: " + now.toLocaleTimeString() + " \u2014 " + discoveredTopics.length + " Topics gefunden");
                    renderTopics();
                })
                .always(function() {
                    clearInterval(countdownInterval);
                    $btn.prop("disabled", false).html("&#128269; Topics entdecken");
                    $("#discovery_loading").hide();
                });
            }, 10000);
        });
    });

    // Event delegation for checkboxes
    $("#topic_groups_container").on("change", ".topic-subscribe", function() {
        var topic = $(this).data("topic");
        if (!subscriptionsV2[topic]) {
            subscriptionsV2[topic] = { topic: topic, enabled: false, json_expand: false, json_fields: [], toMS: [] };
        }
        subscriptionsV2[topic].enabled = $(this).prop("checked");
        renderTopics();
    });

    $("#topic_groups_container").on("change", ".topic-json-expand", function() {
        var topic = $(this).data("topic");
        if (!subscriptionsV2[topic]) {
            subscriptionsV2[topic] = { topic: topic, enabled: false, json_expand: false, json_fields: [], toMS: [] };
        }
        subscriptionsV2[topic].json_expand = $(this).prop("checked");
        renderTopics();
    });

    $("#topic_groups_container").on("change", ".json-field-subscribe", function() {
        var topic = $(this).data("topic");
        var key = $(this).data("key");
        var sub = subscriptionsV2[topic];
        if (!sub) return;

        if (!sub.json_fields) sub.json_fields = [];
        var existing = sub.json_fields.find(function(f) { return f.key === key; });
        if (existing) {
            existing.enabled = $(this).prop("checked");
        } else {
            sub.json_fields.push({ key: key, enabled: $(this).prop("checked") });
        }
    });

    $("#topic_groups_container").on("change", ".mqttgw-topic-ms", function() {
        var topic = $(this).closest(".mqttgw-topic-row").data("topic");
        var val = $(this).val();
        if (!subscriptionsV2[topic]) return;

        if (val === "default") subscriptionsV2[topic].toMS = [];
        else subscriptionsV2[topic].toMS = val.split(",").map(Number);
    });

    // Filter handlers
    $("#topic_filter").on("input", renderTopics);
    $("#filter_subscribed_only").on("change", renderTopics);

    // Group toggle all
    window.groupToggleAll = function(groupName, enable) {
        discoveredTopics.forEach(function(t) {
            if (t.group === groupName) {
                if (!subscriptionsV2[t.topic]) {
                    subscriptionsV2[t.topic] = { topic: t.topic, enabled: false, json_expand: false, json_fields: [], toMS: [] };
                }
                subscriptionsV2[t.topic].enabled = enable;
            }
        });
        renderTopics();
    };

    // Save handler
    $("#saveapply").click(function() {
        var subsArray = [];
        Object.keys(subscriptionsV2).forEach(function(topic) {
            var sub = subscriptionsV2[topic];
            if (sub.enabled) {
                subsArray.push(sub);
            }
        });

        $.ajax({
            type: 'POST',
            url: 'ajax/ajax-mqtt.php?ajax=save_subscriptions_v2',
            contentType: 'application/json; charset=UTF-8',
            data: JSON.stringify({ subscriptions_v2: subsArray })
        })
        .done(function() {
            // Trigger gateway restart to apply new subscriptions
            $.post('ajax/ajax-mqtt.php', { ajax: 'restartgateway' });
        });
    });
});
</script>
</TMPL_IF>
```

- [ ] **Step 4: Test topic browser**

1. Set `Mqtt.GatewayVersion` to `2` in `general.json`
2. Open the Abonnements tab
3. Click "Topics entdecken" — should show loading, then topic groups
4. Toggle subscriptions, JSON expand, filter
5. Click "Speichern" — should save to `mqttgateway.json`

- [ ] **Step 5: Commit**

```bash
git add templates/system/mqtt-gateway.html
git commit -m "feat(mqtt-gw): add V2 topic browser with discovery, grouping, JSON expand"
```

---

## Task 7: Conditional Incoming Overview for V2

**Files:**
- Modify: `templates/system/mqtt-gateway.html` (inside FORM_TOPICS block)

- [ ] **Step 1: Read the FORM_TOPICS block**

Read lines 214-1036 to find the "Do not forward" checkbox generation. Search for `doNotForward` and `do_not_forward` references.

- [ ] **Step 2: Wrap "Do not forward" in V1-only conditional**

Find the "Do not forward" checkbox column in both the HTTP and UDP table generation JavaScript. The checkboxes are generated dynamically in `generate_http_table()` and `generate_udp_table()` functions.

In `generate_http_table()`, find the column that generates `http_do_not_forward_` checkboxes and wrap it:

In the JavaScript section, after the config parsing, add a gateway version variable:

```javascript
var gatewayVersion = parseInt($("#gatewayversion").text()) || 1;
var isV2 = (gatewayVersion === 2);
```

Then in the `generate_http_table()` function, find where the "Do not forward" header and checkbox cells are generated, and wrap them in `if (!isV2)` conditions:

```javascript
// In the table header generation, wrap the "Do not forward" th:
if (!isV2) {
    headerhtml += '<th>Do not forward</th>';
}

// In the per-row generation, wrap the "Do not forward" checkbox td:
if (!isV2) {
    rowhtml += '<td><input type="checkbox" id="http_do_not_forward_' + topickey + '" ... /></td>';
}
```

Apply the same pattern to `generate_udp_table()`.

- [ ] **Step 3: Add V2 info text**

At the top of the FORM_TOPICS section, inside a `<TMPL_IF GATEWAY_V2>` block, add an info note:

```html
<TMPL_IF GATEWAY_V2>
<div style="padding:10px 14px;background:var(--lb-gray-50);border:var(--lb-border);border-radius:var(--lb-radius);margin-bottom:var(--lb-space-md);font-size:var(--lb-font-sm);color:var(--lb-gray-500)">
    &#9432; Gateway V2 (Opt-In): &quot;Do not forward&quot; ist nicht verf&uuml;gbar &mdash; es werden nur explizit abonnierte Topics weitergeleitet.
</div>
</TMPL_IF>
```

- [ ] **Step 4: Also hide the doNotForward AJAX handler calls**

In the `checkbox_doNotForward()` function, add a guard:

```javascript
function checkbox_doNotForward(event) {
    if (isV2) return;  // V2 doesn't use doNotForward
    // ... existing code ...
}
```

- [ ] **Step 5: Test**

1. With V2 active, open Incoming Overview
2. Confirm "Do not forward" column is hidden
3. Confirm info text is shown
4. With V1 active, confirm everything works as before

- [ ] **Step 6: Commit**

```bash
git add templates/system/mqtt-gateway.html
git commit -m "feat(mqtt-gw): hide 'Do not forward' in Incoming Overview for V2"
```

---

## Task 8: Mark Subscription Filters as V1-only in Settings

**Files:**
- Modify: `templates/system/mqtt-gateway.html` (FORM_SETTINGS and FORM_SUBSCRIPTIONS blocks)

- [ ] **Step 1: Read the subscription filters section**

Read lines 109-188 (FORM_SUBSCRIPTIONS) to find the subscription filters textarea.

- [ ] **Step 2: Add V1-only conditional around subscription filters**

In the FORM_SUBSCRIPTIONS block (V1 mode), find the subscription filters `<textarea>` section and confirm it's already inside the `<TMPL_UNLESS GATEWAY_V2>` block added in Task 6. If the filters are in FORM_SETTINGS instead, locate them there.

Based on the codebase analysis, subscription filters are in FORM_SUBSCRIPTIONS (around line 164). Since Task 6 already wrapped the entire V1 subscriptions content in `<TMPL_UNLESS GATEWAY_V2>`, the filters are already hidden in V2 mode.

For the Settings tab, if any filter-related settings exist there, add:

```html
<TMPL_IF GATEWAY_V2>
<div class="lb-section-title">Subscription Filter</div>
<div style="padding:12px;background:var(--lb-gray-50);border-radius:var(--lb-radius);color:var(--lb-gray-500);font-size:var(--lb-font-sm)">
    &#9432; Subscription Filter sind nur bei Gateway V1 relevant. Bei V2 werden Topics direkt im Abonnements-Tab ausgew&auml;hlt.
</div>
</TMPL_IF>
```

- [ ] **Step 3: Test**

1. V1 mode: Subscriptions tab shows textarea + filters as before
2. V2 mode: Subscriptions tab shows topic browser, no filters
3. Settings tab: If filters section exists, shows V1-only message in V2 mode

- [ ] **Step 4: Commit**

```bash
git add templates/system/mqtt-gateway.html
git commit -m "feat(mqtt-gw): mark subscription filters as V1-only in Settings"
```

---

## Task 9: Add zigbee_led as Shipped Transformer

**Files:**
- Modify: `templates/system/mqtt-gateway.html` (FORM_TRANSFORMERS block)

- [ ] **Step 1: Read the transformers section**

Read lines 1038-1122 to understand how transformers are displayed. They are loaded from `/dev/shm/mqttgateway_transformers.json` and rendered via JavaScript.

- [ ] **Step 2: Understand transformer data format**

The transformer JSON from the daemon contains entries like:

```json
{
    "name": "shelly_rgb",
    "type": "shipped",
    "description": "...",
    "filename": "shelly_rgb.pl"
}
```

The `zigbee_led` transformer needs to be added as a shipped transformer file in the backend. Since this plan covers WebUI only and the backend is out of scope, we ensure the UI correctly renders it when present.

However, we can add a reference in the transformers display. Read the JavaScript that builds the transformer table to understand the rendering pattern.

- [ ] **Step 3: No template change needed for zigbee_led**

The transformer list is dynamically generated from the JSON data. When `zigbee_led` is added as a shipped transformer file on the filesystem, it will automatically appear in the UI. No template change is required for this.

The actual transformer file creation is a backend task (add `zigbee_led.pl` to `$lbsbindir/mqtt/transform/`). Mark this as a note in the spec.

- [ ] **Step 4: Commit (skip if no changes)**

If no template changes were made, skip this commit. Note in the PR that `zigbee_led` transformer file needs to be created separately.

---

## Task 10: Final Integration and Testing

**Files:**
- All modified files from Tasks 1-9

- [ ] **Step 1: Full V1 regression test**

Set `Mqtt.GatewayVersion` to `1` (or remove the key) in `general.json`. Walk through all tabs:

1. Gateway Settings — all form fields work, save works
2. Subscriptions — textarea, filters, external plugins all display
3. Conversions — textarea works
4. Incoming Overview — all columns including "Do not forward" visible
5. Transformers — table renders
6. Logs — log viewer works
7. Navbar shows V1 tab structure

- [ ] **Step 2: Full V2 test**

Set `Mqtt.GatewayVersion` to `2` in `general.json`. Walk through all tabs:

1. MQTT Basic — status indicator, version toggle, Miniserver config, protocol toggle, save
2. Abonnements — discovery button, topic groups, checkboxes, JSON expand, filter, MS selector, save
3. Incoming Overview — "Do not forward" hidden, info text shown, tables work
4. Settings — subscription filters marked V1-only
5. Transformers — table renders (zigbee_led shows when backend file exists)
6. Logs — unchanged
7. Navbar shows V2 tab structure

- [ ] **Step 3: Version switching test**

1. Start in V1 mode
2. Navigate to MQTT Basic tab (via direct URL `?form=basic`)
3. Switch to V2, save
4. Page reloads with V2 navbar
5. Switch back to V1, save
6. Page reloads with V1 navbar
7. Confirm no data loss in `mqttgateway.json`

- [ ] **Step 4: Theme test**

Test each theme (classic, dark, modern) with V2 active:
- Status indicator colors
- Topic browser group badges
- JSON expand rows green tint
- Warning boxes
- Button groups

- [ ] **Step 5: Deploy to LoxBerry**

Copy changed files to L: drive (LoxBerry) per standard workflow:
- `templates/system/mqtt-gateway.html` → `L:/opt/loxberry/templates/system/`
- `webfrontend/htmlauth/system/mqtt-gateway.cgi` → `L:/opt/loxberry/webfrontend/htmlauth/system/`
- `webfrontend/htmlauth/system/ajax/ajax-mqtt.php` → `L:/opt/loxberry/webfrontend/htmlauth/system/ajax/`
- `webfrontend/html/system/css/mqtt-gateway-v2.css` → `L:/opt/loxberry/webfrontend/html/system/css/`

Hard-refresh browser and verify on live LoxBerry.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "feat(mqtt-gw): MQTT Gateway V2 WebUI complete - topic browser, conditional tabs, status indicator"
```
