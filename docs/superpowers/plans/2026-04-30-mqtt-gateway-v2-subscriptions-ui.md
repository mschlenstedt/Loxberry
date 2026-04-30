# MQTT Gateway V2 — Subscriptions WebUI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the V2 subscriptions WebUI to use `subscriptions.json` as the single data store, support unlimited-depth recursive JSON tree expansion, and replace the Save button with auto-save (1.5 s debounce).

**Architecture:** Two new PHP endpoints in `ajax-mqtt.php` read/write `subscriptions.json` directly. The V2 JS block in `mqtt-gateway.html` (lines 356–882, inside `<TMPL_IF GATEWAY_V2>`) is replaced in full: `subscriptions[]` array mirrors `subscriptions.json` exactly, `renderJsonTree()` recurses without depth limit through objects/arrays/arrays-of-arrays, and a `markDirty()` / `doSave()` pattern handles auto-save. V1 (`mqttgateway.pl`) and all V1 UI are untouched.

**Tech Stack:** PHP 7+ (file_put_contents + flock), jQuery (existing in LoxBerry), LoxBerry HTML::Template, `subscriptions.json` at `LBSCONFIGDIR/subscriptions.json`.

---

## File Map

| File | Change |
|---|---|
| `webfrontend/htmlauth/system/ajax/ajax-mqtt.php` | Insert two new elseif blocks after line 283 |
| `templates/system/mqtt-gateway.html` | Replace lines 356–882 (content between `<TMPL_IF GATEWAY_V2>` and `</TMPL_IF>` in the FORM_SUBSCRIPTIONS section) |

---

### Task 1: PHP — `get_subscriptions` and `save_subscriptions`

**Files:**
- Modify: `webfrontend/htmlauth/system/ajax/ajax-mqtt.php` (after line 283, before `// Unknown request`)

- [ ] **Step 1: Insert both endpoints**

In `webfrontend/htmlauth/system/ajax/ajax-mqtt.php`, after the closing `}` of the `save_subscriptions_v2` block (line 283) and before `// Unknown request` (line 285), insert:

```php
elseif ( $_POST['ajax'] == 'get_subscriptions' || $_GET['ajax'] == 'get_subscriptions' ) {
    $fullcfgfile = LBSCONFIGDIR.'/subscriptions.json';
    header('Content-Type: application/json');
    if (file_exists($fullcfgfile)) {
        $cfg = json_decode(file_get_contents($fullcfgfile), true);
        echo json_encode($cfg ?: array('Subscriptions' => array()));
    } else {
        echo json_encode(array('Subscriptions' => array()));
    }
}

elseif ( $_POST['ajax'] == 'save_subscriptions' ) {
    $fullcfgfile = LBSCONFIGDIR.'/subscriptions.json';
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || !isset($input['Subscriptions'])) {
        http_response_code(400);
        header('Content-Type: application/json');
        echo json_encode(array('error' => 'Missing Subscriptions data'));
        exit;
    }
    $fp = fopen($fullcfgfile, 'c');
    if (!$fp) {
        http_response_code(500);
        exit;
    }
    flock($fp, LOCK_EX);
    file_put_contents($fullcfgfile, json_encode($input, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    flock($fp, LOCK_UN);
    fclose($fp);
    header('Content-Type: application/json');
    echo json_encode(array('status' => 'ok', 'count' => count($input['Subscriptions'])));
}
```

- [ ] **Step 2: Test `get_subscriptions` on LoxBerry**

```bash
curl -s "http://localhost/admin/system/ajax/ajax-mqtt.php?ajax=get_subscriptions" | python3 -m json.tool
```
Expected: `{"Subscriptions": [...]}` with current content of `subscriptions.json`.

- [ ] **Step 3: Test `save_subscriptions` on LoxBerry**

```bash
curl -s -X POST "http://localhost/admin/system/ajax/ajax-mqtt.php?ajax=save_subscriptions" \
  -H "Content-Type: application/json" \
  -d '{"Subscriptions":[{"Id":"test/ping","Toms":[],"Noncached":false,"resetaftersend":false,"Jsonexpand":false,"Json":[]}]}' \
  | python3 -m json.tool
```
Expected: `{"status": "ok", "count": 1}`

Verify file:
```bash
cat $LBHOMEDIR/config/system/subscriptions.json
```
Expected: contains `test/ping`.

- [ ] **Step 4: Restore real subscriptions.json and commit**

```bash
curl -s -X POST "http://localhost/admin/system/ajax/ajax-mqtt.php?ajax=save_subscriptions" \
  -H "Content-Type: application/json" \
  -d '{"Subscriptions":[{"Id":"mqttgateway2_test/irgendeinwert","Toms":[],"Noncached":false,"resetaftersend":false,"Jsonexpand":false,"Json":[]},{"Id":"mqttgateway2_test/data","Toms":[],"Noncached":false,"resetaftersend":false,"Jsonexpand":false,"Json":[]}]}'

git add webfrontend/htmlauth/system/ajax/ajax-mqtt.php
git commit -m "feat: add get_subscriptions and save_subscriptions PHP endpoints for subscriptions.json"
```

