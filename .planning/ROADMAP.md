# Roadmap: LoxBerry NeXtGen

## Overview

Eight phases of incremental modernization for a Perl/PHP CGI monolith running on a 1 GB Raspberry Pi. The strategy is a strangler fig: grow new layers around the existing system one PR at a time, never break the plugin SDK contract, and ship visible improvements early to build credibility with volunteer maintainers. Security hardening comes first to establish trust before any structural change is proposed. Each phase is designed to produce one or more independently submittable PRs, each reviewable in under 30 minutes.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Security Hardening** - Fix critical vulnerabilities to establish proposal credibility before any structural change
- [ ] **Phase 2: MQTT Gateway Optimization** - Merge pre-prepared performance fixes into the core daemon
- [ ] **Phase 3: Theme System** - Ship a visible, contained UI improvement via CSS custom properties
- [ ] **Phase 4: Code Cleanup** - Reduce technical debt and dual-format maintenance burden before introducing Python
- [ ] **Phase 5: Python API Foundation** - Establish the Flask service and Apache proxy skeleton with zero user-facing features
- [ ] **Phase 6: Backup Feature** - Deliver Miniserver config backup and full system backup as the first real Zone 2 feature
- [ ] **Phase 7: Vue 3 Frontend Migration** - Replace jQuery Mobile page-by-page using the island-mounting pattern
- [ ] **Phase 8: Developer Experience and Infrastructure** - Formalize the Python SDK, add test coverage, and complete Debian 13 support

## Phase Details

### Phase 1: Security Hardening
**Goal**: All known critical vulnerabilities are patched and the codebase is safe to extend
**Depends on**: Nothing (first phase)
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, SEC-06, SEC-07
**Success Criteria** (what must be TRUE):
  1. Admin password changes via admin.cgi no longer pass credentials on the command line — no shell injection vector exists
  2. Accessing an admin CGI that crashes does not display a Perl stack trace in the browser — a structured error page is shown instead
  3. The JsonRPC endpoint rejects all methods not on the explicit allowlist — unknown method names return an error response
  4. A plugin's AJAX call to ajax-generic.php from localhost continues to work after CSRF tokens are enabled — the API bypass mechanism is active
  5. Miniserver SSL/TLS verification can be switched on per Miniserver in the admin UI without editing config files
**Plans**: TBD

Plans:
- [ ] 01-01: Shell injection fix — admin.cgi and plugininstall.pl path validation
- [ ] 01-02: fatalsToBrowser removal and structured error pages (13 CGI scripts)
- [ ] 01-03: CSRF token implementation with plugin API bypass mechanism
- [ ] 01-04: JsonRPC denylist to allowlist conversion
- [ ] 01-05: SSL/TLS optional verification + input sanitization in ajax-generic.php

### Phase 2: MQTT Gateway Optimization
**Goal**: The MQTT gateway runs with measurably lower CPU and memory overhead using the pre-prepared optimizations
**Depends on**: Phase 1
**Requirements**: PERF-01, PERF-03
**Success Criteria** (what must be TRUE):
  1. The optimized MQTT gateway is the active daemon — mqttgateway_optimized.pl replaces the original
  2. High-frequency message bursts no longer produce unbounded log growth — Dumper calls are gated behind a DEBUG flag
  3. CloudDNS resolution does not make a file-read call on every usage within a request — the result is cached for the request lifetime
**Plans**: TBD

Plans:
- [ ] 02-01: Merge mqttgateway_optimized.pl with connection pooling, early filtering, vorkompilierte Regexes
- [ ] 02-02: CloudDNS in-request caching + gated Dumper debug logging

### Phase 3: Theme System
**Goal**: Every page in the admin UI — including plugin pages — respects the user's chosen theme without per-page CGI changes
**Depends on**: Phase 1
**Requirements**: UI-01, UI-02, UI-03, UI-05
**Success Criteria** (what must be TRUE):
  1. The admin UI offers a theme toggle (light, dark, classic, auto) accessible from every page — the choice persists across browser sessions
  2. A plugin's admin page inherits the active theme without any change to the plugin's own code
  3. The admin UI is usable without horizontal scrolling on a 375px-wide mobile screen
  4. Navigation grouping is logical and consistent — related settings are under one menu entry, not scattered
**Plans**: TBD

Plans:
- [ ] 03-01: CSS custom properties theme layer in head.html + Tailwind CSS 3.4 integration
- [ ] 03-02: Theme toggle UI, auto detection via prefers-color-scheme, persistence in general.json
- [ ] 03-03: Responsive layout fixes and navigation restructuring

### Phase 4: Code Cleanup
**Goal**: The codebase has no dual-format maintenance burden and no noise that would complicate reading or instrumenting it for the Python API
**Depends on**: Phase 3
**Requirements**: INF-04, PERF-02
**Success Criteria** (what must be TRUE):
  1. Error logs contain no debug noise by default — print STDERR output only appears when a DEBUG flag is set
  2. No code reads or writes general.cfg — all callers use general.json directly
  3. Loading LoxBerry::System emits a deprecation notice pointing to the replacement module — no silent use of the legacy API
**Plans**: TBD

Plans:
- [ ] 04-01: Gate all print STDERR statements behind $DEBUG flag (63 occurrences)
- [ ] 04-02: Remove general.cfg regeneration shim — migrate remaining callers to general.json
- [ ] 04-03: Deprecate System_v1.pm, merge ajax-generic2.php into ajax-generic.php, archive dead code

