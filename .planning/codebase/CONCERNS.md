# Codebase Concerns

**Analysis Date:** 2026-03-15

---

## Tech Debt

**Dual Config Format (general.cfg vs general.json):**
- Issue: The system migrated from INI-format `general.cfg` to `general.json` at v2.0.2, but a legacy sync mechanism still writes `general.cfg` from JSON on every save. A `recreate-generalcfg` call is triggered in `ajax-generic.php` (line 199) and `ajax-generic2.php` (line 190) every time `general.json` changes.
- Files: `webfrontend/htmlauth/system/ajax/ajax-generic.php`, `webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi`, `libs/perllib/LoxBerry/System_v1.pm`
- Impact: Every config save triggers an extra subprocess. Old update scripts `sbin/loxberryupdate/updatereboot_v1.2.0.pl` through `updatereboot_v3.0.0.pl` still read `general.cfg` directly, meaning they will silently fail if `general.cfg` is ever removed.
- Fix approach: Remove `System_v1.pm` dependency on `general.cfg` (line 673 still reads it), retire the recreate-generalcfg hook once all callers migrate to `general.json`.

**Versioned Legacy System Module:**
- Issue: `libs/perllib/LoxBerry/System_v1.pm` (VERSION 2.0.0.3) still ships alongside `System.pm` (VERSION 3.0.0.7). The old module reads `general.cfg` and exposes a `$lbcgidir` variable (labelled "Legacy variable" in its own POD). No callers currently use it, but its presence creates confusion.
- Files: `libs/perllib/LoxBerry/System_v1.pm`, `libs/perllib/LoxBerry/System.pm`
- Impact: Maintenance overhead; risk of a plugin accidentally requiring the old module.
- Fix approach: Archive `System_v1.pm` outside the active lib path.

**Duplicate AJAX Generic Handlers:**
- Issue: `ajax-generic.php` and `ajax-generic2.php` are near-identical files (functionally equivalent with minor divergence at lines 119/190). Both implement the same `checkPath`, `check_empty_array`, and `startsWith` functions.
- Files: `webfrontend/htmlauth/system/ajax/ajax-generic.php`, `webfrontend/htmlauth/system/ajax/ajax-generic2.php`
- Impact: Bug fixes must be applied to both files; divergence has already begun (line 119 vs 119–123).
- Fix approach: Merge into a single handler; retire `ajax-generic2.php`.

**Accumulated Update Migration Scripts:**
- Issue: 60+ versioned update scripts exist in `sbin/loxberryupdate/` (from `update_v0.3.1.pl` through `update_v3.0.1.2.pl`). The oldest scripts reference Debian Jessie/Stretch/Buster and use `apt-key` (deprecated since Debian Bullseye). Some use `wget http://` over plain HTTP to fetch apt keys.
- Files: `sbin/loxberryupdate/update_v1.4.1.pl` (line 64), `sbin/loxberryupdate/update_v2.0.0.pl` (line 33), `sbin/loxberryupdate/update_v2.0.2.pl` (lines 19–20)
- Impact: Plain HTTP key downloads are vulnerable to MITM; `apt-key` calls will fail on Bookworm+.
- Fix approach: Old one-shot migration scripts can be archived after confirming no install path starts below that version. Remove remaining `apt-key` calls.

**Duplicated Debug `print STDERR` Statements:**
- Issue: 63 unconditional `print STDERR` statements found across CGI scripts in `webfrontend/htmlauth/system/`. Many are not gated by any debug flag. `miniserver.cgi` line 29 prints `Execute miniserver.cgi\n######################\n` on every request.
- Files: `webfrontend/htmlauth/system/miniserver.cgi`, `webfrontend/htmlauth/system/admin.cgi`, and others.
- Impact: Fills Apache error log; masks real errors; causes noise during log analysis.
- Fix approach: Gate with a `$DEBUG` flag or remove entirely.

**Commented-Out Dead Code:**
- Issue: Multiple blocks of commented-out code exist throughout the codebase (e.g., `JsonRpcApi.php` lines 152–161, `ajax-config-handler.cgi` line 310, `loxberry_system.php` lines 20–27). These are not guarded by debug flags or version notes.
- Files: `libs/phplib/LoxBerry/JsonRpcApi.php`, `webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi`, `libs/phplib/loxberry_system.php`
- Impact: Clutters code; can mislead future developers.
- Fix approach: Remove confirmed dead code; use version control history as reference.

