# Codebase Structure

**Analysis Date:** 2026-03-15

## Directory Layout

```
/opt/loxberry/           (= $LBHOMEDIR, typically the loxberry user's home)
├── bin/                 # Non-privileged helper scripts and binaries
│   ├── createconfig.pl  # Generates default config files on first boot
│   ├── showpitype       # Identifies Raspberry Pi hardware variant
│   ├── mqtt/            # MQTT gateway support scripts
│   │   ├── datastore/   # Persistent MQTT topic storage
│   │   ├── transform/   # Topic transform scripts
│   │   │   ├── shipped/ # Built-in transforms (shelly, generic, udpin)
│   │   │   └── custom/  # User-defined transforms
│   │   └── udpin/       # UDP input handlers
│   └── plugins/         # Per-plugin helper scripts (created on install)
│       └── <folder>/    # Plugin-specific executables, healthcheck binary
│
├── config/              # Runtime configuration (editable, persisted)
│   ├── system/          # System-level config files
│   │   ├── general.json # Canonical system config (Miniservers, network, etc.)
│   │   ├── general.cfg  # Legacy INI format, auto-synced from general.json
│   │   ├── mail.json    # Mail server config
│   │   ├── htusers.dat  # Apache Basic Auth credentials
│   │   ├── securepin.dat
│   │   └── mosquitto/   # Mosquitto MQTT broker config
│   └── plugins/         # Per-plugin config files
│       └── <folder>/    # Plugin stores its own .cfg / .json here
│
├── data/                # Runtime data (databases, state)
│   ├── system/          # System data files
│   │   ├── plugindatabase.json  # Plugin registry (source of truth)
│   │   ├── notifications/       # Notification queue
│   │   ├── install/             # Install-time artefacts
│   │   ├── uninstall/           # Uninstall scripts
│   │   └── upgrade/             # Upgrade scripts
│   └── plugins/         # Per-plugin data directories
│       └── <folder>/
│
├── libs/                # Shared libraries (SDK)
│   ├── perllib/         # Perl SDK
│   │   └── LoxBerry/    # LoxBerry Perl modules
│   │       ├── System.pm              # Core paths, system info, plugin list
│   │       ├── System/
│   │       │   ├── General.pm         # general.json read/write
│   │       │   ├── PluginDB.pm        # Plugin database CRUD
│   │       │   └── IO.pm              # Low-level I/O primitives
│   │       ├── Web.pm                 # HTML rendering, templates
│   │       ├── IO.pm                  # Miniserver HTTP/UDP/MQTT I/O
│   │       ├── Log.pm                 # Structured logging + notifications
│   │       ├── JSON.pm                # File-backed JSON objects
│   │       ├── Storage.pm             # Network shares, USB storage
│   │       ├── Update.pm              # apt/rpi-update helpers
│   │       ├── MQTTGateway/
│   │       │   └── IO.pm              # MQTT-gateway-specific I/O variant
│   │       ├── LoxoneTemplateBuilder.pm
│   │       ├── PIDController.pm
│   │       ├── TimeMes.pm
│   │       └── examples/
│   │
│   ├── phplib/          # PHP SDK
│   │   ├── loxberry_system.php        # Core paths, system info
│   │   ├── loxberry_web.php           # HTML rendering
│   │   ├── loxberry_io.php            # Miniserver I/O
│   │   ├── loxberry_log.php           # Logging
│   │   ├── loxberry_json.php          # JSON file wrapper
│   │   ├── loxberry_storage.php       # Storage helpers
│   │   ├── loxberry_XL.php            # XL (extended library)
│   │   ├── LoxBerry/
│   │   │   └── JsonRpcApi.php         # JSON-RPC 2.0 dispatcher
│   │   ├── Config/Lite/               # INI config parser
│   │   ├── Datto/JsonRpc/             # JSON-RPC library
│   │   ├── phpMQTT/                   # MQTT PHP client
│   │   └── suncalc/                   # Sun position calculations
│   │
│   ├── bashlib/         # Bash SDK
│   │   ├── loxberry_log.sh            # Shell logging helpers
│   │   ├── iniparser.sh               # INI file parser for Bash
│   │   └── notify.sh                  # Notification helper
│   │
│   └── pythonlib/       # Python SDK helpers
│       └── mqtt_credentials.py        # MQTT credential helper
│
├── log/                 # Log files
│   ├── system/          # System log files (by subsystem)
│   │   ├── loxberryupdate/
│   │   └── plugininstall/
│   ├── system_tmpfs/    # Volatile log/state on tmpfs (lost on reboot)
│   ├── plugins/         # Per-plugin log directories
│   │   └── <folder>/
│   ├── skel_syslog/     # Skeleton for syslog integration
│   └── skel_system/     # Skeleton for system logs
│
├── sbin/                # Privileged system scripts (run as root or sudo)
│   ├── plugininstall.pl           # Plugin install/upgrade/uninstall
│   ├── mqttgateway.pl             # MQTT gateway daemon
│   ├── mqtt-handler.pl            # MQTT UDP input handler
│   ├── mqttfinder.pl              # MQTT broker discovery
│   ├── loxberryupdate.pl          # System update
│   ├── loxberryupdatecheck.pl     # Update availability check
│   ├── loxberryinit.sh            # Boot init script
│   ├── healthcheck.pl             # System health checks
│   ├── credentialshandler.pl      # Remote credentials management
│   ├── createtmpfsfoldersinit.sh  # Creates tmpfs directories at boot
│   ├── pluginsupdate.pl           # Batch plugin updates
│   ├── setdatetime.pl             # Date/time configuration
│   ├── network.cgi                # (legacy network config)
│   ├── loxberryupdate/            # Per-release update scripts
│   └── notifyproviders/           # Notification provider scripts
│       └── email.pl
│
├── system/              # OS-level configuration files
│   └── apache2/         # Apache 2 config
│       ├── sites-available/000-default.conf   # HTTP vhost (port 80)
│       ├── sites-available/001-default-ssl.conf # HTTPS vhost (port 443)
│       ├── conf-available/
│       ├── conf-enabled/
│       ├── mods-available/
│       └── mods-enabled/
│
├── templates/           # HTML templates (HTML::Template / PHP template format)
│   ├── system/          # System admin page templates
│   │   ├── index.html   # Main dashboard template
│   │   ├── head.html    # Common HTML head
│   │   ├── foot.html    # Common HTML footer
│   │   ├── lang/        # System language INI files
│   │   ├── de/          # German language overrides
│   │   ├── en/          # English language overrides
│   │   ├── es/          # Spanish language overrides
│   │   ├── network/     # Network template fragments
│   │   ├── notifyproviders/ # Notification provider templates
│   │   └── help/        # Help page templates
│   └── plugins/         # Per-plugin templates
│       └── <folder>/
│           └── lang/    # Plugin language INI files
│
└── webfrontend/         # Web-accessible files (served by Apache)
    ├── html/            # Public (unauthenticated), DocumentRoot
    │   ├── system/      # System static assets
    │   │   ├── css/     # Stylesheets and fonts
    │   │   ├── images/  # Icons and logos
    │   │   ├── scripts/ # jQuery, Vue 3, form-validator JS
    │   │   ├── splash/  # Boot splash page
    │   │   ├── tools/   # Public system tools (MQTT viewer)
    │   │   └── error/   # Error pages
    │   ├── plugins/     # Per-plugin public assets
    │   │   └── <folder>/
    │   ├── XL/          # XL (extended library) examples
    │   └── tmp/         # Temporary web-accessible files
    │
    ├── htmlauth/        # Authenticated admin area (Alias: /admin/ and /auth/)
    │   ├── system/      # System admin scripts
    │   │   ├── index.cgi            # Main dashboard
    │   │   ├── admin.cgi            # System settings
    │   │   ├── network.cgi          # Network configuration
    │   │   ├── miniserver.cgi       # Loxone Miniserver config
    │   │   ├── mqtt.cgi / mqtt-gateway.cgi / mqtt-finder.cgi
    │   │   ├── plugininstall.cgi    # Plugin manager
    │   │   ├── updates.cgi          # System updates
    │   │   ├── logmanager.cgi       # Log viewer
    │   │   ├── mailserver.cgi       # Mail settings
    │   │   ├── services.php         # Services widget
    │   │   ├── jsonrpc.php          # JSON-RPC endpoint
    │   │   ├── ajax/                # Async handlers
    │   │   │   ├── ajax-generic.php
    │   │   │   ├── ajax-generic2.php
    │   │   │   ├── ajax-mqtt.php
    │   │   │   ├── ajax-config-handler.cgi
    │   │   │   └── ...
    │   │   └── tools/               # Admin tools (filemanager, linfo)
    │   └── plugins/     # Per-plugin admin pages
    │       └── <folder>/
    │
    └── legacy/          # Legacy CGI shims (backward compatibility)
```

