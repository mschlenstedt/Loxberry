# Domain Pitfalls

**Domain:** Embedded Smart Home Platform Modernization (Raspberry Pi / CGI / Plugin Ecosystem)
**Project:** LoxBerry NeXtGen
**Researched:** 2026-03-15
**Confidence:** HIGH (project-specific pitfalls derived from actual codebase analysis) / MEDIUM (ecosystem patterns from web research)

---

## Critical Pitfalls

Mistakes that cause rewrites, community rejection, or permanent plugin ecosystem damage.

---

### Pitfall 1: Breaking the Plugin Contract Without an Explicit Compatibility Matrix

**What goes wrong:** A change to any of the shared Perl modules (`LoxBerry::System`, `LoxBerry::IO`, `LoxBerry::Log`, `LoxBerry::JSON`) or the PHP library (`loxberry_system.php`, `loxberry_web.php`, `loxberry_io.php`) silently breaks third-party plugins that were never updated for the new behavior. Because there are no automated tests for these modules, regressions are only discovered after user reports.

**Why it happens:** The shared libs are used by every plugin author. Authors read old documentation, copy scaffold code, and rely on undocumented behaviors (env var names, JSON key names, log path conventions). Any rename, path change, or semantic shift in a function that "nobody calls directly" turns out to be called by a dozen plugins in the wild.

**Concrete risk in this codebase:** `LoxBerry/System_v1.pm` still ships, meaning some plugin out there may `use LoxBerry::System_v1`. Removing it without an audit would silently break that plugin. Similarly, `lbplogdir` in `JsonRpcApi.php` returns a wrong path (`logs/plugins/` vs `log/plugins/`); fixing this bug is the right thing to do, but it will silently break any JavaScript client that currently works around the bug by not using the RPC call.

**Consequences:** Community trust erosion. If the first PR from this modernization effort breaks plugins, the proposal will be rejected by core maintainers and the community will be hostile to further changes.

**Prevention:**
1. Before modifying any shared lib function, grep the entire codebase AND document all known plugin API surface in a `PLUGIN_API.md` contract document.
2. Treat any change to public function signatures, return values, environment variable names, file paths, or JSON key names as a breaking change requiring a deprecation cycle.
3. For the `JsonRpcApi.php` path bug: fix it AND add a compatibility alias that returns both `log` and `logs` values, or document the fix with a migration note for plugin authors.
4. Archive `System_v1.pm` to a non-lib path only after confirming zero callers in known plugin repos.

**Detection (warning signs):**
- A PR touches `libs/perllib/LoxBerry/` or `libs/phplib/loxberry_*.php` without a corresponding test addition.
- A PR removes or renames any function, environment variable, or config key.
- A PR changes file paths used by plugins (`log/plugins/`, `config/plugins/`, `data/plugins/`).

**Phase mapping:** Every phase. Must be checked before merge on any phase that touches shared libs. Highest risk in: Security Hardening (changing AJAX handlers), Frontend Migration (changing JS API surface), Python Migration (replacing Perl modules).

---

### Pitfall 2: The Big-Bang Frontend Rewrite Freeze

**What goes wrong:** The team decides to migrate all jQuery/jQuery Mobile UI to Vue 3 in one phase. This requires touching every HTML template, every `.js` file, every AJAX handler simultaneously. The result is a multi-month branch that cannot be merged as incremental PRs, falls out of sync with upstream `mschlenstedt/Loxberry`, and is ultimately rejected by maintainers as too large to review.

**Why it happens:** jQuery Mobile's widget model (data attributes, page events, `$.mobile.changePage`) is so deeply embedded in templates that it feels impossible to remove incrementally. Teams convince themselves "we'll just replace everything at once."

**Concrete risk in this codebase:** jQuery Mobile 1.4.0 (abandoned 2021) and jQuery 1.12.4 (EOL 2016) are intertwined at every `<div data-role="page">` boundary. Vue 3 is already partially present (`vue3.js` exists) but clearly not yet wired into the main layout. The coexistence period is real, and if not managed deliberately it becomes permanent.

