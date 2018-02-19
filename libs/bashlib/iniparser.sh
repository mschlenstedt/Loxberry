#!/bin/bash

# ini parser from https://www.joedog.org/2015/02/13/sh-script-ini-parser/
# and http://mark.aufflick.com/blog/2007/11/08/parsing-ini-files-with-sed

# Usage:
# iniparser <filename> "<section>"
# Example:
# iniparser $LBSCONFIG/general.cfg "BASE"

# http://www.loxwiki.eu/x/cA7L

iniparser() {
    INI_FILE=$1
    INI_SECTION=$2
    eval `sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
        -e 's/;.*$//' \
        -e 's/[[:space:]]*$//' \
        -e 's/^[[:space:]]*//' \
        -e "s/^\(.*\)=\([^\"']*\)$/$INI_SECTION\1=\"\2\"/" \
        < $INI_FILE \
        | sed -n -e "/^\[$INI_SECTION\]/,/^\s*\[/{/^[^;].*\=.*/p;}"`
}