## Directory Purposes

**`bin/`:**
- Purpose: Non-privileged runnable scripts and binaries
- Contains: Perl helpers, shell scripts, MQTT transform/datastore/udpin subsystem, plugin bin directories
- Key files: `bin/createconfig.pl`, `bin/showpitype`

**`config/system/`:**
- Purpose: All writable runtime configuration for the system
- Contains: JSON and INI config files; `general.json` is the primary config; `mosquitto/` holds broker config
- Key files: `config/system/general.json`, `config/system/general.cfg`, `config/system/mail.json`, `config/system/htusers.dat`

**`data/system/`:**
- Purpose: Runtime data that is not configuration — plugin registry, notifications, install/uninstall artefacts
- Contains: JSON databases, `.dat` files, subdirectories for install lifecycle
- Key files: `data/system/plugindatabase.json`

**`libs/perllib/LoxBerry/`:**
- Purpose: The Perl SDK. Every Perl script in the codebase uses these modules.
- Contains: `.pm` module files
- Key files: `System.pm`, `Web.pm`, `IO.pm`, `Log.pm`, `JSON.pm`

**`libs/phplib/`:**
- Purpose: The PHP SDK. Every PHP page uses `require_once` on these files.
- Contains: Flat `loxberry_*.php` files plus vendor libraries (`Datto`, `Config/Lite`, `phpMQTT`)
- Key files: `loxberry_system.php`, `loxberry_web.php`, `loxberry_io.php`, `loxberry_log.php`

