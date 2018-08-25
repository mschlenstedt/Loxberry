#!/bin/bash

source $LBHOMEDIR/libs/bashlib/loxberry_log.sh

NAME=Test
PACKAGE=System
FILENAME=${LBSLOG}/test.log
#LOGDIR=${LBSLOG}
#APPEND=1
ADDTIME=1
#LOGLEVEL=3
#STDERR=1
#NOFILE=1

LOGSTART "Dies ist der Log Start"
LOGFILE=$FILENAME

LOGDEB "Loglevel: $LOGLEVEL"
LOGDEB "Logfile: $FILENAME"
FILENAME=${LBSTMPFSLOG}/test2.log
#APPEND=1
#ADDTIME=1
#LOGLEVEL=3
#STDERR=1
#NOFILE=1
LOGSTART "Log2 gestartet"
LOGFILE2=$FILENAME
ACTIVELOG=2
FILENAME=/dev/null
LOGDEB "Loglevel: $LOGLEVEL"
LOGDEB "Logfile: $FILENAME"
LOGEND "Ich habe 2 fertig"
ACTIVELOG=1
LOGINF "Dies ist eine Info Meldung"
LOGOK "Dies ist eine OK Meldung"
LOGWARN "Dies ist eine Warn Meldung"
LOGERR "Dies ist eine Error Meldung"
LOGCRIT "Dies ist eine Critical Meldung"
LOGALERT "Dies ist eine Alert Meldung"
LOGEMERGE "Dies ist eine Emergency Meldung"

LOGEND "Ich habe fertig"

if [ -n "$LOGFILE" ];then
	echo "Logfile 1 Inhalt:"
	cat $LOGFILE
fi

if [ -n "$LOGFILE2" ];then
	echo "Logfile 2 Inhalt:"
	cat $LOGFILE2
fi
