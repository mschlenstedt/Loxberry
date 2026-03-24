# Project Research Summary

**Project:** LoxBerry NeXtGen — Smart Home Platform Modernization
**Domain:** Embedded smart home administration platform (Raspberry Pi / CGI monolith)
**Researched:** 2026-03-15
**Confidence:** HIGH (stack and pitfalls verified against official sources and direct codebase analysis)

---

## Executive Summary

LoxBerry NeXtGen is an incremental modernization of a Perl/PHP CGI monolith running on a 1 GB Raspberry Pi. The expert pattern for this domain is the **strangler fig**: grow new layers around the monolith one PR at a time, never break the compatibility contract that existing community plugins depend on, and ship visible improvements early to build credibility with unpaid volunteer maintainers. The recommended architecture has five stable zones — Apache routing, Python API service, legacy CGI/PHP layer (preserved), Vue 3 frontend (evolving), and system daemons (minimally changed) — where each zone has a hard boundary and the legacy zone remains operational throughout the entire roadmap.

The recommended stack is Vue 3 (already present in codebase) with Vite 8 build tooling, Pinia 3 state management, Tailwind CSS 3.4 (explicitly not v4 due to browser compatibility floor requirements), and Naive UI as the component library. On the backend, FastAPI 0.135.1 with Uvicorn runs as a systemd service proxied through Apache, sharing the existing file-based JSON config without introducing a database. There is one significant architectural disagreement between research files: STACK.md recommends FastAPI throughout while ARCHITECTURE.md recommends starting with Flask (~50 MB idle RAM vs FastAPI/Uvicorn ~140 MB) and re-evaluating when async I/O becomes necessary. Given the 1 GB RAM constraint, the Flask-first recommendation from ARCHITECTURE.md is the more conservative and defensible choice for initial phases.

The dominant risk is community rejection through plugin compatibility breakage. The plugin SDK contract (Perl/PHP libs, file system layout, `plugininstall.pl` scaffold) is a hard frozen surface — any accidental break will cause maintainers to reject the proposal before it proves its value. Security hardening must come first, but CSRF protection in particular carries a secondary risk of breaking plugin AJAX callers that rely on the existing `Satisfy Any` localhost bypass. Every security PR needs a documented plugin impact assessment before merge.

---

## Key Findings

### Recommended Stack

The stack is largely locked in by existing codebase decisions and hardware constraints. Vue 3 is already present; framework choice is not debatable. The build pipeline (Vite 8, Pinia 3, Vue Router 4) is the current Vue ecosystem standard. Tailwind CSS 3.4 is mandatory over v4 because v4 requires Chrome 111+/Safari 16.4+/Firefox 128+ as hard minimums — an unknown user-browser population accessing an admin panel cannot be assumed to meet that floor.

On the backend, the choice between Flask and FastAPI is the only live decision. FastAPI is faster and has better built-in validation and OpenAPI docs generation; Flask is lighter (~50 MB vs ~140 MB idle) and simpler for synchronous admin operations. The home server context (1-5 concurrent users, 1 GB RAM) does not require FastAPI's concurrency advantages for initial phases. Starting with Flask and migrating to FastAPI when backup streaming or WebSocket log tailing requires async I/O is the lower-risk path. APScheduler 3.x (not 4.x, which is still stabilizing) handles scheduled backup jobs in-process without requiring Redis or RabbitMQ. rclone handles all cloud/NAS sync with 70+ backends.

**Core technologies:**
- Vue 3 (3.5.30): Reactive UI framework — already in codebase, team familiarity confirmed
- Vite 8: Build tooling — runs on developer machine or CI only, never on the Pi
- Pinia 3: State management — official Vuex replacement, Vue 3 Composition API native
- Tailwind CSS 3.4: Utility CSS — v3.4 specifically, v4 incompatible with unknown admin panel browsers
- Naive UI 2.x: Vue 3 component library — tree-shakeable, built-in dark mode via `n-config-provider`
- Flask (initial) / FastAPI (later): Python API — Flask first for RAM budget; FastAPI when async needed
- APScheduler 3.11.2: In-process job scheduling — no broker dependency, SQLite job store
- rclone: Multi-backend file sync — 70+ backends, Debian 12 packaged, ARM confirmed
- pytest 8 + Vitest: Testing — ecosystem standards, Vite-native Vue testing

### Expected Features

