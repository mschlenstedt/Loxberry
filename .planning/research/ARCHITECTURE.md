# Architecture Patterns: Incremental Modernization

**Domain:** Embedded smart home platform (Perl/PHP CGI monolith on Raspberry Pi)
**Researched:** 2026-03-15
**Confidence:** HIGH (current architecture from codebase analysis) / MEDIUM (migration patterns from verified sources)

---

## Recommended Architecture

The target is not a microservices rewrite. It is a **layered strangler fig** where each modernization step is independently deployable and backward compatible. The monolith keeps running; new layers are grown around it.

### Migration Trajectory

```
TODAY (Current)                    TARGET (End of roadmap)
─────────────────────────────      ──────────────────────────────────────────
Browser                            Browser
  │                                  │
  ▼                                  ▼
Apache (Basic Auth)                Apache (Basic Auth)
  │                                  │
  ├── /admin/*.cgi  → Perl CGI       ├── /admin/api/*  → Python API (FastAPI/Flask)
  ├── /admin/*.php  → PHP CGI        ├── /admin/ui/*   → Vue 3 SPA
  └── /            → Static HTML     ├── /admin/*.cgi  → Legacy Perl CGI (untouched)
                                     ├── /admin/*.php  → Legacy PHP CGI (untouched)
                                     └── /             → Static HTML
                                                         (+ Vue 3 assets)

SDK (Perl + PHP)                   SDK (Perl + PHP UNCHANGED)
                                   + Python SDK (new, additive)

File-backed JSON config            File-backed JSON config (unchanged format)

Plugin scaffold (unchanged)        Plugin scaffold (unchanged)
```

---

## Component Boundaries

The architecture defines five component zones. Each has a hard boundary — nothing outside the zone owns its responsibilities.

### Zone 1: Apache Routing Layer
| Responsibility | Details |
|----------------|---------|
| Authentication | HTTP Basic Auth via `.htpasswd` — unchanged |
| URL dispatch | Route `/admin/api/*` to new Python service; all other `/admin/*` to existing CGI/PHP |
| Static assets | Serve Vue 3 bundle, CSS, theme files from `webfrontend/html/system/` |
| TLS termination | Existing 001-default-ssl.conf — unchanged |

**Communicates with:** Python API service (new, via reverse proxy), CGI/PHP scripts (existing, unchanged)

**Key constraint:** Apache configuration is the only place routing decisions are made. CGI scripts and the Python API never know about each other. This enforces the strangler fig boundary.

---

### Zone 2: Python API Service (new)
| Responsibility | Details |
|----------------|---------|
| REST endpoints | New functionality: backup management, config API, health status |
| Config reads/writes | Read/write same JSON files (`general.json`, `plugindatabase.json`) that Perl/PHP already use |
| Privilege escalation | Shell out to existing `sbin/` scripts via subprocess — no reimplementation of privileged ops |
| Gradual Perl migration | New features land here first; existing Perl CGI pages migrated one page at a time |

**Communicates with:** File system (shared config/data), existing `sbin/` scripts via subprocess, Vue 3 frontend via JSON

**Does NOT:** Replace or modify the Perl SDK, PHP SDK, or any existing CGI/PHP scripts

**Process model:** Single Uvicorn worker (Flask as alternative if memory proves critical). On Raspberry Pi 1 GB RAM, Flask idle ~50 MB vs FastAPI/Uvicorn ~140 MB. Use Flask for initial phases; consider FastAPI only when async I/O becomes necessary.

**Recommendation:** Start with Flask (MEDIUM confidence). It is lighter, simpler for synchronous admin operations, and the concurrency advantage of FastAPI is irrelevant for a home server with 1–5 concurrent users. Re-evaluate if backup streaming or WebSocket live log tailing is needed.

---

### Zone 3: Existing CGI/PHP Layer (preserved)
| Responsibility | Details |
|----------------|---------|
| All current admin pages | Untouched during entire migration — pages migrated one at a time to Zone 2 |
| Plugin admin UIs | Plugin `.cgi` and `.php` pages continue to work identically |
| JSON-RPC endpoint | Existing `jsonrpc.php` endpoint stays active; Vue 3 components continue calling it |
| Template rendering | `HTML::Template` + `loxberry_web.php` rendering unchanged |

**Communicates with:** Perl SDK (`libs/perllib/`), PHP SDK (`libs/phplib/`), Apache

