# pagestart.html Sidebar-Umbau — Design Spec

## Ziel

Die jQuery Mobile Panel-Struktur in pagestart.html durch eine CSS-basierte Sidebar-Navigation ersetzen. Plugins-First Sidebar links, Content rechts, responsive Overlay auf Mobile. Bestehende Vue3-Navbar wird als Sidebar-Navigation wiederverwendet.

## Architektur

### HTML-Struktur (neu)

```html
<body class="theme-{name}">
  <div class="lb-layout">
    <!-- Sidebar (links) -->
    <aside class="lb-sidebar" id="lb-sidebar">
      <div class="lb-sidebar-header">
        <div class="lb-sidebar-logo">L</div>
        <div>
          <div class="lb-sidebar-brand"><span>Lox</span>Berry</div>
          <div class="lb-sidebar-version">v{VERSION}</div>
        </div>
      </div>
      <nav class="lb-sidebar-nav" id="vuesidebar">
        <!-- Vue3 rendert Plugins + System + Tools -->
      </nav>
      <div class="lb-sidebar-footer">
        <span class="lb-sidebar-uptime">Up {UPTIME}</span>
      </div>
    </aside>

    <!-- Sidebar Backdrop (nur mobile) -->
    <div class="lb-sidebar-backdrop" id="lb-sidebar-backdrop"></div>

    <!-- Help Panel (rechts, overlay) -->
    <aside class="lb-helppanel" id="helppanel">
      <div class="lb-helppanel-header">
        <h2>{TITLE_HELP}</h2>
        <button class="lb-helppanel-close" id="btn-helppanel-close">&times;</button>
      </div>
      <div class="lb-helppanel-content">
        <p><a href="{HELPLINK}" target="blank">{TITLE_HELPLINK}</a></p>
        {HELPTEXT}
      </div>
    </aside>

    <!-- Main Content -->
    <div class="lb-main">
      <header class="lb-header">
        <div class="lb-header-left">
          <button class="lb-sidebar-toggle" id="btn-sidebar-toggle">
            <i class="pi pi-bars"></i>
          </button>
          <a href="/admin/system/index.cgi" class="lb-header-home">
            <i class="pi pi-home"></i>
          </a>
        </div>
        <h1 class="lb-header-title">{TEMPLATETITLE}</h1>
        <div class="lb-header-actions">
          <div id="update_alert" class="lb-header-update" style="display:none;"></div>
          <a id="btnnotifies" href="/admin/system/tools/showallnotifications.cgi"
             class="lb-header-btn pi pi-bell"></a>
          <a id="btninfo" href="#" class="lb-header-btn pi pi-question-circle"
             onclick="toggleHelpPanel(); return false;"></a>
          <a id="btnpower" href="/admin/system/power.cgi"
             class="lb-header-btn pi pi-power-off"></a>
        </div>
      </header>

      <!-- Vue Navbar (Plugin-Tabs, bleibt fuer Submenu-Navigation) -->
      <div id="vuenavbar" :key="componentKey">
        <!-- Bestehende horizontale Tabs fuer Submenus innerhalb einer Seite -->
      </div>

      <div id="page_content" class="lb-content page_content">
        <!-- Seiteninhalt (pagestart.html ENDE, pageend.html ANFANG) -->
      </div>

      <footer class="lb-footer">
        <a href="/admin/system/index.cgi">
          <img src="/system/images/icons/main_myloxberry.svg" class="lb-footer-logo">
        </a>
      </footer>
    </div>
  </div>

  <!-- Reboot-Force Dialog (ersetzt jQuery Mobile popup) -->
  <dialog class="lb-modal" id="popupRebootForce">
    <div class="lb-modal-header">
      <h2>{POWER.FORCEREBOOT_HEADER}</h2>
    </div>
    <div class="lb-modal-content">
      <img src="/system/images/reboot_required_big.svg">
      <p><b>{POWER.FORCEREBOOT_CONTENT}</b></p>
      <p id="popupRebootForceReason"></p>
      <p>{POWER.FORCEREBOOT_APOLOGY}</p>
      <a class="lb-btn lb-btn-sm lb-btn-icon" href="/admin/system/power.cgi">
        <i class="pi pi-power-off"></i> {HEADER.PANEL_REBOOT}
      </a>
    </div>
  </dialog>
</body>
```

### CSS-Klassen (neu in components.css)

