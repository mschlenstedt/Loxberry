# MQTT Gateway V2 — Subscriptions WebUI Redesign

**Datum:** 2026-04-30  
**Status:** Approved  

---

## Ziel

Das WebUI für MQTT Gateway V2 (Abonnements-Tab) wird in drei Bereichen erweitert:

1. **Vollrekursiver JSON-Baum** — Arrays und Objekte beliebiger Tiefe aufklappbar, inkl. Arrays-von-Arrays
2. **Einheitliches Datenmodell** — JS und PHP arbeiten direkt mit `subscriptions.json`; das bisherige `subscriptions_v2`-Format in `mqttgateway.json` entfällt für V2
3. **Auto-Save ohne Button** — Änderungen werden nach 1,5 s Debounce automatisch gespeichert; kein expliziter Save-Button mehr

**V1 (`mqttgateway.pl`) wird in keiner Zeile angefasst.**

---

## Abgrenzung V1 / V2

| | V1 | V2 |
|---|---|---|
| Gateway-Prozess | `mqttgateway.pl` | `mqtt_gateway.py` |
| Subscription-Datei | `mqttgateway.json` → `cfg.subscriptions` | `subscriptions.json` → `Subscriptions` |
| WebUI-Form | Textarea (bleibt unverändert) | Baumansicht (wird neu gebaut) |
| PHP-Endpoints | bestehende V1-Logik (unangetastet) | neue `get_subscriptions` / `save_subscriptions` |

---

## 1. Datenmodell

### In-Memory (JS)

Die Variable `subscriptions` (Array) spiegelt `subscriptions.json` 1:1:

```javascript
var subscriptions = [
  {
    Id:             "mqttgateway2_test/data",
    Toms:           [],          // per-MS-Routing, Array von Strings ("1", "2", ...)
    Noncached:      false,       // Cache deaktivieren
    resetaftersend: false,       // Wert nach Senden zurücksetzen
    Jsonexpand:     true,        // JSON-Payload expandieren
    Json: [
      { Id: "name",               Toms: [], Noncached: false, resetaftersend: false },
      { Id: "rollen@@[3]@@rolle", Toms: [], Noncached: false, resetaftersend: false }
    ]
  }
];
```

Hilfsfunktionen:

| Funktion | Beschreibung |
|---|---|
| `findSub(topic)` | Gibt Subscription-Eintrag zurück oder `null` |
| `getOrCreateSub(topic)` | Legt Eintrag mit Defaults an falls nicht vorhanden |
| `removeSub(topic)` | Entfernt Eintrag aus Array |
| `findJsonField(sub, path)` | Findet Json-Eintrag by `@@`-Pfad |
| `isTopicSubscribed(topic)` | Boolean — Topic im Array vorhanden |

### subscriptions.json Format

```json
{
  "Subscriptions": [
    {
      "Id": "mqttgateway2_test/irgendeinwert",
      "Toms": [],
      "Noncached": false,
      "resetaftersend": false,
      "Jsonexpand": false,
      "Json": []
    },
    {
      "Id": "mqttgateway2_test/data",
      "Toms": [],
      "Noncached": false,
      "resetaftersend": false,
      "Jsonexpand": true,
      "Json": [
        { "Id": "name",                         "Toms": [], "Noncached": false, "resetaftersend": false },
        { "Id": "rollen@@[0]",                  "Toms": [], "Noncached": false, "resetaftersend": false },
        { "Id": "rollen@@[3]@@rolle",           "Toms": [], "Noncached": false, "resetaftersend": false },
        { "Id": "rollen@@[3]@@rechte@@[0]",     "Toms": [], "Noncached": false, "resetaftersend": false },
        { "Id": "einstellungen@@newsletter",    "Toms": [], "Noncached": false, "resetaftersend": false }
      ]
    }
  ]
}
```

---

## 2. Vollrekursiver JSON-Baum

### Pfadbau-Regeln (`@@` als Trennzeichen)

| Struktur | Beispiel-Pfad |
|---|---|
| Root-Property | `name` |
| Array-Element (Primitiv) | `rollen@@[0]` |
| Objekt-Property in Array | `rollen@@[3]@@rolle` |
| Array in Array | `einstellungen@@benachrichtigungen@@kanäle@@priorität@@regeln@@ruhezeiten@@[0]@@[0]` |
| Objekt-Property tief verschachtelt | `adressen@@[0]@@geo@@lat` |

### Render-Logik

```
renderJsonTree(topic, value, path):
  if Primitiv (string/number/bool/null):
    → Leaf: Checkbox mit data-path=path
    → checked wenn findJsonField(sub, path) != null
    → Optionen: Noncached, resetaftersend, Toms (per-MS)
  
  if Objekt:
    → <details> mit Zusammenfassung: Pfad-Segment, Anzahl Properties, Anzahl subscribed
    → rekursiert: renderJsonTree(topic, obj[key], path + "@@" + key)
  
  if Array:
    → <details> mit Zusammenfassung: Pfad-Segment, Länge, Anzahl subscribed
    → rekursiert: renderJsonTree(topic, arr[i], path + "@@[" + i + "]")
    → gilt auch für Array-Elemente die selbst Arrays sind
```