**`sbin/`:**
- Purpose: Privileged system daemons and admin scripts. Run as root or via sudo.
- Contains: Perl scripts (`.pl`), Bash scripts (`.sh`), and some binaries
- Key files: `plugininstall.pl`, `mqttgateway.pl`, `loxberryinit.sh`, `healthcheck.pl`, `loxberryupdate.pl`

**`templates/system/`:**
- Purpose: HTML template files rendered by `HTML::Template` (Perl) or equivalent PHP template rendering
- Contains: `.html` template files, language INI files, per-language subdirectories
- Key files: `templates/system/index.html`, `templates/system/head.html`, `templates/system/lang/`

**`webfrontend/html/system/`:**
- Purpose: Static assets served publicly (no auth)
- Contains: CSS, JS libraries (jQuery 1.x + Mobile, Vue 3), images/icons, splash screen

**`webfrontend/htmlauth/system/`:**
- Purpose: All authenticated admin CGI and PHP scripts
- Contains: `.cgi` Perl scripts, `.php` PHP pages, `ajax/` subdirectory for async handlers, `tools/` subdirectory

## Key File Locations

**Entry Points:**
- `webfrontend/htmlauth/system/index.cgi`: Main admin dashboard (Perl CGI)
- `webfrontend/htmlauth/system/services.php`: Services widget (PHP)
- `webfrontend/htmlauth/system/jsonrpc.php`: JSON-RPC 2.0 API endpoint
- `sbin/loxberryinit.sh`: System boot init
- `sbin/mqttgateway.pl`: MQTT gateway daemon

**Configuration:**
- `config/system/general.json`: Primary system configuration (Miniservers, network, language, update settings)
- `config/system/general.cfg`: Legacy INI mirror of `general.json` (auto-maintained)
- `config/system/mosquitto/`: Mosquitto MQTT broker configuration
- `system/apache2/sites-available/000-default.conf`: Apache vhost — maps URL paths to filesystem, passes env vars

**Core Logic:**
- `libs/perllib/LoxBerry/System.pm`: Path resolution and system API (Perl)
- `libs/phplib/loxberry_system.php`: Path resolution and system API (PHP)
- `libs/perllib/LoxBerry/IO.pm`: Miniserver communication (Perl)
- `libs/phplib/loxberry_io.php`: Miniserver communication (PHP)
- `sbin/plugininstall.pl`: Plugin lifecycle management
- `data/system/plugindatabase.json`: Plugin registry