#### Layout
- `.lb-layout` — `display: grid; grid-template-columns: 250px 1fr; min-height: 100vh;`
- `.lb-main` — `display: flex; flex-direction: column; min-height: 100vh; overflow-x: hidden;`

#### Sidebar
- `.lb-sidebar` — `position: fixed; top: 0; left: 0; bottom: 0; width: 250px; background: var(--lb-sidebar-bg); color: var(--lb-sidebar-text); display: flex; flex-direction: column; overflow-y: auto; z-index: 1000;`
- `.lb-sidebar-header` — Logo + Branding, `display: flex; align-items: center; gap: 10px; padding: 16px 18px; border-bottom: 1px solid var(--lb-sidebar-border);`
- `.lb-sidebar-logo` — 36x36px Box mit `background: var(--lb-primary); border-radius: var(--lb-radius-sm);`
- `.lb-sidebar-brand` — `font-weight: 700;` mit gruener Akzentfarbe auf "Lox"
- `.lb-sidebar-version` — Klein, muted
- `.lb-sidebar-nav` — `flex: 1; overflow-y: auto; padding: 6px 0;`
- `.lb-sidebar-section` — Abschnitts-Header, `text-transform: uppercase; letter-spacing: 1.5px; font-size: 10px; color: var(--lb-sidebar-section); padding: 16px 18px 6px;`
- `.lb-sidebar-link` — Navigationslink, `display: flex; align-items: center; gap: 10px; padding: 8px 18px 8px 21px; font-size: 12px; color: var(--lb-sidebar-text); text-decoration: none;`
- `.lb-sidebar-link.active` — `background: var(--lb-sidebar-active-bg); color: var(--lb-sidebar-active-text); border-left: 3px solid var(--lb-primary);`
- `.lb-sidebar-status` — Status-Dot, `width: 7px; height: 7px; border-radius: 50%; background: var(--lb-primary);`
- `.lb-sidebar-footer` — `padding: 10px 18px; border-top: 1px solid var(--lb-sidebar-border);`
- `.lb-sidebar-backdrop` — `display: none; position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 999;`
- `.lb-sidebar-toggle` — Hamburger-Button, nur auf Mobile sichtbar

#### Header
- `.lb-header` — `display: flex; align-items: center; padding: 10px 24px; background: var(--lb-card-bg); border-bottom: 1px solid var(--lb-border-color);`
- `.lb-header-title` — `flex: 1; font-size: 18px; font-weight: 700; color: var(--lb-text);`
- `.lb-header-btn` — `width: 34px; height: 34px; background: var(--lb-btn-bg); border-radius: var(--lb-radius-sm); display: flex; align-items: center; justify-content: center;`
- `.lb-header-actions` — `display: flex; gap: 8px;`

#### Content
- `.lb-content` — `flex: 1; padding: 20px 24px;` (ersetzt `#page_content .page_content`)
- `.lb-footer` — `text-align: center; padding: 20px;`
- `.lb-footer-logo` — `width: 90px; height: 90px;`

#### Help Panel
- `.lb-helppanel` — `position: fixed; top: 0; right: 0; bottom: 0; width: 300px; background: var(--lb-card-bg); border-left: 1px solid var(--lb-border-color); transform: translateX(300px); transition: transform 0.3s ease; z-index: 1001; overflow-y: auto;`
- `.lb-helppanel.open` — `transform: translateX(0);`

#### Modal
- `.lb-modal` — Styling fuer `<dialog>`: `border: none; border-radius: var(--lb-radius); box-shadow: var(--lb-card-shadow); max-width: 600px; padding: 0;`
- `.lb-modal::backdrop` — `background: rgba(0,0,0,.5);`
- `.lb-modal-header` — `padding: 16px 20px; border-bottom: 1px solid var(--lb-border-color);`
- `.lb-modal-content` — `padding: 20px; text-align: center;`

### Responsive (Mobile < 768px)

```css
@media (max-width: 768px) {
  .lb-layout {
    grid-template-columns: 1fr; /* Sidebar aus dem Grid */
  }
  .lb-sidebar {
    transform: translateX(-250px);
    transition: transform 0.3s ease;
  }
  .lb-sidebar.open {
    transform: translateX(0);
  }
  .lb-sidebar-backdrop.open {
    display: block;
  }
  .lb-sidebar-toggle {
    display: flex; /* Hamburger nur auf Mobile */
  }
}
@media (min-width: 769px) {
  .lb-sidebar-toggle {
    display: none; /* Hamburger auf Desktop versteckt */
  }
}
```

