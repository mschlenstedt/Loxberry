# Architecture

**Analysis Date:** 2026-03-15

## Pattern Overview

**Overall:** Plugin-based embedded Linux platform with CGI/PHP web frontend, Perl daemon services, and file-based configuration

**Key Characteristics:**
- Home directory (`/opt/loxberry`) is the single root of all file paths — every component resolves its own location relative to `$LBHOMEDIR` (set via env var or user home lookup)
- Two distinct web zones: `webfrontend/html/` (public, unauthenticated) and `webfrontend/htmlauth/` (protected, requires HTTP auth via Apache) — exposed as `/` and `/admin/`
- All extension functionality is delivered as installable plugins; the system provides a standard plugin folder scaffold and a shared SDK (Perl, PHP, Python, Bash) that all plugins consume
- Communication between the Raspberry Pi and the Loxone Miniserver uses HTTP virtual inputs, UDP, and MQTT; these transports are abstracted by `LoxBerry::IO` (Perl) and `loxberry_io.php` (PHP)
- Long-running services (MQTT gateway, healthcheck, update) are Perl daemons invoked from `sbin/` or via cron; they are not managed by a process supervisor other than systemd init scripts

## Layers

**Web Frontend (Public):**
- Purpose: Static assets, unauthenticated landing page, SSDP description
- Location: `webfrontend/html/system/`
- Contains: CSS, JS (jQuery, Vue 3 bundle), images, splash page, `ssdpdesc.php`
- Depends on: Apache static file serving, PHP for SSDP
- Used by: Browser, UPnP discovery

**Web Frontend (Authenticated / Admin):**
- Purpose: All system administration pages and plugin admin UIs
- Location: `webfrontend/htmlauth/system/`
- Contains: `.cgi` (Perl CGI) and `.php` scripts for every admin page, plus `ajax/` subdirectory for async handlers
- Depends on: `LoxBerry::Web` + `LoxBerry::System` (Perl) or `loxberry_web.php` + `loxberry_system.php` (PHP), HTML templates from `templates/system/`
- Used by: Browser (authenticated), `/admin/` Apache alias

**Plugin Web Frontend:**
- Purpose: Per-plugin admin pages (both public and authenticated)
- Location: `webfrontend/html/plugins/<pluginfolder>/` and `webfrontend/htmlauth/plugins/<pluginfolder>/`
- Contains: Plugin-specific `.cgi` / `.php` / `.html` files
- Depends on: Same SDK as system web layer; paths auto-resolved from script location via `LoxBerry::System`
- Used by: Browser, plugin links in system menu

**System Library (Perl SDK):**
- Purpose: Core API for all Perl CGI and daemon code — path resolution, config reading, I/O to Miniserver, logging, plugin DB
- Location: `libs/perllib/LoxBerry/`
- Key modules:
  - `System.pm` — path constants (`$lbhomedir`, `$lbshtmlauthdir`, etc.), plugin discovery, system config
  - `System/General.pm` — reads/writes `general.json` and keeps `general.cfg` in sync
  - `System/PluginDB.pm` — CRUD over `data/system/plugindatabase.json`
  - `Web.pm` — HTML header/footer rendering, language loading, HTML::Template integration
  - `IO.pm` — `mshttp_send`, `msudp_send`, `mqtt_publish`, `mqtt_connect` — all Miniserver transports
  - `Log.pm` — structured logging with severity levels, notification system
  - `JSON.pm` — thin JSON file wrapper with locking
  - `Storage.pm` — network shares and USB storage discovery
  - `Update.pm` — apt and rpi-update helpers (used only by update scripts)
  - `MQTTGateway/IO.pm` — MQTT-gateway-specific I/O variant (overrides `LoxBerry::IO` methods)
- Depends on: CPAN modules (`Config::Simple`, `HTML::Template`, `Net::MQTT::Simple`, `JSON`, etc.)
- Used by: Every Perl CGI in `webfrontend/htmlauth/`, every daemon in `sbin/`, plugin Perl scripts

