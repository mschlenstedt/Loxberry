# Feature Landscape

**Domain:** Smart Home Platform Administration (Raspberry Pi / LoxBerry)
**Researched:** 2026-03-15
**Confidence:** HIGH for table stakes (verified against HA 2025/2026, ioBroker, OpenHAB); MEDIUM for differentiators (community signals + platform comparisons)

---

## Table Stakes

Features users expect in a 2025/2026 admin platform. Missing = users consider the platform outdated or unsafe.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Dark mode / light mode toggle | Every major platform (HA 2026.2, RPi OS, ioBroker admin) now ships dark mode. Users expect it system-wide, not just on dashboards. | Low | CSS variable theming already partially exists; needs consistent token application |
| CSRF protection on all state-changing endpoints | OWASP baseline for any admin web app in 2025. HA, OpenHAB, ioBroker all implement it. LoxBerry is the only one missing it. | Medium | Affects all files in `htmlauth/system/ajax/` and `admin.cgi`. Must cover form POSTs and AJAX. SameSite=Lax cookies + synchronizer token is the standard pattern. |
| Input sanitization / no raw `$_POST` → config file writes | Without field validation, any authenticated user can inject arbitrary config data. This is a baseline expectation, not a hardening extra. | Medium | Currently `ajax-generic.php` writes `$_POST` directly. Field-level schema validation needed before JSON persistence. |
| No shell injection via user inputs | Shell metacharacter injection in passwords and device paths is a critical fail for any system presented as production-ready. | Low-Med | Perl `system LIST` form or pass via ENV/STDIN. Specific files: `admin.cgi`, `ajax-format_devices.cgi`. |
| Scheduled automatic backups | ioBroker auto-backs up before every adapter update. HA 2025.1 ships nightly/weekly scheduling with 3-click wizard. Users treat manual-only backup as a risk. | Medium | Core feature, not a plugin. Cron-driven. Needs UI flow for schedule, retention count, and destination selection. |
| System backup includes configs, plugins, and data | HA's "full backup" covers all integrations + config. ioBroker.backitup covers DBs, scripts, and device configs. Users expect "restore everything from one file." | High | Needs inventory of what to include: `/config/`, `/data/plugins/`, `/log/`, MQTT config, Miniserver credentials, not tmpfs. |
| Responsive layout (mobile + desktop) | Web-first admin should not break on a tablet or phone. jQuery Mobile was the original answer to this — it is now end-of-life and the answer is CSS Grid/Flexbox. | Medium | jQuery Mobile 1.4.0 (abandoned 2021) must be replaced. Vue 3 already partially present. |
| No EOL JavaScript dependencies in production UI | jQuery 1.12.4 has known XSS CVEs unfixed since 2016. Any security audit will flag this as a blocker. | Medium | Already identified in CONCERNS.md. Blocking item for community proposal credibility. |
| SSL/TLS verification option for Miniserver connections | All HTTP calls to Miniservers currently use `SSL_verify_mode => 0`. This is a silent MITM vulnerability. Users who care about security expect at minimum an opt-in for verification. | Low-Med | Needs CA trust path support for Loxone self-signed certs. Optional flag in Miniserver config per-device is sufficient. |
| Structured error pages (no stack traces to browser) | `fatalsToBrowser` in 13 CGI scripts sends file paths, variable values, and module versions to the browser. Every serious web framework suppresses this by default. | Low | Remove `fatalsToBrowser`; log server-side only. Replace with generic error page. |
| Plugin install/uninstall without root shell injection risk | `plugininstall.pl` uses user-controlled folder names in `rm -rf` commands. Any platform that allows third-party plugins must sanitize this path rigorously. | Low | Regex enforce `[A-Za-z0-9_-]{1,64}` before any filesystem op. |

---

## Differentiators