### Checkbox-Interaktion

- **Aktivieren:** `getOrCreateSub(topic)`, dann Json-Eintrag hinzufügen → `markDirty()`
- **Deaktivieren:** Json-Eintrag entfernen; wenn `Json` leer und `Jsonexpand=false` → prüfen ob Topic-Eintrag entfernt werden soll
- **Topic-Checkbox (oberste Ebene):** steuert `isTopicSubscribed`; bei Deaktivierung werden alle Json-Felder entfernt
- **JSON-Expand-Checkbox:** steuert `Jsonexpand`; bei Deaktivierung werden alle Json-Felder entfernt

---

## 3. Auto-Save

### Ablauf

```
Änderung an subscriptions[]
  → markDirty()
      → isDirty = true
      → clearTimeout(saveTimer)
      → saveTimer = setTimeout(saveSubscriptions, 1500)

saveSubscriptions()
  → POST ajax-mqtt.php?ajax=save_subscriptions
  → body: { "Subscriptions": [...] }
  → Erfolg: isDirty = false, Status "Gespeichert ✓" (verschwindet nach 3s)
  → Fehler: Status "Fehler ✗", Timer erneut ansetzen (retry nach 3s)

window.beforeunload
  → wenn isDirty: navigator.sendBeacon('ajax/ajax-mqtt.php?ajax=save_subscriptions', JSON)
```

### Visuelles Feedback

Kleines Status-Label neben dem Discovery-Statusbar:
- `""` — Standardzustand
- `"Speichert…"` — während pending
- `"Gespeichert ✓"` — nach Erfolg, verschwindet nach 3s
- `"Fehler beim Speichern ✗"` — persistent bis zum nächsten erfolgreichen Save

Kein Modal, kein Blocking, kein Reload des Gateways (der Config-Watcher von `mqtt_gateway.py` lädt `subscriptions.json` automatisch alle 5s bei mtime-Änderung).

---

## 4. PHP-Endpoints (ajax-mqtt.php)

### Neu: `get_subscriptions`

```
GET/POST ajax-mqtt.php?ajax=get_subscriptions
→ liest LBSCONFIGDIR/subscriptions.json
→ gibt { "Subscriptions": [...] } zurück
→ gibt { "Subscriptions": [] } wenn Datei nicht existiert
```

### Neu: `save_subscriptions`

```
POST ajax-mqtt.php?ajax=save_subscriptions
→ body: { "Subscriptions": [...] }
→ öffnet subscriptions.json mit LOCK_EX
→ schreibt JSON (pretty-print, UTF-8, unescaped slashes/unicode)
→ gibt { "status": "ok", "count": N } zurück
→ gibt HTTP 400 bei fehlendem Body
→ gibt HTTP 500 bei Schreibfehler
```

### Bestehende Endpoints

`get_subscriptions_v2` und `save_subscriptions_v2` bleiben im Code (kein Breaking Change), werden aber vom V2-UI nicht mehr aufgerufen.

---

## 5. Geänderte Dateien

| Datei | Änderung |
|---|---|
| `templates/system/mqtt-gateway.html` | Nur der V2-Bereich innerhalb `FORM_SUBSCRIPTIONS` (`<TMPL_IF GATEWAY_V2>`-Block) wird neu geschrieben: Datenmodell, `renderJsonTree()`, Auto-Save, neuer Endpoint-Aufruf. Der V1-Textarea-Block (`<TMPL_UNLESS GATEWAY_V2>`) bleibt unverändert. |
| `webfrontend/htmlauth/system/ajax/ajax-mqtt.php` | Zwei neue Endpoints `get_subscriptions` / `save_subscriptions` |

## 6. Unveränderte Dateien

- `sbin/mqtt_gateway.py` — liest `subscriptions.json` bereits korrekt, kein Änderungsbedarf
- `sbin/mqttgateway.pl` — V1, keine Änderung
- `sbin/mqtt-handler.pl` — keine Änderung
- Alle V1-UI-Teile in `mqtt-gateway.html` — keine Änderung
- `config/system/subscriptions.json` — Laufzeitdaten, nicht im Code

---

## 7. Nicht im Scope

- Design/Styling-Änderungen am UI (bestehende CSS-Klassen bleiben)
- Änderungen an der Topic-Discovery-Logik
- Änderungen am V1-Subscriptions-UI (Textarea)
- Migration bestehender `subscriptions_v2`-Daten (kein Migrationspfad nötig, da `subscriptions.json` bereits manuell befüllt wurde)