**System Library (PHP SDK):**
- Purpose: Equivalent API for PHP pages
- Location: `libs/phplib/`
- Key files:
  - `loxberry_system.php` — path constants (`LBHOMEDIR`, `LBSHTMLAUTHDIR`, etc.), plugin data, language, version
  - `loxberry_web.php` — HTML header/footer, template rendering
  - `loxberry_io.php` — Miniserver HTTP/UDP/MQTT I/O
  - `loxberry_log.php` — logging
  - `loxberry_json.php` — JSON file wrapper
  - `loxberry_storage.php` — storage helpers
  - `LoxBerry/JsonRpcApi.php` — JSON-RPC 2.0 endpoint implementation (routes calls to LBSystem/LBWeb PHP functions)
- Depends on: `Datto\JsonRpc`, `Config\Lite`, `phpMQTT`
- Used by: All `.php` pages in `webfrontend/htmlauth/system/`, `webfrontend/htmlauth/plugins/`

**System Daemons / Admin Scripts:**
- Purpose: Privileged operations, background services, system maintenance
- Location: `sbin/`
- Key scripts:
  - `mqttgateway.pl` — persistent MQTT broker bridge, transforms topics, routes to/from Miniserver
  - `plugininstall.pl` — plugin install/uninstall/update lifecycle manager (runs as root)
  - `loxberryupdate.pl` / `loxberryupdatecheck.pl` — system update pipeline
  - `healthcheck.pl` — system and plugin health checks, exposes JSON results
  - `loxberryinit.sh` — boot init script (mount, resize rootfs, create config)
  - `credentialshandler.pl` — manages credentials for remote services
  - `createconfig.pl` (in `bin/`) — generates `general.cfg`/`general.json` defaults
- Depends on: `LoxBerry::System`, `LoxBerry::Log`, `LoxBerry::IO`, system binaries (apt, systemctl)
- Used by: systemd, cron, CGI pages via `sudo` calls

**Plugin Binaries:**
- Purpose: Plugin-specific scripts and helpers
- Location: `bin/plugins/<pluginfolder>/`
- Contains: Executable scripts (any language), `healthcheck` binary
- Depends on: Same SDK as system layer
- Used by: Plugin CGI pages, cron, MQTT gateway plugin hooks

**MQTT Subsystem:**
- Purpose: Bidirectional MQTT-to-Miniserver bridge with configurable topic transforms
- Location:
  - `sbin/mqttgateway.pl` — main daemon
  - `sbin/mqtt-handler.pl` — helper handler
  - `bin/mqtt/transform/shipped/` — built-in transform scripts (udpin, shelly, generic)
  - `bin/mqtt/transform/custom/` — user-supplied transforms
  - `bin/mqtt/datastore/` — persistent topic data store
  - `bin/mqtt/udpin/` — UDP input handlers
  - `config/system/mosquitto/` — Mosquitto broker config
- Depends on: `Net::MQTT::Simple`, `LoxBerry::MQTTGateway::IO`, `LoxBerry::IO`
- Used by: Plugins, Loxone Miniserver virtual UDP inputs

## Data Flow

**Browser Request to Authenticated Admin Page:**

1. Browser sends HTTP GET/POST to `/admin/system/<page>.cgi` or `/admin/system/<page>.php`
2. Apache authenticates via `.htpasswd` (configured per `webfrontend/htmlauth/`)
3. Apache executes CGI script or PHP handler; passes `LBHOMEDIR` and path env vars
4. Script loads `LoxBerry::System` (or `loxberry_system.php`) — path constants are set automatically by parsing `$0`/`SCRIPT_FILENAME` relative to `$LBHOMEDIR`
5. Script reads config from `config/system/general.json`, renders `HTML::Template` template from `templates/system/*.html`
6. Response HTML returned to browser

**Plugin Install Flow:**