**Plugin compatibility contract:** Zone 3 is the compatibility guarantee. As long as Zone 3 exists and the SDK is unchanged, every existing plugin works. No plugin changes are needed at any point in this roadmap.

---

### Zone 4: Vue 3 Frontend (evolving)
| Responsibility | Details |
|----------------|---------|
| New UI components | Replaces jQuery page by page using the existing `vue3.js` bundle already present |
| Theme system | CSS custom properties (design tokens) injected at `<html data-theme="...">`, no JS required for switching |
| API client | Calls both existing `jsonrpc.php` (Zone 3) and new REST endpoints (Zone 2) |
| jQuery coexistence | jQuery 1.12.4 stays loaded for pages not yet migrated; Vue 3 components mounted in isolated `<div id="vue-app">` containers |

**Communicates with:** Zone 2 (REST API), Zone 3 (JSON-RPC endpoint), Apache (static files)

**Coexistence strategy:** jQuery and Vue 3 can coexist on the same page during transition because Vue 3 uses shadow DOM / scoped mounting. A Vue 3 component mounted in `<div id="vue-dashboard">` does not conflict with jQuery operating on other elements. This is well-established practice (MEDIUM confidence — confirmed by multiple migration guides).

**Do not:** Convert all pages at once. Convert one page per PR. Pages not yet converted continue to render via `HTML::Template` in Zone 3 with the jQuery UI they have today.

---

### Zone 5: System Daemons (minimally changed)
| Responsibility | Details |
|----------------|---------|
| MQTT gateway | `mqttgateway.pl` — refactor only (optimization PR), not replaced |
| Plugin installer | `plugininstall.pl` — unchanged; Python API shells out to it for plugin operations |
| Health check | `healthcheck.pl` — Python API reads its JSON output; daemon itself unchanged |
| System update | `loxberryupdate.pl` — unchanged |

**Communicates with:** File system, Mosquitto broker, Loxone Miniserver via HTTP/UDP

**Key principle:** Daemons are not migrated in the modernization roadmap. They are maintained as Perl. Migration can be proposed as a future phase after core modernization is proven.

---

## Data Flow

### Flow 1: Authenticated Admin Page Request (existing, unchanged)

```
Browser GET /admin/system/network.cgi
  → Apache: Basic Auth check → CGI execute
  → network.cgi: use LoxBerry::System; load general.json
  → HTML::Template render → response HTML
```

This flow is never broken by any phase of the modernization.

---

### Flow 2: New REST API Request (introduced in API phase)

```
Browser/Vue3 GET /admin/api/v1/system/info
  → Apache: Basic Auth check → ProxyPass to Flask :5001
  → Flask route handler: read general.json + plugindatabase.json
  → JSON response
```

Apache configuration addition (example):
```apache
# In 000-default.conf, inside the /admin/ location block:
ProxyPass /admin/api/ http://127.0.0.1:5001/api/
ProxyPassReverse /admin/api/ http://127.0.0.1:5001/api/
```

Authentication remains Apache Basic Auth — the Python service runs on localhost only, trusting Apache to enforce auth before proxying. The service is not exposed directly.

---

### Flow 3: Vue 3 Component on a Legacy Page (transition state)

```
Browser loads /admin/system/index.cgi
  → CGI renders HTML with <div id="vue-status"></div> and Vue 3 bundle
  → Vue 3 mounts component to #vue-status
  → Component calls GET /admin/api/v1/system/health (Zone 2)
  → Renders status widget
  → Rest of page remains jQuery / HTML::Template output
```

This is the key transition pattern: Vue 3 components are embedded progressively inside existing CGI-rendered pages before those pages are fully migrated.

---

### Flow 4: Theme System Data Flow

```
User selects theme in admin UI
  → AJAX POST to /admin/api/v1/ui/theme (Zone 2 or jsonrpc.php Zone 3)
  → Saved to general.json: ui.theme = "dark"
  → Apache/CGI reads theme on next page load
  → <html data-theme="dark"> written by HTML::Template or Vue 3 app shell
  → CSS custom properties cascade from [data-theme="dark"] selector
```

Theme tokens live in a single CSS file. No framework required. No JS theme-switching overhead. Uses `prefers-color-scheme` as fallback default.

---

### Flow 5: Backup Operation (new feature, entirely in Zone 2)

```
Browser Vue3 component: POST /admin/api/v1/backup/miniserver
  → Flask receives request, validates params
  → Flask subprocess: calls existing sbin/credentialshandler.pl or new backup script
  → Streams progress via SSE or polls status endpoint
  → Backup file written to configured destination
  → Response: job ID + status URL
```

