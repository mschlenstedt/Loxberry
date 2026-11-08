# Optional browser form login (development version)

This change adds a responsive, password-manager-friendly login at `/login`.
It is **off by default**: the new Apache configuration is not linked into
`conf-enabled`. Existing installations keep their original authentication.
No live LoxBerry was modified or used for these tests. No 2FA is included.

## Existing upstream discussion (checked 2026-11-08)

- [Issue #1599](https://github.com/mschlenstedt/Loxberry/issues/1599) is open
  and requests this exact combination of an HTML form, autocomplete and cookies.
  The maintainer's response declines implementation because plugins and
  Miniserver virtual outputs rely on Basic Auth. Open status is **not** maintainer
  approval. This branch is a local compatibility experiment, not an accepted fix.
- [Issue #1496](https://github.com/mschlenstedt/Loxberry/issues/1496), suggesting
  Authelia/Authentik for MFA, is closed; maintainers considered that approach
  excessive for the intended LAN use.
- Searches of open and closed PRs for `login`, `authentication`, `1599`, and `MFA`
  found no matching browser-login implementation. This is a search result, not a
  guarantee that no unindexed or differently named work exists.

## Behavior and compatibility boundary

1. Requests with `Authorization` still use Apache's original Basic Auth provider,
   password file, authorization rules and unmodified request body. No custom
   header or plugin update is required. Non-browser requests without credentials
   still get the original 401 challenge, allowing challenge/retry clients.
2. Browser navigations without credentials redirect to a fixed HTTPS origin and
   `/login`. Non-navigation AJAX requests get an error rather than an HTML login
   page. Detection uses `Sec-Fetch-Mode: navigate`; `Accept: text/html` alone is
   deliberately insufficient because legacy machines also request HTML. Deep
   links under `/admin/` and `/auth/` are retained. The opt-in root/index landing
   page goes straight to the HTTPS login. Older browsers without Fetch Metadata
   can use `/login` explicitly; a direct protected URL still challenges them.
3. Successful login checks the existing `htusers.dat` using `htpasswd -vi` via
   stdin, without a shell. It rotates the anonymous token to a new random 256-bit
   token. Cookie authentication sets `REMOTE_USER` without synthesizing or storing
   a password/Authorization header. Original Apache authorization still applies.
4. Session requests to `/admin`, `/auth`, plugin directories, static private
   files and the proxied terminal go through the same guard. Existing local
   unauthenticated calls retain `Require local`. Invalid session cookies do not
   receive that exemption. This preserves the existing local trust boundary;
   **do not put an unauthenticated localhost proxy in front of the admin UI**.
5. Cookie-authenticated writes require a matching Origin or Referer. Cookies are
   `Secure`, `HttpOnly`, `SameSite=Strict`, host-only and `Path=/`. A plain HTTP
   form submission is rejected. Headers claiming TLS or a different origin are
   not trusted. TLS termination at a separate reverse proxy is not supported in
   this version; Basic clients retain their existing transport behavior.
6. Sessions expire after 30 minutes of inactivity or 8 hours total. Logout is a
   CSRF-protected POST; the cookie and server-side session are revoked. Password
   and username changes invalidate sessions through a credential fingerprint.
   A browser that already cached Basic credentials can still use those credentials:
   session logout does not erase a browser's Basic Auth cache or log out scripts.
7. `Session / Sign out` appears in the shared Perl/PHP sidebar and mobile menu
   only when the feature is enabled. `/login` also shows the active session and
   logout control. Login translations: English, Dutch, German; other configured
   languages use English. Menu labels cover all five existing languages.

The standard form has associated labels, stable names, `autocomplete="username"`
and `autocomplete="current-password"`. Paste is allowed. Login and logout work
without JavaScript; JS only toggles password visibility. There are no external
fonts, CDN assets, browser storage credentials or cloud services.

Plugin compatibility has been proven with representative HTTP/CGI/proxy fixtures,
not every third-party plugin. A plugin that directly reads `PHP_AUTH_PW` or
`HTTP_AUTHORIZATION`, invents additional auth rules, embeds cross-origin pages or
depends on cross-origin cookie POSTs needs separate testing. Such callers may
continue to use Basic Auth. This implementation does not claim to resolve every
concern raised by the maintainer.

## Architecture and dependencies

- `LoxBerry::WebLogin`: private SQLite store, token hashing, credential checks,
  expiry, revocation, rate limits, and safe redirect destinations.
- `LoxBerry::WebLogin::Apache`: opt-in mod_perl access/authentication hooks and
  page handler. Existing CGI/PHP scripts remain CGI/PHP; they are not converted
  into persistent mod_perl scripts.
- Apache config selects the session auth type only for cookie requests without
  `Authorization`, avoiding hook-order dependence on mod_auth_basic.
- Additional Debian package: `libapache2-mod-perl2`. Perl DBI, DBD::SQLite,
  JSON::PP, Digest::SHA and URI::Escape must be present; `apache2-utils` supplies
  htpasswd. SQLite files live outside the document root in a 0700 directory,
  with a 0600 database. All code/plugins running as the LoxBerry Unix user remain
  in the same trust domain. This does not isolate malicious installed plugins.
- Login attempts are limited per username and client IP; existing Basic Auth
  traffic is not subject to the new limiter. Anonymous form sessions are bounded.
  Database failure denies session access while explicit Basic Auth remains usable.

## Reproduce locally (no running installation required)

From this checkout:

```sh
prove libs/perllib/t/weblogin.t
python3 testing/test_weblogin_apache.py
```

On Debian, select the Apache executable and modules directory:

```sh
LB_TEST_HTTPD=/usr/sbin/apache2 LB_TEST_MODULES=/usr/lib/apache2/modules python3 testing/test_weblogin_apache.py
```

The integration suite creates a temporary home, fictional password file,
self-signed TLS certificate, local proxy backend and Apache instance. It binds
only to 127.0.0.1 and removes its files on completion. Its test-only RemoteIP
header simulates an external client so the actual `Require local` rule can be
tested; that header is **not present in the feature configuration**. Run as an
ordinary user, not root. Apache/mod_perl and the Perl dependencies must be installed.

For visual inspection, `python3 testing/test_weblogin_apache.py --serve` prints
the TLS login and two HTTP **non-submitting static snapshots** for desktop and
390px mobile layout inspection. Those snapshots do not authenticate. Stop with
Ctrl-C. The fixture's self-signed certificate is for automated tests only.

## Enable on a separate staging LoxBerry

This is an explicit, manual opt-in; there is deliberately no automatic release
upgrade script yet. First back up the staging box, keep SSH access available,
and check the Apache/Perl versions, custom ports and plugin auth customizations.

1. Apply the source patch to a staging checkout based on upstream commit
   `2caa1e9d0853b84c3391131c4c3566515425bddb`, then deploy the changed source files
   using your normal staging workflow. Do not copy the test fixture into a live
   web root. LoxBerry's updater excludes `/system`, so explicitly install the
   new `system/apache2/conf-available/weblogin.conf` on staging.
2. Install/verify `libapache2-mod-perl2`, `libdbi-perl`, `libdbd-sqlite3-perl`,
   `liburi-perl` and `apache2-utils`. Enable `perl` in the actual Apache config
   directory used by LoxBerry (`a2enmod perl` on the usual Debian setup). Confirm
   it uses the existing prefork MPM and `loxberry` web user; do not switch MPMs.
3. Create `${LBHOMEDIR}/data/system/weblogin` owned by the Apache user/group with
   mode 0700. For the standard installation:

   ```sh
   install -d -o loxberry -g loxberry -m 0700 /opt/loxberry/data/system/weblogin
   ```

4. Ensure the box already serves HTTPS using a certificate trusted by the test
   browser. Choose one stable hostname/URL for password-manager matching. Define
   `LBLOGINORIGIN` before `weblogin.conf` is included, for example in an enabled
   `00-weblogin-origin.conf` containing:

   ```apache
   Define LBLOGINORIGIN https://loxberry.example
   ```

   Replace that example with the actual hostname. Include a non-default HTTPS
   port if used, omit `:443` for the default, and do not include a trailing slash.
   Do not trust arbitrary forwarded headers to decide the origin.
5. Enable the optional `weblogin` configuration. Run `apache2ctl configtest`
   before reloading Apache. If it fails, disable `weblogin` again before making
   any reload. No existing htaccess or terminal configuration is replaced.
6. Verify `/login`, both aliases, the core UI, installed plugins, terminal,
   Miniserver virtual outputs, wrong passwords, expiry, and logout. Test Basic
   clients both preemptively and with a 401 challenge/retry. Check that the new
   sidebar and mobile logout links are visible and functional.

## Rollback

Disable the `weblogin` configuration, run `apache2ctl configtest`, then reload
Apache. The original htaccess and terminal Basic Auth configuration were never
modified, so native authentication resumes. The conditional menu link disappears.
If removing source files, disable the configuration **before** removing modules.
Invalidate retained browser sessions before re-enabling after a rollback by
removing the disposable session database while the feature is disabled; it holds
sessions/rate limits only, not user credentials. Keep the existing htusers file.

## Validation and remaining release gates

Automated tests cover server-side session lifecycle and CSRF, real Apache with
and without the feature, Basic challenge/retry, unmodified POST bodies, both
aliases, CGI/plugin fixtures, protected static files, proxy terminal, HTTPS,
cookie attributes, origin/redirect validation, rate limiting, credential changes,
session replay/forgery/expiry, local compatibility and store failure.

Validated locally on macOS, Apache 2.4.67/mod_perl 2.0.12, Perl 5.34, SQLite,
plus PHP and JavaScript syntax checks. Desktop and mobile static renderings
were inspected in a browser, including the show/hide password control.

Before a release or live installation, still verify on Debian/LoxBerry hardware:

- Full core and installed-plugin UI, real PHP requests and Miniserver outputs.
- Actual autofill **and save/update prompts** in Bitwarden, 1Password and Apple
  Passwords, including iOS/Safari. HTML semantics were checked; password-manager
  extensions themselves were not exercised in this environment.
- Custom HTTP/HTTPS ports, trusted certificate setup, upgrade, restart, and rollback.
- Existing logged-in Basic Auth browser behavior, third-party AJAX/cross-origin
  flows, additional translations and maintainer review of the new dependency.

2FA is intentionally deferred at the user's request. It must not be bolted onto
the browser flow while leaving the same password usable through Basic Auth as
an unrestricted bypass. Any later MFA design needs separate machine credentials
or an explicit compatibility policy.
