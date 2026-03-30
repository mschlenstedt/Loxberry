# MQTT Gateway V2 — WebUI Design Spec

**Date:** 2026-03-30
**Author:** Philipp (strike1988), designed with Claude
**Context:** Michael Schlenstedt's proposal for LoxBerry 4 MQTT Gateway V2
**Scope:** WebUI only — independent of gateway backend implementation

---

## 1. Overview

LoxBerry 4 introduces a new MQTT Gateway V2 (Max. Performance) alongside the existing V1 (Max. Compatibility). The WebUI must support both versions with conditional tab content, while the V2 subscription model shifts from global topic subscriptions to an explicit Opt-In approach per payload.

### Key Principles

- **Opt-In statt Opt-Out:** V2 subscribes only to explicitly selected topics
- **Discovery-based:** Topics are found via a temporary scan, not permanently subscribed
- **Backward compatible:** V1 UI remains fully functional, V2 extends it
- **Backend-unabhaengig:** WebUI can be built and tested before the V2 backend exists

## 2. Architecture

### Approach: Inline-Migration

The existing `templates/system/mqtt-gateway.html` is extended with V1/V2 conditional blocks. No separate template files.

- Template variable `GATEWAY_VERSION` (from `general.json`) controls which UI variant is shown
- Existing `FORM_*` pattern is preserved for tab switching
- New V2 sections use `lb-*` design system classes
- V1 sections remain unchanged

### Configuration Storage

| Setting | File | Key |
|---------|------|-----|
| Gateway Version (1/2) | `general.json` | `Mqtt.GatewayVersion` |
| V2 Subscriptions | `mqttgateway.json` | `subscriptions_v2[]` |
| V2 JSON Expand per topic | `mqttgateway.json` | `subscriptions_v2[].json_expand` |
| V2 JSON field selection | `mqttgateway.json` | `subscriptions_v2[].json_fields[]` |
| V2 Miniserver per topic | `mqttgateway.json` | `subscriptions_v2[].toMS[]` |
| All other settings | `mqttgateway.json` | Unchanged from V1 |

**Default behavior:**
- Existing installations: `GatewayVersion` absent or `1` → V1
- New installations: `GatewayVersion: 2` → V2

### V2 Subscription Data Structure

```json
{
  "subscriptions_v2": [
    {
      "topic": "zigbee2mqtt/wohnzimmer/temperatur",
      "enabled": true,
      "json_expand": true,
      "json_fields": [
        { "key": "temperature", "enabled": true },
        { "key": "humidity", "enabled": false }
      ],
      "toMS": [1, 2]
    },
    {
      "topic": "zigbee2mqtt/wohnzimmer/licht",
      "enabled": true,
      "json_expand": false,
      "json_fields": [],
      "toMS": [1]
    }
  ]
}
```

## 3. Tab Structure

### Tab Order (V2 active)

| # | Tab | V1 | V2 | Changes for V2 |
|---|-----|----|----|-----------------|
| 1 | **MQTT Basic** | new | new | Gateway Version toggle, Status indicator, Miniserver config |
| 2 | **Abonnements** | existing (textarea) | new (topic browser) | Completely different UI per version |
| 3 | **Incoming** | existing | existing | V2 hides "Do not forward" column |
| 4 | **Settings** | existing (was "Settings" tab) | existing | Subscription Filters marked "V1 only" |
| 5 | **Transformers** | existing | existing | Unchanged, plus zigbee_led as shipped |
| 6 | **Logs** | existing | existing | Unchanged |

## 4. Tab Designs

### 4.1 MQTT Basic (NEW)

This tab replaces the top of the old Settings tab. It contains the gateway version selection and base configuration.

**Components:**

1. **Live Status Indicator** (top of page)
   - Green: "Gateway laeuft — Verbunden mit Broker (host:port)" + Uptime
   - Yellow: "Gateway laeuft — Broker nicht erreichbar"
   - Red: "Gateway gestoppt"
   - Data source: existing AJAX endpoint `getpids` + broker connection check

2. **Gateway Version Selection**
   - `lb-btn-group` with two options: "V1 — Max. Kompatibilitaet" / "V2 — Max. Performance"
   - Active version highlighted (primary color)
   - Warning box appears on version change: "Bei Wechsel von V1 auf V2 muessen Topics im Tab Abonnements explizit ausgewaehlt werden. Bestehende Subscriptions werden als Vorauswahl uebernommen."

3. **Miniserver Data Routing**
   - Standard Miniserver: dropdown of configured Miniservers
   - Protocol: `lb-btn-group` with HTTP / UDP / Both

4. **Action buttons:** Cancel / Save

### 4.2 Abonnements — V1 Mode

Unchanged from current implementation:
- Textarea with one topic per line (pipe syntax for MS routing)
- Subscription filters (RegEx)
- External plugin subscriptions (collapsible)

### 4.3 Abonnements — V2 Mode (NEW — Core Feature)

Completely new Opt-In topic browser.

**Components:**

1. **Discovery Bar**
   - Button: "Topics entdecken" — triggers temporary `#` subscription for 10 seconds
   - Shows: last scan timestamp, number of topics found
   - AJAX endpoint: new `discover_topics` action → returns JSON with all found topics
   - Discovery results cached in `/dev/shm/mqttgateway_discovery.json`

2. **Filter Bar**
   - Text input: filters topics by substring match
   - Checkbox: "Nur abonnierte" — hides unsubscribed topics
   - Counter: "X von Y abonniert"