**Testing:**
- `libs/perllib/LoxBerry/testing/`: Perl library test helpers
- `libs/phplib/testing/`: PHP library test helpers
- `webfrontend/htmlauth/system/testing/`: Integration test scripts (nodejs-jsonrpc, python3-jsonrpc)
- `libs/bashlib/testing/`: Bash library tests

## Naming Conventions

**Files:**
- System admin CGI scripts: `<pagename>.cgi` (e.g., `network.cgi`, `plugininstall.cgi`)
- System admin PHP scripts: `<pagename>.php` or `services.php`
- Ajax handlers: `ajax-<function>.cgi` or `ajax-<function>.php`
- HTML templates: `<pagename>.html` (matching CGI script name)
- Perl modules: `PascalCase.pm` under `LoxBerry/` namespace
- PHP library files: `loxberry_<module>.php` (flat, snake_case)
- Config files: `<name>.json` (canonical) + `<name>.cfg` (legacy INI mirror)
- Language files: `language.ini` inside per-language subdirectory (`de/`, `en/`, `es/`)

**Directories:**
- Plugin folder identifier: lowercase, alphanumeric, no spaces (e.g., `mqttgateway`, `phptest`)
- All plugin artifacts named `plugins/<folder>/` under their respective area directory

## Where to Add New Code

**New System Admin Page:**
- CGI script: `webfrontend/htmlauth/system/<pagename>.cgi`
- PHP page: `webfrontend/htmlauth/system/<pagename>.php`
- HTML template: `templates/system/<pagename>.html`
- Language strings: `templates/system/lang/language.ini` (and per-language subdirs)
- Link it into the menu: `templates/system/index.html` nav section

**New Ajax Handler:**
- Perl: `webfrontend/htmlauth/system/ajax/ajax-<function>.cgi`
- PHP: `webfrontend/htmlauth/system/ajax/ajax-<function>.php`

**New System Library Function:**
- Perl: add sub to appropriate module in `libs/perllib/LoxBerry/` and export from `@EXPORT`
- PHP: add function to appropriate `libs/phplib/loxberry_*.php` file

**New Privileged/Daemon Script:**
- Location: `sbin/<scriptname>.pl` or `sbin/<scriptname>.sh`
- Must be invoked from CGI via sudo or from systemd

**New Plugin (full scaffold):**
- Created automatically by `sbin/plugininstall.pl` on install
- Plugin admin pages go to `webfrontend/htmlauth/plugins/<folder>/`
- Plugin public assets go to `webfrontend/html/plugins/<folder>/`
- Plugin templates go to `templates/plugins/<folder>/`
- Plugin config goes to `config/plugins/<folder>/`
- Plugin data goes to `data/plugins/<folder>/`
- Plugin logs go to `log/plugins/<folder>/`
- Plugin scripts go to `bin/plugins/<folder>/`

**New MQTT Transform:**
- Shipped transforms: `bin/mqtt/transform/shipped/<name>/`
- User/custom transforms: `bin/mqtt/transform/custom/<name>/`

**New Language Translation:**
- System: add key/value to `templates/system/lang/language.ini`, `templates/system/de/language.ini`, `templates/system/en/language.ini`
- Plugin: add to `templates/plugins/<folder>/lang/language.ini`

## Special Directories

**`log/system_tmpfs/`:**
- Purpose: Volatile state stored on tmpfs — lost on reboot; used for `reboot.required` flag and transient system-state markers
- Generated: At boot by `sbin/createtmpfsfoldersinit.sh`
- Committed: No (tmpfs, runtime only)

**`webfrontend/html/tmp/`:**
- Purpose: Temporary web-accessible scratch space
- Generated: At runtime
- Committed: No

**`webfrontend/legacy/`:**
- Purpose: Backward-compatibility shim pages for old plugin URLs
- Generated: No
- Committed: Yes

**`data/system/install/` and `data/system/uninstall/`:**
- Purpose: Artefacts and scripts used during plugin install/uninstall lifecycle by `plugininstall.pl`
- Generated: Yes (by installer)
- Committed: Partially (skeleton files)

**`.planning/codebase/`:**
- Purpose: GSD architecture and planning documents (this directory)
- Generated: By GSD map-codebase command
- Committed: Yes

---

*Structure analysis: 2026-03-15*
