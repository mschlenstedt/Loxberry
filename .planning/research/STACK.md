# Technology Stack

**Project:** LoxBerry NeXtGen — Smart Home Platform Modernization
**Researched:** 2026-03-15
**Research Mode:** Ecosystem (Stack dimension)

---

## Context and Constraints

The existing system runs on Raspberry Pi (1 GB RAM, arm64/armv7l, Debian 12 Bookworm). The web server is Apache 2.4 serving Perl CGI and PHP pages. The goal is **gradual, PR-by-PR modernization** — not a rewrite. Vue 3 is already partially present (`vue3.js` exists in the asset tree), so the frontend choice is confirmed. The backend migration is additive: new Python endpoints run alongside existing Perl/PHP CGI, sharing the Apache vhost via ProxyPass.

All packages must:
1. Install cleanly from pip/apt/npm on Debian 12 arm64
2. Fit inside a 1 GB RAM budget alongside Mosquitto, Apache, and existing daemons
3. Not require a Node.js runtime at **runtime** (build artifacts only)

---

## Recommended Stack

### Frontend Framework

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| Vue 3 | 3.5.30 (stable) | Reactive UI framework replacing jQuery/jQuery Mobile | HIGH |
| Vite | 8.0.0 | Build tooling — dev server + production bundle | HIGH |
| Pinia | 3.x | State management (replaces Vuex, now official recommendation) | HIGH |
| Vue Router | 4.x | SPA routing for admin panel | HIGH |