**Consequences:** Unmergeable PR, months of wasted work, stalled modernization. If the PR does get merged through pressure, the resulting code is fragile because jQuery Mobile's page lifecycle and Vue's reactivity model both assume DOM ownership and will conflict.

**Prevention:**
1. Never attempt full jQuery Mobile removal in a single PR.
2. Use the "strangler fig" pattern: introduce Vue 3 components as islands within the existing jQuery Mobile shell. Each page gets migrated independently.
3. Start with the highest-traffic, most self-contained pages (e.g., the main dashboard overview, not the plugin install wizard which has complex multi-step state).
4. Defer jQuery Mobile page-routing removal until ALL pages are Vue-native. The routing shell can stay until last.
5. Build the Vue components to work without a build step initially (CDN `vue3.js` is already present). Avoid requiring Vite/Node.js on the Pi itself — build artifacts should be committed or generated in CI and deployed as static files.

**Detection (warning signs):**
- A PR modifies more than 10 template files simultaneously.
- A PR introduces `import` / `export` ES modules without a corresponding bundler setup in CI.
- `npm run build` is required as a deployment step on the Pi itself (a 1 GB Pi will OOM during Vite builds).

**Phase mapping:** Frontend Migration phase. Must be explicitly scoped to one page/section at a time. Likely needs a "migration scaffold" sub-phase before any UI work starts.

---

### Pitfall 3: Python Migration Creates a Dual-Runtime Maintenance Burden Without an Exit Strategy

**What goes wrong:** New Python scripts are added alongside existing Perl/PHP scripts. Both runtimes handle the same domain (e.g., config reading, MQTT, health checks). After 6 months there are three implementations of "read general.json" — in Perl, PHP, and Python — that each have subtly different behavior around edge cases (missing keys, encoding, file locking). A bug is fixed in one and silently remains in the other two.

**Why it happens:** Incremental migration is the right strategy, but "incremental" needs an explicit decommission trigger for each migrated unit. Without that trigger, the old code never gets removed.

**Concrete risk in this codebase:** `general.cfg` / `general.json` dual-format is exactly this pattern already. The config was "migrated" to JSON at v2.0.2 but the old `.cfg` regeneration shim is still running on every save four years later. A Python migration without deliberate decommission planning will reproduce this pattern at the runtime level.

**Prevention:**
1. For every Python module added, the corresponding PR must also deprecate the Perl/PHP equivalent (add a `# DEPRECATED: replaced by <python_module>` header and a log warning on invocation).
2. Set a concrete decommission date in the PR description: "Perl version removed in Phase X."
3. Define the Python SDK surface before writing any Python scripts. Agree on: config file reading pattern, logging pattern, IPC pattern. Publish as an internal spec so all Python additions follow the same contract.
4. Never have Python call Perl via subprocess for anything that will become a long-lived pattern. Subprocess calls are fine for one-shot migration shims; they are a maintenance trap if they become the permanent IPC mechanism.
5. Keep both runtimes out of the same code path for the same request. A PHP page that calls a Python subprocess that reads a JSON config that was also read by Perl is untestable.

**Detection (warning signs):**
- The same config file is read by scripts in more than two languages.
- A Python script's primary interface is `subprocess.run(["some.pl", ...])`.
- After 3 months, no Perl scripts have been decommissioned despite Python replacements existing.

**Phase mapping:** Python Migration phase. The exit-strategy spec must be written before the first Python script is added, not discovered afterward.

---

### Pitfall 4: Security Fixes Break Authenticated Plugin Workflows

**What goes wrong:** Adding CSRF protection to AJAX endpoints breaks plugin UIs that call those endpoints directly from JavaScript without a CSRF token. The plugin authors cannot update their code before the fix ships. Result: every plugin with a config page goes broken on update, users roll back, the security fix is reverted.

**Why it happens:** The existing `webfrontend/htmlauth/.htaccess` `Satisfy Any` pattern means plugins running on localhost can call admin endpoints with no auth at all. Plugins have been written relying on this. Adding CSRF tokens to those endpoints breaks those calls.