---

### Task 2: JS — Data model, helpers, auto-save, load (skeleton with render stubs)

**Files:**
- Modify: `templates/system/mqtt-gateway.html` — replace lines 356–882

- [ ] **Step 1: Replace V2 block content**

Delete everything between (but not including) the `<TMPL_IF GATEWAY_V2>` line (355) and `</TMPL_IF>` line (883). Replace with:

```html
<!-- V2: Topic Browser -->
<form id="form_subscriptions_v2" onsubmit="return false;">

    <!-- Discovery Status -->
    <div class="mqttgw-status mqttgw-status-ok">
        <span class="mqttgw-status-dot" id="discovery_pulse"></span>
        <span class="mqttgw-status-label"><span id="discovery_count">--</span> Topics</span>
        <span class="mqttgw-status-detail">&mdash; <span id="discovery_ago"><TMPL_VAR MQTT.DISCOVERY_LOADING></span></span>
        <span class="mqttgw-status-uptime">
            <button class="lb-btn lb-btn-sm mqttgw-discovery-refresh" id="btn_discovery_refresh" type="button" data-role="none" title="<TMPL_VAR MQTT.DISCOVERY_REFRESH>">&#x21bb;</button>
            <span id="save_status" style="font-size:var(--lb-font-sm);margin-left:10px"></span>
        </span>
    </div>

    <!-- Filter Bar -->
    <div class="mqttgw-filter">
        <input class="lb-input mqttgw-filter-input" type="text" id="topic_filter" placeholder="<TMPL_VAR MQTT.FILTER_PLACEHOLDER>" data-role="none">
        <button class="lb-btn lb-btn-primary lb-btn-sm" id="btn_filter_select_all" type="button" data-role="none"><TMPL_VAR MQTT.BTN_SELECT_ALL></button>
        <button class="lb-btn lb-btn-sm" id="btn_filter_deselect_all" type="button" data-role="none"><TMPL_VAR MQTT.BTN_DESELECT_ALL></button>
        <label class="mqttgw-filter-label">
            <input type="checkbox" id="filter_subscribed_only" data-role="none"> <TMPL_VAR MQTT.FILTER_SUBSCRIBED_ONLY>
        </label>
        <span class="mqttgw-filter-count" id="filter_count"></span>
    </div>

    <!-- Topic Groups Container -->
    <div id="topic_groups_container">
        <div style="text-align:center;padding:40px;color:var(--lb-gray-500)">
            <TMPL_VAR MQTT.TOPICS_LOADING>
        </div>
    </div>

</form>

<script>
$(function() {

    // ── Data model — mirrors subscriptions.json exactly ───────────────────
    // Each entry: { Id, Toms[], Noncached, resetaftersend, Jsonexpand, Json[] }
    // Json entry:  { Id (@@-path), Toms[], Noncached, resetaftersend }
    var subscriptions = [];
    var isDirty = false;
    var saveTimer = null;
    var discoveredTopics = [];  // [{ topic, payload, group }]

    // MS count from gateway config
    var cfgstr2 = $("#mqttconfig").text();
    var cfg2    = cfgstr2 ? JSON.parse(cfgstr2) : {};
    var msCount  = Math.max(parseInt(cfg2.Main && cfg2.Main.msno) || 1, 2);
    var defaultMS = parseInt(cfg2.Main && cfg2.Main.msno) || 1;

    // ── Helpers ───────────────────────────────────────────────────────────

    function findSub(topic) {
        for (var i = 0; i < subscriptions.length; i++) {
            if (subscriptions[i].Id === topic) return subscriptions[i];
        }
        return null;
    }

    function getOrCreateSub(topic) {
        var sub = findSub(topic);
        if (!sub) {
            sub = { Id: topic, Toms: [], Noncached: false, resetaftersend: false, Jsonexpand: false, Json: [] };
            subscriptions.push(sub);
        }
        return sub;
    }

    function removeSub(topic) {
        subscriptions = subscriptions.filter(function(s) { return s.Id !== topic; });
    }

    function findJsonField(sub, path) {
        var json = sub.Json || [];
        for (var i = 0; i < json.length; i++) {
            if (json[i].Id === path) return json[i];
        }
        return null;
    }

    function isTopicSubscribed(topic) {
        return findSub(topic) !== null;
    }

    function escHtml(str) {
        return String(str)
            .replace(/&/g,'&amp;').replace(/</g,'&lt;')
            .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
    }

    function pathLastSegment(path) {
        if (!path) return '';
        var parts = path.split('@@');
        return parts[parts.length - 1];
    }

    function countSubscribed(topics) {
        var n = 0;
        topics.forEach(function(t) { if (isTopicSubscribed(t.topic)) n++; });
        return n;
    }

    function countSubscribedUnder(sub, path) {
        var count = 0;
        var prefix = path + '@@';
        var json = sub ? (sub.Json || []) : [];
        for (var i = 0; i < json.length; i++) {
            if (json[i].Id === path || json[i].Id.indexOf(prefix) === 0) count++;
        }
        return count;
    }

    function wildcardToRegex(pattern) {
        var parts = pattern.split('/').map(function(p) {
            if (p === '#') return '.*';
            if (p === '+') return '[^/]+';
            return p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        });
        var re = '^' + parts.join('/');
        if (!pattern.endsWith('#')) re += '$';
        return new RegExp(re);
    }

    function getVisibleTopics() {
        var filterText = $("#topic_filter").val().trim();
        if (!filterText) return discoveredTopics;
        var isWildcard = filterText.indexOf('+') !== -1 || filterText.indexOf('#') !== -1;
        var filterRegex = isWildcard ? wildcardToRegex(filterText) : null;
        var filterLower = filterText.toLowerCase();
        return discoveredTopics.filter(function(t) {
            return isWildcard ? filterRegex.test(t.topic) : t.topic.toLowerCase().indexOf(filterLower) !== -1;
        });
    }

    // ── Auto-save ─────────────────────────────────────────────────────────

    function showSaveStatus(state) {
        var el = $("#save_status");
        if (state === 'pending') {
            el.text('Speichert…').css('color','var(--lb-gray-500,#888)');
        } else if (state === 'ok') {
            el.text('Gespeichert ✓').css('color','var(--lb-success,green)');
            setTimeout(function() { if (!isDirty) el.text(''); }, 3000);
        } else if (state === 'error') {
            el.text('Fehler beim Speichern ✗').css('color','var(--lb-danger,red)');
        }
    }

    function markDirty() {
        isDirty = true;
        showSaveStatus('pending');
        clearTimeout(saveTimer);
        saveTimer = setTimeout(doSave, 1500);
    }

    function doSave() {
        $.ajax({
            type: 'POST',
            url: 'ajax/ajax-mqtt.php?ajax=save_subscriptions',
            contentType: 'application/json; charset=UTF-8',
            data: JSON.stringify({ Subscriptions: subscriptions })
        })
        .done(function() {
            isDirty = false;
            showSaveStatus('ok');
        })
        .fail(function() {
            showSaveStatus('error');
            saveTimer = setTimeout(doSave, 3000);
        });
    }

    $(window).on('beforeunload', function() {
        if (isDirty) {
            clearTimeout(saveTimer);
            navigator.sendBeacon(
                'ajax/ajax-mqtt.php?ajax=save_subscriptions',
                new Blob([JSON.stringify({ Subscriptions: subscriptions })], { type: 'application/json' })
            );
        }
    });

    // ── Load then start discovery ─────────────────────────────────────────

    $.post('ajax/ajax-mqtt.php', { ajax: 'get_subscriptions' })
    .done(function(resp) {
        var data = typeof resp === 'string' ? JSON.parse(resp) : resp;
        subscriptions = data.Subscriptions || [];
    })
    .always(function() {
        startDiscovery();
    });

    // ── Render stubs (replaced in Task 3) ────────────────────────────────

    function renderTopics() {
        $("#topic_groups_container").html(
            '<div style="text-align:center;padding:40px;color:var(--lb-gray-500)">Lade Topics…</div>'
        );
    }

    function startDiscovery() { renderTopics(); }

});
</script>
```