3. **Topic Groups** (Hybrid layout using `<details>` / `lb-collapsible`)
   - Grouped by first topic segment (e.g., `zigbee2mqtt`, `shellies`, `homeassistant`)
   - Group header shows: name, badge "subscribed / total" (green if >0, gray if 0)
   - "Alle an" / "Alle aus" buttons per group
   - Groups collapsed by default, except groups with active subscriptions

4. **Topic Row** (per topic within a group)
   - Checkbox: Subscribe yes/no
   - Topic name (monospace, without group prefix)
   - Last payload value (truncated, gray)
   - JSON Toggle: checkbox to enable JSON expansion
   - MS Dropdown: compact select showing "MS 1", "MS 2", "MS 1+2", or "Standard"
   - Unsubscribed topics: opacity 0.6, MS dropdown disabled

5. **JSON Expand Sub-rows** (shown when JSON toggle is active)
   - Green background (`#f7fbf2`)
   - Indented under parent topic
   - Per JSON key: checkbox (subscribe), key name (monospace, green), value, type indicator
   - Each key individually subscribable

6. **Action buttons:** Cancel / "Speichern & Anwenden"

**V1 → V2 Migration:**
When switching from V1 to V2, existing V1 subscriptions are pre-selected in the V2 topic browser as initial selection. User can then refine.

### 4.4 Incoming Overview

Identical to V1 with one difference:

- **V2 hides:** "Do not forward" checkbox column (not needed — only subscribed topics arrive)
- **V2 shows:** Info text explaining why "Do not forward" is absent
- HTTP Virtual Inputs table: Topic, Value, Status (200/404/500), Disable Cache, Reset-after-Send
- UDP Transmissions table: same structure
- Filter buttons: All, 200, 404, 500
- Auto-refresh behavior unchanged

### 4.5 Settings (Erweiterte Einstellungen)

Moved from being the first tab to position 4. Contains advanced settings shared between V1 and V2.

**Sections:**

1. **Datenverarbeitung**
   - Boolean-Konvertierung: `lb-toggle` (true/false → 1/0)
   - CPU-Profil: `lb-select` (1%, 2.5%, 5%, 10%, 50%)
   - Reset-After-Send: number input (ms)

2. **Conversions (Text → Wert)**
   - Textarea with `text=value` format (one per line)
   - Unchanged from current implementation

3. **Subscription Filters (V1 only)**
   - When V2 active: grayed out with info text "Nur bei Gateway V1 relevant. Bei V2 werden Topics direkt im Abonnements-Tab ausgewaehlt."
   - When V1 active: RegEx textarea as today

### 4.6 Transformers

Position moved from 5 to near the end (more "background" per user request).

**Changes:**
- `zigbee_led` added as **shipped** transformer (currently custom by Andreas Ranalder)
- Transformer table: Type (shipped purple / custom blue), Name, Description
- Syntax helper as `lb-collapsible` at the bottom
- No structural changes otherwise

### 4.7 Logs

Unchanged. MQTT Gateway logfile viewer + Mosquitto logfile reference.

## 5. Gateway Control

Existing control buttons (Reconnect, Restart Gateway) remain in the UI. The backend transition from filesystem-watching to MQTT topic control is transparent to the WebUI.

**Preparation for MQTT control:**
- AJAX endpoints (`reconnect`, `restartgateway`) remain as the WebUI interface
- Backend implementation behind these endpoints can switch from file-ops to MQTT publishing without UI changes
- The Live Status Indicator (Section 4.1) provides visibility into gateway state

## 6. AJAX Endpoints

### Existing (unchanged)
- `relayed_topics` — live topic data for Incoming Overview
- `disablecache` — toggle caching per topic
- `resetAfterSend` — toggle reset per topic
- `getpids` — process status
- `reconnect` — force reconnect
- `restartgateway` — restart daemon

### New for V2
- `discover_topics` — triggers 10-second `#` scan, returns all discovered topics with last payload
- `save_subscriptions_v2` — saves V2 subscription config to `mqttgateway.json`
- `get_subscriptions_v2` — reads current V2 subscription state

### Removed for V2
- `doNotForward` — not needed in Opt-In model

## 7. Design System Usage

All new V2 components use the `lb-*` design system:

| Component | Class |
|-----------|-------|
| Version toggle | `lb-btn-group` |
| Form layout | `lb-form-row`, `lb-form-label`, `lb-form-field`, `lb-form-help` |
| Section headers | `lb-section-title` |
| Topic groups | `lb-collapsible` (`<details>`) |
| Toggles | `lb-toggle` |
| Inputs | `lb-input`, `lb-select`, `lb-textarea` |
| Buttons | `lb-btn`, `lb-btn-primary`, `lb-btn-sm` |
| Action bar | `lb-actions` |

Theme support (classic/dark/modern) is automatic through CSS custom properties.

## 8. Migration Path

1. **Phase 1 (this spec):** Build V2 WebUI with mock data / discovery endpoint
2. **Phase 2 (backend):** Implement V2 gateway logic (separate effort, possibly Python)
3. **Phase 3 (integration):** Connect WebUI to real V2 backend
4. **Phase 4 (deprecation):** Eventually remove V1 UI code when V1 is sunset

The WebUI can be fully developed and tested in Phase 1 using simulated discovery data.

## 9. Out of Scope

- Gateway backend implementation (Perl/Python/PHP decision)
- MQTT broker configuration changes
- Plugin API changes
- Mobile app / API endpoints
- Programmiersprache des Gateways (team decision pending)