**Concrete risk in this codebase:**
- `ajax-generic.php` and `ajax-generic2.php` are called by plugin UIs. Adding CSRF protection here is correct but must be coordinated with a migration path.
- The `Satisfy Any` localhost bypass is used by plugins making programmatic API calls. Removing it without an alternative (API key, session token, service account) will break those integrations.
- The `testenvironment` action in `ajax-config-handler.cgi` must be removed, but if any plugin has it wired in for debugging, that plugin breaks silently.

**Prevention:**
1. Before adding CSRF protection, document every AJAX endpoint and whether it is part of the "public plugin API" surface.
2. Add CSRF protection behind a feature flag first, let plugin authors test against it, then enable by default.
3. Provide an opt-out header (`X-LoxBerry-API: 1`) for server-side plugin callers that cannot embed a browser token, with documentation that human-browser requests still require the token.
4. The `Satisfy Any` removal should be preceded by a formal plugin API for programmatic access (API key or equivalent) — do not remove it until the replacement is available.
5. Security PRs must include a "plugin compatibility impact" section.

**Detection (warning signs):**
- A security PR is submitted without a corresponding test against the plugin scaffold.
- CSRF token implementation does not have a documented server-to-server bypass mechanism.
- The PR removes `Satisfy Any` without adding any alternative auth path for localhost callers.

**Phase mapping:** Security Hardening phase. Every security fix must be categorized as "UI-only safe" vs "plugin-API impacting" before merging.

---

### Pitfall 5: Proposal Rejection Due to Scope Creep in Individual PRs

**What goes wrong:** A PR intended as "security fix for admin.cgi shell injection" also refactors the password change flow, updates error messages, changes log format, and removes a deprecated function. Core maintainers see an unreviable PR and either request a split (delaying the security fix) or reject it outright as too risky.

**Why it happens:** When working in a complex legacy codebase, it is tempting to fix related issues you notice while touching a file. In an upstream-proposal context, this is fatal because each PR must be independently reviewable, independently revertable, and low-risk to the areas it does not touch.

**Consequences specific to LoxBerry:** The project targets `mschlenstedt/Loxberry` with PRs. The core maintainers are unpaid volunteers with limited review bandwidth. A PR that requires understanding 500 lines of diff across 15 files will sit unreviewed indefinitely.

**Prevention:**
1. One concern per PR. Security fix = security fix only. Log cleanup = log cleanup only.
2. Each PR must have a stated rollback procedure: "reverting this PR only affects X."
3. Refactoring PRs (dead code removal, duplicate handler merge) must be explicitly labeled as "zero-behavior-change" and supported by a before/after test.
4. PRs that cannot pass a "could a volunteer review this in 30 minutes?" test should be split.
5. Use a stacked PR strategy: security fix lands first, refactor lands second on top of it.

**Detection (warning signs):**
- A PR diff spans more than 5 files on a first-pass security or bugfix.
- A PR description says "also fixed X while I was in there."
- No rollback procedure is documented.

**Phase mapping:** All phases. Especially: Security Hardening (high temptation to combine), Code Cleanup (should be many tiny PRs, not one giant one).

---

## Moderate Pitfalls

### Pitfall 6: tmpfs Log Exhaustion Under Heavy Debug Logging

**What goes wrong:** During development or testing, DEBUG log level is left enabled on one or more plugins. On a 1 GB Pi, the tmpfs at `log/system_tmpfs/` fills available RAM, causing the entire system to OOM-kill processes — including the MQTT gateway or Apache — in the middle of normal operation.

**Why it happens:** The MQTT gateway already logs `Dumper($cfg)` unconditionally at DEBUG level (line 862 in `mqttgateway.pl`). If the gateway is restarted after a config change, and DEBUG is on, a single restart can produce megabytes of log output.

**Prevention:**
1. Gate `Dumper()` calls behind `if ($LoxBerry::Log::DEBUG)` — this specific fix is already identified in CONCERNS.md.
2. The MQTT performance PR must include this fix as a prerequisite.
3. `healthcheck.pl` already flags plugins running at DEBUG level; ensure the health check alert is visible in the UI and documented as a warning to address.
4. Set a hard tmpfs size limit in the OS configuration and document it.

