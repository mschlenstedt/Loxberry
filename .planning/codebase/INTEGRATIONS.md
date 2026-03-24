# External Integrations

**Analysis Date:** 2026-03-15

## APIs & External Services

**Loxone Miniserver (primary integration):**
- Purpose: The core reason LoxBerry exists - bridges Raspberry Pi capabilities to Loxone home automation controllers
- Protocol: HTTP (REST), UDP, MQTT
- SDK: `libs/perllib/LoxBerry/IO.pm` (Perl), `libs/phplib/loxberry_io.php` (PHP)
- Auth: Credentials stored in `config/system/general.json` under `Miniserver.{N}.Credentials`
- Config key: `config/system/general.json` `Miniserver.1.{Ipaddress,Port,Admin,Pass,Cloudurl}`
- Endpoints called: `/dev/sps/io/{virtual_input}/{value}` (value set), HTTP GET for reading
- Multiple Miniservers supported (numbered 1-N in config)
- Cloud DNS supported via `dns.loxonecloud.com` - resolves serial number to IP

**Loxone Cloud DNS:**
- Purpose: Resolve Loxone Miniserver serial number to current IP address
- Endpoint: `http://dns.loxonecloud.com/?getip&snr={SERIAL}&json=true`
- Used by: `sbin/test_clouddns.sh`
- Config: `config/system/general.json` `Base.Clouddnsuri = dns.loxonecloud.com`

**GitHub API (loxberry update system):**
- Purpose: Check for LoxBerry firmware releases and download updates
- Endpoint: `https://api.github.com/repos/mschlenstedt/Loxberry/releases` (release check)
- Endpoint: `https://api.github.com/repos/mschlenstedt/Loxberry/commits` (commit check)
- Download: `https://github.com/mschlenstedt/Loxberry/archive/{branch}.zip`
- SDK: `LWP::UserAgent` with `HTTP::Request`
- Auth: Unauthenticated (public API)
- Used by: `sbin/loxberryupdatecheck.pl`

**LoxBerry Statistics Collection:**
- Purpose: Anonymous usage telemetry (opt-out via `Sendstatistic` flag)
- Endpoint: `https://stats.loxberry.de/collect.php` (system stats)
- Endpoint: `https://stats.loxberry.de/collectplugin.php` (plugin stats)
- Params: `id`, `version`, `architecture`, `lang`, `country`
- Used by: `sbin/setloxberryid.pl` (run via cron: `system/cron/cron.d/setloxberryid`)

**LoxBerry Remote Support (Cloudflare Tunnel):**
- Purpose: Temporary remote access for support sessions via public URL
- Binary: `cloudflared` (downloaded on demand from GitHub releases)
- Download: `https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-{arch}`
- Registration: `https://www.loxberry.de/supportvpn/register.cgi?remoteurl={url}&id={id}&do=register`
- Used by: `sbin/remoteconnect.pl`
- Config: `config/system/general.json` `Remote.Autoconnect`

## Data Storage

**Databases:**
- SQLite3 3.40.1 (embedded, file-based)
  - PHP module: `php7.4-sqlite3`, `php8.2-sqlite3`
  - Used for: Log storage via `LoxBerry::Log` (Perl), plugin data
  - Client: direct SQLite3 API
  - No MariaDB server installed; MariaDB client present for plugin use
  - MariaDB 10.11.4 client only (`mariadb-client`)

**File-based Storage:**
- JSON files - Primary configuration and data format throughout the system
  - System config: `config/system/general.json`
  - Plugin config: `config/plugins/{pluginname}/`
  - Runtime data: `/dev/shm/mqttgateway_*.json` (tmpfs, volatile)
  - Plugin DB: `data/system/` (JSON-backed plugin registry)
- INI files (legacy) - `config/system/general.cfg` (mirrors general.json for backward compat)
- `.dat` files - `config/system/htusers.dat` (Apache password format), `config/system/securepin.dat`
- Flat log files - Written to `log/system/` and `log/system_tmpfs/` (tmpfs)

**File Storage:**
- Local filesystem only (no cloud file storage)
- Network shares via Samba (SMB) for plugin data access from Windows clients
- USB storage mounting via autofs (`system/autofs/`, `system/systemd/usb-mount@.service`)