Backup is a pure Zone 2 feature. No changes to any existing CGI/PHP script.

---

## Theme System Architecture

### CSS Design Token Approach (HIGH confidence)

The theme system uses CSS custom properties (variables) scoped to a `data-theme` attribute on `<html>`. This requires zero JavaScript at runtime and works on all modern browsers.

```css
/* webfrontend/html/system/css/themes.css — new file */

/* Base tokens (light theme = default) */
:root,
[data-theme="light"] {
  --color-bg-primary: #ffffff;
  --color-bg-secondary: #f5f5f5;
  --color-text-primary: #1a1a1a;
  --color-text-secondary: #555555;
  --color-accent: #2196f3;
  --color-border: #e0e0e0;
  --color-surface: #fafafa;
  --font-size-base: 16px;
  --border-radius-base: 4px;
}

[data-theme="dark"] {
  --color-bg-primary: #121212;
  --color-bg-secondary: #1e1e1e;
  --color-text-primary: #e0e0e0;
  --color-text-secondary: #aaaaaa;
  --color-accent: #64b5f6;
  --color-border: #333333;
  --color-surface: #1a1a1a;
}

[data-theme="classic"] {
  /* Preserves existing LoxBerry color identity */
  --color-bg-primary: #ffffff;
  --color-accent: #ff6600; /* LoxBerry orange */
  /* ... */
}
```

**Implementation in `templates/system/head.html`:**
```html
<html data-theme="<TMPL_VAR name="ui_theme" default="light">">
```

**The Perl SDK reads `general.json` → `ui.theme` and passes it as a template variable.** No changes to any page-specific CGI script — only `Web.pm` header rendering is updated.

---

## Patterns to Follow

### Pattern 1: Apache as the Strangler Boundary

**What:** All routing decisions for new vs. legacy are made in Apache config, not in code.

**When:** Every time a new Python endpoint is introduced.

**Rule:** New paths go under `/admin/api/` — existing CGI/PHP paths are never renamed or removed. The legacy system is never told it is being replaced.

---

### Pattern 2: Shared File System as Integration Bus

**What:** Python API reads and writes the same JSON files (`general.json`, `plugindatabase.json`) that Perl/PHP already uses. File locking via Python's `fcntl`/`filelock` library mirrors what `LoxBerry::JSON.pm` does.

**When:** Python API needs system config or plugin data.

**Why:** Eliminates any synchronization problem. There is no separate database. The file system is the single source of truth, and both old and new code read it the same way.

**Caution:** Python must replicate the write-locking behaviour of `LoxBerry::JSON.pm` (exclusive flock before write). Skipping this causes config corruption under concurrent writes. Use the `filelock` library.

---

### Pattern 3: Subprocess Bridge for Privileged Operations

**What:** The Python API never gains root access directly. It shells out to existing `sbin/` scripts via `subprocess.run(['sudo', 'sbin/plugininstall.pl', ...])`, which already have sudoers entries.

**When:** Backup, plugin install, network config changes.

**Why:** Avoids reimplementing privilege escalation logic. The security boundary (sudoers rules) already exists and is already audited.

---

### Pattern 4: One Page Per PR Frontend Migration

**What:** Each CGI/PHP admin page is migrated to a Vue 3 SPA page in a separate pull request. The old page is not deleted until the new one is confirmed working.

**When:** Frontend modernization phase.

**Implementation:** New page at `/admin/ui/network` (Vue 3 SPA). Old page at `/admin/system/network.cgi` (unchanged). Apache routes `/admin/ui/*` to Vue 3 SPA; `/admin/system/*.cgi` still works. After community confirmation, add a redirect from old URL to new. Old CGI removed in a follow-up PR.

---

### Pattern 5: Design Token Isolation for Theme System

**What:** Existing hardcoded colors in `webfrontend/html/system/css/` are replaced with CSS variables. All variable definitions live in one `themes.css` file. Existing CSS files import this file and use variables.

**When:** Theme system phase.

**Why:** Theme switching requires zero JavaScript and zero page reload. Works in both the legacy CGI-rendered pages (via `head.html` template) and the Vue 3 components (via the same CSS file).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Database Introduction

**What:** Adding PostgreSQL, SQLite, or any relational database as part of this modernization.

**Why bad:** LoxBerry's file-based JSON config is its plugin compatibility contract. Plugins read config files directly. Introducing a DB creates two sources of truth and breaks all plugins that read files directly.