- [ ] **Step 2: Verify in browser**

Open MQTT Gateway → Abonnements (V2 selected).
Open browser DevTools console:
```javascript
console.log('subscriptions:', subscriptions);
```
Expected: Array loaded from `subscriptions.json`.
The topic container shows "Lade Topics…" (stubs active, real rendering in Task 3).
No console errors.

- [ ] **Step 3: Commit**

```bash
git add templates/system/mqtt-gateway.html
git commit -m "feat(v2-ui): replace V2 subscriptions block - new data model, helpers, auto-save skeleton"
```

---

### Task 3: JS — `renderJsonTree`, `renderTopicRow`, `renderTopics`, event handlers, discovery

**Files:**
- Modify: `templates/system/mqtt-gateway.html` — replace the two render stubs and add all remaining functions

- [ ] **Step 1: Replace the two stubs with the full implementation**

Find and replace this block in the `<script>`:

```javascript
    // ── Render stubs (replaced in Task 3) ────────────────────────────────

    function renderTopics() {
        $("#topic_groups_container").html(
            '<div style="text-align:center;padding:40px;color:var(--lb-gray-500)">Lade Topics…</div>'
        );
    }

    function startDiscovery() { renderTopics(); }
```

With the complete implementation below. Paste everything between and including `// ── MS dropdowns` and the closing `});` of the outer `$(function() {`:

```javascript
    // ── MS dropdowns ──────────────────────────────────────────────────────

    function msCheckboxesHtml(topic, selectedMS) {
        var safeTopic  = escHtml(topic);
        var isDefault  = !selectedMS || selectedMS.length === 0;
        var label      = isDefault ? 'Standard'
                       : (selectedMS.length >= msCount ? 'Alle MS' : 'MS ' + selectedMS.join('+'));
        var html  = '<details class="mqttgw-ms-dropdown">';
        html += '<summary class="mqttgw-ms-summary">' + escHtml(label) + '</summary>';
        html += '<div class="mqttgw-ms-panel">';
        html += '<label class="mqttgw-ms-label mqttgw-ms-default"><input type="radio" class="ms-default-radio"'
             + ' data-topic="' + safeTopic + '"' + (isDefault ? ' checked' : '') + '> Standard (MS ' + defaultMS + ')</label>';
        html += '<hr style="margin:4px 0;border:none;border-top:1px solid var(--lb-gray-200)">';
        for (var i = 1; i <= msCount; i++) {
            var ck = !isDefault && selectedMS.indexOf(i) !== -1 ? ' checked' : '';
            html += '<label class="mqttgw-ms-label"><input type="checkbox" class="ms-checkbox"'
                 + ' data-topic="' + safeTopic + '" data-ms="' + i + '"' + ck + '> Miniserver ' + i + '</label>';
        }
        html += '</div></details>';
        return html;
    }

    function msFieldCheckboxesHtml(topic, path, selectedMS) {
        var safeTopic = escHtml(topic);
        var safePath  = escHtml(path);
        var isDefault = !selectedMS || selectedMS.length === 0;
        var label     = isDefault ? 'Standard'
                      : (selectedMS.length >= msCount ? 'Alle MS' : 'MS ' + selectedMS.join('+'));
        var html  = '<details class="mqttgw-ms-dropdown" style="display:inline-block">';
        html += '<summary class="mqttgw-ms-summary">' + escHtml(label) + '</summary>';
        html += '<div class="mqttgw-ms-panel">';
        html += '<label class="mqttgw-ms-label mqttgw-ms-default"><input type="radio" class="ms-field-default-radio"'
             + ' data-topic="' + safeTopic + '" data-path="' + safePath + '"' + (isDefault ? ' checked' : '')
             + '> Standard (MS ' + defaultMS + ')</label>';
        html += '<hr style="margin:4px 0;border:none;border-top:1px solid var(--lb-gray-200)">';
        for (var i = 1; i <= msCount; i++) {
            var ck = !isDefault && selectedMS.indexOf(i) !== -1 ? ' checked' : '';
            html += '<label class="mqttgw-ms-label"><input type="checkbox" class="ms-field-checkbox"'
                 + ' data-topic="' + safeTopic + '" data-path="' + safePath + '" data-ms="' + i + '"' + ck
                 + '> Miniserver ' + i + '</label>';
        }
        html += '</div></details>';
        return html;
    }

    // ── renderFieldOptions (per Json-field options row) ───────────────────

    function renderFieldOptions(topic, path, field) {
        var safeTopic = escHtml(topic);
        var safePath  = escHtml(path);
        var html  = '<span class="mqttgw-json-field-options" style="margin-left:8px">';
        html += '<label class="mqttgw-topic-option"><input type="checkbox" class="json-field-nocache"'
             + ' data-topic="' + safeTopic + '" data-path="' + safePath + '"'
             + (field.Noncached ? ' checked' : '') + '> No Cache</label>';
        html += '<label class="mqttgw-topic-option"><input type="checkbox" class="json-field-reset"'
             + ' data-topic="' + safeTopic + '" data-path="' + safePath + '"'
             + (field.resetaftersend ? ' checked' : '') + '> Reset</label>';
        if (msCount > 1) html += msFieldCheckboxesHtml(topic, path, field.Toms || []);
        html += '</span>';
        return html;
    }

    // ── renderJsonTree — fully recursive, unlimited depth ─────────────────
    // path uses @@ as separator: "key", "arr@@[0]", "arr@@[0]@@sub", "arr@@[0]@@[1]"

    function renderJsonTree(topic, value, path) {
        var sub       = findSub(topic);
        var safeTopic = escHtml(topic);
        var safePath  = escHtml(path);
        var segment   = escHtml(pathLastSegment(path));

        if (Array.isArray(value)) {
            var subCount = sub ? countSubscribedUnder(sub, path) : 0;
            var html  = '<details class="mqttgw-json-node mqttgw-json-array">';
            html += '<summary class="mqttgw-json-node-summary"><span class="mqttgw-json-key">'
                 + segment + '</span> <span class="mqttgw-json-meta">[Array, ' + value.length + ']</span>';
            if (subCount > 0) html += ' <span class="mqttgw-json-subcount">(' + subCount + ')</span>';
            html += '</summary><div class="mqttgw-json-node-content">';
            for (var i = 0; i < value.length; i++) {
                html += renderJsonTree(topic, value[i], path + '@@[' + i + ']');
            }
            html += '</div></details>';
            return html;

        } else if (value !== null && typeof value === 'object') {
            var keys     = Object.keys(value);
            var subCount = sub ? countSubscribedUnder(sub, path) : 0;
            var html  = '<details class="mqttgw-json-node mqttgw-json-object">';
            html += '<summary class="mqttgw-json-node-summary"><span class="mqttgw-json-key">'
                 + segment + '</span> <span class="mqttgw-json-meta">{Object, ' + keys.length + '}</span>';
            if (subCount > 0) html += ' <span class="mqttgw-json-subcount">(' + subCount + ')</span>';
            html += '</summary><div class="mqttgw-json-node-content">';
            for (var j = 0; j < keys.length; j++) {
                html += renderJsonTree(topic, value[keys[j]], path + '@@' + keys[j]);
            }
            html += '</div></details>';
            return html;

        } else {
            // Primitive leaf
            var field     = sub ? findJsonField(sub, path) : null;
            var isChecked = field !== null;
            var rawVal    = (value === null) ? 'null' : String(value);
            var dispVal   = escHtml(rawVal.length > 60 ? rawVal.substring(0, 60) + '…' : rawVal);
            var html  = '<div class="mqttgw-json-leaf' + (isChecked ? ' mqttgw-json-leaf-active' : '') + '">';
            html += '<label class="mqttgw-json-field">';
            html += '<input type="checkbox" class="json-field-subscribe"'
                 + ' data-topic="' + safeTopic + '" data-path="' + safePath + '"'
                 + (isChecked ? ' checked' : '') + '>';
            html += ' <span class="mqttgw-json-key">' + segment + '</span>';
            html += ' <span class="mqttgw-json-val">= ' + dispVal + '</span></label>';
            if (isChecked) html += renderFieldOptions(topic, path, field);
            html += '</div>';
            return html;
        }
    }

    // ── renderTopicRow ────────────────────────────────────────────────────

    function renderTopicRow(t, displayName) {
        var topic       = t.topic;
        var sub         = findSub(topic);
        var isSubscribed = sub !== null;
        var safeTopic   = escHtml(topic);
        var payload     = t.payload || '';

        var html  = '<div class="mqttgw-topic-row' + (isSubscribed ? '' : ' mqttgw-topic-row-disabled')
                  + '" data-topic="' + safeTopic + '">';
        html += '<input type="checkbox" class="topic-subscribe" data-topic="' + safeTopic + '"'
             + (isSubscribed ? ' checked' : '') + '>';
        html += '<span class="mqttgw-topic-name">' + escHtml(displayName) + '</span>';
        html += '<span class="mqttgw-topic-payload" title="' + escHtml(payload) + '">'
             + escHtml(payload.length > 80 ? payload.substring(0, 80) + '…' : payload) + '</span>';

        if (isSubscribed) {
            html += '<label class="mqttgw-topic-json-label"><input type="checkbox" class="topic-json-expand"'
                 + ' data-topic="' + safeTopic + '"' + (sub.Jsonexpand ? ' checked' : '') + '> JSON</label>';
            html += '<label class="mqttgw-topic-option"><input type="checkbox" class="topic-disable-cache"'
                 + ' data-topic="' + safeTopic + '"' + (sub.Noncached ? ' checked' : '') + '> No Cache</label>';
            html += '<label class="mqttgw-topic-option"><input type="checkbox" class="topic-reset-after-send"'
                 + ' data-topic="' + safeTopic + '"' + (sub.resetaftersend ? ' checked' : '') + '> Reset</label>';
            if (msCount > 1) html += msCheckboxesHtml(topic, sub.Toms || []);
        }
        html += '</div>';

        // JSON tree (only when subscribed + Jsonexpand + payload parses as object/array)
        if (isSubscribed && sub.Jsonexpand && payload) {
            try {
                var parsed = JSON.parse(payload);
                if (typeof parsed === 'object' && parsed !== null) {
                    html += '<div class="mqttgw-json-fields" data-parent="' + safeTopic + '">';
                    if (Array.isArray(parsed)) {
                        for (var i = 0; i < parsed.length; i++) {
                            html += renderJsonTree(topic, parsed[i], '[' + i + ']');
                        }
                    } else {
                        var keys = Object.keys(parsed);
                        for (var j = 0; j < keys.length; j++) {
                            html += renderJsonTree(topic, parsed[keys[j]], keys[j]);
                        }
                    }
                    html += '</div>';
                }
            } catch(e) {}
        }
        return html;
    }

    // ── Tree builder ──────────────────────────────────────────────────────

    function buildTree(topics, prefix) {
        var tree = { children: {}, topics: [] };
        topics.forEach(function(t) {
            var rest = t.topic.substring(prefix.length);
            if (rest.charAt(0) === '/') rest = rest.substring(1);
            var slashIdx = rest.indexOf('/');
            if (slashIdx === -1) {
                tree.topics.push({ topic: t, leafName: rest });
            } else {
                var seg = rest.substring(0, slashIdx);
                if (!tree.children[seg]) tree.children[seg] = [];
                tree.children[seg].push(t);
            }
        });
        return tree;
    }

    function subToggleAll(prefix, enable) {
        getVisibleTopics().forEach(function(t) {
            if (t.topic === prefix || t.topic.indexOf(prefix + '/') === 0) {
                if (enable) getOrCreateSub(t.topic);
                else removeSub(t.topic);
            }
        });
        markDirty();
        renderTopics();
    }

    function groupToggleAll(groupName, enable) {
        getVisibleTopics().forEach(function(t) {
            if ((t.group || t.topic.split('/')[0]) === groupName) {
                if (enable) getOrCreateSub(t.topic);
                else removeSub(t.topic);
            }
        });
        markDirty();
        renderTopics();
    }

    function renderTree(topics, prefix) {
        var tree = buildTree(topics, prefix);
        var html = '';
        Object.keys(tree.children).sort().forEach(function(seg) {
            var childTopics = tree.children[seg];
            var childPrefix = prefix + (prefix ? '/' : '') + seg;
            var childSubCount = countSubscribed(childTopics);
            var allChecked = childSubCount === childTopics.length && childSubCount > 0;
            var safePrefix = escHtml(childPrefix);
            html += '<details class="mqttgw-subgroup">';
            html += '<summary><input type="checkbox" class="sub-group-toggle"'
                 + ' data-prefix="' + safePrefix + '"' + (allChecked ? ' checked' : '')
                 + ' onclick="event.stopPropagation();subToggleAll(\'' + safePrefix + '\',this.checked)"'
                 + ' style="margin-right:6px"><strong>' + escHtml(seg) + '</strong>';
            html += '<span class="mqttgw-group-count">(' + childTopics.length + ' Topics, ' + childSubCount + ' abonniert)</span>';
            html += '</summary><div class="mqttgw-subgroup-content">';
            html += renderTree(childTopics, childPrefix);
            html += '</div></details>';
        });
        tree.topics.forEach(function(item) { html += renderTopicRow(item.topic, item.leafName); });
        return html;
    }

    // ── renderTopics ──────────────────────────────────────────────────────

    function renderTopics() {
        var groups = {};
        var subscribedOnly = $("#filter_subscribed_only").prop("checked");
        var visible = getVisibleTopics();
        var totalCount = 0, subCount = 0;

        visible.forEach(function(t) {
            var isSub = isTopicSubscribed(t.topic);
            if (subscribedOnly && !isSub) return;
            var gName = t.group || t.topic.split('/')[0];
            if (!groups[gName]) groups[gName] = { topics: [], subCount: 0 };
            groups[gName].topics.push(t);
            totalCount++;
            if (isSub) { groups[gName].subCount++; subCount++; }
        });

        $("#filter_count").text(subCount + " von " + totalCount + " abonniert");

        // Preserve open/closed state
        var openDetails = {};
        $("#topic_groups_container details[open]").each(function() {
            var key = $(this).find("> summary strong").first().text();
            if (key) openDetails[key] = true;
        });

        var html = '';
        Object.keys(groups).sort().forEach(function(gName) {
            var g = groups[gName];
            var allChecked = g.subCount === g.topics.length && g.subCount > 0;
            var safeGName = escHtml(gName);
            html += '<details class="lb-collapsible mqttgw-group"' + (g.subCount > 0 ? ' open' : '') + '>';
            html += '<summary><input type="checkbox" class="group-toggle"'
                 + ' data-group="' + safeGName + '"' + (allChecked ? ' checked' : '')
                 + ' onclick="event.stopPropagation();groupToggleAll(\'' + safeGName + '\',this.checked)"'
                 + ' style="margin-right:6px"><strong>' + safeGName + '</strong>';
            html += '<span class="mqttgw-group-count">(' + g.topics.length + ' Topics, ' + g.subCount + ' abonniert)</span>';
            html += '</summary><div class="lb-collapsible-content" style="padding:0">';
            html += renderTree(g.topics, gName);
            html += '</div></details>';
        });

        if (!html) html = '<div style="text-align:center;padding:40px;color:var(--lb-gray-500)">Keine Topics gefunden.</div>';

        $("#topic_groups_container").html(html);
        $("#topic_groups_container details").each(function() {
            var key = $(this).find("> summary strong").first().text();
            if (openDetails[key]) $(this).attr("open", "");
        });
    }

    // ── Event handlers ────────────────────────────────────────────────────

    // Topic subscribe / unsubscribe
    $(document).on('change', '.topic-subscribe', function() {
        var topic = $(this).data('topic');
        if ($(this).prop('checked')) getOrCreateSub(topic);
        else removeSub(topic);
        markDirty(); renderTopics();
    });

    // JSON expand toggle — clears Json fields on disable
    $(document).on('change', '.topic-json-expand', function() {
        var topic = $(this).data('topic');
        var sub   = getOrCreateSub(topic);
        sub.Jsonexpand = $(this).prop('checked');
        if (!sub.Jsonexpand) sub.Json = [];
        markDirty(); renderTopics();
    });

    $(document).on('change', '.topic-disable-cache', function() {
        var sub = getOrCreateSub($(this).data('topic'));
        sub.Noncached = $(this).prop('checked');
        markDirty();
    });

    $(document).on('change', '.topic-reset-after-send', function() {
        var sub = getOrCreateSub($(this).data('topic'));
        sub.resetaftersend = $(this).prop('checked');
        markDirty();
    });

    // Topic-level MS routing
    $(document).on('change', '.ms-default-radio', function() {
        var sub = getOrCreateSub($(this).data('topic'));
        sub.Toms = [];
        markDirty(); renderTopics();
    });

    $(document).on('change', '.ms-checkbox', function() {
        var topic = $(this).data('topic');
        var ms    = parseInt($(this).data('ms'));
        var sub   = getOrCreateSub(topic);
        var arr   = sub.Toms || [];
        if ($(this).prop('checked')) { if (arr.indexOf(ms) === -1) arr.push(ms); }
        else arr = arr.filter(function(x) { return x !== ms; });
        sub.Toms = arr.sort();
        markDirty(); renderTopics();
    });

    // Json field subscribe / unsubscribe
    $(document).on('change', '.json-field-subscribe', function() {
        var topic = $(this).data('topic');
        var path  = $(this).data('path');
        var sub   = getOrCreateSub(topic);
        if ($(this).prop('checked')) {
            if (!findJsonField(sub, path))
                sub.Json.push({ Id: path, Toms: [], Noncached: false, resetaftersend: false });
        } else {
            sub.Json = sub.Json.filter(function(f) { return f.Id !== path; });
        }
        markDirty(); renderTopics();
    });

    $(document).on('change', '.json-field-nocache', function() {
        var sub = findSub($(this).data('topic'));
        if (!sub) return;
        var field = findJsonField(sub, $(this).data('path'));
        if (field) { field.Noncached = $(this).prop('checked'); markDirty(); }
    });

    $(document).on('change', '.json-field-reset', function() {
        var sub = findSub($(this).data('topic'));
        if (!sub) return;
        var field = findJsonField(sub, $(this).data('path'));
        if (field) { field.resetaftersend = $(this).prop('checked'); markDirty(); }
    });

    // Json field MS routing
    $(document).on('change', '.ms-field-default-radio', function() {
        var sub = findSub($(this).data('topic'));
        if (!sub) return;
        var field = findJsonField(sub, $(this).data('path'));
        if (field) { field.Toms = []; markDirty(); renderTopics(); }
    });

    $(document).on('change', '.ms-field-checkbox', function() {
        var sub = findSub($(this).data('topic'));
        if (!sub) return;
        var field = findJsonField(sub, $(this).data('path'));
        if (!field) return;
        var ms  = parseInt($(this).data('ms'));
        var arr = field.Toms || [];
        if ($(this).prop('checked')) { if (arr.indexOf(ms) === -1) arr.push(ms); }
        else arr = arr.filter(function(x) { return x !== ms; });
        field.Toms = arr.sort();
        markDirty(); renderTopics();
    });

    // Filter
    $("#topic_filter").on("input", renderTopics);
    $("#filter_subscribed_only").on("change", renderTopics);

    $("#btn_filter_select_all").on("click", function() {
        getVisibleTopics().forEach(function(t) { getOrCreateSub(t.topic); });
        markDirty(); renderTopics();
    });

    $("#btn_filter_deselect_all").on("click", function() {
        getVisibleTopics().forEach(function(t) { removeSub(t.topic); });
        markDirty(); renderTopics();
    });

    // ── Discovery ─────────────────────────────────────────────────────────

    var discoveryRunning = false;
    var lastDiscoveryTime = 0;

    function updateAgo() {
        if (!lastDiscoveryTime) return;
        var secs = Math.round((Date.now() - lastDiscoveryTime) / 1000);
        $("#discovery_ago").text(secs < 5 ? "gerade eben" : "vor " + secs + "s");
    }
    setInterval(updateAgo, 5000);

    function runDiscovery() {
        if (discoveryRunning) return;
        discoveryRunning = true;
        $("#discovery_pulse").addClass("mqttgw-pulse");

        $.post('ajax/ajax-mqtt.php', { ajax: 'getmqttfinderdata' })
        .done(function(resp) {
            var data = typeof resp === 'string' ? JSON.parse(resp) : resp;
            var topics = [];
            if (data && data.topics) {
                data.topics.forEach(function(t) {
                    topics.push({ topic: t.topic, payload: t.payload || '', group: t.topic.split('/')[0] });
                });
            }
            lastDiscoveryTime = Date.now();
            discoveredTopics = topics;
            $("#discovery_count").text(topics.length);
            renderTopics();
        })
        .always(function() {
            discoveryRunning = false;
            $("#discovery_pulse").removeClass("mqttgw-pulse");
            updateAgo();
        });
    }

    function startDiscovery() {
        runDiscovery();
        setInterval(runDiscovery, 30000);
    }

    $("#btn_discovery_refresh").on("click", function() {
        lastDiscoveryTime = 0;
        runDiscovery();
    });

});
</script>
```

