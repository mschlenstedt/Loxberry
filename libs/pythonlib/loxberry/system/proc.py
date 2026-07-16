# -*- coding: utf-8 -*-
"""
loxberry.system.proc - process / system interaction helpers.

Python port of execute, lock, unlock, diskspaceinfo and check_securepin from
the Perl master LoxBerry::System (System.pm). These functions are Linux/
LoxBerry specific (/proc, /var/lock, df, sudo credentialshandler).
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import time

from . import core

# Characters that make Perl's exec() use a shell. If the command contains none
# of them, Perl exec()s the program directly - important for "pgrep -f <pat>",
# which must NOT run under a shell wrapper (otherwise pgrep -f matches the
# wrapper's command line and returns a false positive).
_SHELL_META = re.compile(r"[|&;<>()$`\"'\\*?\[\]{}~\n]")


# ---------------------------------------------------------------------------
# execute  (System.pm lines 1709-1839)
# ---------------------------------------------------------------------------
def execute(command=None, log=None, intro=None, ok=None, error=None,
            warn=None, okcode=0, ignoreerrors=False):
    """Execute a shell command.

    Returns a tuple (exitcode, output, error). Unlike the Perl version - which
    returns only stdout in scalar context - Python always returns the 3-tuple;
    unpack or index as needed, e.g. rc, out, err = execute("...").

    A command WITHOUT shell metacharacters is run directly (no shell wrapper),
    matching Perl's exec() behaviour; commands WITH metacharacters run via
    /bin/sh -c.
    """
    if command is None:
        raise ValueError("execute: argument command missing")

    uselog = False
    if log is not None and hasattr(log, "INF"):
        uselog = True
        if intro is None:
            intro = "Executing command '%s'..." % command
        if ok is None:
            ok = "Command executed successfully."
        if error is None and warn is None:
            error = "ERROR executing command"
        log.INF(intro)

    output = ""
    errout = ""
    try:
        if _SHELL_META.search(command):
            proc = subprocess.run(command, shell=True, executable="/bin/sh",
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            proc = subprocess.run(shlex.split(command),
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        exitcode = proc.returncode
        output = proc.stdout.decode("utf-8", "replace")
        errout = proc.stderr.decode("utf-8", "replace")
    except FileNotFoundError:
        exitcode = 127
        errout = "execute: Cannot execute command\n"
    except OSError as exc:
        exitcode = 127
        errout = "execute: %s\n" % exc

    if uselog:
        out = output.rstrip("\n")
        err = errout.rstrip("\n")
        if exitcode == okcode or ignoreerrors:
            log.OK("%s - Exitcode %s" % (ok, exitcode))
            if hasattr(log, "DEB"):
                log.DEB(out)
                if err != "":
                    log.DEB(err)
        elif warn is not None:
            log.WARN("%s - Exitcode %s" % (warn, exitcode))
            if out != "":
                log.WARN(out)
            if err != "":
                log.WARN(err)
        else:
            log.ERR("%s - Exitcode %s" % (error, exitcode))
            if out != "":
                log.ERR(out)
            if err != "":
                log.ERR(err)

    return (exitcode, output, errout)


# ---------------------------------------------------------------------------
# lock / unlock  (System.pm lines 1342-1524)
# ---------------------------------------------------------------------------
def unlock(lockfile=None):
    """Remove a lock file. Returns None on success, or a reason string."""
    lockfilename = "/var/lock/%s.lock" % lockfile
    if os.path.exists(lockfilename):
        try:
            os.unlink(lockfilename)
        except OSError as exc:
            return "%s: Cannot delete lock file - %s" % (lockfile, exc)
    return None


def lock(lockfile=None, wait=0):
    """Set a LoxBerry-consistent lock. Returns None if ok, else a reason string.

    Waits (up to `wait` seconds) while apt/dpkg or a listed lock is active. A
    `wait` between 1 and 4 is raised to 5.
    """
    if wait and wait < 5:
        wait = 5

    importantfile = "%s/lockfiles.default" % core.lbsconfigdir
    content = core.read_file(importantfile)
    if content is None:
        return "Error opening important lock files list"
    data = [line for line in content.split("\n")]
    if lockfile:
        data.append(lockfile)

    seemsrunning = 0
    delay = 0
    while True:
        seemsrunning = 0

        # apt-get / dpkg / unattended-upgrade activity (pgrep/fuser exitcode 0 = found)
        rc_apt = execute('pgrep "apt-get|apt"')[0]
        rc_dpkg = execute('pgrep "dpkg"')[0]
        rc_unattended = execute('pgrep -f /usr/bin/unattended-upgrade')[0]
        rc_dpkg_lock = execute('fuser /var/lib/dpkg/lock')[0]
        rc_dpkg_frontend = execute('fuser /var/lib/dpkg/lock-frontend')[0]
        rc_apt_archives = execute('fuser /var/cache/apt/archives/lock')[0]

        if 0 in (rc_apt, rc_dpkg, rc_unattended, rc_dpkg_lock,
                 rc_dpkg_frontend, rc_apt_archives):
            if rc_unattended == 0:
                seemsrunning = "unattended-upgrade"
            if rc_apt == 0 or rc_dpkg == 0 or rc_dpkg_lock == 0 \
                    or rc_dpkg_frontend == 0 or rc_apt_archives == 0:
                seemsrunning = "apt, apt-get or dpkg"
            if wait:
                time.sleep(5)
                delay += 5

        # Check lock files
        for lf in data:
            lf = core.trim(lf)
            if not lf:
                continue
            lockfilename = "/var/lock/%s.lock" % lf
            if not os.path.exists(lockfilename):
                continue
            pid = core.trim(core.read_file(lockfilename) or "")
            if not pid:
                # empty PID file -> orphaned
                if unlock(lockfile=lf):
                    seemsrunning = lf
                    if not wait:
                        return "%s: Cannot unlock %s" % (lf, lockfile)
                else:
                    continue
            elif os.path.isdir("/proc/%s" % pid):
                # PID running
                if not wait:
                    return lf
                seemsrunning = lf
            else:
                # PID not running -> orphaned
                if unlock(lockfile=lf):
                    seemsrunning = lf
                    if not wait:
                        return "%s: Cannot unlock %s" % (lf, lockfile)
                else:
                    continue
            if seemsrunning and wait:
                time.sleep(5)
                delay += 5

        if not (seemsrunning and wait and delay < wait):
            break

    if seemsrunning:
        return seemsrunning

    # Set own lock file
    if lockfile:
        lockfilename = "/var/lock/%s.lock" % lockfile
        while True:
            try:
                with open(lockfilename, "w", encoding="utf-8") as fh:
                    fh.write("%d" % os.getpid())
            except OSError as exc:
                if not wait:
                    return "%s: %s" % (lockfile, exc)
            else:
                try:
                    import pwd

                    pw = pwd.getpwnam("loxberry")
                    os.chown(lockfilename, pw.pw_uid, pw.pw_gid)
                    os.chmod(lockfilename, 0o666)
                except Exception:
                    pass
                return None
            if not wait:
                time.sleep(5)
            delay += 5
            if delay >= wait:
                break
        return lockfile

    return None


# ---------------------------------------------------------------------------
# diskspaceinfo  (System.pm lines 1263-1326)
# ---------------------------------------------------------------------------
def _df(fields, folder):
    cmd = ["df", "--output=%s" % fields]
    if folder:
        cmd.append(folder)
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError:
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout.decode("utf-8", "replace").split("\n")


def diskspaceinfo(folder=None):
    """Return disk usage info.

    With a folder: returns a single dict for that folder's filesystem.
    Without a folder: returns a dict keyed by mountpoint, each a dict.
    Returns None on error.
    """
    outarr = _df("size,used,avail,pcent", folder)
    outarr_mp = _df("target", folder)
    outarr_src = _df("source", folder)
    if outarr is None or outarr_mp is None or outarr_src is None:
        return None

    disklist = {}
    idx = 1
    for linenr, line in enumerate(outarr):
        if linenr == 0:
            continue
        if line.strip() == "":
            continue
        fs = outarr_src[idx] if idx < len(outarr_src) else None
        mountpoint = outarr_mp[idx] if idx < len(outarr_mp) else None
        line = core.trim(line)
        line = re.sub(r" +", " ", line)
        parts = line.split(" ", 3)
        while len(parts) < 4:
            parts.append(None)
        size, used, available, usedpercent = parts[0], parts[1], parts[2], parts[3]
        diskhash = {
            "filesystem": fs,
            "size": size,
            "used": used,
            "available": available,
            "usedpercent": usedpercent,
            "mountpoint": mountpoint,
        }
        if folder:
            return diskhash
        disklist[mountpoint] = diskhash
        idx += 1
    return disklist


# ---------------------------------------------------------------------------
# check_securepin  (System.pm lines 1139-1223)
# Returns None if the PIN is correct, or an error code (1 = wrong, 3 = locked).
# ---------------------------------------------------------------------------
def check_securepin(securepin):
    pinerror_file = "%s/log/system_tmpfs/securepin.errors" % core.lbhomedir

    if os.path.exists(pinerror_file):
        pinerr = {}
        raw = core.read_file(pinerror_file)
        if raw:
            try:
                pinerr = json.loads(raw) or {}
            except ValueError:
                pinerr = {}
        if pinerr.get("locked"):
            if time.time() < (pinerr["locked"] + 5 * 60):
                time.sleep(3)
                return 3
            else:
                pinerr.pop("locked", None)
                pinerr.pop("failure_count", None)
                core.write_file(pinerror_file, json.dumps(pinerr))

    try:
        proc = subprocess.run(
            ["sudo", "%s/credentialshandler.pl" % core.lbssbindir,
             "checksecurepin", str(securepin)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        rc = proc.returncode
    except OSError:
        rc = 1

    if rc == 0:
        # OK
        try:
            os.unlink(pinerror_file)
        except OSError:
            pass
        return None

    # Not equal - brute-force counter
    pinerr = {}
    raw = core.read_file(pinerror_file)
    if raw:
        try:
            pinerr = json.loads(raw) or {}
        except ValueError:
            pinerr = {}
    if not pinerr.get("failure_count"):
        pinerr["failure_count"] = 0
    time.sleep(pinerr["failure_count"])
    pinerr["failure_count"] += 1
    if not pinerr.get("failure_time"):
        pinerr["failure_time"] = int(time.time())
    if pinerr["failure_count"] > 5:
        pinerr["locked"] = int(time.time())
        core.write_file(pinerror_file, json.dumps(pinerr))
        return 3
    core.write_file(pinerror_file, json.dumps(pinerr))
    return 1