**Caching:**
- tmpfs at `/dev/shm/` - In-memory JSON files for MQTT gateway runtime state
- `LoxBerry::JSON` module includes file locking for concurrent access safety

## Authentication & Identity

**Auth Provider:**
- Apache Basic Auth (`mod_auth`) - All `/admin/` and `/auth/` routes require authentication
  - User file: `config/system/htusers.dat`
  - Config: `system/apache2/sites-available/000-default.conf` (Alias `/admin/` → `htmlauth/`)
  - Shellinabox terminal also requires Basic Auth

**Custom Admin PIN:**
- Secondary PIN stored in `config/system/securepin.dat`
- Used for additional confirmation of sensitive operations

**Loxone Miniserver Auth:**
- HTTP Basic Auth credentials stored in `config/system/general.json` `Miniserver.{N}.Credentials`
- Stored as raw and potentially encoded forms (`Admin`, `Admin_raw`, `Pass`, `Pass_raw`)

**SSL/TLS:**
- Self-signed certificate management via `sbin/createcert.sh`, `sbin/CA.pl`, `sbin/checkcerts.sh`
- CA config: `config/system/ca.cnf`
- Certificate served at `/admin/system/tools/` and accessible at `webfrontend/html/system/cacert.cer`
- Apache SSL config: `system/apache2/mods-available/ssl.conf`, `system/apache2/sites-available/001-default-ssl.conf`
- Optional HTTPS (disabled by default): `config/system/general.json` `Webserver.Sslenabled`

## Monitoring & Observability

**Health Check System:**
- Custom health check daemon: `sbin/healthcheck.pl`
- Checks: CPU temp, load average, disk space, MQTT broker, Miniserver connectivity, SSL certs, log sizes, tmpfs usage
- Results stored as JSON, accessible via: `webfrontend/htmlauth/system/healthcheck.cgi`
- Runs daily via cron: `system/cron/cron.daily/03-healthcheck`
- Also runs at reboot: `system/cron/cron.reboot/03-healthcheck`
- Links to wiki help pages at `https://wiki.loxberry.de/` for each check

**Error Tracking:**
- No external error tracking service (Sentry etc.)
- Errors logged to structured LoxBerry log files via `LoxBerry::Log`
- Critical errors trigger email notification via msmtp

**Logs:**
- Framework: Custom `LoxBerry::Log` module (severity 0=EMERGE to 7=DEBUG)
- Storage: `log/system/` (persistent), `log/system_tmpfs/` (tmpfs, fast writes)
- Log manager UI: `webfrontend/htmlauth/system/logmanager.cgi`
- Log maintenance cron: `system/cron/cron.daily/01-log_maint`, `system/cron/cron.hourly/02-log_maint`
- Apache logs: `${APACHE_LOG_DIR}/error.log`, PHP errors to `${LBSTMPFSLOG}/apache2/php.log`
- Mosquitto log: `${LBSTMPFSLOG}/mosquitto.log`

## CI/CD & Deployment

**Hosting:**
- Self-hosted on Raspberry Pi hardware (embedded Linux system)
- Installation path: `/opt/loxberry`

**Update Mechanism:**
- Pull-based update from GitHub (`sbin/loxberryupdatecheck.pl`, `sbin/loxberryupdate.pl`)
- Update types: `release`, `prerelease`, `testing` (branch-based)
- Config: `config/system/general.json` `Update.{Releasetype,Interval,Installtype}`
- Installtype: `notify` (alert only) or auto-install
- Scheduled via cron: `system/cron/cron.weekly/loxberryupdate_cron`
- Update scripts versioned: `sbin/loxberryupdate/update_v*.pl`, `updatereboot_v*.pl`
- Plugin updates: `sbin/pluginsupdate.pl`, daily via `system/cron/cron.daily/02-pluginsupdate`

**CI Pipeline:**
- None detected (open-source project, no CI config files present)

## MQTT Integration

**Local MQTT Broker:**
- Mosquitto 2.0.11 running as systemd service (`system/systemd/mosquitto.service`)
- Config dir: `/etc/mosquitto/mosquitto.conf` (not in repo)
- Default port: 1883 (TCP), 9001 (WebSocket)
- UDP-to-MQTT gateway listening on port 11884 (`Mqtt.Udpinport`)
- Mosquitto config stored at: `config/system/mosquitto/`

