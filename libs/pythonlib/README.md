# LoxBerry Python Libraries

Python ports of the LoxBerry core libraries. The Perl libraries under
`libs/perllib/LoxBerry/` are the **master**; these ports mirror their public
API 1:1 (same function names, same dict keys) so code and knowledge carry over
between Perl, PHP and Python.

Supported Python versions: **3.9 (Bullseye), 3.11 (Bookworm), 3.13 (Trixie)**.
Only the Python standard library plus `requests` (already installed on
LoxBerry) is used.

## Using the libraries in a plugin

```python
from loxberry import system as lb

print(lb.lbhomedir)                # /opt/loxberry
print(lb.lbpconfigdir)             # config dir of the calling plugin (or None)

for msnr, ms in lb.get_miniservers().items():
    print(msnr, ms["Name"], ms["IPAddress"], ms["FullURI"])

if lb.is_enabled(some_value):
    ...

print(lb.currtime("file"))         # 20260716_193211
print(lb.plugin_version_compare("1.2.0", "1.2.0-beta1"))   # 1
```

## How the import works (`loxberry.pth`)

`install_pth.py` writes a file `loxberry.pth` into the `dist-packages`
directory of a python3 installation. That file contains one line — the path to
this directory — which Python appends to `sys.path` automatically at startup.
After that, `import loxberry` works from any script, with no boilerplate.

Install it for the system python3 (as root):

```bash
sudo python3 /opt/loxberry/libs/pythonlib/install_pth.py
```

On LoxBerry this is done automatically by the versioned core-update script
`sbin/loxberryupdate/update_v4.0.1.0.pl`, because a `.pth` file lives outside
the rsync-synced tree and must be (re)written for each python version — a distro
upgrade (Bullseye → Bookworm → Trixie) ships a new python that needs it again.

### Plugins running in their own venv

A virtualenv does not see the global `dist-packages` by default. Two options:

1. **Preferred** — create the venv with system site-packages:
   ```bash
   python3 -m venv --system-site-packages /opt/loxberry/data/plugins/<plugin>/venv
   ```
2. Or write the `.pth` into the venv:
   ```bash
   /opt/loxberry/data/plugins/<plugin>/venv/bin/python \
       /opt/loxberry/libs/pythonlib/install_pth.py
   ```
3. Or, as a last resort, prepend the path before importing:
   ```python
   import sys
   sys.path.insert(0, "/opt/loxberry/libs/pythonlib")
   from loxberry import system as lb
   ```

## Testing

Each function (group) has a standalone, runnable test script under `testing/`,
just like the Perl `testing/` directory — run them directly on a live LoxBerry:

```bash
python3 testing/testsystem.py
python3 testing/get_miniservers.py
python3 testing/currtime.py
python3 testing/version.py
```

### Perl ↔ Python parity test

`testing/libcompare_run.py` runs the Perl master emitter (`libcompare.pl`) and
the Python emitter (`libcompare.py`) on the live system and compares the JSON
output per test case (`@@name@@json` protocol, same as the existing Perl ↔ PHP
test):

```bash
python3 testing/libcompare_run.py        # PASS/FAIL table
python3 testing/libcompare_run.py -v     # also show the value of every PASS
```

## Scope

This first step ("Fundament") covers `LoxBerry::System`. Deferred to a later
step: `lock`/`unlock`, `check_securepin`, `set_clouddns` (CloudDNS resolution),
`diskspaceinfo`, `get_plugins` & friends, `execute`, `get_binaries`.
See `docs/superpowers/specs/2026-07-16-loxberry-system-python-port-design.md`.