1. User uploads `.zip` via `webfrontend/htmlauth/system/plugininstall.cgi`
2. CGI calls `sbin/plugininstall.pl` via sudo
3. `plugininstall.pl` extracts archive, verifies metadata (`plugin.cfg`), creates folder scaffold under `webfrontend/htmlauth/plugins/<folder>/`, `config/plugins/<folder>/`, `data/plugins/<folder>/`, `log/plugins/<folder>/`, `bin/plugins/<folder>/`, `templates/plugins/<folder>/`
4. Plugin install script is executed, apt packages installed if declared
5. Plugin record written to `data/system/plugindatabase.json` via `LoxBerry::System::PluginDB`

**MQTT Message Flow (Inbound, device -> Miniserver):**

1. External device (e.g. Shelly) publishes MQTT message to Mosquitto broker
2. `mqttgateway.pl` daemon (subscribed via `Net::MQTT::Simple`) receives message
3. Transform script in `bin/mqtt/transform/shipped/` or `bin/mqtt/transform/custom/` optionally re-maps topic/payload
4. Gateway calls `LoxBerry::IO::mshttp_send` or `LoxBerry::IO::msudp_send` to push value into Loxone Miniserver virtual input
5. Gateway writes retained data to `/dev/shm/mqttgateway_topics.json`

**MQTT Message Flow (Outbound, Miniserver -> devices):**

1. Loxone Miniserver sends UDP datagram to `sbin/mqtt-handler.pl` udpin endpoint
2. Handler parses UDP packet using transform scripts in `bin/mqtt/transform/shipped/udpin/`
3. Handler publishes MQTT topic via `Net::MQTT::Simple` to Mosquitto

**State Management:**
- System configuration stored in `config/system/general.json` (canonical) + `general.cfg` (legacy INI, auto-synced by `System/General.pm`)
- Plugin configuration stored in `config/plugins/<pluginfolder>/`
- Plugin database (registry) stored in `data/system/plugindatabase.json`
- MQTT topic state stored in `/dev/shm/mqttgateway_topics.json` (tmpfs, volatile)
- Reboot-required state stored in `log/system_tmpfs/reboot.required` (tmpfs flag file)
- Notifications stored in `data/system/notifications/`

## Key Abstractions

**LoxBerry::System / loxberry_system.php:**
- Purpose: Auto-detects `$LBHOMEDIR` and all standard path variables for the current script's context (system vs. plugin, by parsing the script's own path)
- Examples: `libs/perllib/LoxBerry/System.pm`, `libs/phplib/loxberry_system.php`
- Pattern: Both Perl and PHP versions use identical path-parsing logic; a script running anywhere under `$LBHOMEDIR` gets correct `lbp*` (plugin) or `lbs*` (system) path variables automatically on `use LoxBerry::System` / `require_once loxberry_system.php`

**LoxBerry::Log / loxberry_log.php:**
- Purpose: Structured log objects that write to `log/system/` or `log/plugins/<folder>/`, with severity levels (0=EMERGE … 7=DEBUG) and notification integration
- Examples: `libs/perllib/LoxBerry/Log.pm`, `libs/phplib/loxberry_log.php`
- Pattern: Instantiate with `new LoxBerry::Log(name => ..., package => ..., logdir => $lbplogdir)` then call `LOGOK`, `LOGWARN`, `LOGERR`, `LOGDEB` macros

**LoxBerry::IO / loxberry_io.php:**
- Purpose: All communication paths to/from Loxone Miniserver — HTTP virtual inputs, UDP, MQTT
- Examples: `libs/perllib/LoxBerry/IO.pm`, `libs/phplib/loxberry_io.php`
- Pattern: `mshttp_send($msnr, key => value, ...)` for HTTP; `msudp_send($msnr, ...)` for UDP; `mqtt_publish($topic, $value)` for MQTT

**LoxBerry::JSON / LBJSON:**
- Purpose: File-backed JSON objects with locking and dirty-write protection
- Examples: `libs/perllib/LoxBerry/JSON.pm`, `libs/phplib/loxberry_json.php`
- Pattern: `$obj = LoxBerry::JSON->new; $data = $obj->open(filename => $path); $obj->write()` — auto-locks file during write

