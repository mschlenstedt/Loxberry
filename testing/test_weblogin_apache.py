#!/usr/bin/env python3
"""Real, disposable Apache + TLS integration test. No LoxBerry installation used.

macOS: python3 testing/test_weblogin_apache.py
Debian: LB_TEST_HTTPD=/usr/sbin/apache2 LB_TEST_MODULES=/usr/lib/apache2/modules \
        python3 testing/test_weblogin_apache.py
Needs mod_perl, DBD::SQLite, htpasswd, openssl. Binds only to loopback.
"""
import base64
import contextlib
import grp
import http.client
import http.server
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import socket
import ssl
import sqlite3
import subprocess
import tempfile
import threading
import time
import sys
import unittest
from urllib.parse import urlencode

REPO = Path(__file__).resolve().parents[1]
PASSWORD = 'A long <test> & "quoted" password!42'


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


class Backend(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'terminal fixture')

    def log_message(self, *_):
        pass


class ApacheFixture:
    def __init__(self, enabled=True):
        self.enabled = enabled
        self.temp = tempfile.TemporaryDirectory(prefix='lb-weblogin-')
        self.root = Path(self.temp.name)
        self.port, self.http_port = free_port(), free_port()
        self.origin = f'https://127.0.0.1:{self.port}'
        self.httpd = os.getenv('LB_TEST_HTTPD', '/usr/sbin/httpd')
        self.modules = Path(os.getenv('LB_TEST_MODULES', '/usr/libexec/apache2'))
        self.htpasswd = shutil.which('htpasswd') or '/usr/bin/htpasswd'
        self.backend = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Backend)
        threading.Thread(target=self.backend.serve_forever, daemon=True).start()
        self.process = None

    def start(self):
        home = self.root / 'home'
        for part in ('data/system/weblogin', 'config/system', 'webfrontend/htmlauth/system', 'webfrontend/htmlauth/plugins/fixture'):
            (home / part).mkdir(parents=True, exist_ok=True)
        (home / 'data/system/weblogin').chmod(0o700)
        # Copy the small fixture instead of symlinking: macOS's system httpd
        # cannot read Documents under TCC, even when its parent Python process can.
        lib = home / 'libs/perllib/LoxBerry'
        lib.mkdir(parents=True)
        shutil.copy(REPO / 'libs/perllib/LoxBerry/WebLogin.pm', lib)
        shutil.copytree(REPO / 'libs/perllib/LoxBerry/WebLogin', lib / 'WebLogin')
        shutil.copytree(REPO / 'templates/system/weblogin', home / 'templates/system/weblogin')
        public = home / 'webfrontend/html/system'
        for folder, names in {'css': ['design-tokens.css', 'weblogin.css'], 'scripts': ['weblogin.js'], 'images': ['Logo_white_transparent.png', 'favicon.ico']}.items():
            (public / folder).mkdir(parents=True)
            for name in names:
                shutil.copy(REPO / 'webfrontend/html/system' / folder / name, public / folder / name)
        shutil.copy(REPO / 'system/apache2/conf-available/weblogin.conf', self.root / 'weblogin.conf')
        (home / 'config/system/general.json').write_text(json.dumps({'Base': {'Lang': 'nl'}}))
        self.home = home
        subprocess.run([self.htpasswd, '-ci', str(home / 'config/system/htusers.dat'), 'admin'], input=PASSWORD + '\n', text=True, check=True, capture_output=True)
        shutil.copy(REPO / 'webfrontend/htmlauth/.htaccess', home / 'webfrontend/htmlauth/.htaccess')
        probe = '#!/usr/bin/perl\nprint "Content-Type: text/plain\\n\\n"; print "user=$ENV{REMOTE_USER};type=$ENV{AUTH_TYPE};method=$ENV{REQUEST_METHOD};query=$ENV{QUERY_STRING};body="; print while <STDIN>;\n'
        for name in ('system/probe.cgi', 'plugins/fixture/run.cgi'):
            path = home / 'webfrontend/htmlauth' / name
            path.write_text(probe)
            path.chmod(0o755)
        (home / 'webfrontend/htmlauth/system/private.txt').write_text('protected static content')
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=localhost', '-keyout', str(self.root / 'key.pem'), '-out', str(self.root / 'cert.pem')], check=True, capture_output=True)
        modules = ['mpm_prefork', 'authn_core', 'authn_file', 'authz_core', 'authz_user', 'authz_host', 'auth_basic', 'alias', 'dir', 'mime', 'env', 'cgi', 'perl', 'socache_shmcb', 'ssl', 'proxy', 'proxy_http', 'remoteip', 'unixd']
        loads = []
        for name in modules:
            if name == 'perl' and not self.enabled:
                continue
            path = self.modules / f'mod_{name}.so'
            if path.exists():
                loads.append(f'LoadModule {name}_module "{path}"')
        terminal = (REPO / 'system/apache2/conf-available/shellinabox.conf').read_text().replace('127.0.0.1:64994', f'127.0.0.1:{self.backend.server_port}')
        (self.root / 'terminal.conf').write_text(terminal)
        feature_config = f'Include "{self.root}/weblogin.conf"\nPerlSetVar WebLoginHtpasswd "{self.htpasswd}"' if self.enabled else ''
        config = f'''
ServerRoot "{self.root}"
DefaultRuntimeDir "{self.root}"
Mutex file:{self.root} default
ServerName 127.0.0.1
PidFile "{self.root}/httpd.pid"
ErrorLog "{self.root}/error.log"
LogLevel warn
{chr(10).join(loads)}
User {pwd.getpwuid(os.getuid()).pw_name}
Group {grp.getgrgid(os.getgid()).gr_name}
StartServers 1
MinSpareServers 1
MaxSpareServers 2
MaxRequestWorkers 4
Listen 127.0.0.1:{self.port}
Listen 127.0.0.1:{self.http_port}
Define LBHOMEDIR "{home}"
Define LBLOGINORIGIN "{self.origin}"
TypesConfig /dev/null
AddType text/css .css
AddType application/javascript .js
DocumentRoot "{home}/webfrontend/html"
<Directory />
  Require all denied
  AllowOverride None
</Directory>
<Directory "{home}/webfrontend/html">
  Options FollowSymLinks
  Require all granted
</Directory>
Alias /admin/ "{home}/webfrontend/htmlauth/"
Alias /auth/ "{home}/webfrontend/htmlauth/"
<Directory "{home}/webfrontend/htmlauth">
  Options +ExecCGI +FollowSymLinks
  AddHandler cgi-script .cgi
  AllowOverride All
  Require all granted
</Directory>
# Simulate an external client for Require local, solely in this isolated fixture.
RemoteIPHeader X-WebLogin-Test-IP
RemoteIPTrustedProxy 127.0.0.1
Include "{self.root}/terminal.conf"
{feature_config}
<VirtualHost 127.0.0.1:{self.port}>
  SSLEngine On
  SSLCertificateFile "{self.root}/cert.pem"
  SSLCertificateKeyFile "{self.root}/key.pem"
</VirtualHost>
<VirtualHost 127.0.0.1:{self.http_port}>
</VirtualHost>
'''
        self.config = self.root / 'httpd.conf'
        self.config.write_text(config)
        checked = subprocess.run([self.httpd, '-t', '-f', str(self.config)], capture_output=True, text=True)
        if checked.returncode:
            raise RuntimeError(checked.stdout + checked.stderr)
        self.process = subprocess.Popen([self.httpd, '-f', str(self.config), '-DFOREGROUND'], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, start_new_session=True)
        for _ in range(100):
            if self.process.poll() is not None:
                raise RuntimeError(self.process.stderr.read().decode() + self.log())
            try:
                self.request('/login')
                return
            except (OSError, http.client.HTTPException):
                time.sleep(0.05)
        raise RuntimeError('Apache startup timed out: ' + self.log())

    def log(self):
        path = self.root / 'error.log'
        return path.read_text() if path.exists() else ''

    def request(self, path, method='GET', headers=None, body=None, tls=True, local=False):
        h = {'X-WebLogin-Test-IP': '192.0.2.10'} if not local else {}
        h.update(headers or {})
        if tls:
            conn = http.client.HTTPSConnection('127.0.0.1', self.port, context=ssl._create_unverified_context(), timeout=5)
        else:
            conn = http.client.HTTPConnection('127.0.0.1', self.http_port, timeout=5)
        conn.request(method, path, body, h)
        response = conn.getresponse()
        result = (response.status, dict(response.getheaders()), response.read().decode())
        conn.close()
        return result

    def login(self, password=PASSWORD, destination='/admin/system/probe.cgi'):
        status, headers, html = self.request('/login')
        assert status == 200, (status, html, self.log())
        cookie = headers['Set-Cookie'].split(';', 1)[0]
        csrf = re.search(r'name="csrf" value="([a-f0-9]+)"', html).group(1)
        body = urlencode({'csrf': csrf, 'username': 'admin', 'password': password, 'return': destination})
        result = self.request('/login', 'POST', {'Cookie': cookie, 'Origin': self.origin, 'Content-Type': 'application/x-www-form-urlencoded'}, body)
        return result, cookie, csrf

    def close(self):
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
            self.process.stderr.close()
        self.backend.shutdown()
        self.backend.server_close()
        self.temp.cleanup()


class WebLoginTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ApacheFixture()
        try:
            cls.server.start()
        except Exception:
            cls.server.close()
            raise

    @classmethod
    def tearDownClass(cls):
        cls.server.close()

    def setUp(self):
        self.s = self.server
        with sqlite3.connect(self.s.home / 'data/system/weblogin/sessions.sqlite') as db:
            db.execute('DELETE FROM attempts')

    def test_01_legacy_basic_challenge_and_body(self):
        status, h, _ = self.s.request('/admin/system/probe.cgi')
        self.assertEqual(status, 401)
        self.assertIn('Basic', h['WWW-Authenticate'])
        # A legacy machine may ask for HTML before retrying a 401 challenge.
        status, h, _ = self.s.request('/admin/system/probe.cgi', headers={'Accept': 'text/html'})
        self.assertEqual(status, 401)
        self.assertIn('Basic', h['WWW-Authenticate'])
        basic = 'Basic ' + base64.b64encode(('admin:' + PASSWORD).encode()).decode()
        for path in ('/admin/system/probe.cgi?key=value', '/auth/plugins/fixture/run.cgi', '/admin/system/private.txt', '/admin/system/tools/terminal/'):
            status, _, body = self.s.request(path, headers={'Authorization': basic})
            self.assertEqual(status, 200, (path, body, self.s.log()))
        status, _, body = self.s.request('/auth/plugins/fixture/run.cgi', 'POST', {'Authorization': basic, 'Content-Type': 'text/plain'}, 'original payload')
        self.assertEqual(status, 200)
        self.assertIn('body=original payload', body)
        self.assertIn('user=admin', body)
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Authorization': 'Basic eDp5'})[0], 401)

    def test_02_navigation_redirect_and_https(self):
        status, h, _ = self.s.request('/auth/plugins/fixture/run.cgi?q=1', headers={'Accept': 'text/html', 'Sec-Fetch-Mode': 'navigate'})
        self.assertEqual(status, 303)
        self.assertIn('/login?return=', h['Location'])
        self.assertNotIn('WWW-Authenticate', h)
        self.assertEqual(self.s.request('/login', tls=False)[1]['Location'], self.s.origin + '/login')
        self.assertEqual(self.s.request('/login', 'POST', tls=False)[0], 403)
        self.assertEqual(self.s.request('/', tls=False)[1]['Location'], self.s.origin + '/login')
        self.assertEqual(self.s.request('/index.html')[1]['Location'], self.s.origin + '/login')

    def test_03_real_login_aliases_plugin_static_terminal(self):
        (status, h, _), anon, _ = self.s.login()
        self.assertEqual(status, 303, self.s.log())
        self.assertEqual(h['Location'], '/admin/system/probe.cgi')
        cookie = h['Set-Cookie'].split(';', 1)[0]
        self.assertNotEqual(cookie, anon)
        for flag in ('Secure', 'HttpOnly', 'SameSite=Strict', 'Path=/'):
            self.assertIn(flag, h['Set-Cookie'])
        for path in ('/admin/system/probe.cgi', '/auth/system/probe.cgi', '/admin/plugins/fixture/run.cgi', '/admin/system/private.txt', '/admin/system/tools/terminal/'):
            status, _, body = self.s.request(path, headers={'Cookie': cookie})
            self.assertEqual(status, 200, (path, body, self.s.log()))
            if path.endswith('.cgi'):
                self.assertIn('user=admin;type=LoxBerrySession', body)
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': anon})[0], 401)

    def test_04_password_manager_form_and_no_js(self):
        status, h, html = self.s.request('/login')
        self.assertEqual(status, 200)
        self.assertIn('autocomplete="username"', html)
        self.assertIn('autocomplete="current-password"', html)
        self.assertIn('<form method="post" action="/login"', html)
        self.assertIn('Welkom terug', html)
        self.assertIn('no-store', h['Cache-Control'])
        self.assertIn("frame-ancestors 'none'", h['Content-Security-Policy'])
        self.assertEqual(self.s.login()[0][0], 303)  # Plain HTTP POST, no JS execution.

    def test_05_wrong_password_and_no_secret_echo(self):
        (status, h, html), _, _ = self.s.login(password='wrong <script>')
        self.assertEqual(status, 200)
        self.assertIn('onjuist', html)
        self.assertNotIn('wrong <script>', html)
        self.assertNotIn('WWW-Authenticate', h)
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': h['Set-Cookie'].split(';')[0]})[0], 401)

    def test_06_csrf_logout_and_replay(self):
        (_, h, _), anon, csrf = self.s.login()
        cookie = h['Set-Cookie'].split(';', 1)[0]
        self.assertEqual(self.s.request('/admin/system/probe.cgi', 'POST', {'Cookie': cookie, 'Origin': 'https://evil.example'}, 'x')[0], 403)
        status, _, body = self.s.request('/admin/system/probe.cgi', 'POST', {'Cookie': cookie, 'Origin': self.s.origin}, 'unchanged')
        self.assertEqual(status, 200)
        self.assertIn('body=unchanged', body)
        self.assertEqual(self.s.request('/login/logout', 'POST', {'Cookie': cookie, 'Origin': self.s.origin, 'Content-Type': 'application/x-www-form-urlencoded'}, 'csrf=wrong')[0], 403)
        _, _, html = self.s.request('/login/logout', headers={'Cookie': cookie})
        self.assertIn('Je bent ingelogd', html)  # GET does not log out.
        token = re.search(r'name="csrf" value="([a-f0-9]+)"', html).group(1)
        status, h, _ = self.s.request('/login/logout', 'POST', {'Cookie': cookie, 'Origin': self.s.origin, 'Content-Type': 'application/x-www-form-urlencoded'}, 'csrf=' + token)
        self.assertEqual(status, 303)
        self.assertIn('Max-Age=0', h['Set-Cookie'])
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie})[0], 401)
        replay = urlencode({'csrf': csrf, 'username': 'admin', 'password': PASSWORD})
        self.assertEqual(self.s.request('/login', 'POST', {'Cookie': anon, 'Origin': self.s.origin, 'Content-Type': 'application/x-www-form-urlencoded'}, replay)[0], 403)

    def test_07_forged_cookie_and_local_compatibility(self):
        forged = '__Host-LBSession=' + 'f' * 64
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': forged})[0], 401)
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': forged}, local=True)[0], 401)
        self.assertEqual(self.s.request('/admin/system/probe.cgi', local=True)[0], 200)
        (_, h, _), _, _ = self.s.login()
        cookie = h['Set-Cookie'].split(';')[0]
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie + '; ' + cookie})[0], 401)
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie}, tls=False)[0], 401)

    def test_08_bad_redirect_and_host_headers(self):
        result, _, _ = self.s.login(destination='https://evil.example/')
        self.assertEqual(result[1]['Location'], '/admin/system/index.cgi')
        status, h, _ = self.s.request('/login', headers={'Host': 'evil.example', 'X-Forwarded-Proto': 'https'})
        self.assertEqual(status, 303)
        self.assertEqual(h['Location'], self.s.origin + '/login')
        self.assertEqual(self.s.request('/login', headers={'X-Forwarded-Proto': 'https'}, tls=False)[0], 303)

    def test_09_password_change_revokes_session(self):
        (_, h, _), _, _ = self.s.login()
        cookie = h['Set-Cookie'].split(';')[0]
        users = self.s.home / 'config/system/htusers.dat'
        original = users.read_bytes()
        try:
            subprocess.run([self.s.htpasswd, '-i', str(users), 'admin'], input='changed password\n', text=True, check=True, capture_output=True)
            self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie})[0], 401)
        finally:
            users.write_bytes(original)

    def test_10_rate_limit(self):
        for _ in range(10):
            self.assertEqual(self.s.login(password='wrong')[0][0], 200)
        (status, h, _), _, _ = self.s.login()
        self.assertEqual(status, 429)
        self.assertEqual(h['Retry-After'], '300')

    def test_11_store_failure_is_closed(self):
        (_, h, _), _, _ = self.s.login()
        cookie = h['Set-Cookie'].split(';')[0]
        state = self.s.home / 'data/system/weblogin'
        state.chmod(0o755)
        try:
            self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie})[0], 503)
            self.assertEqual(self.s.request('/login')[0], 503)
            basic = 'Basic ' + base64.b64encode(('admin:' + PASSWORD).encode()).decode()
            self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Authorization': basic})[0], 200)
        finally:
            state.chmod(0o700)

    def test_12_form_csrf_and_malformed_input(self):
        for body in ('csrf=x', 'a=1&a=2', 'bad=%GG'):
            status, _, _ = self.s.request('/login', 'POST', {'Origin': self.s.origin, 'Content-Type': 'application/x-www-form-urlencoded'}, body)
            self.assertIn(status, (400, 403))
        self.assertEqual(self.s.request('/login', 'PUT')[0], 405)
        self.assertEqual(self.s.request('/login', 'POST', {'Origin': 'https://evil.example', 'Content-Type': 'application/x-www-form-urlencoded'}, '')[0], 403)
        _, h, _ = self.s.request('/login', method='HEAD')
        self.assertIn('no-store', h['Cache-Control'])

    def test_13_cookie_expiry_and_basic_precedence(self):
        (_, h, _), _, _ = self.s.login()
        cookie = h['Set-Cookie'].split(';')[0]
        with sqlite3.connect(self.s.home / 'data/system/weblogin/sessions.sqlite') as db:
            db.execute("UPDATE sessions SET expires = 0 WHERE user = 'admin'")
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie})[0], 401)
        self.assertEqual(self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie, 'Accept': 'text/html', 'Sec-Fetch-Mode': 'navigate'})[0], 303)
        basic = 'Basic ' + base64.b64encode(('admin:' + PASSWORD).encode()).decode()
        status, _, body = self.s.request('/admin/system/probe.cgi', headers={'Cookie': cookie, 'Authorization': basic})
        self.assertEqual(status, 200)
        self.assertIn('type=Basic', body)


