# Technology Stack

**Analysis Date:** 2026-03-15

## Languages

**Primary:**
- Perl 5.36.0 - CGI scripts (`webfrontend/htmlauth/system/*.cgi`), system daemons (`sbin/*.pl`), core libraries (`libs/perllib/`)
- PHP 7.4 / 8.2 - Web UI library layer (`libs/phplib/`), system web helpers, MQTT transform scripts
- Bash 5.2 - System init scripts (`sbin/*.sh`), cron jobs (`system/cron/`)

**Secondary:**
- Python 3.11 - Plugin support (`libs/pythonlib/`), minor utilities; not used in core system
- JavaScript (vanilla) - Browser-side form validation, UI scripts (`webfrontend/html/system/scripts/`)

## Runtime

**Environment:**
- Debian 12 (Bookworm) on Raspberry Pi - arm64 architecture
- Target hardware: Raspberry Pi (all models), also supports x86/x64

**Init System:**
- systemd - Service units in `system/systemd/`
- Custom init via `sbin/loxberryinit.sh` called by `system/systemd/loxberry.service`

**Package Manager:**
- APT (Debian) - Package lists at `packages12.txt` (Debian 12), `packages11.txt` (Debian 11)
- cpanminus - Perl module installer (system-installed)
- Yarn 1.22 - JavaScript dependency management (dev tooling for linfo only)

## Frameworks

**Core Web:**
- Apache 2.4.57 - HTTP server with CGI, PHP mod, SSL support
  - Config: `system/apache2/apache2.conf`, `system/apache2/sites-available/000-default.conf`
  - Listens: port 80 (HTTP), port 443 (HTTPS/SSL optional)
  - CGI execution enabled for `.cgi` scripts
  - PHP 7.4 and PHP 8.2 modules both installed simultaneously

**Perl Web Layer:**
- `CGI.pm` (libcgi-pm-perl 4.55) - Standard CGI interface for all `.cgi` endpoints
- `HTML::Template` (libhtml-template-perl 2.97) - Server-side HTML templating engine, templates in `templates/system/*.html`
- `CGI::Carp` - Error reporting to browser

**PHP Library:**
- `LBWeb` / `LBSystem` (custom) - PHP SDK located at `libs/phplib/loxberry_web.php`, `libs/phplib/loxberry_system.php`
- `Config/Lite.php` - INI-format configuration file parser
- `Datto/JsonRpc` - JSON-RPC server/client implementation

**Testing/Build:**
- Linfo 4.0.2 - PHP server stats tool (`webfrontend/htmlauth/system/tools/linfo/`)
  - Build tooling: Gulp 3.9.1 with gulp-sass, gulp-uglify (dev only)

## Key Dependencies

**Critical Perl Modules (system-installed):**
- `JSON` (libjson-perl 4.10000) - JSON encode/decode used throughout all Perl code
- `Config::Simple` (libconfig-simple-perl 4.59) - INI config file parsing, used in `LoxBerry::System`
- `HTML::Template` (libhtml-template-perl 2.97) - All web page rendering
- `URI::Escape` (liburi-perl 5.17) - URL encoding
- `LWP::UserAgent` / `LWP::Protocol::HTTPS` - HTTP client for update checks and external calls
- `Net::MQTT::Simple` (bundled at `libs/perllib/Net/MQTT/Simple.pm`) - MQTT client
- `Net::MQTT::Simple::SSL` (bundled at `libs/perllib/Net/MQTT/Simple/SSL.pm`) - MQTT over TLS
- `Email::MIME`, `Email::Sender::Simple` - Email notification sending
- `File::Monitor`, `File::Find::Rule` - Filesystem watching in MQTT gateway daemon
- `Hash::Flatten` (bundled at `libs/perllib/Hash/Flatten.pm`) - Nested hash flattening for MQTT
- `Proc::CPUUsage` (bundled at `libs/perllib/Proc/CPUUsage.pm`) - CPU monitoring
- `Time::HiRes` - High-resolution timing

**Critical PHP Libraries (bundled):**
- `phpMQTT` (bluerhinos/phpmqtt, `libs/phplib/phpMQTT/`) - PHP MQTT client, requires PHP >= 5.4
- `suncalc` (auroras-live/suncalc-php, `libs/phplib/suncalc/`) - Sun/moon position calculations
- `Config/Lite` (`libs/phplib/Config/Lite.php`) - INI config file handling
- `Datto/JsonRpc` (`libs/phplib/Datto/`) - JSON-RPC protocol implementation