**Plugin Folder Convention:**
- Purpose: Defines where a plugin stores each type of artifact — enforced by `plugininstall.pl` scaffold creation and path constants in `LoxBerry::System`
- Pattern: Every plugin gets a `<pluginfolder>` identifier (from `plugin.cfg`). All path constants (`lbp*`) resolve to `<area>/plugins/<pluginfolder>/` relative to `$LBHOMEDIR`

**JSON-RPC API (PHP):**
- Purpose: Single endpoint for Vue 3 / JavaScript async calls from web frontend; routes method names to LBSystem/LBWeb PHP functions
- Examples: `libs/phplib/LoxBerry/JsonRpcApi.php`, `webfrontend/htmlauth/system/jsonrpc.php`
- Pattern: POST to `/admin/system/jsonrpc.php` with `{"method":"LBSystem::plugindata","params":["myplugin"]}` — `JsonRpcApi` dispatches to PHP function with security blocklist enforcement

## Entry Points

**Web Admin Dashboard:**
- Location: `webfrontend/htmlauth/system/index.cgi`
- Triggers: HTTP GET `/admin/system/index.cgi` (or `/admin/`)
- Responsibilities: Renders main system dashboard, loads language, checks config files exist (calls `bin/createconfig.pl` if missing)

**System Boot Init:**
- Location: `sbin/loxberryinit.sh`
- Triggers: systemd service at boot
- Responsibilities: Filesystem checks, rootfs resize, swap config, default config creation, tmpfs log dir setup, cron install

**Plugin Install:**
- Location: `sbin/plugininstall.pl`
- Triggers: Called via sudo from `webfrontend/htmlauth/system/plugininstall.cgi`
- Responsibilities: Full plugin lifecycle (install, upgrade, uninstall), folder scaffold, apt packages, plugin script execution, PluginDB update

**MQTT Gateway Daemon:**
- Location: `sbin/mqttgateway.pl`
- Triggers: systemd service (persistent), also startable from `webfrontend/htmlauth/system/mqtt-gateway.cgi`
- Responsibilities: MQTT subscription loop, topic transforms, Miniserver I/O, config file watching

**System Update:**
- Location: `sbin/loxberryupdate.pl`
- Triggers: cron (`sbin/loxberryupdate_cron.sh`) or manual from `webfrontend/htmlauth/system/updates.cgi`
- Responsibilities: Fetches update packages, applies apt and file updates, calls per-update scripts

**JSON-RPC Endpoint:**
- Location: `webfrontend/htmlauth/system/jsonrpc.php`
- Triggers: HTTP POST from browser JS / Vue 3 components
- Responsibilities: Dispatches JSON-RPC 2.0 method calls to PHP SDK functions

## Error Handling

**Strategy:** Fail-loud with log entries; CGI pages use `CGI::Carp fatalsToBrowser` for Perl scripts so fatal errors render in browser during development. Production errors go to Apache error log and LoxBerry log files.

**Patterns:**
- Perl CGI: `use CGI::Carp qw(fatalsToBrowser)` — unhandled die renders to browser
- Daemon scripts: `$SIG{INT}` and `$SIG{TERM}` handlers call `LOGEND()` before exit
- `LoxBerry::JSON->open` dies on malformed JSON — callers must wrap in eval where needed
- Config file checks in `index.cgi`: if `general.json` missing or zero-size, hard die with human-readable message

## Cross-Cutting Concerns

**Logging:** `LoxBerry::Log` / `loxberry_log.php` — structured log files under `log/system/` or `log/plugins/<folder>/`; severity 0–7; notifications written to `data/system/notifications/`

**Validation:** No framework-level input validation — each CGI script validates its own CGI parameters using Perl `CGI` module or PHP `$_GET`/`$_POST` directly

**Authentication:** Apache HTTP Basic Auth for `/admin/` (`webfrontend/htmlauth/`); credentials stored in `config/system/htusers.dat`; public assets under `webfrontend/html/` require no authentication

**Internationalisation:** Language files are INI files under `templates/system/lang/` (system) or `templates/plugins/<folder>/lang/` (plugins); loaded via `LoxBerry::System::readlanguage()` / `LBSystem::readlanguage()`; language detected from system config or `?lang=` URL param

---

*Architecture analysis: 2026-03-15*