Features that would set LoxBerry NeXtGen apart from both the current LoxBerry and comparable platforms. Not universally expected, but meaningfully valued by the target user base.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Miniserver config backup (Loxone-native) | No other open platform targets Loxone Miniserver specifically. Automatic backup of the Miniserver's own XML config gives users a safety net the Loxone ecosystem itself does not provide natively to hobbyists. | High | Requires Miniserver HTTP API to pull config. Scheduled. Versioned (keep N copies). Tied to Miniserver profile in `general.json`. |
| Pre-built themes (dark, light, classic LoxBerry) | HA's theme market is overwhelming — users spend hours finding "the right" theme. 3-4 opinionated, polished presets with system-preference detection is a better experience than a theme marketplace or an editor. | Low-Med | CSS custom properties for token-based theming. `prefers-color-scheme` media query for auto. Theme stored per-user in session or localStorage. |
| Backup to NAS / external via built-in UI (no plugin needed) | HA before 2025.1 required third-party add-ons (Samba Backup, etc.) for NAS backup. Making this a first-class core feature with UI-driven configuration reduces friction significantly. ioBroker.backitup is a popular third-party adapter precisely because the core didn't cover this. | Med-High | Support SMB/CIFS (NAS) and local USB storage as V1 targets. Cloud (S3, Nextcloud) as V2. Credentials stored encrypted in config. |
| MQTT Gateway health dashboard | No other platform surfaces internal MQTT routing metrics in the admin UI. LoxBerry's MQTT gateway is a differentiating feature — making it observable (active subscriptions, message rate, transform errors, last-seen) turns it from a black box into a manageable component. | High | Requires exposing metrics from the gateway process. Lightweight status endpoint or named pipe. Not a full metrics stack — just key counts and error log tail. |
| Incremental Python migration as a developer story | Documenting and scaffolding the Perl → Python migration path makes LoxBerry attractive to a new generation of plugin developers who know Python but not Perl. ioBroker uses Node.js adapters; HA uses Python integrations — Python-native plugins would align LoxBerry with modern expectations. | Med | A "new plugin in Python" scaffold with example and docs is the deliverable. Not a full rewrite. |
| Test coverage for core modules (demonstrated, not complete) | None of the comparable platforms prominently feature test coverage as a selling point because they assume it. For LoxBerry, showing even 60-70% coverage on `LoxBerry::System`, `LoxBerry::IO`, and `plugininstall.pl` would be a significant differentiator in the proposal — it signals maturity. | Med-High | Perl: Test::More + TAP. PHP: PHPUnit. Focus on the modules identified in CONCERNS.md test coverage gaps. |
| Configurable backup retention policy | HA 2025.1 ships this. ioBroker.backitup ships this. LoxBerry currently has no backup system at all. Being on-par with the industry standard at launch (keep N copies, prune automatically) while adding Loxone-specific backup scope is a differentiator within the Loxone ecosystem. | Low | Retention count setting in backup config. Prune oldest on creation of new backup exceeding limit. |

---

## Anti-Features

Things to deliberately not build. Building these would waste time, add complexity, or undermine the project's goals.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom theme editor for end users | PROJECT.md explicitly ruled this out. A live CSS editor adds maintenance burden, can produce broken UIs, and is not what Loxone-ecosystem users need. HA has one; it is widely criticized for producing fragile themes. | 3-4 polished presets with CSS variables. Users who want custom themes can edit the CSS file directly. |
| Real-time dashboard (sensor values, device states) | This is Home Assistant's core product. LoxBerry is an administration layer, not a runtime dashboard. Building live device state views would mean competing with HA/Loxone Visualizer and distracting from the admin mission. | Keep the admin UI focused on system management. Link to Loxone Visualizer for runtime dashboards. |
| Cloud account / user management / SaaS component | Nabu Casa (HA Cloud) exists because HA invested years in the architecture. Building a cloud sync or remote-access service for LoxBerry is out of scope for a community proposal and introduces GDPR/hosting obligations. | Document how to use Cloudflare Tunnel, VPN, or reverse proxy for remote access. |
| Docker / container layer for the system itself | LoxBerry runs on a 1 GB Raspberry Pi. Docker adds ~200 MB RAM overhead per container and significant operational complexity. HA's Docker-based addon system only works because HAOS manages it end-to-end. LoxBerry's plugin system cannot be safely containerized without breaking all existing plugins. | Keep plugins as processes. Harden `plugininstall.pl` path sanitization and sudo rules instead. |
| Breaking changes to the Plugin SDK / API | PROJECT.md's hardest constraint. Any new APIs must be additive. Deprecation without a multi-version grace period destroys the community plugin ecosystem. | Add Python scaffold as new, optional. Keep Perl/PHP scaffold intact. Mark deprecated functions with warnings, not removals. |
| Full rewrite in Python | Every line rewritten is a regression risk and a compatibility gap. The community won't accept a "works for most things" release. | Incremental migration: new features in Python, existing Perl/PHP remains until a module-by-module migration plan proves stability. |
| Mobile app (iOS/Android) | Web-first is the right call for an admin interface on a home server. Building and maintaining a native app for a niche platform is not a viable community effort. | Ensure responsive web UI works well on mobile browsers. PWA installability (manifest + service worker) as a low-effort enhancement if desired. |
| Plugin marketplace / store | A curated marketplace requires moderation, code review, CI/CD infrastructure, and hosting. ioBroker and HA have paid teams for this. LoxBerry's community is too small for this now. | Keep the existing wiki-based plugin directory. Improve plugin discovery through better metadata in `plugin.cfg` and a searchable web list. |
| Full log viewer with search/filter in the admin UI | Log management tools (Grafana Loki, ELK, etc.) do this far better than any bespoke log viewer. Building a passable one takes significant effort and produces a subpar experience. | Surface the last N lines per plugin in the existing log UI. Link to log files directly. Keep `log_maint.pl` rotation working. |

---

## Feature Dependencies