**LoxBerry Core Perl Modules (all bundled at `libs/perllib/LoxBerry/`):**
- `LoxBerry::System` v3.0.0.7 - Core system: directory paths, config reads, utility functions
- `LoxBerry::Web` v3.0.0.3 - Web output, template rendering, i18n
- `LoxBerry::Log` v3.0.0.4 - Structured logging with severity levels, notifications
- `LoxBerry::JSON` v2.2.1.4 - JSON file read/write wrapper with locking
- `LoxBerry::IO` v3.0.0.1 - I/O to Loxone Miniserver (HTTP, UDP, MQTT)
- `LoxBerry::MQTTGateway::IO` v1.2.0.1 - MQTT Gateway variant of I/O module
- `LoxBerry::Storage` v3.0.0.1 - Network shares and USB storage management
- `LoxBerry::Update` v3.0.0.11 - System update logic (apt, download, install)
- `LoxBerry::PIDController` - CPU throttle/load management for MQTT gateway
- `LoxBerry::System::PluginDB` - Plugin registry database (JSON-backed)
- `LoxBerry::System::General` - System general config accessor

**Infrastructure (system-installed Debian packages):**
- Mosquitto 2.0.11 - Local MQTT broker (`system/systemd/mosquitto.service`)
- MariaDB 10.11.4 (client only; no server package confirmed)
- SQLite3 3.40.1 - Embedded database, PHP sqlite3 module installed
- Samba 4.17.12 - SMB/CIFS file sharing (`system/samba/smb.conf`)
- OpenVPN 2.6.3 - VPN support (`sbin/openvpn`)
- Shellinabox 2.21 - Browser-based terminal (proxied via Apache at `/admin/system/tools/terminal`)
- msmtp 1.8.23 - Lightweight SMTP client / MTA for email notifications
- Avahi 0.8 - mDNS/DNS-SD discovery daemon
- Autofs 5.1.8 - Automounting of network shares (`system/autofs/`)
- curl 7.88, wget - HTTP clients for scripts
- NTPsec (ntpdate) - Time synchronization

## Configuration

**Environment Variables (passed via Apache to CGI):**
- `LBHOMEDIR` - Root LoxBerry installation directory (default: `/opt/loxberry`)
- `LBPCGI`, `LBPHTML`, `LBPHTMLAUTH`, `LBPTEMPL`, `LBPDATA`, `LBPLOG`, `LBPCONFIG`, `LBPBIN` - Plugin-scoped paths
- `LBSCGI`, `LBSHTML`, `LBSHTMLAUTH`, `LBSTEMPL`, `LBSDATA`, `LBSLOG`, `LBSTMPFSLOG`, `LBSCONFIG`, `LBSBIN`, `LBSSBIN` - System-scoped paths
- Set via: `system/apache2/sites-available/000-default.conf` (`SetEnv` / `PassEnv`)

**Configuration Files (runtime, not committed):**
- `config/system/general.json` - Primary system config (Miniserver connections, MQTT, network, updates)
- `config/system/general.cfg` - Legacy INI format (mirrors general.json for older code)
- `config/system/mail.json` - SMTP and notification settings
- `config/system/htusers.dat` - Apache Basic Auth user database
- `config/system/securepin.dat` - Admin PIN

**Config Defaults (committed templates):**
- `config/system/general.json.default`
- `config/system/general.cfg.default`
- `config/system/mail.json.default`

**PHP Runtime Config:**
- `system/php/loxberry-apache.ini` - Sets PHP `include_path` to `${LBHOMEDIR}/libs/phplib`
- `system/php/loxberry-cli.ini` - CLI PHP settings

**Build:**
- No build pipeline for core system (server-side CGI/PHP, no transpilation)
- Linfo tool has Gulp build: `webfrontend/htmlauth/system/tools/linfo/package.json`

## Platform Requirements

**Development:**
- Debian 12 (Bookworm), arm64 (Raspberry Pi) or x86/x64
- Apache 2.4 with mod_php and mod_cgid
- Perl 5.36+ with CPAN modules listed above
- PHP 7.4 and PHP 8.2 (both required simultaneously)
- Mosquitto MQTT broker running locally

**Production:**
- Raspberry Pi (primary target; arm64/armv7l/aarch64)
- Also supports x86 and x64 (Linux)
- Installation path: `/opt/loxberry`
- System user: `loxberry`
- Webserver hostname: `loxberry.home.local` (mDNS via Avahi)

---

*Stack analysis: 2026-03-15*