- [ ] **Step 2: Verify `renderJsonTree` in browser console with test data**

Open browser console on the Abonnements tab:
```javascript
var testPayload = {
    "name": "Max",
    "rollen": ["admin", {"rolle": "auditor", "rechte": ["read","export"]}],
    "einstellungen": {"newsletter": false, "favoriten": ["dashboard","reports"]}
};
var html = '';
Object.keys(testPayload).forEach(function(k) {
    html += renderJsonTree('test/topic', testPayload[k], k);
});
$('#topic_groups_container').html(html);
```
Expected: collapsible tree showing:
- `name` = Max (leaf, checkable)
- `rollen` [Array, 2] → `[0]` = admin, `[1]` {Object} → `rolle` = auditor, `rechte` [Array, 2] → `[0]` = read, `[1]` = export
- `einstellungen` {Object} → `newsletter` = false, `favoriten` [Array, 2] → `[0]` = dashboard

- [ ] **Step 3: Verify full subscription flow**

1. Reload page (Gateway V2, Abonnements tab)
2. Wait for broker topics to load — `mqttgateway2_test/data` appears
3. Check topic checkbox → `isTopicSubscribed('mqttgateway2_test/data')` returns `true` in console
4. Check JSON checkbox → payload expands recursively
5. Expand `rollen` → `[3]` → check `rolle` checkbox
6. Browser console:
```javascript
var sub = findSub('mqttgateway2_test/data');
console.log(sub.Json);
```
Expected: `[{Id: "rollen@@[3]@@rolle", Toms: [], Noncached: false, resetaftersend: false}]`
7. Wait 2 s → `showSaveStatus` shows "Gespeichert ✓"

