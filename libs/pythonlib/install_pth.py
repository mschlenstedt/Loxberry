#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
install_pth.py - Make the LoxBerry Python libraries importable system-wide.

Writes a `loxberry.pth` file into the site-packages / dist-packages directory
of the currently running python3. That file contains a single line pointing at
libs/pythonlib, so any Python program can simply do:

    from loxberry import system as lb

Run once (idempotent) for every python3 that should see the libraries. On
LoxBerry it is invoked by the versioned core-update script
sbin/loxberryupdate/update_vX.Y.Z.W.pl, because a .pth file lives OUTSIDE the
rsync-synced tree and is per Python version (a distro upgrade Bullseye ->
Bookworm -> Trixie brings a new python that needs the .pth written again).

Usage:
    python3 install_pth.py [--libdir /opt/loxberry/libs/pythonlib] [--print]

    --libdir   path to write into the .pth (default: this file's directory)
    --print    only print what would be done, do not write
"""

import argparse
import os
import site
import sys

PTH_NAME = "loxberry.pth"


def target_dirs():
    """Candidate site-packages dirs, most-preferred first."""
    dirs = []
    try:
        # Global dist-packages/site-packages (Debian: /usr/lib/python3/dist-packages)
        for d in site.getsitepackages():
            if d not in dirs:
                dirs.append(d)
    except Exception:
        pass
    # In a venv getsitepackages() already returns the venv path; as a fallback
    # add the user site so a non-root run still succeeds.
    usersite = site.getusersitepackages()
    if usersite and usersite not in dirs:
        dirs.append(usersite)
    return dirs


def pick_writable(dirs):
    for d in dirs:
        parent = d if os.path.isdir(d) else os.path.dirname(d)
        if os.path.isdir(d) and os.access(d, os.W_OK):
            return d
        # Try to create it (e.g. user site) if the parent is writable
        if not os.path.isdir(d) and parent and os.access(parent, os.W_OK):
            return d
    return None


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description="Install the loxberry.pth file.")
    ap.add_argument("--libdir", default=here,
                    help="path written into the .pth (default: %(default)s)")
    ap.add_argument("--print", dest="dry", action="store_true",
                    help="only print, do not write")
    args = ap.parse_args()

    libdir = os.path.abspath(args.libdir)
    dirs = target_dirs()

    print("python:   %s (%s)" % (sys.executable, sys.version.split()[0]))
    print("libdir:   %s" % libdir)
    print("site-dirs: %s" % ", ".join(dirs) if dirs else "(none found)")

    target = pick_writable(dirs)
    if target is None:
        print("ERROR: no writable site-packages directory found. Run as root "
              "for the global dist-packages, or use a venv.", file=sys.stderr)
        return 2

    pth_path = os.path.join(target, PTH_NAME)
    if args.dry:
        print("Would write: %s -> %s" % (pth_path, libdir))
        return 0

    # Idempotent: only rewrite if content differs.
    want = libdir + "\n"
    try:
        with open(pth_path, "r", encoding="utf-8") as fh:
            if fh.read() == want:
                print("Already up to date: %s" % pth_path)
                return 0
    except OSError:
        pass

    try:
        os.makedirs(target, exist_ok=True)
        with open(pth_path, "w", encoding="utf-8") as fh:
            fh.write(want)
    except OSError as exc:
        print("ERROR: could not write %s: %s" % (pth_path, exc), file=sys.stderr)
        return 2

    print("Wrote: %s -> %s" % (pth_path, libdir))
    return 0


if __name__ == "__main__":
    sys.exit(main())
