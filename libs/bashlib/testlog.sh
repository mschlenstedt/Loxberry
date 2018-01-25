#!/bin/bash

source $LBHOMEDIR/libs/bashlib/loxberry_log.sh

NAME=Test
PACKAGE=System
FILENAME=${LBSLOG}/test.log
#ADDTIME=1
#LOGLEVEL=3
#STDERR=1
NOFILE=1

LOGSTART "Dies ist der Log Start"
LOGFILE=$FILENAME

LOGDEB "Loglevel: $LOGLEVEL"
LOGDEB "Logfile: $FILENAME"
LOGINF "Dies ist eine Info Meldung"
LOGOK "Dies ist eine OK Meldung"
LOGWARN "Dies ist eine Warn Meldung"
LOGERR "Dies ist eine Error Meldung"
LOGCRIT "Dies ist eine Critical Meldung"
LOGALERT "Dies ist eine Alert Meldung"
LOGEMERGE "Dies ist eine Emergency Meldung"

LOGEND "Ich habe fertig"

echo "Logfile Inhalt:"
cat $LOGFILE