**Detection (warning signs):** System slowdown after config changes. `df -h` showing tmpfs >80% full. Health check warnings for DEBUG-level plugins that have been ignored.

**Phase mapping:** MQTT Gateway Optimization phase (fix the Dumper guard). Security/Hardening phase (ensure health check warnings are surfaced prominently).

---

### Pitfall 7: The `general.cfg` Shim Removal Breaks Update Scripts

**What goes wrong:** The `general.cfg` regeneration shim is removed as part of the config cleanup. This is correct. However, update scripts `updatereboot_v1.2.0.pl` through `updatereboot_v3.0.0.pl` still read `general.cfg` directly. An admin who upgrades from an older LoxBerry version runs those migration scripts, which silently fail to read config because `general.cfg` no longer exists.

**Why it happens:** The dependency is invisible — migration scripts are not in the regular call path, so they are not caught by running the system normally.

**Concrete risk:** Identified directly in CONCERNS.md. The scripts reference `general.cfg` and will produce silent failures.

**Prevention:**
1. Before removing the shim, audit every file in `sbin/loxberryupdate/` for `general.cfg` references.
2. Old migration scripts (pre-v3.0) can be archived (moved to `sbin/loxberryupdate/archive/`). Any installation path that starts below v3.0 is effectively unsupported. Document this assumption.
3. If migration scripts must be kept, add a compatibility shim that generates `general.cfg` from `general.json` on demand (read-only, no writes needed) specifically for the update path.

**Detection (warning signs):** Any PR that removes `recreate-generalcfg` without first auditing `sbin/loxberryupdate/`.

**Phase mapping:** Code Cleanup phase, specifically the config format consolidation task.

---

### Pitfall 8: Vue 3 Build Step Introduced on the Pi Itself

**What goes wrong:** The frontend build toolchain (Vite, Node.js `npm run build`) is configured to run on the target Raspberry Pi device as part of the update/install process. On a 1 GB Pi, a Vite build consumes ~500 MB of RAM and takes several minutes. On low-memory devices, the build process OOMs and leaves the frontend in a broken half-built state.

**Why it happens:** Developers build on powerful workstations where this is never an issue. The deployment documentation says "run `npm run build`" and nobody tests this on actual hardware.

**Prevention:**
1. Build artifacts (compiled Vue JS/CSS) must be committed to the repository or generated in CI and shipped as static files. The Pi never runs `npm` in production.
2. Vue components should initially use the CDN/global `Vue` object via the already-present `vue3.js` file, avoiding any build step requirement until the project has CI infrastructure that pre-builds assets.
3. Node.js must never be a runtime dependency on the Pi. Only static HTML/CSS/JS is served.

**Detection (warning signs):** A PR adds `package.json`, `vite.config.js`, or any `npm run` step to the deployment documentation without a corresponding CI build pipeline that pre-compiles assets.

**Phase mapping:** Frontend Migration phase. This constraint must be stated explicitly in the phase spec before any Vue component work begins.

---

### Pitfall 9: `plugininstall.pl` Path Traversal Not Fixed Before New Plugin Features

**What goes wrong:** The `$pfolder` path traversal risk in `plugininstall.pl` (lines 458, 471) is known but unfixed. If new features are added to the plugin install flow (e.g., backup integration) before this is fixed, the new features inherit the vulnerability and compound the attack surface.

**Why it happens:** Security fixes feel lower priority than features. The install path is rarely exercised in testing.

**Consequences:** A crafted plugin archive with a `PLUGIN.FOLDER` value like `../../` that survives the `tr` filter could delete unintended directories on uninstall.

**Prevention:**
1. The `$pfolder` strict regex validation (`[A-Za-z0-9_-]{1,64}`, non-empty check) must be merged before any PR adds new functionality to `plugininstall.pl`.
2. This should be the first PR in the Security Hardening phase, not the last.