### JavaScript (minimal)

```javascript
// Sidebar toggle (mobile)
function toggleSidebar() {
  document.getElementById('lb-sidebar').classList.toggle('open');
  document.getElementById('lb-sidebar-backdrop').classList.toggle('open');
}
document.getElementById('btn-sidebar-toggle').addEventListener('click', toggleSidebar);
document.getElementById('lb-sidebar-backdrop').addEventListener('click', toggleSidebar);

// Help panel toggle
function toggleHelpPanel() {
  document.getElementById('helppanel').classList.toggle('open');
}
document.getElementById('btn-helppanel-close').addEventListener('click', toggleHelpPanel);

// Reboot popup: replace jQuery Mobile .popup("open") with <dialog>.showModal()
// Existing code calls: $("#popupRebootForce").popup("open")
// New code: document.getElementById('popupRebootForce').showModal()
```

### Vue3 Sidebar-Navigation

Die bestehende Vue3 Navbar-Logik wird angepasst:

**Datenquelle:** Gleiches JSON-Menu (`#jsonmenu`) wie bisher. Die Struktur wird erweitert:
```json
[
  {
    "section": "plugins",
    "Name": "Stats4Lox",
    "URL": "/admin/plugins/stats4lox/index.cgi",
    "Notify_Package": "stats4lox",
    "status": "running"
  },
  ...
  {
    "section": "system",
    "Name": "Miniserver",
    "URL": "/admin/system/miniserver.cgi"
  }
]
```

**Rendering:** Statt horizontaler Tabs werden vertikale Links gerendert:
- Plugins mit Status-Dots und Notification-Badges
- System-Links ohne Status-Dots
- Tools-Links kleiner/muted
- Aktiver Link wird per URL-Matching hervorgehoben

**Vue-Navbar bleibt:** Die horizontale Sub-Navigation (Tabs innerhalb einer Seite, z.B. "Backup" / "Log Files") bleibt als separate Komponente im Header-Bereich. Die wird nicht in die Sidebar verschoben.

### Was entfaellt

- `data-role="page"` Wrapper
- `data-role="panel"` (links + rechts) — ersetzt durch CSS Sidebars
- `data-role="header"` — ersetzt durch `.lb-header`
- `.ui-responsive-panel` Klasse
- `.ui-content`, `.ui-body`, `.ui-body-a` Wrapper
- jQuery Mobile Panel JS
- `data-role="popup"` fuer Reboot-Force — ersetzt durch `<dialog>`

### Was bleibt

- Vue3 fuer Sidebar-Navigation (Plugin-Menus, Notifications)
- Vue3 Navbar fuer Sub-Tabs innerhalb einer Seite
- Notification-Bell AJAX-Logik + SessionStorage Cache
- Reboot-Force Logik (nur UI-Aufruf aendert sich)
- Header-Buttons (Home, Bell, Help, Power)
- `#page_content` / `.page_content` CSS-Klasse als Alias fuer Plugin-Kompatibilitaet
- jQuery Mobile bleibt in head.html geladen (fuer Plugins)

### Plugin-Kompatibilitaet

- `#page_content` und `.page_content` bleiben als IDs/Klassen erhalten
- jQuery Mobile CSS/JS bleibt geladen
- Plugin-Content wird innerhalb von `.lb-content` gerendert
- Keine Aenderung am Plugin-SDK oder Plugin-Templates
- Die `data-role="page"` Struktur die jQuery Mobile erwartet wird durch eine minimale Shim-Div ersetzt wenn noetig

### Dateien

**Modify:**
- `templates/system/pagestart.html` — Kompletter Umbau der Seitenstruktur
- `templates/system/pageend.html` — Footer + Dialog, jQuery Mobile Popup entfernen
- `webfrontend/html/system/css/components.css` — Neue Layout/Sidebar/Header/Modal Klassen
- `webfrontend/html/system/css/main.css` — Alte Navbar-Styles entfernen/anpassen

**Keep (anpassen):**
- `templates/system/pagestart_alternative.html` — Gleiche Aenderungen wie pagestart
- `templates/system/pagestart_nopanels.html` — Vereinfachte Version ohne Sidebar

**Nicht aendern:**
- `templates/system/head.html` — Bleibt wie es ist
- Theme-Files — Sidebar-Tokens sind schon definiert
- Plugin-Templates — Werden nicht angefasst