**MQTT Gateway Daemon:**
- Daemon: `sbin/mqttgateway.pl` (long-running Perl process)
- Handles: UDP-in to MQTT translation, Loxone Miniserver ↔ MQTT bridging
- Transform scripts: `bin/mqtt/transform/shipped/` (PHP scripts for data transformation)
- Custom transforms: `bin/mqtt/transform/custom/`
- Runtime state: `/dev/shm/mqttgateway_*.json` (volatile tmpfs)
- Config: `config/system/mqttgateway.json` (not committed, runtime only)

**Shelly Integration:**
- Example transform scripts for Shelly smart home devices: `bin/mqtt/transform/shipped/udpin/shelly/`

## Email Notifications

**SMTP Provider:**
- Configurable external SMTP server
- MTA: msmtp 1.8.23 (lightweight SMTP client)
- Config: `config/system/mail.json` (`SMTP.EMAIL`, `SMTP.ACTIVATE_MAIL`)
- Sending logic: `sbin/notifyproviders/email.pl`
- Perl modules: `Email::MIME`, `Email::Sender::Simple`
- Templates: `templates/system/notifyproviders/notify_email_template.html`
- Test UI: `webfrontend/htmlauth/system/tools/smtptest.cgi`

**Notification Triggers:**
- Plugin errors/infos
- System errors/infos
- Controlled by: `config/system/mail.json` `NOTIFICATION.*` flags

## Network Discovery

**Avahi mDNS:**
- Avahi 0.8 daemon for local network device discovery
- LoxBerry advertised at hostname `loxberry.home.local`
- SSDP daemon: `sbin/ssdpd` (binary), `system/systemd/ssdpd.service`
- SSDP config: `config/system/general.json` `Ssdp.{Disabled,Uuid}`

## File Sharing (SMB/CIFS)

**Samba 4.17.12:**
- Config: `system/samba/smb.conf`
- Shares:
  - `[XL]` - LoxBerry XL Extended Logic files (`webfrontend/html/XL/`) - authenticated
  - `[loxberry]` - Full LoxBerry install (`/opt/loxberry`) - authenticated
  - `[plugindata]` - Plugin data (`data/plugins/`) - guest read-only
- Autofs integration for mounting remote SMB shares: `system/autofs/loxberry_smb.autofs`

## Time Synchronization

**NTP:**
- Method configurable: `config/system/general.json` `Timeserver.Method` (default: `ntp`)
- Default server: `0.europe.pool.ntp.org`
- Timezone: `Europe/Berlin` (configurable)
- Script: `sbin/setdatetime.pl` (runs hourly via `system/cron/cron.hourly/01-setdatetime`)
- Also synchronizes time from Loxone Miniserver (fallback)

## Plugin System

**Plugin Repository:**
- Plugin install from URL/zip: `webfrontend/htmlauth/system/plugininstall.cgi`, `sbin/plugininstall.pl`
- Plugin folders: `bin/plugins/`, `config/plugins/`, `data/plugins/`, `log/plugins/`, `webfrontend/html/plugins/`, `webfrontend/htmlauth/plugins/`, `templates/plugins/`
- Plugin DB: `libs/perllib/LoxBerry/System/PluginDB.pm` (JSON-backed registry)

## Webhooks & Callbacks

**Incoming:**
- UDP port 11884 - Receives UDP data from Loxone Miniserver, transforms and publishes to MQTT
- HTTP CGI endpoints - All `/admin/` routes receive web UI requests and AJAX calls
- AJAX endpoints: `webfrontend/htmlauth/system/ajax/ajax-*.cgi` (config changes, backup, notifications)

**Outgoing:**
- HTTP to Loxone Miniserver - `LoxBerry::IO::mshttp_send()` posts virtual input values
- UDP to Loxone Miniserver - `LoxBerry::IO::msudp_send()` sends UDP datagrams
- MQTT publish - `LoxBerry::IO::mqtt_publish()` publishes to local or remote broker
- curl calls to `loxberry.de` for remote support registration and statistics

---

*Integration audit: 2026-03-15*