**Must have (table stakes) — missing these means the platform is considered outdated or unsafe:**
- CSRF protection on all state-changing AJAX/CGI endpoints
- Shell injection fixes in `admin.cgi` and `ajax-format_devices.cgi`
- Input sanitization — no raw `$_POST` writes to config files
- Remove `fatalsToBrowser` from 13 CGI scripts (stack traces to browser)
- Dark mode / light mode / classic theme toggle — every peer platform ships this
- Responsive layout replacing jQuery Mobile 1.4.0 (EOL 2021)
- jQuery 1.12.4 replacement — has known unfixed XSS CVEs since 2016
- Scheduled automatic backups with retention policy
- Full system backup covering config, plugins, and data
- SSL/TLS verification option for Miniserver connections
- Plugin install/uninstall without root shell injection risk

**Should have (differentiators within the Loxone ecosystem):**
- Miniserver config backup via Miniserver HTTP API (no other platform covers this)
- Backup to NAS/external storage as first-class core feature (not a plugin)
- MQTT Gateway health dashboard (active subscriptions, message rate, error tail)
- Python plugin scaffold for new-generation plugin developers
- Test coverage on core Perl/PHP modules (credibility signal for maintainers)
- Configurable backup retention policy (keep N copies, prune automatically)

**Defer to v2+:**
- MQTT Gateway health dashboard: blocked by gateway decomposition (1592-line monolith must be decomposed first)
- Full Python migration: scaffold only in initial roadmap; module-by-module migration is a long-horizon project
- Cloud backup destinations (S3, Nextcloud): NAS + local USB as v1; cloud as v2
- PWA installability: low-effort enhancement but not roadmap-blocking