**Instead:** Keep file-based JSON. The Python API reads/writes JSON files with proper locking.

---

### Anti-Pattern 2: Python SDK Duplication

**What:** Re-implementing `LoxBerry::System` path resolution logic in Python as a full SDK replacement.

**Why bad:** Path logic is subtle (script-relative detection) and has edge cases refined over years. A Python reimplementation will have bugs. Plugin compatibility depends on the Perl and PHP SDKs being authoritative.

**Instead:** Python API uses hard-coded `LBHOMEDIR` (read from environment variable, same as Perl/PHP) to construct paths. It reads `general.json` directly. It does not need a full SDK.

---

### Anti-Pattern 3: Breaking the Plugin Scaffold Contract

**What:** Renaming directories, changing plugin folder naming conventions, or modifying `plugininstall.pl` scaffold creation logic.

**Why bad:** Every installed plugin has hard paths to `config/plugins/<folder>/`, `data/plugins/<folder>/`, etc. Changing these paths silently breaks all plugins that predate the change.

**Instead:** The scaffold convention is frozen. New plugin capabilities are additive (new optional directories, new optional SDK functions).

---

### Anti-Pattern 4: Full-Page jQuery Removal Before Vue Migration

**What:** Removing jQuery from `<head>` globally before all pages have been migrated to Vue 3.

**Why bad:** Plugin admin pages depend on jQuery. Removing it breaks all plugins that use `$.ajax`, `$.mobile`, etc. The project does not control plugin code.

**Instead:** jQuery stays loaded until the last plugin-facing page is confirmed jQuery-free. Estimate: this cannot happen until an explicit compatibility announcement is made to plugin authors with a deprecation window.

---

### Anti-Pattern 5: Running Python API as Root

**What:** Starting the Flask/FastAPI service under root or with sudo for the entire process.

**Why bad:** A vulnerability in the API exposes full system control. The entire point of the existing sudo-based architecture is to minimize the privileged attack surface.

**Instead:** Python API runs as the `loxberry` user. Privileged operations call existing `sbin/` scripts with targeted sudoers entries.

---

## Suggested Build Order

This order respects dependency chains and ensures each phase produces a shippable PR.

### Phase 1: Security Hardening (no new architecture)
**Why first:** Fixes known critical vulnerabilities (shell injection in `admin.cgi`, missing CSRF). Does not change architecture — only adds validation inside existing CGI scripts. No risk to plugin compatibility. Establishes credibility with core developers before proposing structural changes.

**Dependencies:** None.

**Produces:** Safer existing architecture, unchanged.

---

### Phase 2: MQTT Gateway Optimization
**Why second:** `mqttgateway_optimized.pl` already exists (7 fixes pre-prepared). Merge it. Pure improvement to Zone 5 with no architectural change. Another credibility-building PR.

**Dependencies:** None.

**Produces:** Faster daemon, unchanged architecture.

---

### Phase 3: Theme System (CSS layer only)
**Why third:** Contained change — one new CSS file, one change to `templates/system/head.html`, one new field in `general.json`. Proves the team can ship visible improvements without touching plugin APIs. Zero JavaScript required.

**Dependencies:** Phase 1 recommended (safer foundation) but not technically required.

**Produces:** Theme switching works for all existing pages, including plugin pages that use the standard head template.

---

### Phase 4: Python API Foundation
**Why fourth:** Introduces the Flask service and Apache proxy configuration. No new features yet — only the skeleton (health endpoint, system info read endpoint). This is the phase that establishes the Zone 2/Zone 3 boundary and validates that Apache proxy routing works.

**Dependencies:** Requires Apache configuration change. Must not interfere with existing routes.

**Produces:** `/admin/api/v1/system/info` returns JSON. Apache proxy working. Flask service managed by systemd unit file.

---

### Phase 5: Backup Feature
**Why fifth:** First real feature in Zone 2. Entirely new functionality — no legacy replacement required. Miniserver config backup and full system backup land here. Scheduled backups via cron.

**Dependencies:** Phase 4 (Python API foundation). Phase 1 (security — credentials handling).

**Produces:** Backup UI (Vue 3 component embedded in existing CGI page) + REST API + systemd timer for scheduled backups.

---

### Phase 6: Vue 3 Frontend Migration (incremental)
**Why sixth:** Highest effort, lowest risk if done one page at a time. By this phase, the API layer is established and Vue 3 components have a real backend to talk to. Start with dashboard widgets (read-only), then settings pages (read-write).

