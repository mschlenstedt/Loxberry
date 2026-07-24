# -*- coding: utf-8 -*-
"""
loxberry.web - Python port of the useful parts of LoxBerry::Web.

LoxBerry::Web is mostly about rendering the LoxBerry web interface with
HTML::Template (lbheader, lbfooter, pagestart, mslist_select_html,
loglist_html, ...). Those functions are specific to the Perl/PHP web frontend
and are intentionally NOT ported to Python (Python is used for daemons/CLI).

Ported here are the data functions that are also useful outside the web
frontend:

    iso_languages()   - available/known ISO languages
    get_plugin_icon() - web path to the current plugin's icon

For language phrases of your plugin use loxberry.system.readlanguage().
"""

from __future__ import annotations

import glob
import os

from . import system

__version__ = "4.0.0.1"


def get_plugin_icon(iconsize=64):
    """Return the web path to the current plugin's icon, or None.

    iconsize is snapped to 64/128/256/512. An icon.svg (if present) is
    preferred as it scales to any size.
    """
    if not system.lbpplugindir:
        return None

    if iconsize > 256:
        iconsize = 512
    elif iconsize > 128:
        iconsize = 256
    elif iconsize > 64:
        iconsize = 128
    else:
        iconsize = 64

    iconbase = "%s/images/icons/%s" % (system.lbshtmldir, system.lbpplugindir)
    iconbase_web = "/system/images/icons/%s" % system.lbpplugindir

    if os.path.exists("%s/icon.svg" % iconbase):
        return "%s/icon.svg" % iconbase_web

    logopath = "%s/icon_%d.png" % (iconbase, iconsize)
    if os.path.exists(logopath):
        return "%s/icon_%d.png" % (iconbase_web, iconsize)
    return None


def iso_languages(onlyavail=False, selection="values"):
    """Return the known ISO languages.

    onlyavail=True limits the result to languages for which a system language
    file (templates/system/lang/language_XX.ini) exists.

    selection="values" -> list of ISO 639-1 codes (in file order)
    selection="labels" -> dict {code: language name}
    """
    filename = "%s/languages.default" % system.lbsconfigdir
    content = system.read_file(filename)
    if content is None:
        return [] if selection == "values" else {}
    lines = content.split("\n")

    # Available system languages from the language_XX.ini files
    availlangs = []
    for path in glob.glob("%s/lang/language_*.ini" % system.lbstemplatedir):
        name = os.path.basename(path)
        name_noext = name.rsplit(".", 1)[0]
        if not name_noext.startswith("language_"):
            continue
        availlangs.append(name_noext[9:11])

    resultvals = []
    resultlabels = {}
    for i, line in enumerate(lines):
        if i == 0:          # skip CSV header
            continue
        if line == "":
            continue
        fields = line.split(";")
        if len(fields) < 6:
            continue
        iso1 = fields[4]
        langname = fields[5]
        if onlyavail and iso1 not in availlangs:
            continue
        resultlabels[iso1] = langname
        resultvals.append(iso1)

    return resultvals if selection == "values" else resultlabels