- [ ] **Step 4: Commit**

```bash
git add templates/system/mqtt-gateway.html
git commit -m "feat(v2-ui): full renderJsonTree recursive + renderTopicRow + event handlers + discovery"
```

---

### Task 4: Integration test, V1 verification, push

**Files:** no code changes

- [ ] **Step 1: Verify subscriptions.json is written correctly**

On LoxBerry after subscribing some topics via the UI:
```bash
cat $LBHOMEDIR/config/system/subscriptions.json | python3 -m json.tool
```
Expected structure:
```json
{
    "Subscriptions": [
        {
            "Id": "mqttgateway2_test/data",
            "Toms": [],
            "Noncached": false,
            "resetaftersend": false,
            "Jsonexpand": true,
            "Json": [
                { "Id": "rollen@@[3]@@rolle", "Toms": [], "Noncached": false, "resetaftersend": false }
            ]
        }
    ]
}
```

- [ ] **Step 2: Verify mqtt_gateway.py picks up changes**

```bash
tail -f $LBSTMPFSLOGDIR/mqtt-gateway.log
```
Within 5 s of saving: expected log line `Config reloaded` and `Subscribed: mqttgateway2_test/data`.

- [ ] **Step 3: Verify beforeunload saves on tab close**

1. Subscribe to a new topic
2. Immediately close/navigate away from the Abonnements tab (before 1.5 s debounce fires)
3. Return to the tab
```bash
cat $LBHOMEDIR/config/system/subscriptions.json
```
Expected: the new subscription is present (sendBeacon fired on unload).