**Detection (warning signs):** Any PR that adds functionality to `plugininstall.pl` or `pluginuninstall.pl` without first merging the regex validation fix.

**Phase mapping:** Security Hardening phase, first PR in that phase.

---

### Pitfall 10: JsonRPC Denylist Expansion Races Feature Development

**What goes wrong:** `JsonRpcApi.php` exposes all `LBSystem::*` and `LBWeb::*` methods via JSON-RPC to authenticated callers, protected only by a denylist. New methods added to `LBSystem` during modernization (e.g., backup management, new config APIs) are automatically exposed to any authenticated caller before the denylist is updated.

**Why it happens:** The denylist is updated reactively, not proactively. Developers adding a new `LBSystem::backup_create()` method do not think to update the JSON-RPC denylist.

**Prevention:**
1. Convert the denylist to an allowlist before any new `LBSystem` methods are added. The allowlist approach means new methods are unexposed by default.
2. This conversion must happen as a dedicated PR in the Security Hardening phase, not deferred.
3. After conversion, every PR that adds a new `LBSystem` method must explicitly decide whether to add it to the allowlist, with a documented rationale.

**Detection (warning signs):** A PR adds new `LBSystem::*` or `LBWeb::*` methods without updating the JSON-RPC access control. The denylist is still in use after the Security Hardening phase is complete.

**Phase mapping:** Security Hardening phase, early PR.

---

## Minor Pitfalls

### Pitfall 11: Accumulated Debug `print STDERR` Masking Real Errors

**What goes wrong:** 63 unconditional `print STDERR` statements (including `miniserver.cgi` printing a banner on every request) fill the Apache error log with noise. When a real error occurs, it is buried. During the modernization, developers grep error logs to debug their changes and miss genuine problems.

**Prevention:** Gate all `print STDERR` behind a `$DEBUG` flag as a dedicated cleanup PR early in the process. This PR is zero-behavior-change and very reviewable.

**Phase mapping:** Code Cleanup phase, one of the first PRs.

---

### Pitfall 12: SQLite Notification Database Write Contention Under Parallel Plugin Activity

**What goes wrong:** Multiple plugins run simultaneously and each inserts a notification via `LoxBerry::Log`. SQLite in default journal mode causes write lock contention. `LoxBerry::Log` uses `Carp::croak` on insert failure, meaning a lock contention error in a plugin's log write crashes the plugin's main thread with an unhandled fatal.

**Prevention:**
1. Enable WAL mode on `notifications.db` (one-time `PRAGMA journal_mode=WAL` call in the database initialization code).
2. Add retry logic (3 attempts, 50ms sleep) in `LoxBerry::Log`'s notification insert before `croak`.
3. Degrade gracefully: log-write failures should warn, not crash.

**Phase mapping:** Performance Optimization phase.

---

### Pitfall 13: SSL VHost Missing `PassEnv` Variables Causes Silent CGI Failures on HTTPS

**What goes wrong:** `001-default-ssl.conf` is missing `PassEnv LBPHTMLAUTH` and `PassEnv LBSHTMLAUTH`. Any admin using the HTTPS vhost (which should be the recommended path after SSL hardening) will find CGI scripts silently receiving empty values for these environment variables, producing confusing access control failures that look like auth bugs.

**Prevention:** Add the two missing `PassEnv` lines to the SSL vhost as a prerequisite to the SSL/TLS hardening PR. This is a one-line fix but must precede any "encourage HTTPS use" recommendation.

**Phase mapping:** Security Hardening phase, prerequisite to SSL verification enablement.

---

### Pitfall 14: `linfo` Vendored Tool Produces Wrong Data on Newer Kernels

**What goes wrong:** The vendored `linfo` system info library has self-annotated `POTENTIALLY BUGGY` sections and is not version-pinned. As LoxBerry runs on newer Raspberry Pi OS versions (Bookworm+), kernel interface changes cause `linfo` to return incorrect or missing system information on the system info page.

**Prevention:** Pin to a specific upstream `linfo` release tag. Consider replacing the system info page functionality with direct `/proc` parsing or a lightweight Python equivalent as part of the Python migration.