---

## Known Bugs

**POST Language Detection Reads Wrong Superglobal:**
- Symptoms: When `lang` is submitted via HTTP POST, `LBSystem::lblanguage()` reads from `$_GET["lang"]` instead of `$_POST["lang"]`, silently returning null and falling back to the system default language.
- Files: `libs/phplib/loxberry_system.php` line 150
- Trigger: Any form or AJAX POST that includes a `lang` parameter.
- Workaround: Pass `lang` as a GET parameter instead.

**Wrong Log Directory Path in JsonRpcApi:**
- Symptoms: `getdirs()` in `JsonRpcApi.php` returns `lbplogdir` as `LBHOMEDIR . '/logs/plugins/' . $plugindir` (note: `logs` plural), while the actual directory and all other code uses `log` (singular).
- Files: `libs/phplib/LoxBerry/JsonRpcApi.php` line 132; correct path defined at `libs/phplib/loxberry_system.php` line 48
- Trigger: Any JavaScript client using the JsonRPC `getdirs` call to obtain the plugin log path will receive a non-existent directory.
- Workaround: None; callers must hard-code the correct path.

**`testenvironment` Action Exposed in Production AJAX Handler:**
- Symptoms: `ajax-config-handler.cgi` contains a `testenvironment` action (lines 387–399) that runs `sudo .../testenvironment.pl` and dumps HTML output including environment variable values. This is reachable via authenticated HTTP requests.
- Files: `webfrontend/htmlauth/system/ajax/ajax-config-handler.cgi` lines 387–399
- Trigger: POST `action=testenvironment` to `/admin/system/ajax/ajax-config-handler.cgi`.
- Workaround: None; remove the action.

---

## Security Considerations

**Shell Injection via Password Parameters in admin.cgi:**
- Risk: User-supplied passwords are interpolated directly into shell command strings using `qx(...)`. For example: `qx(sudo .../credentialshandler.pl checkpasswd 'loxberry' '$adminpassold')`. A password containing `'` followed by shell metacharacters could break out of the single-quoted argument.
- Files: `webfrontend/htmlauth/system/admin.cgi` lines 247, 311, 327, 336, 353, 368
- Current mitigation: Single-quote wrapping provides partial protection; the `check_securepin` call occurs before some of these invocations.
- Recommendations: Pass passwords via STDIN or environment variables rather than command-line arguments; or use Perl's `system LIST` form to avoid shell interpretation.

**SSL Certificate Verification Disabled for Miniserver HTTP Calls:**
- Risk: All HTTP calls to Loxone Miniservers via `LoxBerry::IO::mshttp_call` (IO.pm line 299) have `SSL_verify_mode => 0` and `verify_hostname => 0` hardcoded. `mshttp_call2` defaults to the same values (line 340). This enables MITM interception of credentials and commands sent to Miniservers.
- Files: `libs/perllib/LoxBerry/IO.pm` lines 299, 340, 359; `libs/phplib/loxberry_io.php` lines 248–249; `bin/mqtt/transform/shipped/udpin/generic/http2mqtt.php` lines 72–73; `sbin/setloxberryid.pl` line 84
- Current mitigation: Connections are typically LAN-internal.
- Recommendations: Enable verification at least optionally; document the risk; provide a CA trust path for self-signed Miniserver certificates.

**`fatalsToBrowser` Leaks Internal Stack Traces:**
- Risk: 13 CGI scripts use `CGI::Carp qw(fatalsToBrowser)`, which sends Perl die/confess output directly to the browser response. This reveals file system paths, variable values, and module versions on any unhandled exception.
- Files: `webfrontend/htmlauth/system/admin.cgi`, `webfrontend/htmlauth/system/miniserver.cgi`, `webfrontend/htmlauth/system/plugininstall.cgi`, `webfrontend/htmlauth/system/updates.cgi`, `webfrontend/htmlauth/system/translate.cgi`, `webfrontend/htmlauth/system/tools/changehostname.cgi`, `webfrontend/htmlauth/system/tools/netscan.cgi`, `webfrontend/htmlauth/system/tools/smtptest.cgi`, and others.
- Current mitigation: All these scripts require HTTP Basic Auth; attacker must be authenticated.
- Recommendations: Replace `fatalsToBrowser` with structured error page rendering; log stack traces server-side only.