- [ ] **Step 4: Verify V1 is completely unaffected**

1. Switch WebUI to Gateway V1 (Abonnements tab)
2. Verify V1 textarea is shown (not tree UI)
3. Add a test subscription in the V1 textarea, save
4. Check `mqttgateway.json` is updated, `subscriptions.json` is unchanged:
```bash
grep -c "subscriptions" $LBHOMEDIR/config/system/mqttgateway.json
cat $LBHOMEDIR/config/system/subscriptions.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['Subscriptions']), 'subs')"
```
Expected: `mqttgateway.json` changed, subscription count in `subscriptions.json` unchanged.

- [ ] **Step 5: Push to GitHub**

```bash
git push origin master
```

---

## Self-Review Notes

**Spec coverage:**
- ✅ Deep JSON expansion (unlimited): `renderJsonTree` handles objects, arrays, arrays-of-arrays recursively
- ✅ `@@` path notation: built in `renderJsonTree` and stored in `sub.Json[].Id`
- ✅ Single storage via `subscriptions.json`: PHP endpoints + JS load/save
- ✅ Auto-save 1.5 s debounce: `markDirty()` / `doSave()`
- ✅ `beforeunload` fallback: `navigator.sendBeacon`
- ✅ V1 untouched: new endpoints only touch `subscriptions.json`; V1 textarea block unchanged
- ✅ Visual save status: `#save_status` span in discovery bar

**No placeholders:** all code is complete in each step.

**Type consistency:** `sub.Toms` (Array of int), `field.Toms` (Array of int), `sub.Noncached` (bool), `sub.resetaftersend` (bool), `sub.Jsonexpand` (bool), `sub.Json` (Array), `field.Id` (string with `@@`) — consistent throughout.