**Phase mapping:** Code Cleanup phase (pin version). Python Migration phase (optional replacement).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Security Hardening (CSRF) | Breaks plugin AJAX callers | Add server-to-server bypass header; coordinate with plugin authors before enabling |
| Security Hardening (Satisfy Any removal) | Breaks localhost plugin API calls | Replace with API key mechanism first |
| Security Hardening (shell injection admin.cgi) | Low risk to plugin ecosystem, safe to fix | Use `system LIST` form; straightforward PR |
| Security Hardening (JsonRPC denylist) | New features expose new methods | Convert to allowlist before adding new LBSystem methods |
| Frontend Migration (jQuery Mobile) | Big-bang rewrite attempt | Page-by-page strangler fig; no build step on Pi |
| Frontend Migration (Vue build toolchain) | npm/Vite on Pi OOMs | Pre-build in CI; serve static artifacts only |
| Python Migration (first scripts) | Dual-runtime maintenance divergence | Define Python SDK surface contract first; set decommission dates |
| Python Migration (config handling) | Three implementations of general.json read | Write a single Python config module; deprecate Perl/PHP callers explicitly |
| MQTT Optimization | Fragile monolithic loop; changes break routing | Add integration tests before any refactor; fix Dumper guard first |
| Code Cleanup (general.cfg shim) | Breaks update migration scripts | Audit sbin/loxberryupdate/ first; archive pre-v3 scripts |
| Code Cleanup (System_v1.pm removal) | Unknown plugin callers | Grep known plugin repos; add deprecation warning before removal |
| Backup Feature (new core feature) | Plugin install path inherits path traversal risk | Fix plugininstall.pl regex validation before adding backup hooks |
| Test Infrastructure | Tests added for new code only | Core module tests (LoxBerry::System, IO, Log) must be added first; they are the regression safety net for all other phases |
| PR Submission to Upstream | Scope creep causes rejection | One concern per PR; 30-minute review test; explicit rollback procedure |

---

## Sources

- Project codebase analysis: `.planning/codebase/CONCERNS.md` (HIGH confidence — direct code inspection)
- Project requirements: `.planning/PROJECT.md` (HIGH confidence)
- jQuery Mobile deprecation: [jQuery maintainers deprecate jQuery Mobile (2021)](https://blog.jquery.com/2021/10/07/jquery-maintainers-continue-modernization-initiative-with-deprecation-of-jquery-mobile/) (HIGH confidence)
- Incremental jQuery-to-Vue migration patterns: [Incrementally migrating a legacy jQuery web application to Vue.js](https://medium.com/infraspeak/incrementally-migrating-a-legacy-jquery-web-application-to-a-vue-js-spa-ecbd6671beee) (MEDIUM confidence)
- Vue 3 production deployment (no-build CDN mode): [Vue.js Quick Start](https://vuejs.org/guide/quick-start) (HIGH confidence)
- Strangler fig and branch-by-abstraction for language migrations: [The ABCs of language migration — Increment](https://increment.com/programming-languages/language-migration/) (MEDIUM confidence)
- Open source PR dynamics and maintainer acceptance: [Best Practices for Maintainers — Open Source Guides](https://opensource.guide/best-practices/) (MEDIUM confidence)
- Node.js ARM architecture constraints on older Pi hardware: [Raspberry Pi Forums — Node.js build options](https://forums.raspberrypi.com/viewtopic.php?t=102074) (MEDIUM confidence — architecture constraint for armv6 devices; armv7/arm64 Pi 3/4 are fine)
- ESPHome breaking change patterns (Python version drop, framework EOL): [ESPHome 2025.8.0 Changelog](https://esphome.io/changelog/2025.8.0/) (MEDIUM confidence — reference for how smart home platforms handle deprecation cycles)
- OpenHAB migration community experience (incremental upgrade recommended over big-bang): [openHAB Community migration discussions](https://community.openhab.org/t/migrating-from-openhab-3-0-to-home-assistant/137552) (LOW confidence — community discussion, not authoritative documentation)