**JsonRPC Endpoint Exposes All PHP/LBSystem/LBWeb Functions:**
- Risk: `webfrontend/htmlauth/system/jsonrpc.php` exposes any global function, `LBSystem::*`, or `LBWeb::*` method to authenticated callers via JSON-RPC. The blocklist in `JsonRpcApi.php` (PREVENTED_FUNCTIONS constant) is a denylist strategy, which is weaker than an allowlist. New functions added to LBSystem/LBWeb are automatically exposed.
- Files: `libs/phplib/LoxBerry/JsonRpcApi.php` lines 55–108, `webfrontend/htmlauth/system/jsonrpc.php`
- Current mitigation: HTTP Basic Auth protects the endpoint. Denylist includes common dangerous PHP functions.
- Recommendations: Convert to an explicit allowlist of permitted methods; at minimum verify that no sensitive data-returning functions are inadvertently callable.

**jsonrpc.php Logs All Request/Response Payloads:**
- Risk: `error_log("Received: $jsonquery")` (line 30) and `error_log("Reply from JsonRpc Server: $reply")` (line 47) log full request bodies and responses to the Apache error log. Payloads can include passwords or sensitive config values.
- Files: `webfrontend/htmlauth/system/jsonrpc.php` lines 30, 47
- Current mitigation: Apache error log is not world-readable on a properly configured system.
- Recommendations: Remove unconditional logging or gate it on a debug flag; never log request bodies containing credentials.

**HTTP Basic Auth Uses `Satisfy Any` with Localhost Bypass:**
- Risk: `webfrontend/htmlauth/.htaccess` uses `Satisfy Any`, which means any request from `localhost` or `127.0.0.1` bypasses HTTP Basic Auth entirely. Any process running on the LoxBerry system (including untrusted plugin code) can make unauthenticated requests to the admin interface.
- Files: `webfrontend/htmlauth/.htaccess` lines 6–9
- Current mitigation: Plugin installation requires SecurePIN; plugins run as `loxberry` user.
- Recommendations: Evaluate removing `Satisfy Any` or restricting it to specific admin endpoints only; note that `mod_access_compat` (`Order/Allow/Deny`) is deprecated in Apache 2.4.

**Plain HTTP Used for Cloud DNS Lookup:**
- Risk: Miniserver IP resolution via `http://{clouddnsaddress}/?getip&snr=...` is performed over plain HTTP (loxberry_system.php line 695). A network MITM could redirect Miniserver connections to a malicious host.
- Files: `libs/phplib/loxberry_system.php` line 695
- Current mitigation: LAN-internal network assumed.
- Recommendations: Switch to HTTPS; validate the Cloud DNS endpoint certificate.

---

## Performance Bottlenecks

**Synchronous `general.cfg` Regeneration on Every Config Write:**
- Problem: Every write through `ajax-generic.php` or `ajax-generic2.php` to `general.json` triggers a blocking `exec()` call to `ajax-config-handler.cgi action=recreate-generalcfg`, which itself spawns another process.
- Files: `webfrontend/htmlauth/system/ajax/ajax-generic.php` line 199, `webfrontend/htmlauth/system/ajax/ajax-generic2.php` line 190
- Cause: Legacy compatibility shim for old Perl config readers.
- Improvement path: Remove `general.cfg` dependency from all callers; delete the shim.

**MQTT Gateway Polls Config Files on Every Cycle:**
- Problem: `mqttgateway.pl` monitors config files with `File::Monitor` and re-reads all configuration on any change. During a config reload it logs `Dumper($cfg)` at DEBUG level (line 862), which serializes the entire config hash.
- Files: `sbin/mqttgateway.pl` lines 790–866
- Cause: `Data::Dumper` is unconditionally imported and LOGDEB is called without a guard.
- Improvement path: Gate `Dumper` call on `if($LoxBerry::Log::DEBUG)`.

**CloudDNS Cache Read on Every Miniserver HTTP Call:**
- Problem: `LBSystem::set_clouddns` reads and JSON-decodes the entire CloudDNS cache file on every call (loxberry_system.php lines 652–691), even when the cache entry is still fresh. No in-process caching is used.
- Files: `libs/phplib/loxberry_system.php` lines 640–730
- Cause: Stateless PHP request model; cache is stored in a tmpfs JSON file.
- Improvement path: Use APCu or a static class variable to cache the decoded object within a request lifetime.