### Phase 5: Python API Foundation
**Goal**: A Flask service runs as a systemd unit behind Apache with working proxy routing and zero user-facing features
**Depends on**: Phase 4
**Requirements**: INF-03
**Success Criteria** (what must be TRUE):
  1. GET /admin/api/v1/system/health returns a JSON response — the Python service is reachable through Apache
  2. Existing /admin/*.cgi and /admin/*.php URLs continue to work unchanged after Apache proxy config is added
  3. The Python config module reads general.json with file locking that matches Perl's flock behavior — no race conditions with existing Perl/PHP writers
**Plans**: TBD

Plans:
- [ ] 05-01: Flask skeleton as systemd service + Apache ProxyPass /admin/api/ configuration
- [ ] 05-02: Python config module (general.json + filelock), logging module, /api/v1/system/info and health endpoints

### Phase 6: Backup Feature
**Goal**: Users can back up their Miniserver configuration and the full LoxBerry system to local or NAS storage on a schedule
**Depends on**: Phase 5
**Requirements**: BAK-01, BAK-02, BAK-03, BAK-04, BAK-05, BAK-06
**Success Criteria** (what must be TRUE):
  1. A user can trigger a Miniserver config backup from the admin UI and download the resulting archive — no SSH or command-line access required
  2. A scheduled full system backup runs automatically at the configured interval — config, plugins, and data are all included in the archive
  3. Backup jobs targeting a NAS share (SMB) complete successfully — credentials are stored encrypted, not in plaintext
  4. The backup history page shows the last N completed backups with timestamps, sizes, and destinations — a user can trigger a restore from this page
  5. A full system backup completes on a 1 GB Raspberry Pi without running out of memory — the archive streams to disk rather than buffering in RAM
**Plans**: TBD

Plans:
- [ ] 06-01: Miniserver config backup via Miniserver HTTP API — Flask endpoint + Vue 3 island component
- [ ] 06-02: Full system backup engine — tarfile streaming, plugin/config/data scope
- [ ] 06-03: APScheduler integration — scheduled jobs, SQLite job store, configurable intervals
- [ ] 06-04: NAS/SMB backup destinations via rclone + encrypted credential storage
- [ ] 06-05: Backup history UI — status, restore trigger, admin page integration

### Phase 7: Vue 3 Frontend Migration
**Goal**: The admin UI pages are progressively migrated to Vue 3 components, with jQuery Mobile removed from all migrated pages
**Depends on**: Phase 6
**Requirements**: UI-04
**Success Criteria** (what must be TRUE):
  1. At least the system overview, general settings, and network settings pages are served as Vue 3 SPA pages — jQuery Mobile is not loaded on those pages
  2. Legacy CGI pages that have not yet been migrated remain fully functional throughout the migration — no page is removed before its replacement is confirmed working
  3. Plugin admin pages continue to load and function correctly — no plugin is broken by partial jQuery removal
  4. The Vue build step runs in CI only — Node.js is not installed on the Pi and build artifacts are committed as static files
**Plans**: TBD

Plans:
- [ ] 07-01: CI pipeline for Vite 8 build — artifact commit workflow, Vitest setup
- [ ] 07-02: Vue Router SPA shell + Pinia store — island mounting infrastructure
- [ ] 07-03: System overview and general settings pages migrated to Vue 3
- [ ] 07-04: Network settings and remaining high-traffic admin pages migrated
- [ ] 07-05: jQuery removal audit — confirm clean on all migrated pages, document plugin-facing jQuery dependencies

### Phase 8: Developer Experience and Infrastructure
**Goal**: The Python SDK is formalized, core modules have test coverage, and the system installs cleanly on Debian 13 Trixie
**Depends on**: Phase 7
**Requirements**: INF-01, INF-02, INF-05, DX-01, DX-02
**Success Criteria** (what must be TRUE):
  1. A plugin author can import loxberry.config and loxberry.log in a Python plugin without reading source code — a published PLUGIN_API.md documents the frozen SDK surface
  2. The pytest suite covers LoxBerry::System, LoxBerry::IO, and LoxBerry::Log — a PR that accidentally breaks any public method causes a CI failure
  3. LoxBerry installs without errors on a fresh Debian 13 Trixie image with PHP 8.3 — packages13.txt exists and the installer selects the correct package list automatically
  4. The install script completes on both Debian 12 Bookworm and Debian 13 Trixie with a single command — no manual OS detection required
**Plans**: TBD

Plans:
- [ ] 08-01: Debian 13 Trixie compatibility — packages13.txt, PHP 8.3 validation, install script dual-support
- [ ] 08-02: pytest coverage for LoxBerry::System, LoxBerry::IO, LoxBerry::Log + GitHub Actions CI
- [ ] 08-03: Python SDK package — loxberry.config, loxberry.log, loxberry.plugin_db as importable modules
- [ ] 08-04: PLUGIN_API.md frozen SDK surface documentation + DX-02 Python decommission schedule

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Security Hardening | 0/5 | Not started | - |
| 2. MQTT Gateway Optimization | 0/2 | Not started | - |
| 3. Theme System | 0/3 | Not started | - |
| 4. Code Cleanup | 0/3 | Not started | - |
| 5. Python API Foundation | 0/2 | Not started | - |
| 6. Backup Feature | 0/5 | Not started | - |
| 7. Vue 3 Frontend Migration | 0/5 | Not started | - |
| 8. Developer Experience and Infrastructure | 0/4 | Not started | - |