**Anti-features — do not build:**
- Custom theme editor for end users (PROJECT.md explicit exclusion)
- Real-time device dashboard (that is HA/Loxone Visualizer's product)
- Docker/container layer (200 MB+ RAM overhead, breaks existing plugin architecture)
- Plugin marketplace (requires curation infrastructure the community cannot sustain)
- Breaking changes to Plugin SDK (hard constraint from PROJECT.md)
- Full rewrite in Python

### Architecture Approach

The target architecture is a layered strangler fig with five zones and Apache as the sole routing boundary. New paths go under `/admin/api/` to the Python service; existing `/admin/*.cgi` and `/admin/*.php` paths are never renamed. Python reads and writes the same JSON config files as Perl/PHP (using `filelock` to mirror Perl's `flock` behavior) — no separate database is introduced. Vue 3 components are mounted as islands within existing CGI-rendered pages during transition, then pages are migrated one at a time. Daemons (MQTT gateway, plugin installer, health check, system update) remain in Perl throughout this roadmap.

**Five architectural zones:**
1. **Apache Routing Layer** — auth (Basic Auth unchanged), URL dispatch (new vs legacy), TLS termination, static asset serving
2. **Python API Service (new)** — REST endpoints, config reads/writes, subprocess bridge to `sbin/` scripts for privileged ops
3. **Legacy CGI/PHP Layer (preserved)** — all existing admin pages, plugin admin UIs, JSON-RPC endpoint, template rendering
4. **Vue 3 Frontend (evolving)** — new UI components mounted as islands, theme system via CSS custom properties, calls both Zone 2 and Zone 3
5. **System Daemons (minimally changed)** — MQTT gateway, plugin installer, health check, system update — Perl throughout

**Key patterns to follow:**
- Apache as the strangler boundary: routing decisions in Apache config only, never in code
- Shared file system as integration bus: Python reads/writes same JSON files as Perl/PHP with matching file locking
- Subprocess bridge for privileged operations: Python API never runs as root; calls existing `sbin/` scripts with existing sudoers rules
- One page per PR for frontend migration: old page stays accessible until new page is confirmed
- Design token isolation: all theme tokens in one `themes.css` file using CSS custom properties on `[data-theme]`

### Critical Pitfalls

1. **Breaking the plugin contract (CRITICAL)** — Any change to `LoxBerry::System`, `LoxBerry::IO`, `LoxBerry::Log`, `LoxBerry::JSON`, or the PHP equivalents silently breaks community plugins. No automated tests currently catch this. Before touching any shared lib, document the full public API surface and treat every signature change as a breaking change requiring a deprecation cycle.

2. **CSRF protection breaking plugin AJAX callers (CRITICAL)** — Adding CSRF to `ajax-generic.php` and `ajax-generic2.php` breaks plugin UIs that call these endpoints without CSRF tokens. The existing `Satisfy Any` localhost bypass is actively used by plugins for programmatic calls. Add CSRF behind a feature flag first; provide an `X-LoxBerry-API: 1` bypass header for server-side callers; do not remove `Satisfy Any` until an API key replacement is available.

3. **Big-bang frontend rewrite (CRITICAL)** — Attempting jQuery Mobile removal in one phase produces an unmergeable PR. The strangler fig is the only viable approach: Vue 3 islands in existing pages, one page migrated per PR, jQuery stays loaded until the last plugin-facing page is confirmed jQuery-free. Vue build toolchain must never run on the Pi — OOM risk on 1 GB; build artifacts pre-compiled in CI and committed as static files.

4. **Dual-runtime maintenance divergence (HIGH)** — Adding Python alongside Perl/PHP without explicit decommission triggers results in three implementations of the same logic (already present with `general.cfg`/`general.json` dual-format). Each Python module added must deprecate its Perl/PHP equivalent in the same PR with a concrete removal date. Define the Python config/logging/IPC surface before writing any Python scripts.

5. **Scope creep causing PR rejection (HIGH)** — Core maintainers are unpaid volunteers with limited review bandwidth. A PR that fails the "30-minute review" test sits unreviewed or is rejected. One concern per PR. Security fix only. Refactor only. Never "also fixed X while I was in there." Use stacked PRs for sequential changes.

6. **`plugininstall.pl` path traversal before new features (HIGH)** — The `$pfolder` path traversal risk (lines 458, 471) must be fixed before any new functionality is added to the plugin install flow. This fix must be the first PR in the Security Hardening phase.

7. **Vue build step on the Pi (HIGH)** — `npm run build` on a 1 GB Pi consumes ~500 MB RAM and OOMs. Build artifacts must be committed to the repo or generated in CI and deployed as static files. Node.js is never a runtime dependency on the Pi.

---

## Implications for Roadmap

Based on the combined research, the following 7-phase structure respects all dependency chains, addresses the most critical risks first, and delivers visible progress early enough to build maintainer confidence.

### Phase 1: Security Hardening
**Rationale:** Fixes known critical vulnerabilities without changing architecture. Establishes proposal credibility before any structural changes. Maintainers will not accept structural PRs from an unknown contributor who has not demonstrated safety-first discipline.
**Delivers:** Patched shell injection in `admin.cgi` and `ajax-format_devices.cgi`; `plugininstall.pl` path traversal regex fix; `fatalsToBrowser` removed from 13 CGI scripts; SSL/TLS optional verification for Miniserver calls; CSRF protection (with plugin API bypass mechanism); JSON-RPC denylist converted to allowlist; `Satisfy Any` localhost bypass replaced with API key mechanism; `PassEnv` fix in SSL vhost.
**Features addressed:** CSRF protection, shell injection fixes, input sanitization foundations, SSL/TLS verification, structured error pages, plugin install security
**Pitfalls to avoid:** Pitfall 4 (CSRF breaking plugin AJAX) — coordinate bypass mechanism before enabling; Pitfall 9 (`plugininstall.pl` path traversal must be first PR); Pitfall 10 (JsonRPC denylist — convert to allowlist before adding new methods); Pitfall 5 (one concern per PR)
**Research flag:** Standard patterns — well-documented OWASP patterns, no deep research needed

### Phase 2: MQTT Gateway Optimization
**Rationale:** `mqttgateway_optimized.pl` already exists with 7 pre-prepared fixes. Merging it is a low-risk, high-credibility PR that improves a core daemon without architectural change. Also fixes the tmpfs log exhaustion risk (`Dumper` guard) before it causes production incidents.
**Delivers:** Optimized MQTT gateway with connection pooling, early filtering, and gated `Dumper` logging
**Features addressed:** MQTT reliability (prerequisite to future MQTT health dashboard)
**Pitfalls to avoid:** Pitfall 6 (tmpfs log exhaustion from ungated `Dumper` calls at DEBUG level)
**Research flag:** Standard patterns — existing optimized file in repo, no research needed

### Phase 3: Theme System
**Rationale:** Contained, visible change that touches only one new CSS file and one template. Proves the team can ship user-visible improvements without touching plugin APIs. Works for all pages including plugin pages because it operates through the `head.html` template — zero per-page CGI changes needed.
**Delivers:** Dark/light/classic theme toggle via CSS custom properties; `prefers-color-scheme` auto-detection; theme stored per-user in `general.json`; all existing and plugin pages inherit themes through the shared head template
**Stack elements:** CSS custom properties (native), Tailwind CSS 3.4 for new Vue components
**Features addressed:** Dark/light/classic theme (table stakes), CSS token foundation for all future Vue components
**Pitfalls to avoid:** Pitfall 2 (theme system requires jQuery migration to work cleanly — do not attempt full jQuery removal here, only add the CSS token layer)
**Research flag:** Standard patterns — CSS custom properties are well-documented W3C standard

### Phase 4: Code Cleanup
**Rationale:** Reduces noise and regression risk before introducing the Python API. A clean codebase is easier to instrument. `print STDERR` cleanup makes error logs readable. `general.cfg` shim removal eliminates the dual-format maintenance burden. Both are zero-behavior-change PRs that are easy to review.
**Delivers:** 63 `print STDERR` statements gated behind `$DEBUG` flag; `general.cfg` regeneration shim removed (after `sbin/loxberryupdate/` audit and pre-v3 migration script archival); `System_v1.pm` deprecated with warnings (after grep of known plugin repos); `linfo` version-pinned
**Pitfalls to avoid:** Pitfall 7 (`general.cfg` shim removal — must audit `sbin/loxberryupdate/` first for `general.cfg` references); Pitfall 1 (System_v1.pm — grep known plugin repos before deprecating)
**Research flag:** Standard patterns — no research needed

### Phase 5: Python API Foundation
**Rationale:** Introduces the Flask service and Apache proxy configuration with no new user-facing features — only the skeleton (health endpoint, system info read endpoint). Establishes Zone 2/Zone 3 boundary. Validates that Apache proxy routing works without disturbing existing routes. Defines the Python config, logging, and IPC surface before any feature code is written (preventing dual-runtime divergence).
**Delivers:** Flask service as systemd unit; Apache `ProxyPass /admin/api/` routing; `/api/v1/system/info` and `/api/v1/system/health` JSON endpoints; Python config module reading `general.json` with `filelock` mirroring Perl's `flock`; Python logging module; internal Python SDK surface spec published
**Stack elements:** Flask (initial; upgrade path to FastAPI documented), `filelock`, `python-dotenv` for `LBHOMEDIR`
**Architecture component:** Zone 2 (Python API Service) established
**Pitfalls to avoid:** Pitfall 3 (define Python SDK surface before writing scripts; set decommission dates for any Perl/PHP equivalents); Anti-Pattern 5 (never run Python API as root)
**Research flag:** Needs review of Flask vs FastAPI RAM decision at planning time — if backup streaming requirements are confirmed for Phase 6, migrate directly to FastAPI here rather than starting with Flask

### Phase 6: Backup Feature
**Rationale:** First real user-facing feature in Zone 2. Entirely new functionality — no legacy replacement required, so no regression risk to existing pages. The Miniserver-specific backup scope is the strongest differentiator in the Loxone ecosystem. Includes a Vue 3 component embedded in the existing CGI page, demonstrating the island-mounting pattern before the full frontend migration phase.
**Delivers:** System backup (config + plugins + data) with local and NAS destinations; Miniserver config backup via Miniserver HTTP API; scheduled backups via APScheduler 3.x with SQLite job store; configurable retention policy; Vue 3 backup UI component mounted in existing CGI page; backup streaming (no full backup in RAM); rclone integration for NAS/SMB destinations
**Stack elements:** Flask/FastAPI, APScheduler 3.11.2, rclone, Python `tarfile`/`shutil` stdlib, Vue 3 component (island pattern)
**Features addressed:** System backup, scheduled backups, retention policy, Miniserver config backup, NAS backup destination
**Pitfalls to avoid:** Pitfall 9 (path traversal fix in `plugininstall.pl` must be merged before backup hooks that touch plugin install flow); backup I/O must stream, never buffer full backup in RAM
**Research flag:** Needs phase research — Miniserver HTTP API for config backup needs API documentation review; NAS credential storage encryption approach needs validation

### Phase 7: Vue 3 Frontend Migration (incremental)
**Rationale:** Highest effort, lowest risk when done one page at a time. By this phase, the API layer is established, the theme system is in place (Vue components inherit tokens automatically), and the island-mounting pattern has been proven in Phase 6. Start with read-only dashboard widgets, then settings pages, deferring complex multi-step flows (plugin install wizard) until last.
**Delivers:** Pages migrated one per PR; legacy CGI pages remain accessible throughout; Pinia store for global state; Vue Router SPA shell for migrated pages; jQuery removal deferred until last plugin-facing page is confirmed jQuery-free
**Stack elements:** Vue 3 + Vite 8 (CI-built, artifacts committed), Pinia 3, Vue Router 4, Naive UI 2.x, Tailwind 3.4, Vitest
**Architecture component:** Zone 4 (Vue 3 Frontend) fully activated
**Pitfalls to avoid:** Pitfall 2 (one page per PR; no big-bang jQuery Mobile removal); Pitfall 8 (Vite build in CI only — never on Pi); Anti-Pattern 4 (jQuery stays loaded until last plugin-facing page is confirmed clean)
**Research flag:** Needs phase research — CI pipeline for pre-building Vue assets needs setup; jQuery Mobile coexistence migration guide review recommended

### Phase 8: Developer Experience
**Rationale:** Once the Python API has grown through Phases 5-7, extract common patterns into a formal `loxberry` Python package. Add test coverage to core Perl/PHP modules. Publish the Python plugin scaffold for new plugin authors. This phase cements the long-term developer story.
**Delivers:** `libs/pythonlib/loxberry/` importable Python modules (config, logging, plugin DB); pytest coverage for `LoxBerry::System`, `LoxBerry::IO`, `LoxBerry::Log`; Python plugin scaffold with example and documentation; GitHub Actions CI running tests automatically
**Features addressed:** Test infrastructure, Python migration scaffold
**Pitfalls to avoid:** Pitfall 1 (core module tests must cover the regression surface for all other phases — they are the safety net); Pitfall 3 (Python SDK must reflect patterns already proven in Phases 5-7, not be speculative)
**Research flag:** Standard patterns for pytest, GitHub Actions — no research needed

### Phase Ordering Rationale

- **Security before architecture:** Maintainers will not merge structural changes from a contributor who has not demonstrated safety-first discipline. Phases 1-2 build credibility.
- **Theme before Python API:** The theme system is contained and visible. It proves the team ships incrementally without breaking plugins. It also lays the CSS token foundation that all Phase 7 Vue components inherit automatically.
- **Code cleanup before Python API:** Reduces the noise and technical debt that would otherwise complicate reading and instrumenting the codebase for the API integration.
- **API skeleton before features:** Phase 5 establishes the Zone 2/Zone 3 boundary and validates Apache proxy routing with a zero-feature skeleton. Phase 6 then adds real features on proven infrastructure.
- **Backup before full frontend migration:** Backup is a self-contained new feature with no legacy replacement risk. It also provides the first real Vue 3 island component to validate the coexistence pattern before committing to a full frontend migration.
- **Frontend migration last among core phases:** Highest effort, but by Phase 7 the team has API endpoints, theme tokens, and the island-mounting pattern proven. The risk profile is as low as it can be.
- **Developer experience last:** Phase 8 formalizes patterns that only become clear after implementing Phases 5-7. Extracting a Python SDK before those phases would produce a speculative API.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 5 (Python API Foundation):** Flask vs FastAPI decision must be finalized at planning time based on confirmed Phase 6 backup streaming requirements. If streaming/WebSocket is confirmed, start with FastAPI directly rather than migrating later.
- **Phase 6 (Backup Feature):** Miniserver HTTP API documentation needs review to confirm config backup endpoint availability and authentication method. NAS credential storage encryption approach needs validation before implementation.
- **Phase 7 (Vue 3 Frontend Migration):** CI pipeline configuration for pre-building Vite assets and committing to the repo needs concrete setup plan. jQuery Mobile coexistence migration guide review recommended before first page migration PR.

Phases with standard patterns (skip deep research):
- **Phase 1 (Security Hardening):** OWASP CSRF, shell injection fixes, and input sanitization are well-documented with canonical references.
- **Phase 2 (MQTT Optimization):** Pre-prepared optimized file already exists in repo.
- **Phase 3 (Theme System):** CSS custom properties are W3C standard; implementation pattern is documented.
- **Phase 4 (Code Cleanup):** Mechanical cleanup; no architectural decisions.
- **Phase 8 (Developer Experience):** pytest, GitHub Actions, and Python packaging are well-documented.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Vue 3 locked in by codebase; Vite 8 / Pinia 3 verified on official sources; Tailwind 3.4 vs v4 decision well-documented; FastAPI/Flask both verified on piwheels and ARM |
| Features | HIGH | Table stakes verified against HA 2025/2026, ioBroker, OpenHAB official docs; differentiators based on direct codebase gap analysis |
| Architecture | HIGH (current) / MEDIUM (migration patterns) | Current architecture from direct codebase analysis; strangler fig patterns from 2025 sources; jQuery/Vue coexistence confirmed by multiple migration guides |
| Pitfalls | HIGH (project-specific) / MEDIUM (ecosystem) | Project-specific pitfalls derived from direct codebase analysis of CONCERNS.md and code review; ecosystem patterns from web research |

**Overall confidence:** HIGH — stack decisions are locked in or well-constrained by hardware and existing codebase; feature priorities are validated against peer platform research; pitfalls are grounded in actual identified code issues rather than speculative risks.

### Gaps to Address

- **Flask vs FastAPI RAM decision:** ARCHITECTURE.md recommends Flask (~50 MB idle) while STACK.md recommends FastAPI (~140 MB idle). This gap must be resolved in Phase 5 planning by confirming whether backup streaming in Phase 6 requires async I/O. If yes, start with FastAPI. If no, start with Flask.
- **Naive UI per-component bundle size:** STACK.md notes MEDIUM confidence on comparative gzip size vs alternatives. This only matters if the Vue bundle becomes a performance issue; monitor during Phase 7 and switch components if needed.
- **Miniserver HTTP API availability for config backup:** The Miniserver config backup differentiator (Phase 6) depends on the Loxone Miniserver exposing a config download endpoint via HTTP. This needs verification against current Miniserver firmware documentation before the Phase 6 spec is written.
- **Plugin author coordination for CSRF bypass:** Phase 1 CSRF protection requires coordinating an `X-LoxBerry-API` bypass mechanism with the plugin author community before the feature is enabled by default. The coordination plan needs to be part of the Phase 1 spec.
- **Browser floor for deployed LoxBerry instances:** Tailwind v4 was ruled out due to unknown browser diversity. If the community can confirm all active users are on 2023+ browsers, Tailwind v4 becomes viable for a future phase.

---

## Sources

### Primary (HIGH confidence)
- Vue GitHub Releases — v3.5.30 confirmed stable; Composition API patterns
- Vite releases page (vite.dev) — Vite 8.0.0 confirmed current; Rolldown bundler
- Pinia Introduction (pinia.vuejs.org) — v3.x Vue 3-only confirmed; Vuex maintenance-mode
- Tailwind CSS v4 Compatibility Docs — Chrome 111+/Safari 16.4+/Firefox 128+ hard minimum confirmed
- FastAPI on PyPI — v0.135.1, Python >=3.10 confirmed; piwheels ARM wheel availability confirmed
- APScheduler on PyPI — v3.11.2, Python >=3.8 confirmed
- rclone official site — 70+ backends, Debian 12 packaged
- Apache 2.4 Reverse Proxy Guide — ProxyPass configuration patterns
- OWASP CSRF Prevention Cheat Sheet — canonical CSRF reference
- Home Assistant 2025.1 and 2026.2 release notes — backup and theme feature benchmarks
- LoxBerry codebase: `.planning/codebase/CONCERNS.md` and `.planning/codebase/ARCHITECTURE.md` — direct code analysis

### Secondary (MEDIUM confidence)
- Better Stack Flask vs FastAPI — RAM comparison benchmarks (50 MB vs 140 MB idle)
- Strangler Fig pattern — Laminas Project 2025 guidance for PHP monolith migrations
- jQuery to Vue 3 coexistence migration guides — island-mounting pattern validation
- ioBroker.backitup adapter (GitHub) — peer platform backup scope reference
- CSS Variables Guide 2025 (frontendtools.tech) — design token implementation patterns
- Downgrading from Tailwind v4 post-mortem (Medium) — real-world v4 stability concerns

### Tertiary (LOW confidence)
- OpenHAB community migration discussions — incremental upgrade pattern reference
- jQuery maintainers deprecation announcement 2021 — jQuery Mobile EOL confirmation

---

*Research completed: 2026-03-15*
*Ready for roadmap: yes*