---

## Fragile Areas

**plugininstall.pl Plugin Folder Name is User-Controlled:**
- Files: `sbin/plugininstall.pl` lines 458, 471
- Why fragile: `$pfolder` is read from the plugin's own `plugin.cfg` and sanitized via `tr/A-Za-z0-9_-//cd`. However, the same value is then used directly in `rm -rfv $lbhomedir/{config,data,log}/plugins/$pfolder/` (lines 1582–1608). A crafted plugin with a relative path component in `PLUGIN.FOLDER` that survives the `tr` filter could delete unintended directories.
- Safe modification: Validate `$pfolder` matches a strict regex of `[A-Za-z0-9_-]{1,64}` and is not empty before any filesystem operations.
- Test coverage: No automated tests found for the install/uninstall paths.

**Apache VHost SSL Config Missing Two `PassEnv` Declarations:**
- Files: `system/apache2/sites-available/001-default-ssl.conf`
- Why fragile: The SSL vhost is missing `PassEnv LBPHTMLAUTH` and `PassEnv LBSHTMLAUTH` compared to the HTTP vhost (`000-default.conf`). CGI scripts expecting these environment variables on HTTPS connections will silently receive an empty value.
- Safe modification: Add the two missing `PassEnv` lines to `001-default-ssl.conf`.
- Test coverage: None.

**mqttgateway.pl is a Single Monolithic Loop (1592 lines):**
- Files: `sbin/mqttgateway.pl`
- Why fragile: The entire MQTT gateway runs as one long event loop with 15+ `eval {}` blocks for error recovery. Config reloads, UDP socket handling, MQTT subscription management, HTTP forwarding, and transformer script execution are all interleaved. An exception in any path may leave the internal state inconsistent.
- Safe modification: Changes to any single responsibility (e.g., subscription filters) risk inadvertently affecting others. Trace data flow carefully; add integration tests before modifying.
- Test coverage: No tests found.

**healthcheck.pl Uses `no strict 'refs'` for Dynamic Check Dispatch:**
- Files: `sbin/healthcheck.pl` lines 9, 76 (dynamic function call via string reference)
- Why fragile: Check names are pushed to an `@checks` array as strings and executed via a symbolic reference. This means any typo in a check name, or a plugin providing a malformed `PLUGINDB_FOLDER` value, could result in calling an unintended function or a silent no-op.
- Safe modification: Validate each check name exists as a defined function before executing; add logging on lookup failure.
- Test coverage: No tests found.

**ajax-format_devices.cgi Passes User-Supplied Device Path to sudo:**
- Files: `webfrontend/htmlauth/system/ajax/ajax-format_devices.cgi` line 61
- Why fragile: The `$device` parameter is passed directly to `sudo .../format_device.pl $device`. While the endpoint requires auth, an authenticated attacker could supply an unexpected device path.
- Safe modification: Validate `$device` against a regex matching `/dev/sdX` or `/dev/mmcblkX` patterns before executing.
- Test coverage: None.

---

## Scaling Limits

**SQLite for Notification Database:**
- Current capacity: Single-file SQLite database at `data/system/notifications.db`. Suitable for the embedded Raspberry Pi context.
- Limit: Concurrent writes from multiple plugins or rapid notification bursts can cause lock contention. SQLite WAL mode is not confirmed as enabled.
- Scaling path: Enable WAL pragma; add retry logic in `LoxBerry::Log` notification insertion (currently uses `Carp::croak` on insert error at line 1373).

**Log Files on tmpfs:**
- Current capacity: System logs in `log/system_tmpfs/` are stored in RAM (tmpfs). On a Raspberry Pi with 1 GB RAM, heavy logging can exhaust available memory.
- Limit: Excessive DEBUG log level across plugins (flagged by `healthcheck.pl`) fills tmpfs faster.
- Scaling path: `log_maint.pl` provides rotation; ensure cron invocation is active.

---

## Dependencies at Risk