**Why Vue 3 and not React or Svelte:**
- Already present in the codebase (`vue3.js` asset). Core developers have already made this call — switching frameworks would block acceptance of any PR.
- Vue 3's Composition API with `<script setup>` produces concise, readable components that non-frontend developers (the LoxBerry core team) can review.
- Smaller baseline than React (Vue 3 + Vite produces ~16 KB hello-world bundle vs React's ~40 KB). On a Pi serving an admin panel, this matters for cold-load time.
- Vue 3 does not require SSR. Pure SPA mode, static files served by Apache — zero new runtime processes.

**Why Vite 8 and not Webpack:**
- Webpack 5 is still viable but Vite is now the Vue ecosystem default. `create-vue` scaffolding uses Vite exclusively.
- Vite 8 ships Rolldown (Rust bundler) as its unified bundler, with 10–30× faster builds. Build artifacts are identical to Vite 6/7.
- Build runs on a developer's machine or CI — the Pi only serves the compiled output. Build speed is irrelevant to Pi RAM.

**Why Pinia and not Vuex:**
- Vuex is in maintenance mode. The official Vue docs now point to Pinia as the state management solution.
- Pinia 3 drops Vue 2 support entirely — it is Vue 3-only and integrates tightly with the Composition API.
- Zero boilerplate: no separate mutations, no magic strings, first-class TypeScript inference.

---

### CSS / Design System

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| Tailwind CSS | **3.4.x (NOT v4)** | Utility-first CSS, theme variables | HIGH |
| CSS custom properties | Native | Theme switching (light/dark/classic) | HIGH |

**Why Tailwind 3.4 and not v4:**
Tailwind CSS v4.0 (released January 2025) requires **Chrome 111+, Safari 16.4+, Firefox 128+** as absolute minimums. It uses `@property` and `color-mix()` as core framework features — not optional utilities. Older browsers get broken layouts, not graceful degradation.

LoxBerry is an admin panel served to home users on embedded hardware. Browser diversity is unknown — users may access it from old tablets, embedded browsers, or kiosk setups. Tailwind 3.4 covers all modern browsers without those constraints, is fully stable, and produces the same utility classes the team already knows.

Tailwind v4 can be revisited when the target browser floor is confirmed to be 2023+ everywhere. For this proposal, v3.4 is the safe, correct choice.

**Why Tailwind and not a full CSS framework like Bootstrap:**
Bootstrap injects its own component opinions (modals, navbars, cards) that conflict with a Vue component library. Tailwind is composition-friendly: you write Vue components and apply utilities — no fighting with Bootstrap's DOM assumptions.

**Theme System Implementation:**
Use CSS custom properties (`--color-bg`, `--color-surface`, `--color-accent`, etc.) defined per-theme in a `:root[data-theme="dark"]` selector block. Tailwind's `@apply` references these variables. JavaScript writes `data-theme` to `<html>`. No JavaScript needed at paint time — themes apply via CSS.

Three themes: `light`, `dark`, `classic` (approximates the existing jQuery Mobile look for users who want minimal change).

---

### Vue Component Library

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| Naive UI | latest (2.x) | Vue 3 component library | MEDIUM |

**Why Naive UI:**
- Built exclusively for Vue 3 (no Vue 2 compat layer bloating the bundle).
- All 90+ components are individually tree-shakeable. An admin panel that imports 15 components ships only those 15.
- Built-in dark mode support via `n-config-provider` — a single prop switches all components between themes. This aligns directly with the 3-theme requirement.
- Smaller practical footprint than PrimeVue (369 KB gzipped baseline) or Quasar (full framework with router, build system, etc. entangled).
- TypeScript-first; no separate `@types` package needed.

**Why not PrimeVue:**
369 KB gzipped for the full library. For a local admin panel this is acceptable, but the tree-shaking story is weaker — the CSS layer is harder to scope than Naive UI's JS-in-CSS approach.

**Why not Quasar:**
Quasar is a full framework (its own CLI, build pipeline, router integration). Integrating it into an Apache-served Vue 3 SPA that coexists with Perl CGI is friction-heavy. It assumes it owns the entire application.

**Why not a headless library (Headless UI, Radix Vue):**
Headless libraries require you to build all visual components from scratch. For a focused admin panel modernization proposal, a styled component library cuts scope significantly.

**Confidence note:** Naive UI's exact gzip footprint per-component was not available in verified sources. The tree-shaking claim is confirmed by official documentation and GitHub. MEDIUM confidence on the comparative size claim vs alternatives; HIGH confidence on the dark-mode and Vue 3 exclusivity claims.

---

### Python Backend (Gradual Migration Layer)

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| FastAPI | 0.135.1 | Python web API framework for new endpoints | HIGH |
| Uvicorn | 0.41.0 | ASGI server running FastAPI | HIGH |
| Pydantic | 2.x (bundled with FastAPI) | Request/response validation and serialization | HIGH |
| httpx | latest | HTTP client for inter-service calls | HIGH |

**Why FastAPI and not Flask:**
- **Performance:** FastAPI handles 15,000–20,000 req/s vs Flask's 2,000–3,000 req/s. Even for a home Pi, this means less CPU time per request and lower latency for the admin panel.
- **Async native:** Uvicorn + coroutines is dramatically more memory-efficient than multi-process Gunicorn workers. On 1 GB RAM, each additional Gunicorn worker costs ~30–50 MB. One Uvicorn worker with async handles the same concurrency.
- **OpenAPI built-in:** FastAPI generates `/docs` automatically. This is directly useful as a developer API reference when proposing to the LoxBerry team.
- **Pydantic validation:** Input sanitization (a stated project requirement) is handled structurally rather than via manual string checks. This directly addresses the shell injection and input sanitization security requirements.
- **Both FastAPI and Uvicorn are on piwheels** (confirmed), meaning `pip install fastapi uvicorn` on a Raspberry Pi installs pre-compiled wheels without a C compiler.
- FastAPI requires Python >=3.10; the system runs Python 3.11 (Debian 12 default). No conflict.

**Integration pattern (coexistence with Apache/Perl/PHP):**
```
Apache vhost:
  ProxyPass /api/ http://127.0.0.1:8000/
  ProxyPassReverse /api/ http://127.0.0.1:8000/
```
FastAPI runs as a systemd service (`loxberry-api.service`) on port 8000, localhost only. Existing `.cgi` and PHP routes are untouched. Each new feature adds a FastAPI endpoint; migration replaces CGI endpoints one at a time.

**Why not Django:**
Django is opinionated about ORM, auth, templates, and project structure — none of which align with LoxBerry's existing file-based config and Perl CGI architecture. It would import ~7 MB of framework just to serve JSON endpoints. FastAPI imports ~1.5 MB.

**Why not keeping everything in Perl/PHP:**
The project mandate explicitly requires gradual Python migration for new features. Flask or FastAPI — the question is which Python framework, not whether to use Python.

---

### Python Backup Tooling

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| rclone | latest stable (1.69+) | File sync to NAS / cloud (NFS, S3, Backblaze B2, WebDAV, etc.) | HIGH |
| APScheduler | 3.11.2 | In-process scheduled jobs for backup automation | HIGH |
| Python `tarfile` + `shutil` | stdlib | Local archive creation (no extra dependency) | HIGH |
| Python `subprocess` | stdlib | Invoking rclone and rsync | HIGH |

**Why rclone and not writing custom cloud sync:**
- rclone supports 70+ storage backends including NAS (NFS/SMB), S3-compatible (Backblaze B2, Wasabi, AWS), WebDAV, Google Drive, Dropbox. Writing custom integrations for all these is months of work.
- rclone is packaged in Debian 12 (`apt install rclone`) and has a Raspberry Pi forum thread confirming systemd integration works.
- Python calls rclone via `subprocess.run(["rclone", "copy", src, dst, "--log-file", ...])` — no Python rclone binding needed.

**Why APScheduler 3.x and not cron:**
- Cron requires root to manage user crontabs or editing system crontab files. APScheduler runs inside the Python process and persists schedules to a file/SQLite store — manageable via the FastAPI admin API without touching system files.
- APScheduler 3.x (not 4.x — which is a complete API rewrite still stabilizing) is the proven production version, available on PyPI with Python 3.8–3.13 support.
- Schedules survive restarts because APScheduler can use a SQLite job store.

**Why not Celery or other task queues:**
Celery requires a message broker (Redis or RabbitMQ). Redis is ~30 MB additional RAM; RabbitMQ is ~100 MB. For scheduled backup jobs on a home Pi, APScheduler's in-process scheduler is the correct weight class.

**Why stdlib `tarfile` + `shutil` for archive creation:**
Zero extra dependencies. `shutil.make_archive()` wraps tarfile for simple cases; `tarfile` directly handles streaming, filtering, and progress for LoxBerry's multi-directory backups.

---

### Testing Infrastructure

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| pytest | 8.x (latest stable) | Test runner for Python modules | HIGH |
| httpx | latest | FastAPI `TestClient` transport for integration tests | HIGH |
| pytest-asyncio | latest | Async test support for FastAPI endpoints | HIGH |
| Vitest | latest (via Vite) | Unit testing Vue 3 components | HIGH |

**Why pytest and not unittest:**
pytest is the de-facto standard for Python testing in 2025. The JetBrains Developer Survey found 40% of Python developers use pytest exclusively. Its fixture system and plugin ecosystem (`pytest-asyncio`, `pytest-httpx`) make FastAPI endpoint testing clean and expressive.

**FastAPI testing pattern:**
```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_backup_status():
    response = client.get("/api/backup/status")
    assert response.status_code == 200
```

`TestClient` is synchronous and built on HTTPX — no special async setup needed for most tests.

**Why Vitest and not Jest:**
Vitest is Vite-native. It reuses the same Vite config, meaning no separate Babel/Jest transformer configuration. Jest requires `@vue/vue3-jest` and separate Babel config to handle `.vue` SFC files; Vitest handles them natively.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Frontend | Vue 3 | React, Svelte | Already in codebase; team familiarity; smaller baseline bundle |
| Build | Vite 8 | Webpack 5, Parcel | Vue ecosystem default; no runtime on Pi; faster builds |
| CSS | Tailwind 3.4 | Tailwind 4, Bootstrap 5 | TW4 requires Chrome 111+/Firefox 128+ — unsafe for admin panels; Bootstrap fights Vue component model |
| Components | Naive UI | PrimeVue, Quasar | PrimeVue large baseline; Quasar is a full framework, not a component library |
| State | Pinia 3 | Vuex 4 | Vuex in maintenance mode; Pinia is official replacement |
| Python API | FastAPI 0.135 | Flask, Django | FastAPI: async native, lower RAM per request, built-in validation, OpenAPI docs |
| Scheduling | APScheduler 3.11 | Celery, cron | Celery requires broker (+30–100 MB RAM); cron requires system file access |
| Cloud sync | rclone | custom scripts | rclone has 70+ backends; custom scripts have 1 |
| Testing (Python) | pytest 8 | unittest | pytest is ecosystem standard; better fixture model |
| Testing (Vue) | Vitest | Jest | Vite-native; no separate transpiler config |

---

## Installation

```bash
# Python backend (on Raspberry Pi, uses piwheels for ARM wheels)
pip install fastapi==0.135.1 uvicorn==0.41.0 APScheduler==3.11.2 httpx pytest pytest-asyncio

# Frontend build tooling (on developer machine, NOT on Pi)
npm create vue@latest  # scaffolds Vue 3 + Vite 8 + Pinia + Vue Router
npm install -D tailwindcss@3 naive-ui vitest
npx tailwindcss init

# System packages (Raspberry Pi / Debian 12)
apt install rclone
```

```
# systemd service for FastAPI
# /etc/systemd/system/loxberry-api.service
[Unit]
Description=LoxBerry Python API
After=network.target

[Service]
User=loxberry
WorkingDirectory=/opt/loxberry/sbin
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1
Restart=always

[Install]
WantedBy=multi-user.target
```

**Note on workers:** Use `--workers 1` on 1 GB Pi. Uvicorn's async handles admin panel concurrency without multiple processes. Each additional worker costs ~30–50 MB RAM.

---

## What NOT to Use

| Technology | Reason |
|------------|--------|
| Tailwind CSS v4 | Requires Chrome 111+/Safari 16.4+/Firefox 128+ minimum — not safe for unknown admin panel browsers |
| Node.js runtime on Pi | Vue/Vite build artifacts are static files. No Node.js process needed at runtime |
| Quasar Framework | Full framework owns its own CLI and build pipeline — incompatible with Apache + CGI coexistence |
| Vuex | Official maintenance-mode; Pinia is the replacement |
| Celery / Redis / RabbitMQ | Over-engineered for scheduled backup jobs; 30–100 MB RAM for the broker alone |
| Django | Heavy framework for JSON API work; ~7 MB import overhead vs FastAPI's ~1.5 MB |
| Vue 2 | EOL; Pinia 3 doesn't support it; no path forward |
| jQuery Mobile | EOL; actively replaced in this modernization; do not add new jQuery Mobile code |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Vue 3 as frontend | HIGH | Already present in codebase; official Vue releases verified |
| Vite 8 build tooling | HIGH | Official vite.dev confirmed v8.0.0 as current stable |
| Tailwind 3.4 (not v4) | HIGH | Official Tailwind docs confirm v4 browser floor requirements |
| Naive UI component library | MEDIUM | Official docs confirm Vue 3 exclusivity and tree-shaking; per-component gzip size data not independently verified |
| Pinia 3 state management | HIGH | Official Vue docs recommend Pinia; Vuex maintenance-mode confirmed |
| FastAPI 0.135.1 | HIGH | PyPI confirmed; piwheels confirmed for Raspberry Pi ARM |
| Uvicorn 0.41.0 | HIGH | PyPI confirmed; ARM ASGI efficiency over WSGI confirmed in multiple sources |
| APScheduler 3.11.2 | HIGH | PyPI confirmed; Raspberry Pi forum confirms ARM compatibility |
| rclone as sync backend | HIGH | Debian 12 packaged; systemd Raspberry Pi integration confirmed |
| pytest + Vitest | HIGH | Industry-standard tools; ecosystem default in 2025/2026 |

---

## Sources

**Vue 3 / Vite:**
- [Vue 3.5 Release Blog](https://blog.vuejs.org/posts/vue-3-5) — Vue 3.5 reactivity improvements, no breaking changes
- [Vue GitHub Releases](https://github.com/vuejs/core/releases) — v3.5.30 confirmed latest stable (March 2025)
- [Vite releases page](https://vite.dev/releases) — Vite 8.0.0 confirmed current
- [Vue Performance Guide](https://vuejs.org/guide/best-practices/performance) — Bundle size baseline ~16 KB minified+brotli

**Pinia:**
- [Pinia Introduction](https://pinia.vuejs.org/introduction.html) — v3.x confirmed for Vue 3; Vuex maintenance-mode
- [Vue State Management Guide](https://vuejs.org/guide/scaling-up/state-management) — Official Pinia recommendation

**Tailwind CSS:**
- [Tailwind CSS v4 Compatibility Docs](https://tailwindcss.com/docs/compatibility) — Chrome 111+, Safari 16.4+, Firefox 128+ hard minimum
- [Tailwind v4 vs v3 StaticMania](https://staticmania.com/blog/tailwind-v4-vs-v3-comparison) — Breaking changes summary
- [Downgrading from Tailwind v4 post-mortem](https://medium.com/@pradeepgudipati/%EF%B8%8F-downgrading-from-tailwind-css-v4-to-v3-a-hard-earned-journey-back-to-stability-88aa841415bf) — Real-world stability concerns

**FastAPI / Uvicorn:**
- [FastAPI on PyPI](https://pypi.org/project/fastapi/) — v0.135.1, Python >=3.10 confirmed
- [Uvicorn on PyPI](https://pypi.org/project/uvicorn/) — v0.41.0, Python >=3.10 confirmed
- [piwheels FastAPI](https://www.piwheels.org/project/fastapi/) — ARM wheel availability confirmed
- [FastAPI on Raspberry Pi guide](https://sulacosoft.com/content/IoT/RaspberryPi_RestApi_FastApi_Python/index.html) — Practical deployment
- [FastAPI vs Flask performance](https://towardsdatascience.com/fastapi-versus-flask-3f90adc9572f/) — 15k–20k vs 2k–3k req/s

**APScheduler / rclone:**
- [APScheduler on PyPI](https://pypi.org/project/APScheduler/) — v3.11.2, Python >=3.8 confirmed
- [rclone official site](https://rclone.org/) — 70+ storage backends
- [rclone + systemd on Raspberry Pi forum](https://forum.rclone.org/t/systemd-on-raspberry-pi/15744) — ARM systemd integration

**Python application servers:**
- [Python Application Servers 2026](https://www.deployhq.com/blog/python-application-servers-in-2025-from-wsgi-to-modern-asgi-solutions) — ASGI efficiency for ARM

---

*Stack research: 2026-03-15*