```
CSRF Protection
  └── Requires: session management (currently HTTP Basic Auth only — must add server-side session state or use Double-Submit Cookie pattern)
  └── Blocks: input sanitization completeness (sanitizing without CSRF is incomplete defense)

Theme System
  └── Requires: jQuery/jQuery Mobile migration (theming jQuery Mobile pages and Vue 3 components with the same token system is not feasible while both coexist)
  └── Requires: CSS custom property audit across all admin pages

System Backup
  └── Requires: backup destination configuration UI
  └── Requires: plugin inventory API (to know what to include)
  └── Blocks: Miniserver config backup (reuses the same scheduler and destination system)

Scheduled Backups
  └── Requires: System Backup core (scheduler wraps the backup action)
  └── Requires: Retention policy logic

Miniserver Config Backup
  └── Requires: SSL/TLS verification option (backup pulls credentials — should not do so over unverified TLS)
  └── Requires: Miniserver HTTP connectivity (already in LoxBerry::IO)

MQTT Gateway Health Dashboard
  └── Requires: MQTT Gateway refactor (monolith must expose a status channel — not feasible to instrument 1592-line single loop without first decomposing it)
  └── Is blocked by: mqttgateway.pl refactor phase

Python Migration Scaffold
  └── Requires: Python SDK wrapper for LoxBerry::System equivalents (get_miniservers, loglevels, paths)
  └── Does NOT require: Perl removal (additive only)

Test Infrastructure
  └── Requires: CI setup (GitHub Actions or similar) to run tests automatically
  └── Blocks nothing, but should precede any large refactor to catch regressions

Shell Injection Fixes
  └── Requires: audit of all `qx(...)` and `system(...)` calls with user input
  └── Is a prerequisite for: proposal credibility (security auditors check these first)
```

---

## MVP Recommendation

The minimum that makes this a credible proposal to the core developers:

**Phase 1 (Security Foundation) — Prioritize:**
1. CSRF protection on all state-changing AJAX/CGI endpoints (HIGH impact, no UI work)
2. Shell injection fixes in `admin.cgi` and `ajax-format_devices.cgi` (specific, bounded, LOW risk)
3. Remove `fatalsToBrowser` from 13 CGI scripts (LOW effort, HIGH credibility signal)
4. SSL/TLS optional verification for Miniserver calls (LOW effort, MEDIUM security gain)

**Phase 2 (Frontend Modernization) — Next:**
5. jQuery 1.12.4 replacement (MEDIUM effort, removes critical CVEs, enables theming)
6. Theme system: dark / light / classic with CSS custom properties (LOW-MED effort, HIGH user visibility)

**Phase 3 (Backup System) — Core New Feature:**
7. System backup (config + plugins + data) with local and NAS destinations
8. Scheduled backups with retention policy
9. Miniserver config backup (after SSL fix is in place)

**Phase 4 (Developer Experience):**
10. Test infrastructure for core Perl/PHP modules
11. Python plugin scaffold

**Defer:**
- MQTT Gateway health dashboard: requires gateway decomposition first — too large for initial proposal phases
- Full Python migration: multi-phase, long-horizon work; scaffold only in Phase 4
- Input sanitization completeness: deep work, deliver incrementally per-endpoint alongside CSRF

---

## Sources

- Home Assistant 2025.1 backup overhaul: https://www.home-assistant.io/blog/2025/01/03/3-2-1-backup/ (HIGH confidence — official release notes)
- Home Assistant 2025.2 backup iteration: https://www.home-assistant.io/blog/2025/02/05/release-20252/ (HIGH confidence)
- Home Assistant 2026.2 UI/theme redesign: https://www.home-assistant.io/blog/2026/02/04/release-20262/ (HIGH confidence)
- Home Assistant app security model: https://developers.home-assistant.io/docs/apps/security/ (HIGH confidence — official dev docs)
- ioBroker.backitup adapter: https://github.com/simatec/ioBroker.backitup (MEDIUM confidence — community adapter, widely used)
- OpenHAB security documentation: https://www.openhab.org/docs/installation/security.html (MEDIUM confidence)
- OWASP CSRF Prevention Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html (HIGH confidence — canonical security reference)
- MDN CSRF prevention: https://developer.mozilla.org/en-US/docs/Web/Security/Practical_implementation_guides/CSRF_prevention (HIGH confidence)
- ioBroker vs OpenHAB vs HA comparison: https://dev.to/selfhostingsh/openhab-vs-iobroker-which-to-self-host-1jf1 (LOW confidence — single community article, corroborates other findings)
- Home Assistant frontend architecture: https://developers.home-assistant.io/docs/frontend/architecture/ (HIGH confidence — official dev docs)
- LoxBerry plugin permissions: https://loxwiki.atlassian.net/wiki/spaces/LOXEN/pages/1370096143/Permissions+Loxberry+plugins (MEDIUM confidence — official wiki but last update date unclear)