class DisabledTests(unittest.TestCase):
    def test_disabled_configuration_keeps_native_auth(self):
        s = ApacheFixture(enabled=False)
        try:
            s.start()
            status, h, _ = s.request('/admin/system/probe.cgi', headers={'Accept': 'text/html'})
            self.assertEqual(status, 401)
            self.assertIn('Basic', h['WWW-Authenticate'])
            self.assertEqual(s.request('/login')[0], 404)
            self.assertEqual(s.request('/admin/system/probe.cgi', local=True)[0], 200)
        finally:
            s.close()


if __name__ == '__main__':
    if '--serve' in sys.argv:
        server = ApacheFixture()
        try:
            server.start()
            _, _, html = server.request('/login')
            # Static, non-submitting visual snapshot for browsers that reject the
            # disposable test certificate. The real login still requires HTTPS.
            preview = re.sub(r'name="csrf" value="[a-f0-9]+"', 'name="csrf" value="preview"', html)
            preview = preview.replace('action="/login"', 'action="#"').replace('type="submit"', 'type="button"')
            public = server.home / 'webfrontend/html'
            (public / 'preview.html').write_text(preview)
            (public / 'preview-mobile.html').write_text('<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><body style="margin:0;background:#e2e7df;display:grid;place-items:center;min-height:100vh"><iframe title="Mobile login preview" src="/preview.html" width="390" height="844" style="border:0"></iframe>')
            print('LOGIN_URL=' + server.origin + '/login', flush=True)
            print(f'PREVIEW_URL=http://127.0.0.1:{server.http_port}/preview.html', flush=True)
            print(f'MOBILE_URL=http://127.0.0.1:{server.http_port}/preview-mobile.html', flush=True)
            print('TEST_ACCOUNT=admin (password is the fictional PASSWORD constant in this file)', flush=True)
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        finally:
            server.close()
    else:
        unittest.main(verbosity=2)