**Dependencies:** Phase 4 (API endpoints). Phase 3 (theme tokens already in CSS so Vue components inherit them automatically).

**Produces:** Pages converted one per PR. Legacy CGI pages remain accessible throughout.

---

### Phase 7: Python SDK Module (optional, later)
**Why last:** Once the Python API has grown enough that common patterns repeat (config reading, logging, plugin DB access), extract them into a `loxberry` Python package under `libs/pythonlib/`. This is additive — it does not replace Perl/PHP SDK.

**Dependencies:** Phase 4, 5, 6 (enough Python code exists to know what the SDK should contain).

**Produces:** `libs/pythonlib/loxberry/` — importable Python modules for config, logging, plugin DB.

---

## Plugin Compatibility Strategy

This is the highest-stakes constraint. The strategy has three rules:

**Rule 1: SDK files are append-only during this roadmap.**
`LoxBerry::System`, `LoxBerry::Web`, `LoxBerry::IO`, and all PHP equivalents receive no breaking changes. New functions may be added; existing function signatures and return values are frozen. Confidence: HIGH (this is an explicit project constraint).

**Rule 2: The file system contract is frozen.**
Directory layout (`config/plugins/<folder>/`, `data/plugins/<folder>/`, etc.) and file formats (`general.json` schema, `plugindatabase.json` schema) do not change. If a new field is added to `general.json`, it is optional with a safe default. Confidence: HIGH.

**Rule 3: The plugin scaffold created by `plugininstall.pl` is unchanged.**
New plugins install identically. The `plugin.cfg` format is unchanged. Existing plugins upgrading via the plugin manager continue to work. Confidence: HIGH — `plugininstall.pl` is not in scope for modification except for security fixes.

**Validation approach:** Before any PR that touches the SDK or config format is merged, run the existing test suite in `libs/perllib/LoxBerry/testing/` and `libs/phplib/testing/`. These test stubs exist but need to be populated as part of Phase 1 (test infrastructure).

---

## Scalability Considerations

LoxBerry runs on a Raspberry Pi with 1 GB RAM. Scalability means staying within memory budget, not handling high concurrency.

| Concern | Approach | Rationale |
|---------|----------|-----------|
| Python API memory | Flask single process, lazy imports, no ORM | Flask idle ~50 MB; FastAPI/Uvicorn ~140 MB. On 1 GB system, 90 MB difference is meaningful. |
| Vue 3 bundle size | Single bundle, tree-shaken, no heavy UI component library | Avoid Vuetify/Quasar (large bundle). Use Tailwind CSS or plain CSS variables instead. |
| MQTT gateway | Use pre-built `mqttgateway_optimized.pl` | Already has connection pooling and early filtering; no new architecture needed. |
| Config file locking | File locking in Python mirrors Perl's flock | Prevents corruption under concurrent admin operations (rare but possible). |
| Backup I/O | Stream backup files; never buffer full backup in RAM | Full system backup can be hundreds of MB — stream directly to destination. |

---

## Sources

- Strangler Fig pattern for PHP monoliths: [Laminas Project — Strangler Fig Pattern](https://getlaminas.org/blog/2025-08-06-strangler-fig-pattern.html) (MEDIUM confidence — current 2025 guidance)
- Apache reverse proxy for routing segregation: [Apache 2.4 Reverse Proxy Guide](https://httpd.apache.org/docs/2.4/howto/reverse_proxy.html) (HIGH confidence — official docs)
- Flask vs FastAPI memory comparison: [Better Stack — Flask vs FastAPI](https://betterstack.com/community/guides/scaling-python/flask-vs-fastapi/) (MEDIUM confidence — benchmarks vary)
- CSS design tokens and theming: [CSS Variables Guide 2025](https://www.frontendtools.tech/blog/css-variables-guide-design-tokens-theming-2025) (HIGH confidence — W3C standard, broad support)
- jQuery/Vue 3 coexistence migration: [jQuery to Vue Migration Guide](https://www.legacyleap.ai/blog/jquery-migration/) (MEDIUM confidence — WebSearch, general guidance)
- API backward compatibility: [API Backwards Compatibility Best Practices — Zuplo](https://zuplo.com/learning-center/api-versioning-backward-compatibility-best-practices) (MEDIUM confidence)
- Current architecture: `.planning/codebase/ARCHITECTURE.md` (HIGH confidence — derived from codebase analysis)