**jQuery 1.12.4 and jQuery Mobile 1.4.0 (End of Life):**
- Risk: Both are end-of-life with known XSS and prototype-pollution CVEs. jQuery 1.x has not received security updates since 2016.
- Impact: Any user-controlled data rendered through jQuery `.html()` or related methods in the system UI is potentially exploitable.
- Files: `webfrontend/html/system/scripts/jquery/jquery-1.12.4.min.js`, `webfrontend/html/system/scripts/jquery/js/jquery.mobile-1.4.0.min.js`
- Migration plan: Upgrade to jQuery 3.x; audit jQuery Mobile usage (project abandoned 2021) and migrate affected UI components to Vue 3, which is already partially adopted (`webfrontend/html/system/scripts/vue3/vue3.js`).

**`linfo` Third-Party System Info Tool (Vendored, Stale):**
- Risk: The `linfo` library at `webfrontend/htmlauth/system/tools/linfo/` is vendored directly into the repo with no version pinning. It contains multiple `TODO` and `POTENTIALLY BUGGY` comments in its own source.
- Impact: Stale system info parsers may produce incorrect data on newer kernel versions; no upstream security patches will be applied automatically.
- Files: `webfrontend/htmlauth/system/tools/linfo/src/`
- Migration plan: Pin to a specific upstream release; add composer/dependency management for PHP tools.

---

## Missing Critical Features

**No CSRF Protection on State-Changing Endpoints:**
- Problem: None of the AJAX CGI scripts or PHP handlers implement CSRF token validation. All state-changing POST requests (config write, plugin install, poweroff/reboot, password change) rely solely on HTTP Basic Auth.
- Blocks: A malicious page visited by an authenticated admin can trigger any admin action via a cross-origin form POST.
- Files: All files in `webfrontend/htmlauth/system/ajax/`; `webfrontend/htmlauth/system/admin.cgi`
- Priority: High — particularly critical for the reboot/poweroff and plugin install endpoints.

**No Input Sanitisation on `$_POST` Data Written to Config Files:**
- Problem: `ajax-generic.php` and `ajax-generic2.php` write `$_POST` data directly into JSON config files after only JSON-decoding them. No field-level validation or sanitisation is applied before persistence.
- Blocks: A malicious authenticated user can inject arbitrary key/value pairs into any config file accessible via the generic handler.
- Files: `webfrontend/htmlauth/system/ajax/ajax-generic.php` lines 121–122, `webfrontend/htmlauth/system/ajax/ajax-generic2.php` lines 119–120
- Priority: Medium.

---

## Test Coverage Gaps

**No Tests for Core Perl Modules in Production Use:**
- What's not tested: `LoxBerry::System`, `LoxBerry::IO`, `LoxBerry::Log`, `LoxBerry::JSON` — the modules used by every script — have testing files only in `libs/perllib/LoxBerry/testing/`, which are standalone developer scripts, not automated test suites with assertions.
- Files: `libs/perllib/LoxBerry/testing/` (all files are `test_*.pl` scripts that require manual interpretation of output)
- Risk: Regressions in core library functions can silently break all plugins and system scripts.
- Priority: High.

**No Tests for Plugin Install/Uninstall Lifecycle:**
- What's not tested: `sbin/plugininstall.pl` is 1990 lines with no corresponding test suite. Installation failure paths, plugin version conflict logic, and folder cleanup are entirely untested.
- Files: `sbin/plugininstall.pl`
- Risk: Plugin install regressions can corrupt the plugin database or leave orphaned files.
- Priority: High.

**No Tests for MQTT Gateway:**
- What's not tested: `sbin/mqttgateway.pl` handles all MQTT message routing, UDP ingestion, and Miniserver forwarding. It has no test suite.
- Files: `sbin/mqttgateway.pl`
- Risk: Changes to message routing logic, regex filter validation, or transform execution could silently break smart home automation.
- Priority: High.

**PHP Library Functions Untested:**
- What's not tested: `libs/phplib/loxberry_system.php`, `libs/phplib/loxberry_web.php`, `libs/phplib/loxberry_io.php` have a `libs/phplib/testing/` directory but no PHPUnit test suite.
- Files: `libs/phplib/testing/`
- Risk: Changes to `lblanguage()`, `get_miniservers()`, or `checkPath()` could affect all PHP-based plugins and system pages.
- Priority: Medium.

---

*Concerns audit: 2026-03-15*
